import 'package:flutter/material.dart';

/// String 확장 메서드
extension StringExtension on String {
  /// 문자열이 비어있거나 공백만 있는지 확인
  bool get isBlank => trim().isEmpty;

  /// 문자열이 비어있지 않고 공백이 아닌지 확인
  bool get isNotBlank => trim().isNotEmpty;

  /// 첫 글자를 대문자로 변환
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// 전화번호 포맷 (010-1234-5678)
  String formatPhoneNumber() {
    final cleaned = replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length == 10) {
      return '${cleaned.substring(0, 3)}-${cleaned.substring(3, 6)}-${cleaned.substring(6)}';
    } else if (cleaned.length == 11) {
      return '${cleaned.substring(0, 3)}-${cleaned.substring(3, 7)}-${cleaned.substring(7)}';
    }
    return this;
  }

  /// 학번 포맷 (2023-1234)
  String formatStudentId() {
    if (length == 8) {
      return '${substring(0, 4)}-${substring(4)}';
    }
    return this;
  }

  /// 숫자만 추출
  String get numbersOnly => replaceAll(RegExp(r'[^0-9]'), '');

  /// 문자만 추출
  String get lettersOnly => replaceAll(RegExp(r'[^a-zA-Z가-힣]'), '');
}

/// DateTime 확장 메서드
extension DateTimeExtension on DateTime {
  /// 오늘인지 확인
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// 어제인지 확인
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year && month == yesterday.month && day == yesterday.day;
  }

  /// 내일인지 확인
  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return year == tomorrow.year && month == tomorrow.month && day == tomorrow.day;
  }

  /// 이번 주인지 확인
  bool get isThisWeek {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    return isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
        isBefore(endOfWeek.add(const Duration(days: 1)));
  }

  /// 이번 달인지 확인
  bool get isThisMonth {
    final now = DateTime.now();
    return year == now.year && month == now.month;
  }

  /// 과거인지 확인
  bool get isPast => isBefore(DateTime.now());

  /// 미래인지 확인
  bool get isFuture => isAfter(DateTime.now());

  /// 날짜만 복사 (시간 제거)
  DateTime get dateOnly => DateTime(year, month, day);

  /// 시간만 복사 (날짜는 오늘)
  DateTime get timeOnly {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute, second);
  }

  /// 월의 첫 날
  DateTime get firstDayOfMonth => DateTime(year, month, 1);

  /// 월의 마지막 날
  DateTime get lastDayOfMonth => DateTime(year, month + 1, 0);

  /// 주의 첫 날 (월요일)
  DateTime get firstDayOfWeek => subtract(Duration(days: weekday - 1));

  /// 주의 마지막 날 (일요일)
  DateTime get lastDayOfWeek => add(Duration(days: 7 - weekday));

  /// 다음 날
  DateTime get nextDay => add(const Duration(days: 1));

  /// 이전 날
  DateTime get previousDay => subtract(const Duration(days: 1));

  /// 다음 달
  DateTime get nextMonth => DateTime(year, month + 1, day);

  /// 이전 달
  DateTime get previousMonth => DateTime(year, month - 1, day);
}

/// List 확장 메서드
extension ListExtension<T> on List<T> {
  /// 리스트가 비어있지 않은지 확인
  bool get isNotEmpty => !isEmpty;

  /// 안전한 인덱스 접근
  T? getOrNull(int index) {
    if (index < 0 || index >= length) return null;
    return this[index];
  }

  /// 조건에 맞는 첫 번째 요소 찾기 (없으면 null)
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }

  /// 리스트를 청크로 나누기
  List<List<T>> chunk(int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < length; i += size) {
      chunks.add(sublist(i, i + size > length ? length : i + size));
    }
    return chunks;
  }
}

/// int 확장 메서드
extension IntExtension on int {
  /// 바이트를 읽기 쉬운 형식으로 변환 (1024 -> 1 KB)
  String get bytesToReadable {
    if (this < 1024) return '$this B';
    if (this < 1024 * 1024) return '${(this / 1024).toStringAsFixed(1)} KB';
    if (this < 1024 * 1024 * 1024) {
      return '${(this / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(this / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// 숫자를 통화 형식으로 변환 (10000 -> ₩10,000)
  String get toCurrency {
    final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return '₩${toString().replaceAllMapped(formatter, (match) => '${match[1]},')}';
  }

  /// 숫자를 천 단위로 구분 (10000 -> 10,000)
  String get withComma {
    final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return toString().replaceAllMapped(formatter, (match) => '${match[1]},');
  }

  /// 퍼센트로 변환 (50 -> 50%)
  String get toPercent => '$this%';
}

/// double 확장 메서드
extension DoubleExtension on double {
  /// 소수점 자리수 제한
  double toPrecision(int fractionDigits) {
    return double.parse(toStringAsFixed(fractionDigits));
  }

  /// 퍼센트로 변환 (0.5 -> 50%)
  String get toPercent => '${(this * 100).toStringAsFixed(0)}%';

  /// 통화 형식으로 변환
  String get toCurrency {
    final formatter = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return '₩${toStringAsFixed(0).replaceAllMapped(formatter, (match) => '${match[1]},')}';
  }
}

/// BuildContext 확장 메서드
extension BuildContextExtension on BuildContext {
  /// 화면 크기
  Size get screenSize => MediaQuery.of(this).size;

  /// 화면 너비
  double get screenWidth => screenSize.width;

  /// 화면 높이
  double get screenHeight => screenSize.height;

  /// 안전 영역 패딩
  EdgeInsets get padding => MediaQuery.of(this).padding;

  /// 키보드 높이
  double get keyboardHeight => MediaQuery.of(this).viewInsets.bottom;

  /// 키보드가 열려있는지 확인
  bool get isKeyboardVisible => keyboardHeight > 0;

  /// 테마
  ThemeData get theme => Theme.of(this);

  /// 텍스트 테마
  TextTheme get textTheme => theme.textTheme;

  /// 색상 스킴
  ColorScheme get colorScheme => theme.colorScheme;

  /// 네비게이터
  NavigatorState get navigator => Navigator.of(this);

  /// 스낵바 표시
  void showSnackBar(String message, {Duration? duration}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration ?? const Duration(seconds: 2),
      ),
    );
  }

  /// 에러 스낵바 표시
  void showErrorSnackBar(String message, {Duration? duration}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }

  /// 성공 스낵바 표시
  void showSuccessSnackBar(String message, {Duration? duration}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: duration ?? const Duration(seconds: 2),
      ),
    );
  }
}

/// Color 확장 메서드
extension ColorExtension on Color {
  /// 밝은 색상인지 확인
  bool get isLight => computeLuminance() > 0.5;

  /// 어두운 색상인지 확인
  bool get isDark => !isLight;

  /// 대비되는 텍스트 색상 반환
  Color get contrastText => isLight ? Colors.black : Colors.white;

  /// 색상을 어둡게
  Color darken([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final darkened = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return darkened.toColor();
  }

  /// 색상을 밝게
  Color lighten([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final lightened = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return lightened.toColor();
  }
}
