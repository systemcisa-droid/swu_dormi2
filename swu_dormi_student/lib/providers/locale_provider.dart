import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  static const _languageCodeKey = 'app_language_code';

  String _languageCode = 'ko';

  String get languageCode => _languageCode;
  bool get isEnglish => _languageCode == 'en';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _languageCode = prefs.getString(_languageCodeKey) ?? 'ko';
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    if (code == _languageCode) return;
    _languageCode = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageCodeKey, code);
  }
}
