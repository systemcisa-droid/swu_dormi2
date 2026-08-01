class CheckInOutStrings {
  final bool isEnglish;
  const CheckInOutStrings(this.isEnglish);

  String get title => isEnglish ? 'Move-in / Move-out' : '입사/퇴사';

  static const List<String> categoryLabelsKo = [
    '입사자격', '입사절차',
    '정규퇴사', '학기중퇴사', '강제퇴사', '영구퇴사', '관비환불',
  ];

  static const List<String> categoryLabelsEn = [
    'Eligibility', 'Procedure',
    'Regular Move-out', 'Mid-semester', 'Forced Move-out', 'Permanent Move-out', 'Fee Refund',
  ];
}

class SubSection {
  final String titleKo;
  final String titleEn;
  final String contentKo;
  final String contentEn;

  const SubSection({
    required this.titleKo,
    required this.titleEn,
    required this.contentKo,
    required this.contentEn,
  });
}

class GuideCard {
  final String titleKo;
  final String titleEn;
  final List<SubSection> sections;
  final List<String> bulletsKo;
  final List<String> bulletsEn;

  const GuideCard({
    required this.titleKo,
    required this.titleEn,
    this.sections = const [],
    this.bulletsKo = const [],
    this.bulletsEn = const [],
  });
}

