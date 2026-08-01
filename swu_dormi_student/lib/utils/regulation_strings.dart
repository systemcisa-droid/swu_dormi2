class RegulationStrings {
  final bool isEnglish;
  const RegulationStrings(this.isEnglish);

  String _t(String ko, String en) => isEnglish ? en : ko;

  String get title => _t('사생수칙', 'Resident Rules');
  String get tabRegulation => _t('사생수칙', 'Rules');
  String get tabSignature => _t('동의 및 서명', 'Agreement & Signature');
  String get tabDocument => _t('서약서내용', 'Agreement Document');

  // ── 동의 및 서명 탭 ──
  String get nameRequired => _t('이름을 입력해주세요', 'Please enter your name');
  String get signatureRequired => _t('서명을 작성해주세요', 'Please provide your signature');
  String get userNotFound => _t('사용자 정보를 찾을 수 없습니다', 'Unable to find user information');
  String get signatureGenerationFailed => _t('서명 이미지 생성 실패', 'Failed to generate signature image');
  String get agreementSubmitted => _t('동의서가 제출되었습니다', 'Agreement submitted');
  String genericError(Object e) => _t('오류가 발생했습니다: $e', 'An error occurred: $e');

  String get formTitle => _t('기숙사 사생수칙', 'Dormitory Resident Rules');
  String get formSubtitle => _t('동의 및 준수 서약서', 'Agreement and Compliance Pledge');

  String get pledgeBodyKo =>
      '본인은 기숙사 사생수칙의 모든 내용을 충분히 숙지하였으며, 그 내용을 정확히 이해하였습니다.\n\n'
      '또한, 기숙사 생활 중 사생수칙의 모든 조항을 성실히 준수할 것을 서약하며, 이를 위반할 경우 규정에 따른 처분을 받을 것을 동의합니다.\n\n'
      '특히, 다음 사항을 확인하였습니다:\n\n'
      '• 입·퇴사 및 생활 규칙\n'
      '• 인원 확인 및 외출·외박 절차\n'
      '• 시설물 관리 및 보수 신청 방법\n'
      '• 반입 가능/불가 물품 목록\n'
      '• 상벌점 제도 및 퇴사 기준';

  String get pledgeBodyEn =>
      'I have fully familiarized myself with all the contents of the dormitory resident rules '
      'and have accurately understood them.\n\n'
      'I also pledge to faithfully comply with all provisions of the resident rules during my time in the dormitory, '
      'and agree to accept disciplinary action in accordance with the rules if I violate them.\n\n'
      'In particular, I have confirmed the following:\n\n'
      '• Move-in/move-out and living rules\n'
      '• Headcount check and outing/overnight-leave procedures\n'
      '• Facility management and repair request methods\n'
      '• List of permitted/prohibited items\n'
      '• Reward/penalty point system and move-out criteria';

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

  // ── 서약서내용 탭 ──
  String get userDataUnavailable => _t('사용자 정보를 불러올 수 없습니다', 'Unable to load user information');
  String get noAgreementYet => _t('아직 서약서를 작성하지 않았습니다', 'You have not written the agreement yet');
  String get noAgreementHint => _t('"동의 및 서명" 탭에서 서약서를 작성해주세요', 'Please write the agreement in the "Agreement & Signature" tab');

  String get documentPledgeKo =>
      '본인은 기숙사 사생수칙의 모든 내용을 충분히 숙지하였으며, '
      '그 내용을 정확히 이해하였습니다.\n\n'
      '또한, 기숙사 생활 중 사생수칙의 모든 조항을 성실히 준수할 것을 서약하며, '
      '이를 위반할 경우 규정에 따른 처분을 받을 것을 동의합니다.\n\n'
      '특히, 다음 사항을 확인하였습니다:\n\n'
      '  • 입·퇴사 및 생활 규칙\n'
      '  • 인원 확인 및 외출·외박 절차\n'
      '  • 시설물 관리 및 보수 신청 방법\n'
      '  • 반입 가능/불가 물품 목록\n'
      '  • 상벌점 제도 및 퇴사 기준\n\n'
      '위 사항을 모두 확인하였으며, 기숙사 생활 동안 이를 준수할 것을 엄숙히 서약합니다.';

  String get documentPledgeEn =>
      'I have fully familiarized myself with all the contents of the dormitory resident rules '
      'and have accurately understood them.\n\n'
      'I also pledge to faithfully comply with all provisions of the resident rules during my time in the dormitory, '
      'and agree to accept disciplinary action in accordance with the rules if I violate them.\n\n'
      'In particular, I have confirmed the following:\n\n'
      '  • Move-in/move-out and living rules\n'
      '  • Headcount check and outing/overnight-leave procedures\n'
      '  • Facility management and repair request methods\n'
      '  • List of permitted/prohibited items\n'
      '  • Reward/penalty point system and move-out criteria\n\n'
      'I have confirmed all of the above and solemnly pledge to comply with them during my dormitory life.';

  String get writtenDateLabel => _t('작성일자', 'Date Written');
  String get writtenTimeLabel => _t('작성시간', 'Time Written');
  String get building => _t('건물', 'Building');
  String get room => _t('호실', 'Room');
  String get name => _t('이름', 'Name');
  String get signature => _t('서명', 'Signature');
  String get signatureLoadError => _t('서명을 불러올 수 없습니다', 'Unable to load signature');
  String get noSignature => _t('서명 없음', 'No signature');
  String get finalStatement =>
      _t('본인은 위 내용에 동의하며 성실히 준수할 것을 서약합니다.', 'I agree to the above and pledge to faithfully comply with it.');
  String get agreementCompleted => _t('서약서 작성이 완료되었습니다', 'The agreement has been completed');
  String writtenAt(String date, String time) => _t('작성일시: $date $time', 'Written on: $date $time');
}
