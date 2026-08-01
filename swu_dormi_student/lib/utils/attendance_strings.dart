class AttendanceStrings {
  final bool isEnglish;
  const AttendanceStrings(this.isEnglish);

  String _t(String ko, String en) => isEnglish ? en : ko;

  String get title => _t('출석체크', 'Attendance Check');
  String errorLabel(Object e) => _t('오류: $e', 'Error: $e');
  String get retry => _t('다시 시도', 'Retry');

  String get attendanceBlocked => _t('출석 불가', 'Unavailable');
  String get qrScan => _t('QR 스캔', 'QR Scan');

  String get attendanceUnavailableTitle => _t('출석체크 불가', 'Attendance Check Unavailable');
  String get residenceInfoMissing =>
      _t('기숙사 건물, 호실, 자리번호가 등록되어 있지 않습니다.\n프로필은 기숙사 입사날 자동 업데이트됩니다.',
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
        '하단의 QR 스캔 버튼을 눌러\n관리자가 표시한 QR 코드를 스캔하세요',
        'Tap the QR Scan button below\nand scan the QR code shown by the administrator',
      );

  String recordsCount(int n) => _t('출석 내역 ($n건)', 'Attendance Records ($n)');
  String get noRecords => _t('출석 내역이 없습니다', 'No attendance records');

  String get invalidQrCode => _t('유효하지 않은 QR 코드입니다', 'Invalid QR code');
  String get expiredQrCode => _t('만료된 QR 코드입니다. 다시 스캔해주세요', 'This QR code has expired. Please scan again');
  String get eventNotFound => _t('존재하지 않는 이벤트입니다', 'This event does not exist');
  String get eventEnded => _t('종료된 이벤트입니다', 'This event has ended');
  String get alreadyCheckedIn => _t('이미 출석체크를 완료했습니다', 'You have already checked in');
  String roomMismatch(String eventRoom, String studentRoom) =>
      _t('$eventRoom호 출석 이벤트입니다. 본인 호실($studentRoom호)과 일치하지 않아 출석이 거부되었습니다.',
          'This attendance event is for Room $eventRoom. Check-in was denied because it does not match your room ($studentRoom).');
  String checkInCompleted(String eventTitle) => _t('출석체크 완료: $eventTitle', 'Attendance checked in: $eventTitle');
  String checkInFailed(Object e) => _t('출석체크 실패: $e', 'Attendance check failed: $e');
  String currentStatusBlockedShort(String status) =>
      _t('현재 상태($status)로는 출석체크를 사용할 수 없습니다.', 'Attendance check is unavailable with your current status ($status).');

  String get qrScanTitle => _t('QR 코드 스캔', 'Scan QR Code');
  String get qrScanHint => _t('관리자 화면의 QR 코드를 스캔하세요', "Scan the QR code shown on the administrator's screen");
}
