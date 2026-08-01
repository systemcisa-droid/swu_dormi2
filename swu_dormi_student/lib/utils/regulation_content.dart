// 사생수칙 본문(9개 장, 44개 조항) 한/영 데이터
class RegulationArticle {
  final String numberKo;
  final String numberEn;
  final String? titleKo;
  final String? titleEn;
  final String contentKo;
  final String contentEn;

  const RegulationArticle({
    required this.numberKo,
    required this.numberEn,
    this.titleKo,
    this.titleEn,
    required this.contentKo,
    required this.contentEn,
  });
}

class RegulationChapter {
  final String numberKo;
  final String numberEn;
  final String titleKo;
  final String titleEn;
  final List<RegulationArticle> articles;

  const RegulationChapter({
    required this.numberKo,
    required this.numberEn,
    required this.titleKo,
    required this.titleEn,
    required this.articles,
  });
}

class RegulationContent {
  static const List<String> categoryLabelsKo = [
    '총칙', '학생선발', '입·퇴사', '인원확인',
    '생활관리', '광고집회', '보건안전', '벌칙', '사생회',
  ];

  static const List<String> categoryLabelsEn = [
    'General', 'Selection', 'Move-in/out', 'Headcount',
    'Living', 'Notices', 'Health & Safety', 'Penalties', 'Council',
  ];

