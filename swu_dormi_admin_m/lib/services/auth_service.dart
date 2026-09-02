import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 현재 사용자 가져오기
  User? get currentUser => _auth.currentUser;

  // 인증 상태 변화 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 관리자 로그인
  Future<UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 관리자 권한 확인
      final userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (userDoc.exists &&
          userDoc.data()?['role'] != 'admin' &&
          userDoc.data()?['role'] != 'admin_m') {
        await _auth.signOut();
        throw Exception('관리자 권한이 없습니다.');
      }

      // 이용약관 위반으로 정지된 계정 차단 (App Store 가이드라인 1.2)
      if (userDoc.exists && userDoc.data()?['disabled'] == true) {
        await _auth.signOut();
        throw Exception('이 계정은 이용약관 위반으로 이용이 정지되었습니다.\n문의: dormitory@swu.ac.kr');
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = '사용자를 찾을 수 없습니다.';
          break;
        case 'wrong-password':
        // 최신 Firebase 는 비밀번호 오류에도 invalid-credential 을 반환한다.
        case 'invalid-credential':
          errorMessage = '비밀번호를 확인해주세요';
          break;
        case 'invalid-email':
          errorMessage = '유효하지 않은 이메일 주소입니다.';
          break;
        case 'user-disabled':
          errorMessage = '비활성화된 계정입니다.';
          break;
        default:
          errorMessage = '로그인 중 오류가 발생했습니다: ${e.message}';
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('로그인 중 오류가 발생했습니다: $e');
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('로그아웃 중 오류가 발생했습니다: $e');
    }
  }

  // 관리자 회원가입
  Future<UserCredential?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      return userCredential;
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = '이미 사용 중인 이메일입니다.';
          break;
        case 'invalid-email':
          errorMessage = '유효하지 않은 이메일 주소입니다.';
          break;
        case 'weak-password':
          errorMessage = '비밀번호가 너무 약합니다.';
          break;
        default:
          errorMessage = '계정 생성 중 오류가 발생했습니다: ${e.message}';
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('계정 생성 중 오류가 발생했습니다: $e');
    }
  }

  // 관리자 계정 생성 (초기 설정용)
  Future<UserCredential?> createAdminAccount({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Firestore에 관리자 정보 저장
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': email,
        'name': name,
        'role': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return userCredential;
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = '이미 사용 중인 이메일입니다.';
          break;
        case 'invalid-email':
          errorMessage = '유효하지 않은 이메일 주소입니다.';
          break;
        case 'weak-password':
          errorMessage = '비밀번호가 너무 약합니다.';
          break;
        default:
          errorMessage = '계정 생성 중 오류가 발생했습니다: ${e.message}';
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('계정 생성 중 오류가 발생했습니다: $e');
    }
  }

  // 비밀번호 재설정
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = '사용자를 찾을 수 없습니다.';
          break;
        case 'invalid-email':
          errorMessage = '유효하지 않은 이메일 주소입니다.';
          break;
        default:
          errorMessage = '비밀번호 재설정 이메일 전송 중 오류가 발생했습니다: ${e.message}';
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('비밀번호 재설정 이메일 전송 중 오류가 발생했습니다: $e');
    }
  }

  // ── 사용자 차단 (App Store 가이드라인 1.2) ──

  /// 차단한 사용자 uid 목록을 가져온다.
  Future<List<String>> getBlockedUsers() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];
    final doc = await _firestore.collection('users').doc(uid).get();
    return List<String>.from(doc.data()?['blockedUsers'] ?? []);
  }

  /// 사용자를 차단한다. 차단하면 해당 사용자의 메시지가 즉시 보이지 않는다.
  Future<void> blockUser(String targetUid) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다.');
    await _firestore.collection('users').doc(uid).update({
      'blockedUsers': FieldValue.arrayUnion([targetUid]),
    });
  }

  /// 차단을 해제한다.
  Future<void> unblockUser(String targetUid) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다.');
    await _firestore.collection('users').doc(uid).update({
      'blockedUsers': FieldValue.arrayRemove([targetUid]),
    });
  }

  /// 현재 로그인한 계정이 이용 정지 상태인지 확인한다.
  /// 관리자가 신고 처리 중 이용 정지시킨 경우 앱 접속을 막기 위해 사용한다.
  Future<bool> isCurrentUserDisabled() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data()?['disabled'] == true;
    } catch (_) {
      // 네트워크 오류 시에는 접속을 막지 않는다.
      return false;
    }
  }
}
