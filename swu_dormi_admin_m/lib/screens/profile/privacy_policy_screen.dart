import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('개인정보 처리방침 및 회원탈퇴'),
      ),
      body: Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                _buildTab(0, '개인정보 처리방침'),
                _buildTab(1, '회원탈퇴'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _selectedTab == 0
                ? _buildPrivacyPolicy()
                : _AccountDeletionContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyPolicy() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection(
            title: '1. 개인정보의 수집 및 이용 목적',
            content: '''기숙사 관리 시스템(이하 '본 앱')은 다음의 목적을 위하여 개인정보를 처리합니다. 처리하고 있는 개인정보는 다음의 목적 이외의 용도로는 이용되지 않으며, 이용 목적이 변경되는 경우에는 「개인정보 보호법」 제18조에 따라 별도의 동의를 받는 등 필요한 조치를 이행할 예정입니다.

• 기숙사 업무 관리: 수리 보수 접수 및 처리, 청소 점검, 출석 체크 등 기숙사 운영 업무 수행
• 입주 학생 관리: 호실 배정 정보 확인, 학생 현황 파악
• 업무 기록 관리: 점검 이력, 근무일지 등 업무 수행 기록 유지''',
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: '2. 수집하는 개인정보 항목',
            content: '''본 앱은 서비스 제공을 위해 다음과 같은 개인정보를 처리합니다.

[계정 정보]
• 이메일 주소
• 비밀번호 (암호화하여 저장)
• 이름
• 담당 구역 정보

[업무 수행 중 처리하는 학생 정보]
• 이름, 학번, 호실 정보
• 청소 점검 기록, 출석 기록, 시설 신고 내용

[자동 수집 항목]
• 서비스 이용 기록
• 접속 로그''',
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: '3. 개인정보의 보유 및 이용 기간',
            content: '''본 앱은 법령에 따른 개인정보 보유·이용기간 내에서 개인정보를 처리·보유합니다.

• 계정 정보: 회원 탈퇴 시까지
• 시설 신고 처리 기록: 처리 완료일로부터 1년
• 청소 점검 기록: 해당 학기 종료 후 1년
• 출석 기록: 해당 학기 종료 후 1년

다만, 관계 법령 위반에 따른 수사·조사 등이 진행 중인 경우에는 해당 수사·조사 종료 시까지 보유합니다.''',
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: '4. 개인정보의 제3자 제공',
            content: '''본 앱은 정보주체의 개인정보를 제1조에서 명시한 범위 내에서만 처리하며, 「개인정보 보호법」 제17조 및 제18조에 해당하는 경우에만 제3자에게 제공합니다.

현재 본 앱은 개인정보를 제3자에게 제공하지 않습니다.''',
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: '5. 개인정보 처리의 위탁',
            content: '''본 앱은 원활한 서비스 운영을 위하여 다음과 같이 개인정보 처리업무를 위탁하고 있습니다.

• 수탁업체: Google Firebase
• 위탁업무 내용: 클라우드 서버 제공, 사용자 인증, 데이터 저장 및 관리
• 위탁기간: 회원 탈퇴 시 또는 위탁 계약 종료 시까지''',
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: '6. 정보주체의 권리·의무 및 행사 방법',
            content: '''정보주체는 본 앱에 대해 언제든지 다음 각 호의 개인정보 보호 관련 권리를 행사할 수 있습니다.

• 개인정보 열람 요구
• 개인정보 오류 등이 있을 경우 정정 요구
• 개인정보 삭제 요구
• 개인정보 처리 정지 요구

위 권리 행사는 개인정보 보호책임자에게 서면, 전화, 이메일 등을 통하여 하실 수 있습니다.''',
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: '7. 개인정보 보호책임자',
            content: '''▶ 개인정보 보호책임자
• 소속: 기숙사 사무실
• 연락처: 02-970-7901
• 이메일: dormitory@swu.ac.kr''',
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: '8. 개인정보의 안전성 확보 조치',
            content: '''본 앱은 개인정보의 안전성 확보를 위해 다음과 같은 조치를 취하고 있습니다.

• 관리적 조치: 내부관리계획 수립·시행, 정기적 직원 교육 등
• 기술적 조치: 접근권한 관리, 접근통제시스템 설치, 암호화, 보안프로그램 설치
• 물리적 조치: 전산실, 자료보관실 등의 접근통제

비밀번호는 암호화되어 저장 및 관리되고 있어 본인만이 알 수 있습니다.''',
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: '9. 개인정보 처리방침의 변경',
            content: '''이 개인정보 처리방침은 2024년 1월 1일부터 적용됩니다.

처리방침 변경 시 개정 최소 7일 전부터 앱 내 공지를 통해 고지합니다. 이용자 권리의 중요한 변경이 있을 경우에는 최소 30일 전에 고지합니다.''',
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('공고일자: 2024년 1월 1일',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                const SizedBox(height: 4),
                Text('시행일자: 2024년 1월 1일',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade700)),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade800,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

// ── 회원탈퇴 탭 ──────────────────────────────────────────────────────────────
class _AccountDeletionContent extends StatefulWidget {
  @override
  State<_AccountDeletionContent> createState() =>
      _AccountDeletionContentState();
}

class _AccountDeletionContentState extends State<_AccountDeletionContent> {
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
    if (!_confirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('탈퇴 안내 사항에 동의해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_passwordController.text.isEmpty) {
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
            child: const Text('탈퇴하기',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('로그인 상태가 아닙니다.');

      // 비밀번호로 재인증
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _passwordController.text,
      );
      await user.reauthenticateWithCredential(credential);

      // Firestore 사용자 문서 삭제
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();

      // Firebase Auth 계정 삭제
      await user.delete();

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      String message;
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          message = '비밀번호가 올바르지 않습니다.';
          break;
        case 'too-many-requests':
          message = '너무 많은 시도가 있었습니다. 잠시 후 다시 시도해주세요.';
          break;
        case 'requires-recent-login':
          message = '보안을 위해 재로그인 후 다시 시도해주세요.';
          break;
        case 'network-request-failed':
          message = '네트워크 오류가 발생했습니다. 인터넷 연결을 확인해주세요.';
          break;
        default:
          message = '회원탈퇴 실패: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 경고 박스
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
                  '• 층장 업무 기록(점검, 근무일지 등)이 모두 삭제됩니다.\n'
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
          // 비밀번호 입력
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
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // 동의 체크박스
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
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // 탈퇴 버튼
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
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