class CheckInOutContent {
  static const List<GuideCard> cards = [
    // 1. 입사 자격
    GuideCard(
      titleKo: '1. 입사 자격',
      titleEn: '1. Move-in Eligibility',
      sections: [
        SubSection(
          titleKo: '가. 지역', titleEn: 'a. Region',
          contentKo: '서울, 의정부, 남양주, 하남, 구리, 과천, 광주, 동두천, 성남(9개 지역)를 제외한 지역 거주자 (부모님 등본 기준)',
          contentEn: 'Residents of regions other than Seoul, Uijeongbu, Namyangju, Hanam, Guri, Gwacheon, Gwangju, Dongducheon, and Seongnam (9 regions), based on the parents\' resident registration',
        ),
        SubSection(
          titleKo: '나. 성적', titleEn: 'b. Grades',
          contentKo: '직전학기 평점 3.0 이상인 학생',
          contentEn: 'Students with a GPA of 3.0 or higher in the previous semester',
        ),
        SubSection(
          titleKo: '다. 우선입사', titleEn: 'c. Priority Move-in',
          contentKo:
              '사생회 임원, 총학생회, 국가보훈대상자(한부모, 부모), 기초생활수급자, 비풍장학금, 바롬교시반, 대학선교방, 석.박사 통합과정, 장애 학생 및 기타 규정에 의해 따른 입사가 허가 된 자\n\n'
              '※ 상기 우선입사 대상자들은 지역, 성적 등 기본적인 입사자격이 충족되어야 하며, 반드시 신청 기간 내에 증명서를 제출 한다. 단, 비고시반은 지역 제한이 없다. 국가보훈대상자, 기초생활수급자, 비풍장학금 2,4인실만 우선 배정이 가능하고, 비고시반은 2인실만, 대학선교방은 4인실만, 석.박사 통합과정은 1, 2인실만 입사 가능하다.',
          contentEn:
              'Residents\' council officers, student council members, national merit recipients (single/both parents), basic livelihood recipients, Bipung scholarship recipients, Barom exam-prep class members, university mission house members, integrated master\'s/doctoral program students, students with disabilities, and others permitted to move in under other regulations\n\n'
              '※ The above priority applicants must still meet the basic eligibility requirements such as region and grades, and must submit supporting documents within the application period. However, there is no regional restriction for exam-prep class members. National merit recipients, basic livelihood recipients, and Bipung scholarship recipients may only be prioritized for 2- or 4-person rooms; exam-prep class members only for 2-person rooms; university mission house members only for 4-person rooms; and integrated master\'s/doctoral program students only for 1- or 2-person rooms.',
        ),
        SubSection(
          titleKo: '라. 제한사항', titleEn: 'd. Restrictions',
          contentKo: '강제퇴사자, 영구퇴사자 및 규정에 따른 징계제한자는 입사를 불허한다.',
          contentEn: 'Those who have been forced to move out, permanently moved out, or are restricted due to disciplinary action under the regulations are not permitted to move in.',
        ),
        SubSection(
          titleKo: '마. 주의사항', titleEn: 'e. Notes',
          contentKo: '서류 미제출자 및 입사신청 시 허위기재사항이 있을 시에는 입사를 취소한다.',
          contentEn: 'Move-in will be canceled for those who fail to submit required documents or who provide false information on the move-in application.',
        ),
      ],
    ),
    // 2. 입사절차
    GuideCard(
      titleKo: '2. 입사절차',
      titleEn: '2. Move-in Procedure',
      sections: [
        SubSection(
          titleKo: '가. 기숙사 입사 공고', titleEn: 'a. Dormitory Move-in Announcement',
          contentKo:
              '1. 학교 홈페이지 및 기숙사 홈페이지에 모집 공고\n'
              '2. 기숙사 입사를 원하는 학생은 신청기간 중 통합정보시스템 (swis.swu.ac.kr) 에서 입사 신청',
          contentEn:
              '1. The recruitment notice is posted on the school website and the dormitory website.\n'
              '2. Students who wish to move into the dormitory must apply through the Integrated Information System (swis.swu.ac.kr) during the application period.',
        ),
        SubSection(
          titleKo: '나. 컴퓨터 무작위 추첨', titleEn: 'b. Computer Random Draw',
          contentKo:
              '1. 학생들이 신청한 내용에 따라 실 (1인실, 2인실, 4인실), 침상 및 예상 (임의지정) 을 추첨하여 배정한다.\n'
              '2. 추첨으로 결정된 사항은 임의로 변경할 수 없다. (입사 후 호실 변경 불가)',
          contentEn:
              '1. Based on students\' applications, rooms (1-, 2-, or 4-person), beds, and spare rooms (randomly assigned) are drawn and assigned.\n'
              '2. Results decided by the draw may not be changed arbitrarily. (Room changes are not allowed after move-in.)',
        ),
        SubSection(
          titleKo: '다. 입사승인여부 확인', titleEn: 'c. Checking Move-in Approval',
          contentKo: '1. 통합정보시스템 (swis.swu.ac.kr) 에서 본인의 입사승인여부를 반드시 확인해야 한다.',
          contentEn: '1. Students must check their move-in approval status on the Integrated Information System (swis.swu.ac.kr).',
        ),
        SubSection(
          titleKo: '라. 관비 (입사비 포함) 및 식비납부', titleEn: 'd. Payment of Dormitory Fee (Including Move-in Fee) and Meal Fee',
          contentKo:
              '1. 지정된 기간 내에 관비 (입사비 포함) 및 식비를 지정된 구좌로 납입해야 한다.\n'
              '2. 기간 내에 관비 (입사비 포함) 및 식비를 납입하지 않은 학생은 입사 포기로 간주하고 대기자로 충원한다.',
          contentEn:
              '1. The dormitory fee (including the move-in fee) and meal fee must be paid to the designated account within the specified period.\n'
              '2. Students who fail to pay the dormitory fee (including the move-in fee) and meal fee within the period are considered to have forfeited their move-in, and a waitlisted student will be admitted instead.',
        ),
        SubSection(
          titleKo: '마. 제출서류', titleEn: 'e. Documents to Submit',
          contentKo:
              '1. 흉부 X-Ray 검진서 : 모든 입사자는 입사 전 지정된 기간에 제출해야 하며, 미제출 시 입사허가를 취소한다. (흉부 X-Ray 검사결과가 반드시 포함된 검진서 제출)\n'
              '2. 주민등록등본 : 모든 입사자는 본인의 주민등록등본 (거주지 확인용) 을 입사 전 지정된 기간에 제출해야 하며, 입사 필수 온라인 신청 시 기재된 내용이 사실과 다를 경우 입사를 취소할 수 있다.\n'
              '3. 서약서 : 모든 입사자는 서약서에 동의해야 한다. (통합정보시스템 상에서 서명 진행)',
          contentEn:
              '1. Chest X-ray examination report: All residents must submit this within the designated period before moving in; failure to submit will result in cancellation of move-in approval. (The report must include chest X-ray results.)\n'
              '2. Copy of resident registration: All residents must submit their own copy of resident registration (to confirm residence) within the designated period before moving in; move-in may be canceled if the information provided during the required online application differs from the facts.\n'
              '3. Agreement form: All residents must agree to the agreement form. (Signed electronically on the Integrated Information System.)',
        ),
        SubSection(
          titleKo: '바. 입사', titleEn: 'f. Move-in',
          contentKo: '1. 입사 당일 지정된 시간에 해당 기숙사의 소정의 절차를 마치고 입사할 수 있다.',
          contentEn: '1. On the day of move-in, residents may move in after completing the required procedures at the designated time.',
        ),
      ],
    ),
    // 1. 정규 퇴사
    GuideCard(
      titleKo: '1. 정규 퇴사',
      titleEn: '1. Regular Move-out',
      sections: [
        SubSection(
          titleKo: '가. 퇴사일', titleEn: 'a. Move-out Date',
          contentKo: '종강일 다음 날 오전에 퇴사하는 것을 원칙으로 하며, 그 기간은 추후에 공지한다.',
          contentEn: 'In principle, move-out takes place in the morning of the day after the semester ends; the exact period will be announced later.',
        ),
        SubSection(
          titleKo: '나. 주의사항', titleEn: 'b. Notes',
          contentKo: '퇴사확인증을 받지 않고 퇴사 시에는 무단퇴사로 간주되어 영구퇴사되며, 기숙사 재입사를 불허한다.',
          contentEn: 'Moving out without obtaining a move-out confirmation is considered an unauthorized move-out, resulting in permanent move-out and a ban on re-admission to the dormitory.',
        ),
      ],
    ),
    // 2. 학기 중 퇴사
    GuideCard(
      titleKo: '2. 학기 중 퇴사',
      titleEn: '2. Mid-semester Move-out',
      sections: [
        SubSection(
          titleKo: '가. 중간퇴사 사유', titleEn: 'a. Reasons for Mid-semester Move-out',
          contentKo: '학기 중 중간퇴사는 자퇴, 휴학, 취업, 질병, 입사신청 불가 지역으로의 거주지 이전 및 기타 기숙사 사생수칙에 명시된 사유로 제한하며, 증빙서류를 제출하고 승인을 받은 후에 퇴사할 수 있다.',
          contentEn: 'Mid-semester move-out is limited to reasons such as withdrawal from school, leave of absence, employment, illness, relocation to a region ineligible for dormitory application, and other reasons specified in the dormitory resident rules; a resident may move out only after submitting supporting documents and receiving approval.',
        ),
        SubSection(
          titleKo: '나. 무단퇴사', titleEn: 'b. Unauthorized Move-out',
          contentKo: '위의 특별한 사유 없이 무단 퇴사할 경우 영구퇴사로 간주되며, 기숙사 재입사를 불허한다.',
          contentEn: 'Moving out without one of the special reasons above is considered a permanent move-out, and re-admission to the dormitory is not permitted.',
        ),
      ],
    ),
    // 3. 강제 퇴사
    GuideCard(
      titleKo: '3. 강제 퇴사',
      titleEn: '3. Forced Move-out',
      sections: [
        SubSection(
          titleKo: '가. 벌점 기준', titleEn: 'a. Penalty Point Criteria',
          contentKo: '입사학기 (1학기, 여름방학, 2학기, 겨울방학) 단위로 하여, 각 학기 16점 이상의 벌점을 받은 경우 규정에 따라 강제퇴사될 수 있으며, 강제퇴사가 결정된 학생은 행정실에서 지정하는 기간 (퇴사 결정일로부터 5일) 내에 퇴사해야 한다.',
          contentEn: 'On a per-residency-semester basis (Semester 1, summer break, Semester 2, winter break), a resident who accumulates 16 or more penalty points in a given semester may be forced to move out under the regulations; a student whose forced move-out has been decided must move out within the period designated by the administrative office (5 days from the date of the move-out decision).',
        ),
        SubSection(
          titleKo: '나. 재입사 제한', titleEn: 'b. Re-admission Restriction',
          contentKo: '강제퇴사자는 1년간 재입사를 불허한다.',
          contentEn: 'Those forced to move out are not permitted to re-apply for one year.',
        ),
        SubSection(
          titleKo: '다. 환불 규정', titleEn: 'c. Refund Policy',
          contentKo: '사생수칙 제 9장 제 43조에 의거하여 강제퇴사 시 관비 환불은 기숙사 규정에 따르며, 위약금 30%를 제외하고 환불한다.',
          contentEn: 'In accordance with Article 43 of Chapter 9 of the resident rules, refunds of dormitory fees upon forced move-out follow dormitory regulations, with a 30% penalty fee deducted from the refund.',
        ),
      ],
    ),
    // 4. 영구 퇴사
    GuideCard(
      titleKo: '4. 영구 퇴사',
      titleEn: '4. Permanent Move-out',
      sections: [
        SubSection(
          titleKo: '가. 퇴사 기준', titleEn: 'a. Move-out Criteria',
          contentKo: '사생수칙 제 9장 제 40조 4항에 해당하는 자는 영구퇴사될 수 있으며, 영구퇴사가 결정된 학생은 행정실에서 지정하는 기간 (퇴사 결정일로부터 5일) 내에 퇴사해야 한다.',
          contentEn: 'A person falling under Article 40, Paragraph 4 of Chapter 9 of the resident rules may be permanently moved out; a student whose permanent move-out has been decided must move out within the period designated by the administrative office (5 days from the date of the move-out decision).',
        ),
        SubSection(
          titleKo: '나. 재입사 제한', titleEn: 'b. Re-admission Restriction',
          contentKo: '영구퇴사자는 영구적으로 입사를 불허한다.',
          contentEn: 'Those permanently moved out are permanently barred from moving in again.',
        ),
        SubSection(
          titleKo: '다. 환불 규정', titleEn: 'c. Refund Policy',
          contentKo: '사생수칙 제 9장 제 43조에 의거하여 영구퇴사 시 관비의 환불은 기숙사 규정에 따르며, 위약금 30%를 제외하고 환불한다.',
          contentEn: 'In accordance with Article 43 of Chapter 9 of the resident rules, refunds of dormitory fees upon permanent move-out follow dormitory regulations, with a 30% penalty fee deducted from the refund.',
        ),
      ],
    ),
    // 5. 관비의 환불
    GuideCard(
      titleKo: '5. 관비의 환불',
      titleEn: '5. Refund of Dormitory Fees',
      sections: [
        SubSection(
          titleKo: '기본 원칙', titleEn: 'Basic Principle',
          contentKo: '중간퇴사 시 전체기간을 4분기로 나누어 입사 잔여기간에 해당하는 관비를 환불한다. (특별한 사유 있을 시 적용)',
          contentEn: 'For mid-semester move-out, the total period is divided into 4 quarters, and the dormitory fee corresponding to the remaining residency period is refunded. (Applies when there is a special reason.)',
        ),
      ],
      bulletsKo: [
        '입사기간의 1/4 이하 입주 시 관비의 75% 환불',
        '입사기간의 2/4 이하 입주 시 관비의 50% 환불',
        '입사기간의 3/4 이하 입주 시 관비의 25% 환불',
        '입사기간의 3/4 초과 입주 시 관비 환불 불가',
      ],
      bulletsEn: [
        'Refund of 75% of the dormitory fee if the stay is 1/4 or less of the residency period',
        'Refund of 50% of the dormitory fee if the stay is 2/4 or less of the residency period',
        'Refund of 25% of the dormitory fee if the stay is 3/4 or less of the residency period',
        'No refund of the dormitory fee if the stay exceeds 3/4 of the residency period',
      ],
    ),
  ];
}
