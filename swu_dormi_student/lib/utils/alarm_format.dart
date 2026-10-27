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

/// 반복 요일까지 고려한 다음 알람 시각. repeatDays가 비어있으면(1회성)
/// [nextOccurrence]와 같다.
DateTime nextAlarmOccurrence(int hour, int minute, Set<int> repeatDays) {
  if (repeatDays.isEmpty) return nextOccurrence(hour, minute);
  DateTime? earliest;
  for (final weekday in repeatDays) {
    var candidate = nextOccurrence(hour, minute);
    while (candidate.weekday != weekday) {
      candidate = candidate.add(const Duration(days: 1));
    }
    if (earliest == null || candidate.isBefore(earliest)) {
      earliest = candidate;
    }
  }
  return earliest!;
}

/// "3시간 25분 후에 울립니다" 같은 안내 문구를 만든다.
String formatTimeUntilAlarm(DateTime target, bool isEnglish) {
  final diff = target.difference(DateTime.now());
  final totalMinutes = diff.inMinutes < 0 ? 0 : diff.inMinutes;
  final days = totalMinutes ~/ (24 * 60);
  final hours = (totalMinutes % (24 * 60)) ~/ 60;
  final minutes = totalMinutes % 60;

  if (isEnglish) {
    final parts = <String>[];
    if (days > 0) parts.add('$days day${days == 1 ? '' : 's'}');
    if (hours > 0) parts.add('$hours hour${hours == 1 ? '' : 's'}');
    if (days == 0 && minutes > 0) parts.add('$minutes minute${minutes == 1 ? '' : 's'}');
    if (parts.isEmpty) parts.add('less than a minute');
    return 'Alarm will ring in ${parts.join(' ')}';
  }

  final parts = <String>[];
  if (days > 0) parts.add('$days일');
  if (hours > 0) parts.add('$hours시간');
  if (days == 0 && minutes > 0) parts.add('$minutes분');
  if (parts.isEmpty) parts.add('1분 미만');
  return '${parts.join(' ')} 후에 울립니다';
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