  static const List<RegulationChapter> chapters = [
    RegulationChapter(
      numberKo: '제1장',
      numberEn: 'Chapter 1',
      titleKo: '총칙',
      titleEn: 'General Provisions',
      articles: [
        RegulationArticle(
          numberKo: '제1조', numberEn: 'Article 1',
          titleKo: '(목적)', titleEn: '(Purpose)',
          contentKo: '이 수칙의 목적은 기숙사에 입사하는 학생들을 위하여 공동생활의 질서를 유지하고 이를 통해 면학 분위기를 조성하는데 있다.',
          contentEn: 'The purpose of these rules is to maintain order in communal living for students residing in the dormitory and to foster an atmosphere conducive to studying.',
        ),
        RegulationArticle(
          numberKo: '제2조', numberEn: 'Article 2',
          titleKo: '(명칭)', titleEn: '(Title)',
          contentKo: '이 수칙은 기숙사 사생수칙이라 칭한다.',
          contentEn: 'These rules shall be referred to as the Dormitory Resident Rules.',
        ),
      ],
    ),
    RegulationChapter(
      numberKo: '제2장',
      numberEn: 'Chapter 2',
      titleKo: '학생선발 기준',
      titleEn: 'Student Selection Criteria',
      articles: [
        RegulationArticle(
          numberKo: '제3조', numberEn: 'Article 3',
          contentKo: '''① 한국인 학생은 선발 기준 지역의 거주자이면서 성적이 3.0이상인 자로 컴퓨터 랜덤 추첨에 의하여 선발한다.
② 외국인 학생은 본교 소속의 외국인 학생에 한한다.
③ 장애학생의 입사자격 및 기준은 예외를 적용할 수 있으며, 장애학생의 입사신청이 없을 경우에 장애인실에 일반학생 혹은 기숙사 직원을 입사시킬 수 있다.''',
          contentEn: '''① Korean students are selected by computer random draw among residents of the designated eligible regions with a GPA of 3.0 or higher.
② International students are limited to international students enrolled at this university.
③ Exceptions may apply to the eligibility and criteria for students with disabilities; if no student with a disability applies, a general student or dormitory staff member may be assigned to the room designated for students with disabilities.''',
        ),
        RegulationArticle(
          numberKo: '제4조', numberEn: 'Article 4',
          contentKo: '''① 강제퇴사(외국인 포함) 등으로 입사 제한 조치를 받은 경우 해당기간동안 입사를 불허한다.
② 영구퇴사로 입사 제한 조치를 받은 경우 영구적으로 입사를 불허한다.
③ 외국인 재입사자인 경우 생활태도 우수자를 우선 선발한다.''',
          contentEn: '''① Students subject to move-in restrictions due to forced move-out (including international students) are not permitted to move in during the restricted period.
② Students subject to move-in restrictions due to permanent move-out are permanently barred from moving in.
③ For international students reapplying to move in, those with excellent conduct records are given priority.''',
        ),
        RegulationArticle(
          numberKo: '제5조', numberEn: 'Article 5',
          contentKo: '사생회 임원 중 생활태도가 우수한 경우, 다음 학기 입사에 우선 선발된다.',
          contentEn: 'Residents\' council officers with excellent conduct records are given priority for move-in the following semester.',
        ),
      ],
    ),
    RegulationChapter(
      numberKo: '제3장',
      numberEn: 'Chapter 3',
      titleKo: '입·퇴사',
      titleEn: 'Move-in / Move-out',
      articles: [
        RegulationArticle(
          numberKo: '제6조', numberEn: 'Article 6',
          contentKo: '입사는 개강 전으로 하며, 퇴사는 종강일 이후로 하되 정확한 일정은 따로 공지한다.',
          contentEn: 'Move-in takes place before the start of the semester, and move-out takes place after the end of the semester; the exact schedule will be announced separately.',
        ),
        RegulationArticle(
          numberKo: '제7조', numberEn: 'Article 7',
          contentKo: '''① 입사기간은 한 학기를 기준으로 하며, 학기 중 중간퇴사는 불허한다. 단, 자퇴, 휴학, 취업, 질병, 입사신청 불가지역 거주지 이전 등에 대해서는 증빙서류를 제출하고 승인을 받은 후에 퇴사할 수 있다.
② 방학 중에는 교내교과목과 프로그램 참석자에 한하여 해당부서의 요청에 의하여 프로그램이 끝나는 시기에 중간퇴사 할 수 있다.''',
          contentEn: '''① The residency period is based on one semester, and mid-semester move-out is not permitted. However, in cases such as withdrawal from school, leave of absence, employment, illness, or relocation to a region ineligible for dormitory application, a resident may move out mid-semester after submitting supporting documents and receiving approval.
② During vacation periods, only those attending on-campus courses or programs may move out mid-term, at the request of the relevant department, when the program ends.''',
        ),
        RegulationArticle(
          numberKo: '제8조', numberEn: 'Article 8',
          contentKo: '흉부 X-ray 검사결과지를 제출하고, 입사동의서에 동의한다.',
          contentEn: 'Residents must submit chest X-ray results and agree to the move-in consent form.',
        ),
        RegulationArticle(
          numberKo: '제9조', numberEn: 'Article 9',
          contentKo: '호실배정은 컴퓨터 무작위 추첨으로 결정되며 일단 배정된 방은 임의로 변경할 수 없다.',
          contentEn: 'Room assignments are determined by computer random draw, and once a room is assigned, it may not be changed arbitrarily.',
        ),
        RegulationArticle(
          numberKo: '제10조', numberEn: 'Article 10',
          contentKo: '''학기 중 다음 사항에 해당하는 학생은 책임교수의 명에 따라 퇴사조치 할 수 있다.
1. 학교 등록 미필자, 휴학자
2. 학칙에 의하여 학교에서 징계처분을 받은 자
3. 전염병 질환자, 보균자
4. 사생수칙 제9장 40조 3항, 4항에 해당하는 자(강제퇴사, 영구퇴사)''',
          contentEn: '''Students falling under the following categories during the semester may be ordered to move out by the responsible faculty member.
1. Students who have not completed school registration, or students on leave of absence
2. Students who have received disciplinary action from the school under school regulations
3. Students with a contagious disease or carriers of one
4. Students falling under Article 40, Paragraphs 3 and 4 of Chapter 9 of these rules (forced move-out, permanent move-out)''',
        ),
        RegulationArticle(
          numberKo: '제11조', numberEn: 'Article 11',
          contentKo: '퇴사 시에는 퇴사에 따르는 절차를 따라야 하며, 이를 지키지 않을 경우 재입사를 불허한다.',
          contentEn: 'Residents must follow the required move-out procedures when moving out; failure to do so will result in a ban on re-admission.',
        ),
      ],
    ),
    RegulationChapter(
      numberKo: '제5장',
      numberEn: 'Chapter 5',
      titleKo: '인원 확인',
      titleEn: 'Headcount Check',
      articles: [
        RegulationArticle(
          numberKo: '제15조', numberEn: 'Article 15',
          contentKo: '인원 확인의 목적은 사생의 생활과 시설의 점검을 통하여 보다 편안한 공동생활을 영위할 수 있게 하는 데 있다.',
          contentEn: 'The purpose of the headcount check is to enable more comfortable communal living by checking on residents and facilities.',
        ),
        RegulationArticle(
          numberKo: '제16조', numberEn: 'Article 16',
          contentKo: '인원 확인은 담당직원에 의하여 행해지며 상황에 따라서는 학생에게 위임할 수 있다.',
          contentEn: 'Headcount checks are conducted by staff in charge, and depending on the situation, may be delegated to a student.',
        ),
        RegulationArticle(
          numberKo: '제17조', numberEn: 'Article 17',
          contentKo: '인원 확인은 24시에 각자의 호실에서 실시한다. 주말과 공휴일 당일과 전일에는 인원확인을 실시하지 않는다.',
          contentEn: 'Headcount checks are conducted at midnight (24:00) in each room. Headcount checks are not conducted on weekends and public holidays, or the day before them.',
        ),
        RegulationArticle(
          numberKo: '제18조', numberEn: 'Article 18',
          contentKo: '인원 확인에 불참하거나 인원 확인시간을 지키지 못하는 경우 이에 준하는 벌점이 적용된다.',
          contentEn: 'Penalty points are applied for failing to participate in the headcount check or failing to meet the designated time.',
        ),
      ],
    ),
    RegulationChapter(
      numberKo: '제6장',
      numberEn: 'Chapter 6',
      titleKo: '생활 및 관리',
      titleEn: 'Living and Management',
      articles: [
        RegulationArticle(
          numberKo: '제19조', numberEn: 'Article 19',
          contentKo: '관내 시설이나 개인 소유물은 깨끗이 보존하고 정돈하여야 한다.',
          contentEn: 'On-site facilities and personal belongings must be kept clean and tidy.',
        ),
        RegulationArticle(
          numberKo: '제20조', numberEn: 'Article 20',
          contentKo: '각 방의 관리책임은 공동이 진다.',
          contentEn: 'Responsibility for managing each room is shared jointly by its occupants.',
        ),
        RegulationArticle(
          numberKo: '제21조', numberEn: 'Article 21',
          contentKo: '공용물의 파손, 분실 시에는 개인변상을 원칙으로 한다.',
          contentEn: 'In the event of damage to or loss of shared property, individual compensation is the principle.',
        ),
        RegulationArticle(
          numberKo: '제22조', numberEn: 'Article 22',
          contentKo: '전기, 수도, 난방 등의 고장 혹은 시설물의 파손을 발견하였을 때는 기숙사 행정실로 시설보수를 신청한다.',
          contentEn: 'If a malfunction in electricity, water, heating, or damage to a facility is discovered, a repair request should be submitted to the dormitory administrative office.',
        ),
        RegulationArticle(
          numberKo: '제23조', numberEn: 'Article 23',
          contentKo: '실내에서는 동물의 사육을 금한다.',
          contentEn: 'Keeping animals indoors is prohibited.',
        ),
        RegulationArticle(
          numberKo: '제24조', numberEn: 'Article 24',
          contentKo: '시설 비품은 임의로 이동하거나 독점할 수 없으며, 훼손되지 않도록 주의하여야 한다.',
          contentEn: 'Facility equipment may not be arbitrarily moved or monopolized, and care must be taken not to damage it.',
        ),
        RegulationArticle(
          numberKo: '제25조', numberEn: 'Article 25',
          contentKo: '''각 방의 쓰레기는 다음과 같이 처리한다.
1. 쓰레기는 봉투에 넣어서 지정된 쓰레기 처리장에 직접 버린다.
2. 재활용 쓰레기와 음식물 쓰레기는 지정된 장소의 분리수거함을 이용한다.''',
          contentEn: '''Trash in each room shall be disposed of as follows.
1. Trash must be placed in a bag and disposed of directly at the designated trash disposal area.
2. Recyclable waste and food waste must be disposed of using the separate collection bins at the designated location.''',
        ),
        RegulationArticle(
          numberKo: '제26조', numberEn: 'Article 26',
          titleKo: '사내 정숙', titleEn: '(Quietness in the Dormitory)',
          contentKo: '''1. 공동생활에 지장을 주지 않도록 소음 등에 주의하여야 한다.
2. 밤늦은 시간 휴대폰(전화), 컴퓨터(노트북) 등의 사용은 자제한다.''',
          contentEn: '''1. Residents must be mindful of noise so as not to disrupt communal living.
2. Use of mobile phones (calls), computers (laptops), etc., late at night should be minimized.''',
        ),
        RegulationArticle(
          numberKo: '제27조', numberEn: 'Article 27',
          contentKo: '각 방에서 식사할 수 없다. 단, 허락된 환자는 제외한다.',
          contentEn: 'Eating meals in individual rooms is not permitted, except for approved patients.',
        ),
        RegulationArticle(
          numberKo: '제28조', numberEn: 'Article 28',
          contentKo: '''주요 공용 비품과 후생시설의 사용은 다음 규정에 의하여 처리한다.
1. 전기용품의 사용은 사무실 승인을 받아 지정된 장소에서 사용한다.
2. 특별실에 있는 비품(예, 운동기구, 다리미, 전자렌지 등)은 이동을 금한다.
3. 특별실 사용 후, 다음에 이용할 사생들을 위하여 뒷정리를 깨끗이 한다.''',
          contentEn: '''The use of major shared equipment and welfare facilities shall be handled according to the following rules.
1. The use of electrical appliances requires office approval and must take place in a designated location.
2. Equipment in special rooms (e.g., exercise equipment, irons, microwaves, etc.) may not be moved.
3. After using a special room, residents must clean up thoroughly for the next residents to use.''',
        ),
        RegulationArticle(
          numberKo: '제29조', numberEn: 'Article 29',
          contentKo: '''기숙사 생활점검은 월 1회 이상 실시하며 사생은 성실히 응해야 한다.
1. 호실 청결상태, 시설, 비품 이상 유무 등 질서 있는 공동생활을 위해 필요한 사항의 점검 및 지도를 실시한다.
2. 지정된 일자에 1인 이상 재실한 상태에서 검사를 받는다.''',
          contentEn: '''Dormitory living inspections are conducted at least once a month, and residents must fully cooperate.
1. Inspections and guidance are conducted for matters necessary for orderly communal living, such as room cleanliness and the condition of facilities and equipment.
2. Inspections must be received with at least one resident present on the designated date.''',
        ),
        RegulationArticle(
          numberKo: '제30조', numberEn: 'Article 30',
          contentKo: '기숙사 안전교육(화재대피훈련, 소방안전교육)은 학기 중에 1회 이상 실시하며 사생은 성실히 응해야 한다.',
          contentEn: 'Dormitory safety training (fire evacuation drills, fire safety education) is conducted at least once per semester, and residents must fully cooperate.',
        ),
      ],
    ),
    RegulationChapter(
      numberKo: '제7장',
      numberEn: 'Chapter 7',
      titleKo: '광고, 유인물 배포, 집회',
      titleEn: 'Advertising, Flyer Distribution, and Assembly',
      articles: [
        RegulationArticle(
          numberKo: '제31조', numberEn: 'Article 31',
          contentKo: '학생은 기숙사 홈페이지 공지사항, 관내 지정 게시판의 광고 및 게시물을 반드시 확인하고 준수해야 한다.',
          contentEn: 'Students must check and comply with notices on the dormitory website and advertisements and postings on the designated on-site bulletin boards.',
        ),
        RegulationArticle(
          numberKo: '제32조', numberEn: 'Article 32',
          contentKo: '모든 광고는 게시 후 주중 48시간이 경과(주말 제외)하면 주지된 것으로 인정하고 뗄 수 있다.',
          contentEn: 'All advertisements are considered acknowledged and may be removed once 48 weekday hours (excluding weekends) have passed since posting.',
        ),
        RegulationArticle(
          numberKo: '제33조', numberEn: 'Article 33',
          contentKo: '학생이 관내에 게시하거나 유인물을 배포하고자 할 때에는 기숙사의 승인을 받아야 한다.',
          contentEn: 'Students who wish to post notices or distribute flyers on-site must obtain approval from the dormitory.',
        ),
        RegulationArticle(
          numberKo: '제34조', numberEn: 'Article 34',
          contentKo: '모든 관내의 학생 집회는 24시간 전까지 행정실로 신청한다.',
          contentEn: 'All student assemblies on-site must be applied for with the administrative office at least 24 hours in advance.',
        ),
      ],
    ),
    RegulationChapter(
      numberKo: '제8장',
      numberEn: 'Chapter 8',
      titleKo: '보건위생 및 안전',
      titleEn: 'Health, Hygiene, and Safety',
      articles: [
        RegulationArticle(
          numberKo: '제35조', numberEn: 'Article 35',
          contentKo: '모든 사생은 입사 전 흉부 X-ray 검사결과지를 제출해야 하며, 이에 따라 입사가 불가할 수 있다.',
          contentEn: 'All residents must submit chest X-ray results before moving in, and move-in may be denied based on the results.',
        ),
        RegulationArticle(
          numberKo: '제36조', numberEn: 'Article 36',
          contentKo: '사생들은 몸이 아플 때 교내에 있는 보건실을 이용 할 수 있다.(이용시간 : 평일 9:00 ∼ 17:30) 단 그 외의 시간에는 기숙사 행정실 또는 경비실을 이용할 수 있다.',
          contentEn: 'Residents may use the on-campus health office when feeling ill (hours: weekdays 9:00–17:30). Outside these hours, they may use the dormitory administrative office or security office.',
        ),
        RegulationArticle(
          numberKo: '제37조', numberEn: 'Article 37',
          contentKo: '담당직원 또는 보건사의 지시가 있을 때 사생은 즉시 병원진료를 받아야 하며 치료비는 본인이 부담한다.',
          contentEn: 'When instructed by staff in charge or a health worker, a resident must immediately seek medical treatment, and the resident is responsible for the cost.',
        ),
        RegulationArticle(
          numberKo: '제38조', numberEn: 'Article 38',
          contentKo: '허가되지 않은 화재위험물질, 전열 기구는 관내에서 사용할 수 없으며 이를 어겼을 시에는 퇴사 조치한다.',
          contentEn: 'Unauthorized fire-hazard materials and heating appliances may not be used on-site; violators will be subject to move-out.',
        ),
        RegulationArticle(
          numberKo: '제39조', numberEn: 'Article 39',
          contentKo: '재해 및 안전, 시설점검, 수리와 관련하여 사생이 재실하고 있지 않을 경우 호실을 열고 점검할 수 있고, 점검사실을 사후에 통보한다.',
          contentEn: 'In matters related to disaster and safety, facility inspection, or repairs, if a resident is not present, the room may be opened for inspection, and the resident will be notified afterward.',
        ),
      ],
    ),
    RegulationChapter(
      numberKo: '제10장',
      numberEn: 'Chapter 10',
      titleKo: '사생회',
      titleEn: 'Residents\' Council',
      articles: [
        RegulationArticle(
          numberKo: '제44조', numberEn: 'Article 44',
          contentKo: '사생 2/3 참석, 과반수 찬성으로 사생회장 1명과 약간 명으로 사생회를 구성하며, 기숙사 책임교수의 임명을 받는다.',
          contentEn: 'With 2/3 of residents present and a majority vote, the residents\' council is formed with one council president and several members, and they are appointed by the dormitory\'s responsible faculty member.',
        ),
        RegulationArticle(
          numberKo: '제45조', numberEn: 'Article 45',
          contentKo: '사생회는 사생들의 대표로서 사생들의 의견을 수렴하고 학생들의 자치활동 및 원활한 기숙사 생활을 돕는다.(인원확인, 입·퇴사업무보조, 소방훈련, 안전교육 등)',
          contentEn: 'As representatives of the residents, the residents\' council gathers residents\' opinions and supports students\' self-governing activities and smooth dormitory life (headcount checks, assistance with move-in/move-out tasks, fire drills, safety education, etc.).',
        ),
      ],
    ),
  ];

