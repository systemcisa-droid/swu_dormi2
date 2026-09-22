import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

class GoogleSignInResult {
  final UserCredential userCredential;
  final bool isNewUser;

  const GoogleSignInResult({required this.userCredential, required this.isNewUser});
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  // email 아이디 부분(@swu.ac.kr 앞)이 곧 학번이므로, 구글 가입자와 동일한 학번
  // 중복 방지 규칙(student_ids 컬렉션)을 이메일 가입에도 동일하게 적용한다.
  Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    // Firebase 클라이언트 SDK의 email-already-in-use 에러는 "이메일+비밀번호"
    // 수단이 이미 있을 때만 발생하고, 구글로만 가입된 이메일은 걸러내지 못한다.
    // (프로젝트의 이메일 열거 보호 설정 때문에 클라이언트에서 직접 조회도 신뢰할 수 없어
    //  Admin SDK를 쓰는 Cloud Function으로 사전 확인한다.)
    await _ensureNoExistingGoogleAccount(email);

    final studentId = email.split('@').first;
    final studentIdRef = _firestore.collection('student_ids').doc(studentId);

    // 관리프로그램이 올린 사생 명단에 없는 학번은 가입시키지 않는다.
    if (!await isStudentIdInRoster(studentId)) {
      throw Exception(studentIdNotInRosterMessage);
    }

    // 계정 생성 전에 먼저 확인해 대부분의 중복을 걸러낸다.
    // (동시 가입 레이스는 아래 계정 생성 후 재확인 + 롤백으로 최종 방어한다.)
    if ((await studentIdRef.get()).exists) {
      throw Exception('이미 동일한 학번으로 가입된 계정이 존재합니다.');
    }

