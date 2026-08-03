import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  static const String _cachedUserKey = 'cached_user_data';

  final AuthService _authService = AuthService();
  StreamSubscription<User?>? _authSubscription;
  UserModel? _currentUser;
  bool _isLoading = true;
  // Firebase Auth 로그인은 성공했지만 아직 users 문서가 없는(학번 미입력) 신규 가입자의 uid.
  // null이 아니면 화면은 학번 입력 페이지를 보여줘야 한다.
  String? _pendingGoogleUid;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  String? get pendingGoogleUid => _pendingGoogleUid;

  AuthProvider() {
    _initAuth();
  }

  Future<UserModel?> _loadCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cachedUserKey);
      if (cached != null) {
        return UserModel.fromMap(jsonDecode(cached) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveUserToCache(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedUserKey, jsonEncode(user.toMap()));
    } catch (_) {}
  }

  Future<void> _clearUserCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedUserKey);
    } catch (_) {}
  }

  void _initAuth() {
    _authSubscription = _authService.authStateChanges.listen((User? user) async {
      if (user != null) {
        try {
          final fetched = await _authService.getUserData(user.uid);
          if (fetched != null) {
            _currentUser = fetched;
            _pendingGoogleUid = null;
            await _saveUserToCache(fetched);
          } else {
            // Firestore 문서가 없으면 캐시에서 먼저 복원을 시도한다.
            final cached = await _loadCachedUser();
            if (cached != null) {
              _currentUser = cached;
            } else {
              // 캐시도 없다면 학번을 아직 입력하지 않은 신규 가입자로 간주해
              // 화면이 학번 입력 페이지로 이동하도록 상태를 남긴다.
              _currentUser = null;
              _pendingGoogleUid = user.uid;
            }
          }
        } catch (_) {
          // 네트워크 오류 등 → 캐시에서 복원
          _currentUser = await _loadCachedUser();
        }
      } else {
        _currentUser = null;
        _pendingGoogleUid = null;
        await _clearUserCache();
      }
      _isLoading = false;
      notifyListeners();
    }, onError: (_) {
      _isLoading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<String?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      await _authService.signUpWithEmail(
        email: email,
        password: password,
        name: name,
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      if (credential?.user != null) {
        final userData = await _authService.getUserData(credential!.user!.uid);
        if (userData == null || userData.role != 'student') {
          await _authService.signOut();
          return '학생 계정만 로그인할 수 있습니다.';
        }
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<bool> isStudentIdAvailable(String studentId) {
    return _authService.isStudentIdAvailable(studentId);
  }

  // 반환값: null이면 취소(사용자가 팝업을 닫음), 문자열이면 에러 메시지.
  // 성공 시에는 authStateChanges 리스너가 _currentUser 또는 _pendingGoogleUid를 채운다.
  Future<String?> signInWithGoogle() async {
    try {
      final result = await _authService.signInWithGoogle();
      if (result == null) return null; // 사용자가 취소함

      if (!result.isNewUser) {
        // 기존 가입자 재로그인 — role 검사(학생 계정만 허용)
        final uid = result.userCredential.user?.uid;
        final userData = uid != null ? await _authService.getUserData(uid) : null;
        if (userData == null || userData.role != 'student') {
          await _authService.signOut();
          return '학생 계정만 로그인할 수 있습니다.';
        }
      }
      return null;
    } catch (e) {
      final message = e.toString();
      return message.startsWith('Exception: ') ? message.substring(11) : message;
    }
  }

  // 학번 입력 페이지에서 호출. 성공하면 authStateChanges가 재평가되어 홈으로 이동한다.
  Future<String?> registerStudentId(String studentId) async {
    if (_pendingGoogleUid == null) return '로그인 상태를 확인할 수 없습니다.';
    try {
      await _authService.registerStudentId(uid: _pendingGoogleUid!, studentId: studentId);
      final fetched = await _authService.getUserData(_pendingGoogleUid!);
      if (fetched != null) {
        _currentUser = fetched;
        _pendingGoogleUid = null;
        await _saveUserToCache(fetched);
        notifyListeners();
      }
      return null;
    } catch (e) {
      final message = e.toString();
      return message.startsWith('Exception: ') ? message.substring(11) : message;
    }
  }

  // 학번 입력 페이지에서 취소(뒤로가기)한 경우 호출.
  Future<void> cancelPendingGoogleSignUp() async {
    await _authService.cancelPendingGoogleSignUp();
    _pendingGoogleUid = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    await _clearUserCache();
    notifyListeners();
  }

  Future<String?> resetPassword(String email) async {
    try {
      await _authService.resetPassword(email);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> refreshUserData() async {
    if (_authService.currentUser != null) {
      _currentUser = await _authService.getUserData(_authService.currentUser!.uid);
      notifyListeners();
    }
  }

  List<String> get blockedUsers => _currentUser?.blockedUsers ?? [];

  Future<String?> blockUser(String targetUid) async {
    if (_currentUser == null) return '로그인이 필요합니다.';
    try {
      await _authService.blockUser(myUid: _currentUser!.uid, targetUid: targetUid);
      await refreshUserData();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> unblockUser(String targetUid) async {
    if (_currentUser == null) return '로그인이 필요합니다.';
    try {
      await _authService.unblockUser(myUid: _currentUser!.uid, targetUid: targetUid);
      await refreshUserData();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  bool get isGoogleSignedIn => _authService.isGoogleSignedIn;

  Future<String?> deleteAccount({String? password}) async {
    try {
      await _authService.deleteAccount(password: password);
      _currentUser = null;
      await _clearUserCache();
      notifyListeners();
      return null;
    } catch (e) {
      final message = e.toString();
      return message.startsWith('Exception: ') ? message.substring(11) : message;
    }
  }
}