  // ── 제9장 벌칙 (구조가 다르므로 별도 처리) ──
  static const String penaltyChapterNumberKo = '제9장';
  static const String penaltyChapterNumberEn = 'Chapter 9';
  static const String penaltyChapterTitleKo = '벌칙';
  static const String penaltyChapterTitleEn = 'Penalties';

  static const String article40NumberKo = '제40조';
  static const String article40NumberEn = 'Article 40';
  static const String article40IntroKo = '각 조 수칙을 위반한 사생에게는 다음의 처분을 할 수 있으며 벌점 기준은 별첨1과 같다.';
  static const String article40IntroEn = 'Residents who violate any provision of these rules may be subject to the following actions; the penalty point criteria are as shown in Attachment 1.';

  static const String warningKo = '1. 경고';
  static const String warningEn = '1. Warning';
  static const String penaltyPointKo = '2. 벌점';
  static const String penaltyPointEn = '2. Penalty points';

  static const String forcedMoveOutKo = '3. 강제퇴사';
  static const String forcedMoveOutEn = '3. Forced move-out';
  static const List<String> forcedMoveOutSubItemsKo = [
    '가. 벌점이 15점을 초과하여 16점 이상인 경우',
    '나. 퇴사일 청소확인을 받지 않고 퇴사하는 경우',
    '다. 기타 책임교수가 사생의 안전 등 강제퇴사가 필요하다고 판단하는 경우',
  ];
  static const List<String> forcedMoveOutSubItemsEn = [
    'a. When penalty points exceed 15, i.e., reach 16 or more',
    'b. When moving out without receiving a cleaning check on the move-out date',
    'c. Other cases where the responsible faculty member determines that forced move-out is necessary, such as for resident safety',
  ];

