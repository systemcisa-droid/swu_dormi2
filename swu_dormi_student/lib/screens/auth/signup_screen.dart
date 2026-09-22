import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/signup_strings.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailIdController = TextEditingController(text: '20');
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailIdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    // 처리 중 재진입(중복 제출) 방지
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // 이메일 아이디가 곧 학번이다. 관리프로그램이 올린 사생 명단에 없으면 팝업으로 안내하고 가입하지 않는다.
    // (명단 조회 자체가 실패하면 여기서 막지 않고, 가입 처리 단계의 검사에 맡긴다.)
    final studentId = _emailIdController.text.trim();
    bool inRoster = true;
    try {
      inRoster = await authProvider.isStudentIdInRoster(studentId);
    } catch (_) {}
    if (!mounted) return;
    if (!inRoster) {
      setState(() => _isLoading = false);
      await _showStudentIdNotInRosterDialog();
      return;
    }

    final error = await authProvider.signUp(
      email: '${_emailIdController.text}@swu.ac.kr',
      password: _passwordController.text,
      name: _nameController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    } else if (mounted) {
      Navigator.pop(context);
      final isEnglish = Provider.of<LocaleProvider>(context, listen: false).isEnglish;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(SignupStrings(isEnglish).signupComplete),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _showStudentIdNotInRosterDialog() {
    final s = SignupStrings(Provider.of<LocaleProvider>(context, listen: false).isEnglish);
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.studentIdNotInRosterTitle),
        content: Text(s.studentIdNotInRosterBody),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.studentIdNotInRosterOk),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = Provider.of<LocaleProvider>(context).isEnglish;
    final s = SignupStrings(isEnglish);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.title),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    labelText: s.name,
                    prefixIcon: const Icon(Icons.person),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return s.nameRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailIdController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    labelText: s.emailId,
                    hintText: s.emailIdHint,
                    prefixIcon: const Icon(Icons.email),
                    border: const OutlineInputBorder(),
                    suffixText: '@swu.ac.kr',
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) {
                      return s.emailIdRequired;
                    }
                    if (!RegExp(r'^[0-9]+$').hasMatch(v)) {
                      return s.emailIdInvalid;
                    }
                    if (v.length != 10) {
                      return s.emailIdLengthInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    s.emailIdGuide,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  enabled: !_isLoading,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: s.password,
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
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
                    if (value.length < 6) {
                      return s.passwordTooShort;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  enabled: !_isLoading,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: s.confirmPassword,
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(
                            () => _obscureConfirmPassword = !_obscureConfirmPassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return s.confirmPasswordRequired;
                    }
                    if (value != _passwordController.text) {
                      return s.passwordMismatch;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.profileUpdateNotice,
                          style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),


                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignup,
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
                          s.signupButton,
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
