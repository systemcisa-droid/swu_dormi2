import 'package:flutter/material.dart' hide Colors, FilledButton, IconButton, Card, ListTile, showDialog, Divider, Checkbox, Tooltip, ButtonStyle;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:swu_dormi_admin/services/auth_service.dart';
import 'package:swu_dormi_admin/screens/windows/windows_navigation_shell.dart';
import 'package:window_manager/window_manager.dart';

class WindowsLoginScreen extends StatefulWidget {
  const WindowsLoginScreen({super.key});

  @override
  State<WindowsLoginScreen> createState() => _WindowsLoginScreenState();
}

class _WindowsLoginScreenState extends State<WindowsLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_emailIdController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = '이메일과 비밀번호를 모두 입력해주세요';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _authService.signInWithEmailAndPassword(
        email: '${_emailIdController.text.trim()}@swu.ac.kr',
        password: _passwordController.text.trim(),
      );

      if (user != null && mounted) {
        Navigator.of(context).pushReplacement(
          FluentPageRoute(
            builder: (context) => const WindowsNavigationShell(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().contains('user-not-found')
              ? '존재하지 않는 사용자입니다'
              : e.toString().contains('wrong-password')
                  ? '비밀번호가 올바르지 않습니다'
                  : e.toString().contains('invalid-email')
                      ? '올바른 이메일 형식이 아닙니다'
                      : '로그인 중 오류가 발생했습니다';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = FluentTheme.of(context).brightness;

    return ScaffoldPage(
      content: Stack(
        children: [
          // 배경 그라데이션
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  brightness == Brightness.light
                      ? const Color(0xFF0078D4).withOpacity(0.1)
                      : const Color(0xFF0078D4).withOpacity(0.05),
                  brightness == Brightness.light
                      ? const Color(0xFF005A9E).withOpacity(0.06)
                      : const Color(0xFF005A9E).withOpacity(0.03),
                ],
              ),
            ),
          ),

          // 창 컨트롤 버튼
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(FluentIcons.chrome_minimize, size: 12),
                  onPressed: () => windowManager.minimize(),
                ),
                IconButton(
                  icon: const Icon(FluentIcons.chrome_close, size: 12),
                  onPressed: () => windowManager.close(),
                ),
              ],
            ),
          ),

          // 로그인 폼
          Center(
            child: SizedBox(
              width: 420,
              child: Card(
                padding: const EdgeInsets.all(48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 로고 영역
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'SWU',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '샬롬하우스 관리 시스템',
                      style: FluentTheme.of(context).typography.title,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '관리자 계정으로 로그인하세요',
                      style: FluentTheme.of(context).typography.caption?.copyWith(
                        color: Colors.grey[100],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 에러 메시지
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              FluentIcons.error_badge,
                              color: Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // 이메일 입력
                    InfoLabel(
                      label: '이메일',
                      child: TextBox(
                        controller: _emailIdController,
                        placeholder: '아이디 입력',
                        prefix: const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Icon(FluentIcons.mail, size: 16),
                        ),
                        suffix: const Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: Text('@swu.ac.kr', style: TextStyle(fontSize: 13, color: Colors.grey)),
                        ),
                        enabled: !_isLoading,
                        autofocus: true,
                        onSubmitted: (_) => _handleLogin(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 비밀번호 입력
                    InfoLabel(
                      label: '비밀번호',
                      child: PasswordBox(
                        controller: _passwordController,
                        placeholder: '비밀번호 입력',
                        leadingIcon: const Icon(FluentIcons.lock, size: 16),
                        enabled: !_isLoading,
                        revealMode: PasswordRevealMode.peek,
                        onSubmitted: (_) => _handleLogin(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 로그인 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: ProgressRing(strokeWidth: 2),
                              )
                            : const Text('로그인'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 추가 옵션
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        HyperlinkButton(
                          onPressed: () {
                            displayInfoBar(
                              context,
                              builder: (context, close) => InfoBar(
                                title: const Text('비밀번호 재설정'),
                                content: const Text('관리자에게 문의해주세요'),
                                action: IconButton(
                                  icon: const Icon(FluentIcons.clear),
                                  onPressed: close,
                                ),
                                severity: InfoBarSeverity.info,
                              ),
                            );
                          },
                          child: const Text(
                            '비밀번호를 잊으셨나요?',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}