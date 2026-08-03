import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/login_strings.dart';

// Google 로그인은 성공했지만 아직 학번을 입력하지 않은 신규 가입자가 보게 되는 화면.
// 학번 검증(중복 확인)을 통과해야 users 문서가 생성되고 홈으로 이동한다.
class GoogleStudentIdScreen extends StatefulWidget {
  const GoogleStudentIdScreen({super.key});

  @override
  State<GoogleStudentIdScreen> createState() => _GoogleStudentIdScreenState();
}

class _GoogleStudentIdScreenState extends State<GoogleStudentIdScreen> {
  final _studentIdController = TextEditingController(text: '20');
  bool _isCheckingStudentId = false;
  bool _isSubmitting = false;
  bool _isCancelling = false;
  // 사용가능 확인을 통과한 학번. 값이 바뀌면(재입력) 다시 확인해야 하므로 null로 초기화된다.
  String? _verifiedStudentId;

  @override
  void initState() {
    super.initState();
    _studentIdController.addListener(_onStudentIdChanged);
  }

  void _onStudentIdChanged() {
    if (_verifiedStudentId != null && _verifiedStudentId != _studentIdController.text.trim()) {
      setState(() => _verifiedStudentId = null);
    }
  }

  @override
  void dispose() {
    _studentIdController.removeListener(_onStudentIdChanged);
    _studentIdController.dispose();
    super.dispose();
  }

  bool get _isStudentIdValid =>
      RegExp(r'^[0-9]{10}$').hasMatch(_studentIdController.text.trim());

  bool get _isStudentIdVerified =>
      _verifiedStudentId != null && _verifiedStudentId == _studentIdController.text.trim();

  Future<void> _checkStudentIdAvailable() async {
    final isEnglish = Provider.of<LocaleProvider>(context, listen: false).isEnglish;
    final s = LoginStrings(isEnglish);

    if (!_isStudentIdValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.googleStudentIdInvalid), backgroundColor: Colors.orange),
      );
      return;
    }

    final studentId = _studentIdController.text.trim();
    setState(() => _isCheckingStudentId = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final isAvailable = await authProvider.isStudentIdAvailable(studentId);

      if (!mounted) return;
      setState(() {
        _isCheckingStudentId = false;
        _verifiedStudentId = isAvailable ? studentId : null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAvailable ? s.googleStudentIdAvailable : s.googleStudentIdDuplicate),
          backgroundColor: isAvailable ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCheckingStudentId = false);
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _submit() async {
    if (!_isStudentIdVerified) return;

    setState(() => _isSubmitting = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final error = await authProvider.registerStudentId(_studentIdController.text.trim());

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (error != null) {
      setState(() => _verifiedStudentId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
    // 성공 시에는 AuthProvider가 _currentUser를 채워 main.dart 라우팅이 자동으로 홈으로 이동한다.
  }

  Future<void> _cancel() async {
    setState(() => _isCancelling = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.cancelPendingGoogleSignUp();
    // 취소 후 main.dart 라우팅이 로그인 화면으로 되돌린다.
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = Provider.of<LocaleProvider>(context).isEnglish;
    final s = LoginStrings(isEnglish);
    final isBusy = _isSubmitting || _isCancelling;

    return Scaffold(
      appBar: AppBar(title: Text(s.googleStudentIdPageTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Icon(Icons.badge_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                s.googleStudentIdPageGuide,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _studentIdController,
                keyboardType: TextInputType.number,
                enabled: !isBusy,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: s.googleStudentIdLabel,
                  hintText: s.googleStudentIdHint,
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: const OutlineInputBorder(),
                  suffixIcon: _isStudentIdVerified
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: (isBusy || _isCheckingStudentId || !_isStudentIdValid || _isStudentIdVerified)
                    ? null
                    : _checkStudentIdAvailable,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isCheckingStudentId
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(s.googleStudentIdCheck),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: (isBusy || !_isStudentIdVerified) ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(s.googleStudentIdComplete, style: const TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: isBusy ? null : _cancel,
                child: _isCancelling
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(s.cancelSignUp),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
