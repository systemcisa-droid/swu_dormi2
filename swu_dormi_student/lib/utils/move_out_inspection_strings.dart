class MoveOutInspectionStrings {
  final bool isEnglish;
  const MoveOutInspectionStrings(this.isEnglish);

  String _t(String ko, String en) => isEnglish ? en : ko;

  String get title => _t('퇴사검사', 'Move-out Inspection');
  String get tabGuide => _t('퇴사 안내', 'Guide');
  String get tabSignature => _t('동의 및 서명', 'Agreement & Signature');
  String get tabDocument => _t('서약서 내용', 'Agreement Document');

  // ── 퇴사 안내 탭 ──
  String get guideSubtitle => _t('기숙사 퇴사검사 안내', 'Dormitory Move-out Inspection Guide');

  String get whatIsTitle => _t('퇴사검사란?', 'What is a Move-out Inspection?');
  List<String> get whatIsItems => isEnglish
      ? [
          'This is a procedure where staff directly inspect the condition of your room before you move out.',
          'It checks for facility damage, cleanliness, and whether equipment has been returned.',
          'If you do not pass the inspection, your move-out process may be delayed.',
        ]
      : [
          '퇴사 전 호실 상태를 담당자가 직접 점검하는 절차입니다.',
          '시설물 파손, 청결 상태, 비품 반납 여부 등을 확인합니다.',
          '퇴사검사를 통과하지 못하면 퇴사 처리가 지연될 수 있습니다.',
        ];

  String get itemsTitle => _t('퇴사검사 항목', 'Inspection Items');
  List<String> get inspectionItems => isEnglish
      ? [
          'Room cleanliness (floor, windows, furniture, etc.)',
          'Facility damage (walls, floor, furniture, equipment, etc.)',
          'Complete removal of personal belongings',
          'Removal of food from the refrigerator',
          'Bathroom cleanliness',
          'Electrical and plumbing issues',
        ]
      : [
          '호실 내 청결 상태 (바닥, 창문, 가구 등)',
          '시설물 파손 여부 (벽, 바닥, 가구, 비품 등)',
          '개인 소지품 완전 반출 여부',
          '냉장고 내 음식물 제거 여부',
          '화장실 청결 상태',
          '전기·수도 이상 여부',
        ];

  String get noticeTitle => _t('유의사항', 'Notes');
  List<String> get noticeItems => isEnglish
      ? [
          'If you move out without a cleaning check on the day of move-out, you will be treated as a forced move-out.',
          'You are responsible for compensation if facilities are damaged.',
          'All personal belongings must be removed before the move-out inspection.',
          'Any packages or mail delivered after move-out will be discarded.',
          'If personal items or trash are found after the move-out cleaning inspection, it will be treated as a forced move-out.',
        ]
      : [
          '퇴사 당일 청소확인을 받지 않고 퇴사 시 강제퇴사 처리됩니다.',
          '시설물 파손 시 변상 책임이 있습니다.',
          '퇴사검사 전 모든 개인 소지품을 반출해야 합니다.',
          '퇴사 후 배달된 택배나 우편물은 폐기 처분됩니다.',
          '퇴사청소검사 후 개인 물건이나 쓰레기 발견 시 강제퇴사 처리됩니다.',
        ];

  String get procedureTitle => _t('퇴사 절차', 'Move-out Procedure');
  List<String> get procedureItems => isEnglish
      ? [
          '① Completely remove all personal belongings',
          '② Complete room cleaning',
          '③ Apply for move-out inspection (App "Agreement & Signature" tab)',
          '④ Staff visit and inspection',
        ]
      : [
          '① 개인 소지품 완전 반출',
          '② 호실 청소 완료',
          '③ 퇴사검사 신청 (앱 "동의 및 서명" 탭)',
          '④ 담당자 방문 점검',
        ];

  // ── 동의 및 서명 탭 ──
  String get nameRequired => _t('이름을 입력해주세요', 'Please enter your name');
  String get signatureRequired => _t('서명을 작성해주세요', 'Please provide your signature');
  String get userNotFound => _t('사용자 정보를 찾을 수 없습니다', 'Unable to find user information');
  String get signatureGenerationFailed => _t('서명 이미지 생성 실패', 'Failed to generate signature image');
  String get agreementSubmitted => _t('동의서가 제출되었습니다', 'Agreement submitted');
  String genericError(Object e) => _t('오류가 발생했습니다: $e', 'An error occurred: $e');

  String get formTitle => _t('기숙사 퇴사검사', 'Dormitory Move-out Inspection');
  String get formSubtitle => _t('동의 및 확인 서약서', 'Agreement and Confirmation Pledge');

  String get pledgeBodyKo =>
      '본인은 기숙사 퇴사검사 절차를 충분히 숙지하였으며,'
      '그 내용을 정확히 이해하였습니다.\n\n'
      '또한, 퇴사검사 시 모든 항목을 성실히 이행할 것을 서약하며, '
      '규정 위반 시 관련 처분을 받을 것을 동의합니다.\n\n'
      '특히, 다음 사항을 확인하였습니다:\n\n'
      '• 퇴사 당일 호실 청소 완료\n'
      '• 모든 개인 소지품 완전 반출\n'
      '• 시설물 파손 여부 확인 및 변상 동의\n'
      '• 퇴사검사 미이행 시 강제퇴사 처리 동의';

  String get pledgeBodyEn =>
      'I have fully familiarized myself with the dormitory move-out inspection procedure '
      'and have accurately understood its contents.\n\n'
      'I also pledge to faithfully carry out all items during the move-out inspection, '
      'and agree to accept any related disciplinary action in case of a violation of the rules.\n\n'
      'In particular, I have confirmed the following:\n\n'
      '• Room cleaning completed on the day of move-out\n'
      '• All personal belongings completely removed\n'
      '• Confirmation of facility damage and agreement to compensate if applicable\n'
      '• Agreement to be treated as a forced move-out if the inspection is not completed';

  String get signHint => _t('아래 서명란에 이름을 입력하고 서명해주세요', 'Please enter your name and sign below');
  String get writtenAtLabel => _t('작성일시:', 'Date/Time:');
  String get buildingLabel => _t('건물:', 'Building:');
  String get roomLabel => _t('호실:', 'Room:');
  String get nameLabel => _t('이름:', 'Name:');
  String get nameHint => _t('이름을 입력하세요', 'Enter your name');
  String get signatureLabel => _t('서명:', 'Signature:');
  String get redo => _t('다시 작성', 'Redo');
  String get agreeStatement => _t('위 사항에 동의하며 서약합니다.', 'I agree to and pledge the above.');
  String get dormLabel => _t('기숙사', 'Dormitory');
  String get submitAgreement => _t('동의서 제출', 'Submit Agreement');
  String get privacyNotice =>
      _t('제출된 동의서는 기숙사 관리 목적으로만 사용됩니다.', 'The submitted agreement is used only for dormitory management purposes.');

  // ── 서약서 내용 탭 ──
  String get userDataUnavailable => _t('사용자 정보를 불러올 수 없습니다', 'Unable to load user information');
  String get noAgreementYet => _t('아직 서약서를 작성하지 않았습니다', 'You have not written the agreement yet');
  String get noAgreementHint => _t('"동의 및 서명" 탭에서 서약서를 작성해주세요', 'Please write the agreement in the "Agreement & Signature" tab');

  String get documentPledgeKo =>
      '본인은 기숙사 퇴사검사 절차를 충분히 숙지하였으며,'
      '그 내용을 정확히 이해하였습니다.\n\n'
      '또한, 퇴사검사 시 모든 항목을 성실히 이행할 것을 서약하며, '
      '규정 위반 시 관련 처분을 받을 것을 동의합니다.\n\n'
      '특히, 다음 사항을 확인하였습니다:\n\n'
      '  • 퇴사 당일 호실 청소 완료\n'
      '  • 모든 개인 소지품 완전 반출\n'
      '  • 시설물 파손 여부 확인 및 변상 동의\n'
      '  • 키(카드) 반납 의무\n'
      '  • 퇴사검사 미이행 시 강제퇴사 처리 동의\n\n'
      '위 사항을 모두 확인하였으며, 성실히 이행할 것을 엄숙히 서약합니다.';

  String get documentPledgeEn =>
      'I have fully familiarized myself with the dormitory move-out inspection procedure '
      'and have accurately understood its contents.\n\n'
      'I also pledge to faithfully carry out all items during the move-out inspection, '
      'and agree to accept any related disciplinary action in case of a violation of the rules.\n\n'
      'In particular, I have confirmed the following:\n\n'
      '  • Room cleaning completed on the day of move-out\n'
      '  • All personal belongings completely removed\n'
      '  • Confirmation of facility damage and agreement to compensate if applicable\n'
      '  • Obligation to return keys (cards)\n'
      '  • Agreement to be treated as a forced move-out if the inspection is not completed\n\n'
      'I have confirmed all of the above and solemnly pledge to faithfully carry them out.';

  String get writtenDateLabel => _t('작성일자', 'Date Written');
  String get writtenTimeLabel => _t('작성시간', 'Time Written');
  String get building => _t('건물', 'Building');
  String get room => _t('호실', 'Room');
  String get name => _t('이름', 'Name');
  String get signature => _t('서명', 'Signature');
  String get signatureLoadError => _t('서명을 불러올 수 없습니다', 'Unable to load signature');
  String get noSignature => _t('서명 없음', 'No signature');
  String get finalStatement => _t('본인은 위 내용에 동의하며 성실히 이행할 것을 서약합니다.', 'I agree to the above and pledge to faithfully carry it out.');
  String get agreementCompleted => _t('서약서 작성이 완료되었습니다', 'The agreement has been completed');
  String writtenAt(String date, String time) => _t('작성일시: $date $time', 'Written on: $date $time');
}
