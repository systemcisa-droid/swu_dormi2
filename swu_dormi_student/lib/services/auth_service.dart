import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      UserModel newUser = UserModel(
        uid: userCredential.user!.uid,
        email: email,
        name: name,
        roomNumber: '000', // 기본값
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(newUser.toMap());

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
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
    batch.set(studentIdRef, {'uid': uid});
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
