import 'package:intl/intl.dart';

/// 날짜 포맷 유틸리티 클래스
class DateFormatter {
  // 날짜 포맷터
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd', 'ko_KR');
  static final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm', 'ko_KR');
  static final DateFormat _timeFormat = DateFormat('HH:mm', 'ko_KR');
  static final DateFormat _fullDateFormat = DateFormat('yyyy년 MM월 dd일', 'ko_KR');
  static final DateFormat _fullDateTimeFormat = DateFormat('yyyy년 MM월 dd일 HH시 mm분', 'ko_KR');
  static final DateFormat _monthDayFormat = DateFormat('MM월 dd일', 'ko_KR');
  static final DateFormat _dayOfWeekFormat = DateFormat('EEEE', 'ko_KR');

  /// DateTime을 'yyyy-MM-dd' 형식의 문자열로 변환
  static String formatDate(DateTime dateTime) {
    return _dateFormat.format(dateTime);
  }

  /// DateTime을 'yyyy-MM-dd HH:mm' 형식의 문자열로 변환
  static String formatDateTime(DateTime dateTime) {
    return _dateTimeFormat.format(dateTime);
  }

  /// DateTime을 'HH:mm' 형식의 문자열로 변환
  static String formatTime(DateTime dateTime) {
    return _timeFormat.format(dateTime);
  }

  /// DateTime을 'yyyy년 MM월 dd일' 형식의 문자열로 변환
  static String formatFullDate(DateTime dateTime) {
    return _fullDateFormat.format(dateTime);
  }

  /// DateTime을 'yyyy년 MM월 dd일 HH시 mm분' 형식의 문자열로 변환
  static String formatFullDateTime(DateTime dateTime) {
    return _fullDateTimeFormat.format(dateTime);
  }

  /// DateTime을 'MM월 dd일' 형식의 문자열로 변환
  static String formatMonthDay(DateTime dateTime) {
    return _monthDayFormat.format(dateTime);
  }

  /// DateTime을 요일 문자열로 변환
  static String formatDayOfWeek(DateTime dateTime) {
    return _dayOfWeekFormat.format(dateTime);
  }

  /// 'yyyy-MM-dd' 형식의 문자열을 DateTime으로 변환
  static DateTime? parseDate(String dateString) {
    try {
      return _dateFormat.parse(dateString);
    } catch (e) {
      return null;
    }
  }

  /// 'yyyy-MM-dd HH:mm' 형식의 문자열을 DateTime으로 변환
  static DateTime? parseDateTime(String dateTimeString) {
    try {
      return _dateTimeFormat.parse(dateTimeString);
    } catch (e) {
      return null;
    }
  }

  /// 현재 날짜를 'yyyy-MM-dd' 형식의 문자열로 반환
  static String getCurrentDate() {
    return formatDate(DateTime.now());
  }

  /// 현재 날짜와 시간을 'yyyy-MM-dd HH:mm' 형식의 문자열로 반환
  static String getCurrentDateTime() {
    return formatDateTime(DateTime.now());
  }

  /// 두 날짜 사이의 일수 차이 계산
  static int daysBetween(DateTime from, DateTime to) {
    from = DateTime(from.year, from.month, from.day);
    to = DateTime(to.year, to.month, to.day);
    return (to.difference(from).inHours / 24).round();
  }

  /// 특정 날짜가 오늘인지 확인
  static bool isToday(DateTime dateTime) {
    final now = DateTime.now();
    return dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
  }

  /// 특정 날짜가 어제인지 확인
  static bool isYesterday(DateTime dateTime) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return dateTime.year == yesterday.year &&
        dateTime.month == yesterday.month &&
        dateTime.day == yesterday.day;
  }

  /// 특정 날짜가 이번 주인지 확인
  static bool isThisWeek(DateTime dateTime) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    return dateTime.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
        dateTime.isBefore(endOfWeek.add(const Duration(days: 1)));
  }

  /// 상대 시간 표시 (예: "방금 전", "3분 전", "2시간 전", "어제", "3일 전")
  static String getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (isYesterday(dateTime)) {
      return '어제';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return formatDate(dateTime);
    }
  }

  /// 기간을 문자열로 변환 (예: "2023-01-01 ~ 2023-01-31")
  static String formatPeriod(DateTime start, DateTime end) {
    return '${formatDate(start)} ~ ${formatDate(end)}';
  }

  /// 월의 첫 날 가져오기
  static DateTime getFirstDayOfMonth(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, 1);
  }

  /// 월의 마지막 날 가져오기
  static DateTime getLastDayOfMonth(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month + 1, 0);
  }

  /// 주의 첫 날 가져오기 (월요일)
  static DateTime getFirstDayOfWeek(DateTime dateTime) {
    return dateTime.subtract(Duration(days: dateTime.weekday - 1));
  }

  /// 주의 마지막 날 가져오기 (일요일)
  static DateTime getLastDayOfWeek(DateTime dateTime) {
    return dateTime.add(Duration(days: 7 - dateTime.weekday));
  }
}
