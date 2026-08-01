import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacyConsentScreen extends StatefulWidget {
  final VoidCallback onAgreed;

  const PrivacyConsentScreen({super.key, required this.onAgreed});

  @override
  State<PrivacyConsentScreen> createState() => _PrivacyConsentScreenState();
}

class _PrivacyConsentScreenState extends State<PrivacyConsentScreen> {
  bool _agreedPrivacy = false;
  bool _agreedEula = false;

  bool get _allAgreed => _agreedPrivacy && _agreedEula;

  Future<void> _onAgree() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_policy_agreed', true);
    widget.onAgreed();
  }

  void _toggleAll(bool value) {
    setState(() {
      _agreedPrivacy = value;
      _agreedEula = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('서비스 이용약관 및 개인정보 처리방침 / Terms of Service & Privacy Policy'),
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
                            '서비스 이용을 위해 아래 이용약관 및 개인정보 처리방침을 읽고 동의해 주세요.\n'
                            'Please read and agree to the Terms of Service and Privacy Policy below to use this service.',
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

                  // ── EULA 섹션 ──
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
                            Icon(Icons.gavel,
                                color: Colors.orange.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '서비스 이용약관 (EULA) / Terms of Service',
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
                          '본 약관은 기숙사 앱(이하 "본 앱") 이용에 관한 조건 및 절차, 이용자와 운영자의 권리·의무 및 책임 사항을 규정함을 목적으로 합니다.\n\n'
                          '제2조 (이용자의 의무)\n'
                          '이용자는 다음 각 호의 행위를 하여서는 안 됩니다.\n\n'
                          '• 타인을 비방하거나 명예를 훼손하는 게시글 작성\n'
                          '• 욕설, 혐오 표현, 음란물 등 부적절한 콘텐츠 게시\n'
                          '• 허위 사실 유포 및 타인의 개인정보 무단 게재\n'
                          '• 기숙사 운영을 방해하거나 질서를 해치는 행위\n'
                          '• 기타 법령 또는 공공질서에 반하는 행위\n\n'
                          '제3조 (제재 조치)\n'
                          '이용자가 제2조를 위반할 경우, 운영자는 사전 통보 없이 즉시 다음 조치를 취할 수 있습니다.\n\n'
                          '⚠️  비방이나 부적절한 게시글 작성 시 즉시 탈퇴 처리됩니다.\n\n'
                          '• 게시글 삭제 및 계정 이용 정지\n'
                          '• 회원 자격 즉시 박탈 (강제 탈퇴 처리)\n'
                          '• 필요 시 관련 법령에 따른 법적 조치\n\n'
                          '제4조 (면책 조항)\n'
                          '운영자는 이용자가 작성한 게시글로 인해 발생한 분쟁에 대해 책임을 지지 않으며, 해당 이용자가 모든 법적 책임을 부담합니다.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade800,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Divider(color: Colors.orange.shade200),
                        const SizedBox(height: 16),
                        Text(
                          'Article 1 (Purpose)\n'
                          'These Terms govern the conditions and procedures for using the dormitory app (the "App"), as well as the rights, obligations, and responsibilities of users and the operator.\n\n'
                          'Article 2 (User Obligations)\n'
                          'Users shall not engage in any of the following:\n\n'
                          '• Posting content that defames or disparages others\n'
                          '• Posting abusive language, hate speech, or obscene content\n'
                          '• Spreading false information or disclosing others\' personal information without consent\n'
                          '• Disrupting dormitory operations or public order\n'
                          '• Any other act that violates applicable laws or public order\n\n'
                          'Article 3 (Sanctions)\n'
                          'If a user violates Article 2, the operator may immediately take the following actions without prior notice.\n\n'
                          '⚠️  Defamatory or inappropriate posts will result in immediate account termination.\n\n'
                          '• Deletion of posts and suspension of account use\n'
                          '• Immediate revocation of membership (forced account deletion)\n'
                          '• Legal action under applicable law, if necessary\n\n'
                          'Article 4 (Disclaimer)\n'
                          'The operator is not liable for disputes arising from content posted by users; the user who posted the content bears full legal responsibility.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── 개인정보 처리방침 섹션 ──
                  _buildSection(
                    title: '1. 개인정보의 수집 및 이용 목적 / Purpose of Collection and Use of Personal Information',
                    content:
                        '''기숙사 관리 시스템(이하 '본 앱')은 다음의 목적을 위하여 개인정보를 처리합니다. 처리하고 있는 개인정보는 다음의 목적 이외의 용도로는 이용되지 않으며, 이용 목적이 변경되는 경우에는 「개인정보 보호법」 제18조에 따라 별도의 동의를 받는 등 필요한 조치를 이행할 예정입니다.

• 회원 가입 및 관리: 회원제 서비스 이용에 따른 본인 식별·인증, 회원자격 유지·관리, 서비스 부정이용 방지
• 기숙사 생활 관리: 입사·퇴사 관리, 호실 배정, 시설 신고 접수 및 처리
• 공지사항 전달: 기숙사 운영 관련 공지사항, 식단 정보, 중요 알림 전달
• 상벌점 관리: 기숙사 생활 규칙 준수 여부 관리, 상벌점 부여 및 조회
• 민원 처리: 시설 신고, 건의사항 등 민원 접수 및 처리''',
                    contentEn:
                        '''The Dormitory Management System (the "App") processes personal information for the following purposes. Personal information will not be used for any purpose other than those listed below, and if the purpose of use changes, we will obtain separate consent as required under Article 18 of the Personal Information Protection Act.

• Membership registration and management: identity verification, maintaining membership eligibility, preventing fraudulent use of the service
• Dormitory life management: move-in/move-out management, room assignment, receiving and processing facility reports
• Notice delivery: dormitory operation notices, meal information, important announcements
• Reward/penalty point management: managing compliance with dormitory rules, granting and viewing reward/penalty points
• Complaint handling: receiving and processing facility reports, suggestions, and other complaints''',
                  ),
                  const SizedBox(height: 24),
                  _buildSection(
                    title: '2. 수집하는 개인정보 항목 / Personal Information Collected',
                    content:
                        '''본 앱은 서비스 제공을 위해 다음과 같은 개인정보를 수집하고 있습니다.

[필수 수집 항목]
• 이메일 주소
• 비밀번호 (암호화하여 저장)
• 성명
• 학번
• 전화번호
• 호실 정보
• 학부/학과 정보

[선택 수집 항목]
• 프로필 사진
• 보호자 정보 (성명, 전화번호)

[자동 수집 항목]
• 서비스 이용 기록
• 접속 로그
• 기기 정보''',
                    contentEn:
                        '''The App collects the following personal information to provide its services.

[Required Items]
• Email address
• Password (stored encrypted)
• Name
• Student ID number
• Phone number
• Room information
• College/department information

[Optional Items]
• Profile photo
• Guardian information (name, phone number)

[Automatically Collected Items]
• Service usage records
• Access logs
• Device information''',
                  ),
                  const SizedBox(height: 24),
                  _buildSection(
                    title: '3. 개인정보의 보유 및 이용 기간 / Retention and Use Period of Personal Information',
                    content:
                        '''본 앱은 법령에 따른 개인정보 보유·이용기간 또는 정보주체로부터 개인정보를 수집 시에 동의 받은 개인정보 보유·이용기간 내에서 개인정보를 처리·보유합니다.

• 회원 정보: 회원 탈퇴 시까지
• 시설 신고 기록: 처리 완료일로부터 1년
• 상벌점 기록: 졸업 후 1년
• 공지사항 열람 기록: 1년

다만, 다음의 사유에 해당하는 경우에는 해당 사유 종료 시까지 보유합니다.
• 관계 법령 위반에 따른 수사·조사 등이 진행 중인 경우: 해당 수사·조사 종료 시까지
• 본 앱 이용에 따른 채권·채무관계 잔존 시: 해당 채권·채무관계 정산 시까지''',
                    contentEn:
                        '''The App processes and retains personal information within the retention period required by law or the period consented to by the data subject at the time of collection.

• Membership information: until account deletion
• Facility report records: 1 year from the date of completion
• Reward/penalty point records: 1 year after graduation
• Notice view records: 1 year

However, information may be retained until the relevant reason ends in the following cases:
• If an investigation related to a violation of applicable law is in progress: until the investigation concludes
• If a claim or obligation related to use of the App remains outstanding: until such claim or obligation is settled''',
                  ),
                  const SizedBox(height: 24),
                  _buildSection(
                    title: '4. 개인정보의 제3자 제공 / Provision of Personal Information to Third Parties',
                    content:
                        '''본 앱은 정보주체의 개인정보를 제1조(개인정보의 수집 및 이용 목적)에서 명시한 범위 내에서만 처리하며, 정보주체의 동의, 법률의 특별한 규정 등 「개인정보 보호법」 제17조 및 제18조에 해당하는 경우에만 개인정보를 제3자에게 제공합니다.

현재 본 앱은 개인정보를 제3자에게 제공하지 않습니다.''',
                    contentEn:
                        '''The App processes personal information only within the scope stated in Section 1 (Purpose of Collection and Use), and provides personal information to third parties only where permitted under Articles 17 and 18 of the Personal Information Protection Act, such as with the data subject's consent or under specific legal provisions.

The App currently does not provide personal information to any third party.''',
                  ),
                  const SizedBox(height: 24),
                  _buildSection(
                    title: '5. 개인정보 처리의 위탁 / Outsourcing of Personal Information Processing',
                    content:
                        '''본 앱은 원활한 개인정보 업무처리를 위하여 다음과 같이 개인정보 처리업무를 위탁하고 있습니다.

• 수탁업체: Google Firebase
• 위탁업무 내용: 클라우드 서버 제공, 사용자 인증, 데이터 저장 및 관리
• 위탁기간: 회원 탈퇴 시 또는 위탁 계약 종료 시까지

본 앱은 위탁계약 체결 시 「개인정보 보호법」 제26조에 따라 위탁업무 수행목적 외 개인정보 처리금지, 기술적·관리적 보호조치, 재위탁 제한, 수탁자에 대한 관리·감독, 손해배상 등 책임에 관한 사항을 계약서 등 문서에 명시하고, 수탁자가 개인정보를 안전하게 처리하는지를 감독하고 있습니다.''',
                    contentEn:
                        '''To ensure smooth handling of personal information, the App outsources personal information processing as follows.

• Service provider: Google Firebase
• Scope of outsourced work: cloud server hosting, user authentication, data storage and management
• Outsourcing period: until account deletion or termination of the outsourcing agreement

In accordance with Article 26 of the Personal Information Protection Act, the App specifies in its outsourcing agreements matters such as the prohibition of processing personal information beyond the outsourced purpose, technical and administrative safeguards, restrictions on re-outsourcing, supervision of the service provider, and liability for damages, and supervises whether the service provider handles personal information safely.''',
                  ),
                  const SizedBox(height: 24),
                  _buildSection(
                    title: '6. 정보주체의 권리·의무 및 행사 방법 / Rights and Obligations of Data Subjects and How to Exercise Them',
                    content:
                        '''정보주체는 본 앱에 대해 언제든지 다음 각 호의 개인정보 보호 관련 권리를 행사할 수 있습니다.

• 개인정보 열람 요구
• 개인정보 오류 등이 있을 경우 정정 요구
• 개인정보 삭제 요구
• 개인정보 처리 정지 요구

위 권리 행사는 본 앱 내 '프로필 수정' 기능을 통해 직접 수정하거나, 개인정보 보호책임자에게 서면, 전화, 이메일 등을 통하여 하실 수 있으며, 본 앱은 이에 대해 지체 없이 조치하겠습니다.''',
                    contentEn:
                        '''Data subjects may exercise the following rights regarding their personal information with the App at any time.

• Request to view personal information
• Request to correct errors in personal information
• Request to delete personal information
• Request to suspend processing of personal information

These rights may be exercised directly through the "Edit Profile" feature in the App, or by contacting the Data Protection Officer in writing, by phone, or by email. The App will take action without delay.''',
                  ),
                  const SizedBox(height: 24),
                  _buildSection(
                    title: '7. 개인정보 보호책임자 / Data Protection Officer',
                    content:
                        '''본 앱은 개인정보 처리에 관한 업무를 총괄해서 책임지고, 개인정보 처리와 관련한 정보주체의 불만처리 및 피해구제 등을 위하여 아래와 같이 개인정보 보호책임자를 지정하고 있습니다.

▶ 개인정보 보호책임자
• 소속: 기숙사 사무실
• 연락처: 02-970-7901
• 이메일: dormitory@swu.ac.kr

※ 개인정보 보호 담당부서로 연결됩니다.

정보주체께서는 본 앱의 서비스를 이용하시면서 발생한 모든 개인정보 보호 관련 문의, 불만처리, 피해구제 등에 관한 사항을 개인정보 보호책임자에게 문의하실 수 있습니다.''',
                    contentEn:
                        '''The App designates a Data Protection Officer as shown below, who is responsible for overseeing personal information processing and handling complaints and remedies related to data subjects.

▶ Data Protection Officer
• Department: Dormitory Office
• Contact: 02-970-7901
• Email: dormitory@swu.ac.kr

※ You will be connected to the department in charge of personal information protection.

Data subjects may contact the Data Protection Officer with any inquiries, complaints, or requests for remedies related to personal information protection arising from use of the App's services.''',
                  ),
                  const SizedBox(height: 24),
                  _buildSection(
                    title: '8. 개인정보의 안전성 확보 조치 / Measures to Ensure the Security of Personal Information',
                    content:
                        '''본 앱은 개인정보의 안전성 확보를 위해 다음과 같은 조치를 취하고 있습니다.

• 관리적 조치: 내부관리계획 수립·시행, 정기적 직원 교육 등
• 기술적 조치: 개인정보처리시스템 등의 접근권한 관리, 접근통제시스템 설치, 고유식별정보 등의 암호화, 보안프로그램 설치
• 물리적 조치: 전산실, 자료보관실 등의 접근통제

특히, 비밀번호는 암호화되어 저장 및 관리되고 있어 본인만이 알 수 있으며, 개인정보의 확인 및 변경도 비밀번호를 알고 있는 본인에 의해서만 가능합니다.''',
                    contentEn:
                        '''The App takes the following measures to ensure the security of personal information.

• Administrative measures: establishing and implementing internal management plans, regular staff training, etc.
• Technical measures: managing access permissions to personal information processing systems, installing access control systems, encrypting unique identifying information, installing security programs
• Physical measures: access control for server rooms, data storage areas, etc.

In particular, passwords are stored and managed in encrypted form so that only the account holder can know them, and personal information can only be viewed or changed by the account holder who knows the password.''',
                  ),
                  const SizedBox(height: 24),
                  _buildSection(
                    title: '9. 개인정보 처리방침의 변경 / Changes to This Privacy Policy',
                    content:
                        '''이 개인정보 처리방침은 2024년 1월 1일부터 적용됩니다.

본 개인정보 처리방침의 내용 추가, 삭제 및 수정이 있을 시에는 개정 최소 7일 전부터 앱 내 '공지사항'을 통해 고지할 것입니다. 다만, 개인정보의 수집 및 활용, 제3자 제공 등과 같이 이용자 권리의 중요한 변경이 있을 경우에는 최소 30일 전에 고지합니다.''',
                    contentEn:
                        '''This Privacy Policy is effective as of January 1, 2024.

If there are additions, deletions, or amendments to this Privacy Policy, notice will be given through the "Notices" section of the App at least 7 days before the changes take effect. However, if there is a material change affecting user rights, such as the collection and use of personal information or provision to third parties, notice will be given at least 30 days in advance.''',
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
                        Text(
                          '공고일자: 2024년 1월 1일 / Date of Announcement: January 1, 2024',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '시행일자: 2024년 1월 1일 / Effective Date: January 1, 2024',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade700),
                        ),
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
                // 전체 동의
                GestureDetector(
                  onTap: () => _toggleAll(!_allAgreed),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _allAgreed
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.08)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _allAgreed
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
                            value: _allAgreed,
                            onChanged: (v) => _toggleAll(v ?? false),
                            activeColor:
                                Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '아래 약관에 모두 동의합니다\nI agree to all the terms below',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // 개인정보 처리방침 동의
                GestureDetector(
                  onTap: () =>
                      setState(() => _agreedPrivacy = !_agreedPrivacy),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _agreedPrivacy,
                          onChanged: (v) => setState(
                              () => _agreedPrivacy = v ?? false),
                          activeColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '[필수] 개인정보 처리방침에 동의합니다.\n[Required] I agree to the Privacy Policy.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),

                // EULA 동의
                GestureDetector(
                  onTap: () =>
                      setState(() => _agreedEula = !_agreedEula),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _agreedEula,
                          onChanged: (v) =>
                              setState(() => _agreedEula = v ?? false),
                          activeColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '[필수] 서비스 이용약관에 동의합니다.\n(비방·부적절한 게시글 작성 시 즉시 탈퇴 처리)\n'
                          '[Required] I agree to the Terms of Service.\n(Defamatory or inappropriate posts will result in immediate account termination)',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 동의 버튼
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _allAgreed ? _onAgree : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                    child: const Text(
                      '동의하고 시작하기 / Agree & Continue',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
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

  Widget _buildSection({
    required String title,
    required String content,
    String? contentEn,
  }) {
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
        if (contentEn != null) ...[
          const SizedBox(height: 12),
          Text(
            contentEn,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.6,
            ),
          ),
        ],
      ],
    );
  }
}
