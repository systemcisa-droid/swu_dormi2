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
  String get menuCleaningInspection => _t('단위실 청소점검', 'Room Cleaning Inspection');
  String get menuCleaningMonthly => _t('월 검사/퇴사 검사', 'Monthly/Move-out Inspection');
  String get menuMoveOutCheck => _t('퇴사 확인', 'Move-out Confirmation');
  String get menuAttendance => _t('출석체크', 'Attendance Check');
  String get menuOt => _t('기숙사 OT자료', 'Dorm Orientation Materials');
  String get menuRegulationGroup => _t('사생수칙 & 입사퇴사', 'Rules & Move-in/out');
  String get menuRegulation => _t('사생수칙', 'Resident Rules');
  String get menuCheckInOut => _t('입사퇴사', 'Move-in/out');
  String get menuRewardPenalty => _t('상벌점', 'Reward/Penalty Points');
  String get menuLanguage => _t('언어', 'Language');
}
