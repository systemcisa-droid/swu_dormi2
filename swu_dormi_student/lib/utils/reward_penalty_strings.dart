class RewardPenaltyStrings {
  final bool isEnglish;
  const RewardPenaltyStrings(this.isEnglish);

  String _t(String ko, String en) => isEnglish ? en : ko;

  String get title => _t('상벌점', 'Reward/Penalty Points');
  String get tabCriteria => _t('기준표', 'Criteria');
  String get tabHistory => _t('이력', 'History');

  String get userDataUnavailable => _t('사용자 정보를 불러올 수 없습니다', 'Unable to load user information');
  String genericError(Object e) => _t('오류가 발생했습니다: $e', 'An error occurred: $e');

  String get currentTotalLabel => _t('현재 상벌점 합계', 'Current Point Total');
  String points(int p) => _t('$p점', '$p pts');
  String historyCount(int n) => _t('이력 ($n건)', 'History ($n)');
  String get noHistory => _t('상벌점 이력이 없습니다', 'No point history');

  String get penaltyCriteriaTitle => _t('벌점 기준표', 'Penalty Point Criteria');
  String get rewardCriteriaTitle => _t('상점 기준표', 'Reward Point Criteria');
}

class CriteriaItem {
  final String descriptionKo;
  final String descriptionEn;
  final String pointsKo;
  final String pointsEn;
  const CriteriaItem({
    required this.descriptionKo,
    required this.descriptionEn,
    required this.pointsKo,
    required this.pointsEn,
  });
}

class CriteriaCard {
  final String? number;
  final String titleKo;
  final String titleEn;
  final List<Object> items; // String (subtitle), CriteriaItem, or _WarningEntry
  const CriteriaCard({
    this.number,
    required this.titleKo,
    required this.titleEn,
    required this.items,
  });
}

class SubTitle {
  final String ko;
  final String en;
  const SubTitle(this.ko, this.en);
}

class WarningEntry {
  final String ko;
  final String en;
  final bool isHighlight;
  const WarningEntry(this.ko, this.en, {this.isHighlight = false});
}