  static const String permanentMoveOutKo = '4. 영구퇴사';
  static const String permanentMoveOutEn = '4. Permanent move-out';
  static const List<String> permanentMoveOutSubItemsKo = [
    '가. 외부인과 출입, 무단퇴사, 음주, 흡연, 절도, 본교 비사생에게 기숙실 출입 혹은 기숙사에서 잠을 자도록 한 경우',
    '나. 기숙사내 반입이 불가한 물품을 사용하거나, 해당 물품으로 인해 문제를 야기한 경우',
    '다. 출입 게이트를 비정상적으로 넘나드는 행위',
    '라. 기숙사 통금시간에 행정실 승인 없이 출입 하는 행위(01시 ～ 05시)',
    '마. 기타 책임교수가 공동생활이 불가능하다고 판단한 경우',
  ];
  static const List<String> permanentMoveOutSubItemsEn = [
    'a. Entering/exiting with outsiders, unauthorized move-out, drinking alcohol, smoking, theft, or allowing a non-resident of this school to enter the room or sleep in the dormitory',
    'b. Using prohibited items in the dormitory, or causing problems due to such items',
    'c. Abnormally crossing the entry/exit gate',
    'd. Entering/exiting during the dormitory curfew hours without administrative office approval (01:00–05:00)',
    'e. Other cases where the responsible faculty member determines that communal living is not possible',
  ];

