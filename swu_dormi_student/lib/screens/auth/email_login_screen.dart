import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/app_strings.dart';
import '../../utils/login_strings.dart';
import 'signup_screen.dart';

/// 학번(이메일) 기반 로그인/회원가입 화면.
/// 일반 학생 로그인 화면(LoginScreen)에서 숨겨진 진입점을 통해서만 접근한다.
class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // 처리 중 재진입(중복 제출) 방지
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final error = await authProvider.signIn(
      email: '${_emailIdController.text.trim()}@swu.ac.kr',
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

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
    final a = AppStrings(isEnglish);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.emailLoginToggle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _emailIdController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    labelText: s.emailId,
                    prefixIcon: const Icon(Icons.email),
                    border: const OutlineInputBorder(),
                    suffixText: '@swu.ac.kr',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return s.emailIdRequired;
                    }
                    if (!RegExp(r'^[0-9]{10}$').hasMatch(value.trim())) {
                      return s.googleStudentIdInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: s.password,
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return s.passwordRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          s.login,
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignupScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    s.signup,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    _showPasswordResetDialog(s, a);
                  },
                  child: Text(s.forgotPassword),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPasswordResetDialog(LoginStrings s, AppStrings a) {
    final emailIdController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.resetPasswordTitle),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: emailIdController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: s.emailId,
                  hintText: s.enterIdHint,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 4),
              child: Text('@swu.ac.kr', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(a.cancel),
          ),
          TextButton(
            onPressed: () async {
              final email = '${emailIdController.text.trim()}@swu.ac.kr';
              if (emailIdController.text.trim().isEmpty) return;

              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              final error = await authProvider.resetPassword(email);

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error ?? s.resetPasswordEmailSent),
                    backgroundColor: error != null ? Colors.red : Colors.green,
                  ),
                );
              }
            },
            child: Text(a.send),
          ),
        ],
      ),
    );
  }
}