class RewardPenaltyContent {
  static const List<CriteriaCard> penaltyCards = [
    CriteriaCard(
      number: '1',
      titleKo: '지각 관련',
      titleEn: 'Late Arrival',
      items: [
        SubTitle('지각한 경우 (기숙사 폐문시간 24시)', 'When late (dormitory closing time is midnight)'),
        CriteriaItem(descriptionKo: '24시 ~ 24시 15분', descriptionEn: '00:00 - 00:15', pointsKo: '3점', pointsEn: '3 pts'),
        CriteriaItem(descriptionKo: '24시 15분 초과 ~ 01시', descriptionEn: 'After 00:15 - 01:00', pointsKo: '7점', pointsEn: '7 pts'),
        CriteriaItem(descriptionKo: '01시 초과 ~ 05시', descriptionEn: 'After 01:00 - 05:00', pointsKo: '출입불가', pointsEn: 'No entry'),
        CriteriaItem(descriptionKo: '인원확인지각(관내에 있었으나 인원확인에 늦은 경우)', descriptionEn: 'Late for headcount check (was inside the building but late for headcount)', pointsKo: '1점', pointsEn: '1 pt'),
      ],
    ),
    CriteriaCard(
      number: '2',
      titleKo: '출입 관련',
      titleEn: 'Building Access',
      items: [
        SubTitle('본교 비사생과 출입한 경우', 'Entering with a non-resident student of the university'),
        CriteriaItem(descriptionKo: '1회', descriptionEn: '1st offense', pointsKo: '13점', pointsEn: '13 pts'),
        SubTitle('외부인(본교 비사생 포함)의 출입을 묵인한 경우', 'Condoning entry of an outsider (including non-resident students)'),
        CriteriaItem(descriptionKo: '1회', descriptionEn: '1st offense', pointsKo: '5점', pointsEn: '5 pts'),
        SubTitle('출입카드(학생증, 임시출입증)를 무단으로 사용하는 경우', 'Unauthorized use of an access card (student ID, temporary access card)'),
        CriteriaItem(descriptionKo: '3회', descriptionEn: '3rd offense', pointsKo: '3점', pointsEn: '3 pts'),
        SubTitle('출입카드 미소지로 출입하는 경우', 'Entering without carrying an access card'),
        CriteriaItem(descriptionKo: '3회', descriptionEn: '3rd offense', pointsKo: '1점', pointsEn: '1 pt'),
        CriteriaItem(descriptionKo: '4회', descriptionEn: '4th offense', pointsKo: '2점', pointsEn: '2 pts'),
        CriteriaItem(descriptionKo: '5회 이상(1회 초과 시마다 1점 추가)', descriptionEn: '5th offense or more (1 additional point per further offense)', pointsKo: '3점', pointsEn: '3 pts'),
      ],
    ),
    CriteriaCard(
      number: '3',
      titleKo: '규칙 위반',
      titleEn: 'Rule Violations',
      items: [
        CriteriaItem(descriptionKo: '사생이 정당한 사유 없이 기숙사 직원의 지시에 불응하거나 사생 혹은 보호자가 폭언을 하는 경우', descriptionEn: 'A resident refuses staff instructions without just cause, or a resident or guardian uses abusive language', pointsKo: '5~10점', pointsEn: '5-10 pts'),
        CriteriaItem(descriptionKo: '화재대피훈련 불참 등 공동생활을 저해하는 행위를 하는 경우', descriptionEn: 'Acts that disrupt communal living, such as not participating in fire evacuation drills', pointsKo: '1~10점', pointsEn: '1-10 pts'),
        CriteriaItem(descriptionKo: '기숙사내 반입이 불가한 물품을 소지한 경우', descriptionEn: 'Possessing items prohibited in the dormitory', pointsKo: '10점', pointsEn: '10 pts'),
        WarningEntry(
          '※ 반입 불가 물품 소지 1회 적발시 벌점 10점, 2회 적발시 강제퇴사, 3회 적발시 영구퇴사 적용',
          '※ Possession of prohibited items: 10 penalty points on the 1st offense, forced move-out on the 2nd, permanent move-out on the 3rd',
        ),
        WarningEntry(
          '※ 방에서 개봉된 주류 병 및 캔 적발 시 영구 퇴사 적용',
          '※ Discovery of opened alcohol bottles or cans in the room results in permanent move-out',
          isHighlight: true,
        ),
      ],
    ),
    CriteriaCard(
      number: '5',
      titleKo: '강제 퇴사 사유',
      titleEn: 'Grounds for Forced Move-out',
      items: [
        CriteriaItem(descriptionKo: '벌점이 15점을 초과하여 16점 이상인 경우', descriptionEn: 'Penalty points exceed 15, reaching 16 or more', pointsKo: '강제퇴사', pointsEn: 'Forced move-out'),
        CriteriaItem(descriptionKo: '퇴사일 청소확인을 받지 않고 퇴사하는 경우', descriptionEn: 'Moving out without receiving a cleaning check on the move-out day', pointsKo: '강제퇴사', pointsEn: 'Forced move-out'),
        CriteriaItem(descriptionKo: '기타 책임교수가 사생의 안전 등 강제퇴사가 필요하다고 판단하는 경우', descriptionEn: 'The supervising professor determines forced move-out is necessary for the resident\'s safety or other reasons', pointsKo: '강제퇴사', pointsEn: 'Forced move-out'),
      ],
    ),
    CriteriaCard(
      number: '6',
      titleKo: '영구 퇴사 사유',
      titleEn: 'Grounds for Permanent Move-out',
      items: [
        CriteriaItem(descriptionKo: '외부인과 출입, 무단퇴사, 음주, 흡연, 절도, 본교 비사생에게 기숙실 출입 혹은 기숙사에서 잠을 자도록 한 경우 등', descriptionEn: 'Entering with an outsider, unauthorized move-out, drinking, smoking, theft, allowing a non-resident student to enter or sleep in the dormitory, etc.', pointsKo: '영구퇴사', pointsEn: 'Permanent move-out'),
        CriteriaItem(descriptionKo: '기숙사내 반입이 불가한 물품을 사용하거나, 해당 물품으로 인해 문제를 야기한 경우', descriptionEn: 'Using items prohibited in the dormitory, or causing problems due to such items', pointsKo: '영구퇴사', pointsEn: 'Permanent move-out'),
        CriteriaItem(descriptionKo: '출입 게이트를 비정상적으로 넘나드는 행위', descriptionEn: 'Abnormally passing through the access gate', pointsKo: '영구퇴사', pointsEn: 'Permanent move-out'),
        CriteriaItem(descriptionKo: '기숙사 통금시간에 행정실 승인 없이 출입하는 행위(01시~05시)', descriptionEn: 'Entering during dormitory curfew hours (01:00-05:00) without administrative office approval', pointsKo: '영구퇴사', pointsEn: 'Permanent move-out'),
        CriteriaItem(descriptionKo: '기타 책임교수가 공동생활이 불가능하다고 판단한 경우', descriptionEn: 'The supervising professor determines communal living is no longer possible', pointsKo: '영구퇴사', pointsEn: 'Permanent move-out'),
      ],
    ),
  ];

