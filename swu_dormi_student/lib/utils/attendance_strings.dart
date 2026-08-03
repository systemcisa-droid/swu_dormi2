class AttendanceStrings {
  final bool isEnglish;
  const AttendanceStrings(this.isEnglish);

  String _t(String ko, String en) => isEnglish ? en : ko;

  String get title => _t('출석체크', 'Attendance Check');
  String errorLabel(Object e) => _t('오류: $e', 'Error: $e');
  String get retry => _t('다시 시도', 'Retry');

  String get attendanceUnavailableTitle => _t('출석체크 불가', 'Attendance Check Unavailable');
  String get residenceInfoMissing =>
      _t('기숙사 건물, 호실, 자리번호가 등록되어 있지 않습니다.\n프로필은 기숙사 입사일 자동 업데이트됩니다.',
          'Your dormitory building, room, and seat number are not registered.\nyour profile will be automatically updated on the day you move into the dormitory.');
  String currentStatusBlocked(String status) =>
      _t('현재 상태가 $status(으)로\n출석체크를 사용할 수 없습니다.', 'Your current status is $status,\nso attendance check is unavailable.');

  static const Map<String, String> _statusEn = {
    '재실중': 'Currently Residing',
    '자퇴': 'Withdrawn',
    '바롬인성교육관': 'Barom Character Education Hall',
  };
  String status(String ko) => isEnglish ? (_statusEn[ko] ?? ko) : ko;

  String get qrCheckTitle => _t('QR 코드로 출석체크', 'Check in with QR Code');
  String get qrCheckHint => _t(
        '내 QR 코드를 층장에게 보여주면\n출석체크가 완료됩니다',
        'Show your QR code to the floor captain\nto complete your attendance check',
      );

  String recordsCount(int n) => _t('출석 내역 ($n건)', 'Attendance Records ($n)');
  String get noRecords => _t('출석 내역이 없습니다', 'No attendance records');

  String get myQrCodeTitle => _t('내 QR 코드', 'My QR Code');
  String get myQrCodeHint =>
      _t('이 QR 코드를 층장에게 보여주면\n자동으로 출석체크가 완료됩니다', 'Show this QR code to the floor captain\nto complete your attendance check');
  String qrValidFor(int seconds) => _t('$seconds초 후 갱신', 'Refreshes in ${seconds}s');
}
