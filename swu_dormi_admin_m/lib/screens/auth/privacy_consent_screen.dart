import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacyConsentScreen extends StatefulWidget {
  final VoidCallback onAgreed;

  const PrivacyConsentScreen({super.key, required this.onAgreed});

  @override
  State<PrivacyConsentScreen> createState() => _PrivacyConsentScreenState();
}

class _PrivacyConsentScreenState extends State<PrivacyConsentScreen> {
  bool _agreed = false;

  Future<void> _onAgree() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_policy_agreed', true);
    widget.onAgreed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('서비스 이용약관 및 개인정보 처리방침'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '서비스 이용을 위해 아래 이용약관 및 개인정보 처리방침을 읽고 동의해 주세요.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // ── 서비스 이용약관 (EULA) ──
                  // App Store 가이드라인 1.2: 부적절한 콘텐츠·이용자에 대한
                  // 무관용 원칙을 약관에 명시하고 가입 전 동의를 받아야 한다.
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.gavel, color: Colors.orange.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '서비스 이용약관 (EULA)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '제1조 (목적)\n'
                          '본 약관은 기숙사 층장 매니저 앱(이하 "본 앱") 이용에 관한 조건 및 절차, 이용자와 운영자의 권리·의무 및 책임 사항을 규정함을 목적으로 합니다.\n\n'
                          '제2조 (이용자의 의무)\n'
                          '이용자는 다음 각 호의 행위를 하여서는 안 됩니다.\n\n'
                          '• 타인을 비방하거나 명예를 훼손하는 메시지 작성\n'
                          '• 욕설, 혐오 표현, 음란물 등 부적절한 콘텐츠 게시\n'
                          '• 허위 사실 유포 및 타인의 개인정보 무단 게재\n'
                          '• 기숙사 운영을 방해하거나 질서를 해치는 행위\n'
                          '• 기타 법령 또는 공공질서에 반하는 행위\n\n'
                          '제3조 (제재 조치)\n'
                          '본 앱은 부적절한 콘텐츠와 이용자에 대해 무관용 원칙을 적용합니다. 이용자가 제2조를 위반할 경우, 운영자는 사전 통보 없이 즉시 다음 조치를 취할 수 있습니다.\n\n'
                          '⚠️  비방이나 부적절한 콘텐츠 작성 시 즉시 탈퇴 처리됩니다.\n\n'
                          '• 해당 콘텐츠 즉시 삭제 및 계정 이용 정지\n'
                          '• 회원 자격 즉시 박탈 (강제 탈퇴 처리)\n'
                          '• 필요 시 관련 법령에 따른 법적 조치\n\n'
                          '제4조 (신고 및 처리)\n'
                          '이용자는 부적절한 콘텐츠를 발견한 경우 신고 기능을 통해 운영자에게 알릴 수 있으며, 특정 이용자를 차단할 수 있습니다. 운영자는 접수된 신고를 24시간 이내에 검토하여 해당 콘텐츠를 삭제하고 작성자를 퇴출하는 등의 조치를 취합니다.\n\n'
                          '제5조 (면책 조항)\n'
                          '운영자는 이용자가 작성한 콘텐츠로 인해 발생한 분쟁에 대해 책임을 지지 않으며, 해당 이용자가 모든 법적 책임을 부담합니다.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade800,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
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
• 이메일 주소 (관리자가 사전 부여)
• 비밀번호 (암호화하여 저장)
• 담당 구역 정보

※ 본 앱은 별도의 회원가입 절차가 없으며, 계정은 관리자가 직접 생성하여 부여합니다.

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

• 계정 정보: 계정 삭제 시까지 (계정 삭제는 관리자가 처리)
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
• 위탁기간: 서비스 종료 시 또는 위탁 계약 종료 시까지''',
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
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                        const SizedBox(height: 4),
                        Text('시행일자: 2024년 1월 1일',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // ── 하단 동의 영역 ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _agreed = !_agreed),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _agreed
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _agreed
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _agreed,
                            onChanged: (v) => setState(() => _agreed = v ?? false),
                            activeColor: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '[필수] 서비스 이용약관 및 개인정보 처리방침에 동의합니다.\n'
                            '(비방·부적절한 콘텐츠 작성 시 즉시 탈퇴 처리)',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _agreed ? _onAgree : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                    child: const Text(
                      '동의하고 시작하기',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