  static const String itemsTitleKo = '반입 가능/불가 물품';
  static const String itemsTitleEn = 'Permitted/Prohibited Items';
  static const String allowedItemsKo =
      '* 반입가능 : PC, 헤어드라이어, 충전기, 스탠드, 가습기, 소형청소기(핸디형), 가습기(초음파), 고데기(KC전기안전인증을 통과한 자동전원차단 기능이 포함된 제품, 스티커 미부착 고데기 사용시 벌점 10점 부과 및 해당기기 압수 폐기처분)';
  static const String allowedItemsEn =
      '* Permitted: PC, hair dryer, charger, desk lamp, humidifier, small handheld vacuum cleaner, ultrasonic humidifier, hair straightener/curler (must have passed KC electrical safety certification with an auto power-off function; using one without the certification sticker results in a 10-point penalty and confiscation/disposal of the device)';
  static const String prohibitedLabelKo = '* 반입불가 :';
  static const String prohibitedLabelEn = '* Prohibited:';
  static const String prohibitedElectricKo =
      '-전기제품 : 전기히터, 전기요, 온수매트, 전기방석, 전기밥솥, 커피포트, 커피머신, 전기프라이팬, 라면포트, 오븐, 토스트기, 에어프라이어, 가열식 가습기, 선풍기, 에어서큘레이터, 요구르트제조기, 다리미, 전동킥보드 등';
  static const String prohibitedElectricEn =
      '-Electrical appliances: electric heater, electric blanket, hot water mat, electric cushion, rice cooker, coffee pot, coffee machine, electric frying pan, ramen pot, oven, toaster, air fryer, heating-type humidifier, electric fan, air circulator, yogurt maker, iron, electric kickboard, etc.';
  static const String prohibitedFireKo =
      '-화재위험물질 : 휴대용 가스레인지, 성냥, 라이터, 담배(전자담배 포함), 모기향, 향초, 양초, 휘발성 유류, 폭약';
  static const String prohibitedFireEn =
      '-Fire-hazard materials: portable gas stove, matches, lighters, cigarettes (including e-cigarettes), mosquito coils, incense, candles, volatile oils, explosives';
  static const String prohibitedAlcoholKo =
      '-주류 : 모든 종류의 주류, 무알콜 맥주 등(알콜이 조금이라도 포함된 경우 주류에 포함)';
  static const String prohibitedAlcoholEn =
      '-Alcoholic beverages: all types of alcohol, non-alcoholic beer, etc. (if it contains any alcohol at all, it is considered an alcoholic beverage)';
  static const String prohibitedPenaltyNoticeKo =
      '※ 반입 불가 물품 소지 1회 적발시 벌점10점, 2회 적발시 강제퇴사, 3회 적발시 영구 퇴사 적용';
  static const String prohibitedPenaltyNoticeEn =
      '※ First offense for possessing a prohibited item: 10-point penalty; second offense: forced move-out; third offense: permanent move-out';