  static const String penaltyInfoKo =
      '강제퇴사(벌점 16점 이상) 및 영구퇴사가 결정된 학생의 경우 보호자에게 고지하며 발생일로부터 5일 이내 퇴사\n\n강제퇴사 및 영구퇴사의 경우 기숙사 규정에 의거, 위약금을 제하고 환불.';
  static const String penaltyInfoEn =
      'For students who are forced to move out (16 or more penalty points) or permanently moved out, guardians are notified, and the student must move out within 5 days of the decision.\n\nFor forced or permanent move-out, refunds follow dormitory regulations with the penalty fee deducted.';

  static const List<CriteriaCard> rewardCards = [
    CriteriaCard(
      titleKo: '안전',
      titleEn: 'Safety',
      items: [
        CriteriaItem(descriptionKo: '안전교육참석(소방, 전기) - 학기당 1회, 계절학기당 1회', descriptionEn: 'Attending safety training (fire, electrical) - once per semester, once per intersession', pointsKo: '3점', pointsEn: '3 pts'),
        CriteriaItem(descriptionKo: '응급상황 사생동행 - 행정실에 신고하고 행정실에서 동행하도록 한 경우', descriptionEn: 'Accompanying a resident in an emergency - reported to the administrative office and asked to accompany by the office', pointsKo: '2점', pointsEn: '2 pts'),
        CriteriaItem(descriptionKo: '심폐소생술 교육이수증 제출 - 심폐소생술 교내 · 외 교육 참여 (한 학기 중 택1 인정)', descriptionEn: 'Submitting a CPR training completion certificate - participation in on/off-campus CPR training (one recognized per semester)', pointsKo: '5점', pointsEn: '5 pts'),
        CriteriaItem(descriptionKo: '기숙사 안전보안실천 - 기숙사 무단 침입자를 목격하거나 중대한 위험 사실을 알림', descriptionEn: 'Practicing dormitory safety/security - witnessing an unauthorized intruder or reporting a serious hazard', pointsKo: '3점', pointsEn: '3 pts'),
        CriteriaItem(descriptionKo: '위급상황 협조 - 교내 위급상황에 대한 실질적 대처로 행정부서 혹은 교수 확인서 제출 시', descriptionEn: 'Cooperation in an emergency - substantive response to an on-campus emergency, with a confirmation submitted by an administrative office or professor', pointsKo: '1~5점', pointsEn: '1-5 pts'),
        CriteriaItem(descriptionKo: '엔젤호실 지정엔젤 - 비상구에서 가장 멀리 있는 호실을 엔젤호실로 지정하여 1인을 엔젤로 임명, 화재대피 훈련 시 각 호실 출입문 두드려 대피 유도', descriptionEn: 'Designated "angel" for the angel room - the room farthest from the emergency exit is designated the angel room and one resident is appointed as angel, knocking on each room\'s door to guide evacuation during fire drills', pointsKo: '2점', pointsEn: '2 pts'),
      ],
    ),
    CriteriaCard(
      titleKo: '봉사활동',
      titleEn: 'Volunteer Activity',
      items: [
        CriteriaItem(descriptionKo: '입퇴사 도우미 - 행정실로 신청하여 확정된 경우', descriptionEn: 'Move-in/move-out helper - applied through and confirmed by the administrative office', pointsKo: '2점', pointsEn: '2 pts'),
        CriteriaItem(descriptionKo: '택배정리 지원 - 신청자 중 행정실에서 정리하도록 한 자', descriptionEn: 'Parcel organization support - applicants designated by the administrative office to organize parcels', pointsKo: '일 1점', pointsEn: '1 pt/day'),
        CriteriaItem(descriptionKo: '행정실 업무 지원 - 외부 시설보수신청시 동행 등 행정실로 신청하여 진행한 경우', descriptionEn: 'Administrative office task support - such as accompanying external facility repair requests, applied through and carried out with the office', pointsKo: '시간당 1점 (일 최대 3점)', pointsEn: '1 pt/hour (max 3 pts/day)'),
      ],
    ),
    CriteriaCard(
      titleKo: '시설보호 환경미화',
      titleEn: 'Facility Protection & Cleanliness',
      items: [
        CriteriaItem(descriptionKo: '청소 우수 호실 - 청소확인 시 층장이 2회이상 환경미화 및 청소상태 우수호실로 지정한 호실의 구성원', descriptionEn: 'Excellent cleaning room - members of a room designated by the floor leader as excellent in cleanliness 2 or more times during cleaning checks', pointsKo: '매회 2점', pointsEn: '2 pts each time', ),
        CriteriaItem(descriptionKo: '시설물 운영 개선 - 시설물 운영개선 제안하여 채택된 경우', descriptionEn: 'Facility operation improvement - a proposed facility operation improvement that is adopted', pointsKo: '2점', pointsEn: '2 pts'),
        CriteriaItem(descriptionKo: '에너지 절약 - 수도 및 전기 등 에너지 절약에 적극 참여한 자', descriptionEn: 'Energy saving - actively participating in saving energy such as water and electricity', pointsKo: '2점', pointsEn: '2 pts'),
        CriteriaItem(descriptionKo: '시설물 보전관리지원 - 시설물 보전관리 협조 및 파손예방에 적극 참여한 자', descriptionEn: 'Facility preservation support - actively cooperating in facility preservation and preventing damage', pointsKo: '2점', pointsEn: '2 pts'),
      ],
    ),
    CriteriaCard(
      titleKo: '문화발전',
      titleEn: 'Cultural Development',
      items: [
        CriteriaItem(descriptionKo: '주요행사 참여 - 사생회 문화행사에 적극 참여하여 사생회장이 추천한 경우', descriptionEn: 'Participation in major events - actively participating in resident council cultural events and recommended by the council president', pointsKo: '1~3점', pointsEn: '1-3 pts'),
      ],
    ),
    CriteriaCard(
      titleKo: '기타',
      titleEn: 'Other',
      items: [
        CriteriaItem(descriptionKo: '책임교수의 판단으로 기숙사에 협조한 경우', descriptionEn: 'Cooperated with the dormitory at the discretion of the supervising professor', pointsKo: '1~5점', pointsEn: '1-5 pts'),
      ],
    ),
  ];
}
