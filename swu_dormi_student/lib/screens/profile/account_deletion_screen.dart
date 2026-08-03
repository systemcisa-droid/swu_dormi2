import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _confirmed = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isGoogle = authProvider.isGoogleSignedIn;

    if (!_confirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('탈퇴 안내 사항에 동의해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (!isGoogle && _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('비밀번호를 입력해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('회원탈퇴 최종 확인'),
        content: const Text(
          '탈퇴 후에는 모든 데이터가 삭제되며 복구할 수 없습니다.\n정말 탈퇴하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('탈퇴하기', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    if (!mounted) return;

    final error = await authProvider.deleteAccount(
      password: isGoogle ? null : _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      String message;
      if (error.contains('wrong-password') || error.contains('invalid-credential')) {
        message = '비밀번호가 올바르지 않습니다.';
      } else if (error.contains('too-many-requests')) {
        message = '너무 많은 시도가 있었습니다. 잠시 후 다시 시도해주세요.';
      } else if (error.contains('requires-recent-login')) {
        message = '보안을 위해 재로그인 후 다시 시도해주세요.';
      } else if (error.contains('network-request-failed')) {
        message = '네트워크 오류가 발생했습니다. 인터넷 연결을 확인해주세요.';
      } else {
        message = '회원탈퇴 실패: $error';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
      );
    } else {
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGoogle = Provider.of<AuthProvider>(context).isGoogleSignedIn;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.red.shade600, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      '회원탈퇴 전 꼭 확인하세요',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '• 탈퇴 즉시 모든 개인정보 및 이용 기록이 삭제됩니다.\n'
                  '• 삭제된 데이터는 복구할 수 없습니다.\n'
                  '• 상벌점, 출석 기록, 작성한 게시글 등 모든 활동 기록이 사라집니다.\n'
                  '• 탈퇴 후 동일한 이메일로 재가입이 가능합니다.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.red.shade800,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          if (isGoogle) ...[
            const Text(
              '본인 확인',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '탈퇴하기를 누르면 Google 계정 확인 창이 표시됩니다.\n본인 계정으로 다시 로그인하여 확인해주세요.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5),
            ),
          ] else ...[
            const Text(
              '비밀번호 확인',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '본인 확인을 위해 현재 비밀번호를 입력해주세요.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: '비밀번호 입력',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _confirmed,
                activeColor: Colors.red,
                onChanged: (v) => setState(() => _confirmed = v ?? false),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _confirmed = !_confirmed),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text(
                      '위 내용을 모두 확인하였으며, 회원탈퇴에 동의합니다.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: (_confirmed && !_isLoading) ? _deleteAccount : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      '회원탈퇴',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