  static const String article41NumberKo = '제41조';
  static const String article41NumberEn = 'Article 41';
  static const String article41Item1Ko = '① 별첨2의 상점 기준표에 의하여 상점을 부과하며, 상점은 부과된 벌점을 상쇄할 수 있다.';
  static const String article41Item1En = '① Reward points are granted according to the reward point criteria in Attachment 2, and reward points may offset assessed penalty points.';
  static const String article41Item2Ko = '② 벌점으로 퇴사가 결정된 학생은 행정실에서 지정하는 기간(약 5일)내 퇴사하여야 하나, 부득이한 경우 행정실의 심의를 거쳐 최대 20일까지 그 기간을 연장할 수 있다.';
  static const String article41Item2En = '② A student whose move-out is decided due to penalty points must move out within the period designated by the administrative office (about 5 days), but in unavoidable circumstances, the period may be extended up to 20 days upon review by the administrative office.';
  static const String article41Item3Ko = '퇴사 처분 사실은 학생과 보호자에게 고지하며, 외국인은 국제교류팀에 고지한다.';
  static const String article41Item3En = 'The fact of the move-out decision is notified to the student and guardian; for international students, it is notified to the International Exchange Team.';

  static const String article42NumberKo = '제42조';
  static const String article42NumberEn = 'Article 42';
  static const String article42Item1Ko = '① 퇴사는 강제퇴사와 영구퇴사로 구분되며 강제퇴사자는 1년 동안 입사가 불가하고, 영구퇴사자는 영구적으로 입사를 불허한다.';
  static const String article42Item1En = '① Move-out is divided into forced move-out and permanent move-out; those forced to move out cannot move in for one year, and those permanently moved out are permanently barred from moving in.';
  static const String article42Item2Ko = '② 강제퇴사 이상의 징계처분을 받은 자가 이의를 제기하고자 하는 경우 통보받은 날로 부터 10일 이내에 서면으로 이의신청서를 제출하여야 하며, 기숙사운영위원회의 심의를 거쳐 학생의 퇴사여부를 결정한다.';
  static const String article42Item2En = '② A student who has received disciplinary action of forced move-out or higher and wishes to appeal must submit a written objection within 10 days of notification, and the dormitory operating committee will review the case and determine whether the student must move out.';

  static const String article43NumberKo = '제43조';
  static const String article43NumberEn = 'Article 43';
  static const String article43ContentKo = '관비환불은 기숙사규정에 따른다.';
  static const String article43ContentEn = 'Refunds of dormitory fees are governed by dormitory regulations.';
}
