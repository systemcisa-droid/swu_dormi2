// 세미나실 예약 화면에서 사용하는 다국어 문자열
class ReservationStrings {
  final bool isEnglish;
  const ReservationStrings(this.isEnglish);

  String _t(String ko, String en) => isEnglish ? en : ko;

  String get title => _t('세미나실 예약', 'Seminar Room Reservation');
  String get roomLabel => _t('세미나실 선택', 'Select Room');
  String get timeLabel => _t('시간 선택 (30분 단위, 최대 2시간)', 'Select Time (30-min slots, up to 2 hours)');
  String get todayOnlyNotice => _t('당일 예약만 가능합니다', 'Same-day reservations only');
  String get cautionMaxHours =>
      _t('1일 1인당 최대 2시간 예약 가능', 'Up to 2 hours per person per day');
  String get cautionNoProxy =>
      _t('예약자 본인이 직접 예약(대리불가)', 'Reserve in person only (no proxy reservations)');
  String get myReservationTitle => _t('내 예약', 'My Reservation');
  String get noMyReservation => _t('오늘 예약이 없습니다', 'No reservation today');
  String get reserveButton => _t('예약하기', 'Reserve');
  String get cancelButton => _t('예약 취소', 'Cancel Reservation');
  String get residenceInfoMissing =>
      _t('기숙사 건물 정보가 등록되어 있지 않습니다.', 'Your dormitory building is not registered.');
  String get alreadyReservedToday =>
      _t('오늘은 이미 예약이 있습니다. 하루에 한 건만 예약할 수 있습니다.', 'You already have a reservation today. Only one reservation per day is allowed.');
  String get slotUnavailable => _t('선택한 시간대에 이미 예약이 있습니다', 'The selected time slot is already booked');
  String get selectTimeFirst => _t('시간을 선택해주세요', 'Please select a time');
  String reserveSuccess(String room, String timeRange) =>
      _t('$room $timeRange 예약이 완료되었습니다', 'Reserved $room at $timeRange');
  String get cancelSuccess => _t('예약이 취소되었습니다', 'Reservation cancelled');
  String get cancelConfirmTitle => _t('예약 취소', 'Cancel Reservation');
  String get cancelConfirmContent => _t('예약을 취소하시겠습니까?', 'Are you sure you want to cancel this reservation?');
  String get keep => _t('아니요', 'No');
  String get confirm => _t('취소하기', 'Yes, Cancel');
  String errorLabel(Object e) => _t('오류: $e', 'Error: $e');
  String get loadingSlots => _t('예약 현황을 불러오는 중...', 'Loading availability...');
  String get shalom125MondayCaution => _t(
      '샬롬하우스 125호는 매주 월요일 21:30~22:30에는 예약할 수 없습니다',
      'Room 125 (Shalom House) cannot be reserved on Mondays from 21:30 to 22:30');
  String get slotBlockedByRule =>
      _t('이 시간대는 예약이 제한되어 있습니다', 'Reservations are restricted for this time slot');
}
