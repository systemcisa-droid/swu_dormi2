import 'package:intl/intl.dart';

String formatAlarmClock(int hour, int minute, bool isEnglish) {
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  final mm = minute.toString().padLeft(2, '0');
  if (isEnglish) {
    final period = hour < 12 ? 'AM' : 'PM';
    return '$hour12:$mm $period';
  }
  final period = hour < 12 ? '오전' : '오후';
  return '$period $hour12:$mm';
}

DateTime nextOccurrence(int hour, int minute) {
  final now = DateTime.now();
  var dt = DateTime(now.year, now.month, now.day, hour, minute);
  if (!dt.isAfter(now)) dt = dt.add(const Duration(days: 1));
  return dt;
}

String formatAlarmDate(DateTime date, bool isEnglish, {bool withRelativePrefix = false}) {
  final pattern = isEnglish ? 'MMM d (E)' : 'M월 d일 (E)';
  final formatted = DateFormat(pattern, isEnglish ? null : 'ko').format(date);
  if (!withRelativePrefix) return formatted;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = target.difference(today).inDays;
  String prefix;
  if (diff == 0) {
    prefix = isEnglish ? 'Today' : '오늘';
  } else if (diff == 1) {
    prefix = isEnglish ? 'Tomorrow' : '내일';
  } else {
    return formatted;
  }
  return '$prefix-$formatted';
}
