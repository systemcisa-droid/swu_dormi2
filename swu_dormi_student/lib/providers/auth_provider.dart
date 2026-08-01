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

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;

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
            await _saveUserToCache(fetched);
          } else {
            // Firestore 문서가 없으면 캐시에서 복원
            _currentUser = await _loadCachedUser();
          }
        } catch (_) {
          // 네트워크 오류 등 → 캐시에서 복원
          _currentUser = await _loadCachedUser();
        }
      } else {
        _currentUser = null;
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

  Future<String?> signInWithGoogle({required String studentId}) async {
    try {
      final credential = await _authService.signInWithGoogle(studentId: studentId);
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

  Future<String?> deleteAccount({required String password}) async {
    try {
      await _authService.deleteAccount(password: password);
      _currentUser = null;
      await _clearUserCache();
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