    UserCredential? userCredential;
    try {
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = userCredential.user!.uid;

      // Create user document in Firestore
      UserModel newUser = UserModel(
        uid: uid,
        email: email,
        name: name,
        studentId: studentId,
        roomNumber: '000', // 기본값
        createdAt: DateTime.now(),
      );

      // users 문서와 student_ids 문서를 하나의 트랜잭션으로 함께 생성해
      // 두 컬렉션 간 데이터 불일치와 동시 가입으로 인한 학번 중복을 함께 방지한다.
      await _firestore.runTransaction((tx) async {
        final duplicateDoc = await tx.get(studentIdRef);
        if (duplicateDoc.exists) {
          throw Exception('이미 동일한 학번으로 가입된 계정이 존재합니다.');
        }
        tx.set(_firestore.collection('users').doc(uid), newUser.toMap());
        // provider: 이 학번이 어떤 수단으로 가입했는지 구분 (G=구글, A=애플, E=이메일)
        tx.set(studentIdRef, {'uid': uid, 'provider': 'E'});
      });

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      // 트랜잭션에서 학번 중복이 뒤늦게 발견된 경우, 이미 만들어진 Auth 계정을 정리한다.
      if (userCredential?.user != null) {
        await userCredential!.user!.delete();
      }
      rethrow;
    }
  }

  // 동일 이메일로 구글 계정이 이미 존재하면 예외를 던진다.
  // Cloud Function 호출이 실패해도(네트워크 오류 등) 가입 자체를 막지는 않는다 —
  // 이 경우 실제 중복은 Firebase Auth의 email-already-in-use로 최종 검증된다.
  Future<void> _ensureNoExistingGoogleAccount(String email) async {
    try {
      final result = await _functions
          .httpsCallable('checkEmailSignInMethods')
          .call({'email': email});
      final data = result.data as Map<dynamic, dynamic>;
      final providers = (data['providers'] as List<dynamic>? ?? [])
          .map((p) => p.toString())
          .toList();
      if (providers.contains('google.com')) {
        throw Exception('이미 구글 계정으로 가입된 이메일입니다. 구글 로그인을 이용해주세요.');
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('구글 가입 여부 확인 실패(무시하고 진행): ${e.message}');
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // 학번 중복 여부를 조회한다. true면 사용 가능(중복 없음).
  // student_ids/{studentId} 문서 존재 여부만 확인하므로 로그인 전(미인증) 상태에서도 호출 가능하다.
  Future<bool> isStudentIdAvailable(String studentId) async {
    final doc = await _firestore
        .collection('student_ids')
        .doc(studentId)
        .get()
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw Exception('네트워크 상황을 확인해주세요'),
        );
    return !doc.exists;
  }

  static const studentIdNotInRosterMessage =
      '입력한 학번이 기숙사 사생 명단에 없습니다. 학번을 확인해주세요.';

  // 관리프로그램이 사생 기본 정보 엑셀을 올릴 때 갱신하는 student_roster/{studentId} 명단에
  // 이 학번이 있는지 확인한다. true면 가입 가능. 문서 존재 여부만 보므로 미인증 상태에서도 호출 가능하다.
  // 명단이 아직 한 번도 올라오지 않았으면(_meta 없음 또는 0건) 검사를 건너뛰어 가입을 막지 않는다.
  Future<bool> isStudentIdInRoster(String studentId) async {
    final col = _firestore.collection('student_roster');
    final meta = await col.doc('_meta').get().timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw Exception('네트워크 상황을 확인해주세요'),
        );
    final count = (meta.data()?['count'] as num?)?.toInt() ?? 0;
    if (!meta.exists || count == 0) return true;
    final doc = await col.doc(studentId).get().timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw Exception('네트워크 상황을 확인해주세요'),
        );
    return doc.exists;
  }

  // Sign in with Google (학번 입력과 완전히 분리됨)
  // 반환된 GoogleSignInResult.isNewUser가 true면, 아직 users 문서가 없는 신규 가입자이므로
  // 화면에서 학번 입력 페이지로 이동시켜 registerStudentId를 호출해야 한다.
  Future<GoogleSignInResult?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // 사용자가 취소함

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user == null) return GoogleSignInResult(userCredential: userCredential, isNewUser: false);

    final doc = await _firestore.collection('users').doc(user.uid).get();
    return GoogleSignInResult(userCredential: userCredential, isNewUser: !doc.exists);
  }

  // 구글 신규 가입자의 학번을 등록한다. 학번 중복 시 예외를 던지고 로그인 세션도 정리한다.
  Future<void> registerStudentId({required String uid, required String studentId}) async {
    final studentIdRef = _firestore.collection('student_ids').doc(studentId);
    final duplicateDoc = await studentIdRef.get();
    if (duplicateDoc.exists) {
      throw Exception('이미 동일한 학번으로 가입된 계정이 존재합니다.');
    }

    final displayName = _auth.currentUser?.displayName ?? '';
    final newUser = UserModel(
      uid: uid,
      email: '$studentId@swu.ac.kr',
      name: displayName,
      studentId: studentId,
      roomNumber: '000',
      createdAt: DateTime.now(),
    );
    // users 문서와 student_ids 문서를 하나의 배치로 함께 생성해
    // 두 컬렉션 간 데이터 불일치(예: users만 생성되고 student_ids가 누락되는 상황)를 방지한다.
    final batch = _firestore.batch();
    batch.set(_firestore.collection('users').doc(uid), newUser.toMap());
    // provider: 이 학번이 어떤 수단으로 가입했는지 구분 (G=구글, A=애플, E=이메일)
    batch.set(studentIdRef, {'uid': uid, 'provider': 'G'});
    await batch.commit();
  }

  // 학번 입력 페이지에서 사용자가 뒤로가기/취소한 경우, 만들어진 Firebase Auth 계정을 정리한다.
  // (users 문서가 없으므로 다음 로그인 시 다시 신규 가입 흐름을 타게 된다.)
  Future<void> cancelPendingGoogleSignUp() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Get user data from Firestore
  Future<UserModel?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user data: $e');
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    required String uid,
    String? name,
    String? phoneNumber,
    String? profileImageUrl,
  }) async {
    try {
      Map<String, dynamic> updates = {};
      if (name != null) updates['name'] = name;
      if (phoneNumber != null) updates['phoneNumber'] = phoneNumber;
      if (profileImageUrl != null) updates['profileImageUrl'] = profileImageUrl;

      await _firestore.collection('users').doc(uid).update(updates);
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  // Block a user
  Future<void> blockUser({required String myUid, required String targetUid}) async {
    await _firestore.collection('users').doc(myUid).update({
      'blockedUsers': FieldValue.arrayUnion([targetUid]),
    });
  }

  // Unblock a user
  Future<void> unblockUser({required String myUid, required String targetUid}) async {
    await _firestore.collection('users').doc(myUid).update({
      'blockedUsers': FieldValue.arrayRemove([targetUid]),
    });
  }

  // 현재 로그인이 Google 계정으로 이루어졌는지 여부.
  // (users 문서에 password가 없으므로 화면에서 비밀번호 입력란 대신 재인증 버튼을 보여줘야 한다.)
  bool get isGoogleSignedIn =>
      _auth.currentUser?.providerData.any((p) => p.providerId == 'google.com') ?? false;

  // Delete account and all user data
  // 이메일/비밀번호 계정은 password로, Google 계정은 password 없이(구글 재인증 팝업으로) 재인증한다.
  Future<void> deleteAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('로그인 상태가 아닙니다.');
    final wasGoogleSignedIn = isGoogleSignedIn;

    if (wasGoogleSignedIn) {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('본인 확인이 취소되었습니다.');
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
    } else {
      if (password == null || password.isEmpty) {
        throw Exception('비밀번호를 입력해주세요.');
      }
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final studentId = userDoc.data()?['studentId'] as String?;

    final batch = _firestore.batch();
    batch.delete(_firestore.collection('users').doc(user.uid));
    if (studentId != null && studentId.isNotEmpty) {
      batch.delete(_firestore.collection('student_ids').doc(studentId));
    }
    await batch.commit();

    await user.delete();
    if (wasGoogleSignedIn) {
      await _googleSignIn.signOut();
    }
  }

  // Handle authentication exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return '비밀번호가 너무 약합니다.';
      case 'email-already-in-use':
        return '이미 사용 중인 이메일입니다.';
      case 'invalid-email':
        return '유효하지 않은 이메일 주소입니다.';
      case 'user-not-found':
        return '사용자를 찾을 수 없습니다.';
      case 'wrong-password':
        return '비밀번호를 확인하세요';
      case 'invalid-credential':
        return '비밀번호를 확인하세요';
      case 'user-disabled':
        return '비활성화된 계정입니다.';
      case 'too-many-requests':
        return '너무 많은 요청이 발생했습니다. 잠시 후 다시 시도해주세요.';
      default:
        return '인증 오류가 발생했습니다: ${e.message}';
    }
  }
}
