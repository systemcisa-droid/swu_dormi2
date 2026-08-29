// 홈 화면 및 사이드 메뉴에서 사용하는 다국어 문자열
class HomeStrings {
  final bool isEnglish;
  const HomeStrings(this.isEnglish);

  String _t(String ko, String en) => isEnglish ? en : ko;

  String get student => _t('학생', 'Student');
  String get dormOfficeContact => _t('기숙사 사무실 02-970-7901', 'Dormitory Office 02-970-7901');

  String get menuNotices => _t('공지사항 & 기숙사일정', 'Notices & Dorm Schedule');
  String get menuBoard => _t('게시판', 'Board');
  String get menuMeal => _t('식단표', 'Meal Plan');
  String get menuFacilityReport => _t('수리 보수 신청', 'Repair Request');

  // 사생수칙 동의 필요 안내
  String get regulationRequiredTitle =>
      _t('사생수칙 동의 필요', 'Agreement Required');
  String get regulationRequiredContent => _t(
      '이 메뉴는 사생수칙 동의 및 서명을 제출한 후 이용할 수 있습니다.\n\n'
      '지금 사생수칙 페이지로 이동하시겠습니까?',
      'This menu is available after submitting the dormitory rules agreement and signature.\n\n'
      'Would you like to go to the dormitory rules page now?');
  String get regulationRequiredClose => _t('닫기', 'Close');
  String get regulationRequiredGo => _t('이동', 'Go');
  String get menuCleaningInspection => _t('단위실 청소점검', 'Room Cleaning Inspection');
  String get menuCleaningMonthly => _t('월 검사/퇴사 검사', 'Monthly/Move-out Inspection');
  String get menuMoveOutCheck => _t('퇴사 확인', 'Move-out Confirmation');
  String get menuAttendance => _t('인원점검(화재대피훈련)', 'Attendance Check(Fire Evacuation Drill)');
  String get menuReservation => _t('예약', 'Reservation');
  String get menuFloorChat =>
      _t('층장단톡(청검|인검 문의)', 'Floor Captain Chat (Cleaning/Attendance)');
  String get floorChatTooltip => _t('층장단톡방', 'Floor Captain Chat');

  // 팝업 공지
  String get popupNoticeDefaultTitle => _t('공지사항', 'Notice');
  String get popupNoticeHideToday =>
      _t('오늘 하루 보지 않기', "Don't show today");
  String get popupNoticeClose => _t('닫기', 'Close');
  String get menuRegulationGroup => _t('사생수칙 & 입사퇴사', 'Rules & Move-in/out');
  String get menuRegulation => _t('사생수칙', 'Resident Rules');
  String get menuCheckInOut => _t('입사퇴사', 'Move-in/out');
  String get menuRewardPenalty => _t('상벌점', 'Reward/Penalty Points');
  String get menuLanguage => _t('언어', 'Language');
}
