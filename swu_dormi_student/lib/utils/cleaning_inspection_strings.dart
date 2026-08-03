class CleaningInspectionStrings {
  final bool isEnglish;
  const CleaningInspectionStrings(this.isEnglish);

  String _t(String ko, String en) => isEnglish ? en : ko;

  String get title => _t('단위실 청소점검 월검사/퇴사검사', 'Room Cleaning Inspection (Monthly/Move-out)');
  String get retry => _t('다시 시도', 'Retry');
  String get residenceInfoMissing =>
      _t('기숙사 건물, 호실, 자리번호가 등록되어 있지 않습니다.\n프로필은 기숙사 입사일 자동 업데이트됩니다.',
          'Your dormitory building, room, and seat number are not registered.\nyour profile will be automatically updated on the day you move into the dormitory".');
  String get loadError => _t('데이터를 불러오는 중 오류가 발생했습니다', 'An error occurred while loading data');

  String get tabGuide => _t('점검 안내', 'Guide');
  String get tabSchedule => _t('점검 스케줄', 'Inspection Schedule');
  String get tabHistory => _t('신청 내역', 'Request History');

  String scheduleCount(String location, int count) =>
      _t('$location | 점검 일정 $count건', '$location | $count schedule(s)');
  String roomScheduleCount(String room, int count) =>
      _t('$room호 | 점검 일정 $count건', 'Room $room | $count schedule(s)');
  String get noSchedule => _t('등록된 점검 일정이 없습니다', 'No inspection schedule registered');

  String get moveOutInspection => _t('퇴사검사', 'Move-out Inspection');
  String get monthlyInspection => _t('월검사', 'Monthly Inspection');
  // 작은 배지용 축약 라벨 (고정폭 컨테이너에서 오버플로우 방지)
  String get moveOutInspectionShort => _t('퇴사검사', 'Move-out');
  String get monthlyInspectionShort => _t('월검사', 'Monthly');

  String get statusApplied => _t('신청완료', 'Applied');
  String get statusScheduled => _t('예정', 'Scheduled');
  String get statusExpired => _t('기한만료', 'Expired');
  String get statusFull => _t('마감', 'Full');
  String get statusDuplicateBlocked => _t('중복신청불가', 'Already Applied');
  String get statusApply => _t('신청', 'Apply');

  String applyStartLabel(String dateTime) => _t('신청 시작: $dateTime', 'Starts: $dateTime');
  String applyEndUrgent(String dateTime, int hours, int minutes) =>
      _t('⏰ 신청 종료: $dateTime ($hours시간 $minutes분 남음)', '⏰ Ends: $dateTime ($hours h $minutes min left)');
  String applyEndLabel(String dateTime) => _t('신청 종료: $dateTime', 'Ends: $dateTime');
  String remainingRooms(int remaining, int max) => _t('잔여 $remaining/$max호실', '$remaining/$max rooms left');

  String get tapToChange => _t('탭하여 이 일정으로 변경', 'Tap to change to this schedule');
  String get tapToReapply => _t('탭하여 재신청', 'Tap to reapply');
  String get changeAvailable => _t('변경가능', 'Changeable');
  String get notApplied => _t('미신청', 'Not Applied');

  String get statusWaiting => _t('대기중', 'Waiting');
  String get statusInspecting => _t('점검중', 'Inspecting');
  String get statusCompleted => _t('완료', 'Completed');
  String get statusRejected => _t('반려됨', 'Rejected');

  String appliedAtLabel(String dateTime) => _t('신청: $dateTime', 'Applied: $dateTime');
  String scoreLabel(String score) => _t('점수: $score점 / 4점', 'Score: $score / 4');
  String get recheckNeeded => _t('재검사 필요', 'Recheck Required');
  String get commonAreasLabel => _t('공동구역: ', 'Common Areas: ');

  String get scheduleChangeTitle => _t('일정 변경', 'Change Schedule');
  String scheduleChangeConfirm(String dateTime) =>
      _t('신청을 $dateTime 으로 변경하시겠습니까?', 'Do you want to change your request to $dateTime?');
  String get cancel => _t('취소', 'Cancel');
  String get changeAction => _t('변경하기', 'Change');
  String get outOfApplicationPeriod => _t('변경하려는 일정의 신청 기간이 아닙니다', 'This schedule is not within the application period');
  String get applicationExpired => _t('변경하려는 일정의 신청 기한이 만료되었습니다', 'The application deadline for this schedule has expired');
  String get scheduleChanged => _t('일정이 변경되었습니다', 'Schedule changed');
  String get changeError => _t('변경 중 오류가 발생했습니다', 'An error occurred while changing the schedule');

  String get cancelRequestTitle => _t('신청 취소', 'Cancel Request');
  String get cancelRequestConfirm => _t('청소점검 신청을 취소하시겠습니까?', 'Are you sure you want to cancel your cleaning inspection request?');
  String get close => _t('닫기', 'Close');
  String get cancelAction => _t('취소하기', 'Cancel Request');
  String get requestCanceled => _t('신청이 취소되었습니다', 'Request has been canceled');
  String get cancelError => _t('취소 중 오류가 발생했습니다', 'An error occurred while canceling the request');

  // ── 안내 탭 ──
  String get evalCriteriaTitle => _t('점검 평가 기준', 'Evaluation Criteria');
  String get evalCriteriaContent => _t(
        '• 매우양호 : 청결 상태가 매우 우수한 경우\n• 양호 : 청결 기준을 충족한 경우\n• 미흡 : 청결 기준에 미달하거나 개선이 필요한 경우\n\n미흡 판정 시 재점검이 요구될 수 있으며, 벌점이 부과될 수 있습니다.',
        '• Excellent: Cleanliness is very good\n• Good: Meets cleanliness standards\n• Insufficient: Below standards or needs improvement\n\nAn "Insufficient" rating may require a recheck and may result in penalty points.',
      );
  String get areasTitle => _t('청소 점검 구역', 'Inspection Areas');
  String get areasContent => _t(
        '▶ 현관: 바닥, 거울(먼지, 얼룩) 청소\n\n▶ 바닥: 거실, 개인 방, 책상 아래 구석들(먼지, 머리카락) 청소\n\n▶ 창문: 창틀(먼지, 얼룩) 청소\n\n▶ 냉장고: 냉장고 안(얼룩) 청소 / 냉장고 주류 적발 시 벌점 10점\n\n▶ 샤워실: 하수구(머리카락) 청소 후, 거름망 세워두기 / 거울(물때, 얼룩) 청소 / 샤워실 바닥, 모서리(물때 곰팡이) 청소\n\n▶ 세면대(4인실): 세면대(물때, 얼룩) 청소 / 거울(물때, 얼룩) 청소\n\n▶ 화장실: 하수구(머리카락) 청소 후, 거름망 세워두기 / 변기 안(얼룩) 락스와 솔을 이용해 청소 후 변기 커버 올려놓기\n\n▶ 콘센트: 문어발 식 사용 여부 점검 / 콘센트(먼지) 점검\n\n▶ 반입 불가품: 벌점 기준표 기준 반입 불가품 적발 시 벌점 10점',
        '▶ Entrance: Clean the floor and mirror (dust, stains)\n\n▶ Floor: Clean the living room, personal room, and corners under the desk (dust, hair)\n\n▶ Windows: Clean the window frames (dust, stains)\n\n▶ Refrigerator: Clean the inside (stains) / 10-point penalty if alcohol is found in the refrigerator\n\n▶ Shower room: Clean the drain (hair) and set up the strainer / Clean the mirror (water stains, stains) / Clean the shower floor and corners (water stains, mold)\n\n▶ Sink (4-person room): Clean the sink (water stains, stains) / Clean the mirror (water stains, stains)\n\n▶ Bathroom: Clean the drain (hair) and set up the strainer / Clean the inside of the toilet (stains) with bleach and a brush, then put the toilet cover down\n\n▶ Outlets: Check for octopus-leg style overloaded outlets / Check outlets for dust\n\n▶ Prohibited items: 10-point penalty if prohibited items are found per the penalty point guidelines',
      );
  String get penaltyRewardTitle => _t('벌점 / 상점 기준', 'Penalty/Reward Criteria');
  String get penaltyRewardContent => _t(
        '• 기간 외 신청: -2점 (변경 시 벌점 없음)\n• 청소점검 미실시: -4점 (호실 전원 벌점 부과)\n• 청소 미흡 시 통과될 때까지 재검사\n• 우수청소호실(5점 만점) 2회 이상 선정 시 상점 부여',
        '• Applying outside the period: -2 points (no penalty when changing)\n• Not undergoing inspection: -4 points (applied to all room members)\n• If cleaning is insufficient, rechecks continue until it passes\n• Reward points are given if selected as an excellent cleaning room (5/5) 2 or more times',
      );
  String get noticeTitle => _t('유의사항', 'Notes');
  String get noticeContent => _t(
        '• 청소 점검 당일 1명 이상 재실 필수\n• 샤워실·변기 청소용 락스는 평일 행정실에서 대여 (당일 반납 필수, 지연반납 시 벌점)\n• 솔은 개인이 구비\n• 점검 결과는 "신청 내역" 탭에서 확인 가능',
        '• At least one resident must be present on the day of the inspection\n• Bleach for the shower/toilet can be borrowed from the administrative office on weekdays (must be returned the same day; late return incurs a penalty)\n• Residents must provide their own brush\n• Inspection results can be checked in the "Request History" tab',
      );
  String get warningBoxText => _t(
        '청소 신청 당일에는 날짜·시간 변경 절대 불가\n변경 시 청소검사 미이행으로 벌점 4점 부여',
        'Date and time changes are strictly prohibited on the day of the cleaning appointment\nChanging it will result in a 4-point penalty for failing to complete the cleaning inspection',
      );
  String get contactInfo => _t('문의: 해당 구역 층장 오픈카톡방', 'Contact: The floor captain\'s open KakaoTalk chat room for your area');

  // ── 신청 다이얼로그 ──
  String get residenceInfoRequired =>
      _t('기숙사 건물, 호실, 자리번호를 먼저 등록해주세요 (내 정보 수정)', 'Please register your dormitory building, room, and seat number first (Edit Profile)');
  String get applyDialogTitle => _t('청소점검 신청', 'Cleaning Inspection Request');
  String dateLabel(String date) => _t('날짜: $date', 'Date: $date');
  String timeLabel(String start, String end) => _t('시간: $start ~ $end', 'Time: $start ~ $end');
  String nameLabel(String name) => _t('이름: $name', 'Name: $name');
  String roomLabelWithNumber(String room) => _t('호실: $room호', 'Room: $room');
  String get commonAreaSelectTitle => _t('공동구역 선택 (선택사항)', 'Select Common Areas (Optional)');
  String get commonAreaSelectHint => _t('점검이 필요한 공동구역을 선택해 주세요', 'Please select the common areas that need inspection');
  String get memoHint => _t('전달 사항 (선택)', 'Message (optional)');
  String get applyAction => _t('신청하기', 'Apply');

  static const Map<String, String> _commonAreaEn = {
    '현관': 'Entrance',
    '화장실': 'Bathroom',
    '샤워실': 'Shower Room',
    '세면대': 'Sink',
    '바닥': 'Floor',
    '냉장고': 'Refrigerator',
  };
  String commonArea(String ko) => isEnglish ? (_commonAreaEn[ko] ?? ko) : ko;

  String get notApplicationPeriod => _t('아직 신청 기간이 아닙니다', 'The application period has not started yet');
  String get applicationDeadlinePassed => _t('신청 기한이 만료되었습니다', 'The application deadline has passed');
  String get alreadyPending => _t('이미 대기 중인 신청이 있습니다', 'You already have a pending request');
  String get monthlyLimitReached =>
      _t('월검사는 한 달에 한 번만 신청할 수 있습니다', 'You can only apply for the monthly inspection once per month');
  String get requestSubmitted => _t('청소점검 신청이 완료되었습니다', 'Your cleaning inspection request has been submitted');
  String get requestSubmitError => _t('신청 중 오류가 발생했습니다. 다시 시도해주세요.', 'An error occurred while submitting the request. Please try again.');

  // ── 재검사 신청 ──
  String get recheckApplyAction => _t('재검사 신청', 'Recheck');
  String get recheckSubmitted => _t('재검사 신청이 완료되었습니다', 'Your recheck request has been submitted');
  String get recheckBadge => _t('재검사 신청', 'Recheck Request');
}
