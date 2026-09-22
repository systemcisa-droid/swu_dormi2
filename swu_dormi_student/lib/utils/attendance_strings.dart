class AttendanceStrings {
  final bool isEnglish;
  const AttendanceStrings(this.isEnglish);

  String _t(String ko, String en) => isEnglish ? en : ko;

  String get title => _t('인원점검(화재대피훈련)', 'Attendance Check');
  String errorLabel(Object e) => _t('오류: $e', 'Error: $e');
  String get retry => _t('다시 시도', 'Retry');

  String get attendanceUnavailableTitle => _t('인원점검 불가', 'Attendance Check Unavailable');
  String get residenceInfoMissing =>
      _t('기숙사 건물, 호실, 자리번호가 등록되어 있지 않습니다.\n프로필은 기숙사 입사일 자동 업데이트됩니다.',
          'Your dormitory building, room, and seat number are not registered.\nyour profile will be automatically updated on the day you move into the dormitory.');
  String currentStatusBlocked(String status) =>
      _t('현재 상태가 $status(으)로\n인원점검을 사용할 수 없습니다.', 'Your current status is $status,\nso attendance check is unavailable.');

  static const Map<String, String> _statusEn = {
    '재실중': 'Currently Residing',
    '자퇴': 'Withdrawn',
    '바롬인성교육관': 'Barom Character Education Hall',
  };
  String status(String ko) => isEnglish ? (_statusEn[ko] ?? ko) : ko;

  // 층장/관리자가 지정한 출석 상태 기록(recordType: 'status')의 표시 문구
  static const Map<String, String> _recordStatusEn = {
    '불참': 'Absent',
    '부재': 'Away',
    '외박': 'Overnight leave',
    '외박신청완료': 'Overnight leave (approved)',
    '외박미수정': 'Overnight leave (unrevised)',
    '외박미신청': 'Overnight leave (not applied)',
    '재실확인': 'Presence confirmed',
    '바롬인성교육관': 'Barom Character Education Hall',
    '무단퇴사': 'Unauthorized move-out',
    '기타': 'Other',
  };
  String recordStatus(String ko) => isEnglish ? (_recordStatusEn[ko] ?? ko) : ko;
  String get statusSetByCaptain => _t('층장 지정', 'Set by floor captain');
  // 예: "샬롬하우스 A동 3층 층장"
  String captainOf(String floorLabel) =>
      _t('$floorLabel 층장', 'Floor captain ($floorLabel)');

  String get qrCheckTitle => _t('QR 코드로 인원점검', 'Check in with QR Code');
  String get qrCheckHint => _t(
        '내 QR 코드를 층장에게 보여주면\n인원점검이 완료됩니다',
        'Show your QR code to the floor captain\nto complete your attendance check',
      );

  String recordsCount(int n) => _t('인원점검 내역 ($n건)', 'Attendance Records ($n)');
  String get noRecords => _t('인원점검 내역이 없습니다', 'No attendance records');

  String get myQrCodeTitle => _t('내 QR 코드', 'My QR Code');
  String get myQrCodeHint =>
      _t('이 QR 코드를 층장에게 보여주면\n자동으로 인원점검이 완료됩니다', 'Show this QR code to the floor captain\nto complete your attendance check');
  String qrValidFor(int seconds) => _t('$seconds초 후 갱신', 'Refreshes in ${seconds}s');
}
