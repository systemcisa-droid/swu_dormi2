import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/login_strings.dart';
import '../../widgets/google_logo.dart';
import 'email_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isGoogleLoading = false;

  /// 숨겨진 진입점(학교명 문구) 연속 터치 횟수. 10번 터치하면 이메일 로그인 화면으로 이동한다.
  int _hiddenEmailEntryTapCount = 0;

  void _handleHiddenEmailEntryTap(LoginStrings s) {
    _hiddenEmailEntryTapCount++;
    if (_hiddenEmailEntryTapCount >= 10) {
      _hiddenEmailEntryTapCount = 0;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(s.emailLoginConfirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(s.no),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EmailLoginScreen()),
                );
              },
              child: Text(s.yes),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _handleGoogleLogin() async {
    // 처리 중 재진입(중복 제출) 방지
    if (_isGoogleLoading) return;
    setState(() => _isGoogleLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final error = await authProvider.signInWithGoogle();

    if (!mounted) return;
    setState(() => _isGoogleLoading = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = Provider.of<LocaleProvider>(context).isEnglish;
    final s = LoginStrings(isEnglish);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: _buildLanguageToggle(context),
                ),
                const SizedBox(height: 8),
                Image.asset(
                  'assets/images/login.jpg',
                  width: 700,
                  height: 300,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.school,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    );
                  },
                ),

                Text(
                  s.dormNames,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  s.baromNote,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  s.verse,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isGoogleLoading ? null : _handleGoogleLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    elevation: 1,
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                  icon: _isGoogleLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const GoogleLogo(size: 20),
                  label: Text(
                    s.googleLogin,
                    style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 24),
                // ── 숨겨진 이메일 로그인/회원가입 진입점 ──
                // 이 문구를 10번 연속으로 터치하면 이메일 로그인 화면으로 이동한다.
                // 학생들이 Google 로그인을 우선 선택하도록 눈에 띄지 않게 둔다.
                GestureDetector(
                  onTap: () => _handleHiddenEmailEntryTap(s),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Seoul Women\'s University',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
        ),
      ),
    );
  }

  Widget _buildLanguageToggle(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.language, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        _buildLanguageOption(context, localeProvider, 'KO', 'ko'),
        const SizedBox(width: 6),
        _buildLanguageOption(context, localeProvider, 'EN', 'en'),
      ],
    );
  }

  Widget _buildLanguageOption(
      BuildContext context, LocaleProvider localeProvider, String label, String code) {
    final isSelected = localeProvider.languageCode == code;
    return GestureDetector(
      onTap: () => localeProvider.setLanguage(code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

}
