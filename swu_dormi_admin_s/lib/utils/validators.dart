/// 입력 검증 유틸리티 클래스
class Validators {
  /// 이메일 형식 검증
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return '이메일을 입력해주세요.';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return '올바른 이메일 형식이 아닙니다.';
    }

    return null;
  }

  /// 비밀번호 검증 (최소 6자)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '비밀번호를 입력해주세요.';
    }

    if (value.length < 6) {
      return '비밀번호는 최소 6자 이상이어야 합니다.';
    }

    return null;
  }

  /// 비밀번호 확인 검증
  static String? validatePasswordConfirm(String? value, String? password) {
    if (value == null || value.isEmpty) {
      return '비밀번호 확인을 입력해주세요.';
    }

    if (value != password) {
      return '비밀번호가 일치하지 않습니다.';
    }

    return null;
  }

  /// 필수 입력 검증
  static String? validateRequired(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return '${fieldName ?? '필수 항목'}을(를) 입력해주세요.';
    }
    return null;
  }

  /// 전화번호 검증 (한국 전화번호 형식)
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return '전화번호를 입력해주세요.';
    }

    // 하이픈 제거
    final cleanedValue = value.replaceAll('-', '');

    final phoneRegex = RegExp(
      r'^01[0-9]{8,9}$|^0[2-9]{1}[0-9]{7,8}$',
    );

    if (!phoneRegex.hasMatch(cleanedValue)) {
      return '올바른 전화번호 형식이 아닙니다.';
    }

    return null;
  }

  /// 학번 검증 (8자리 숫자)
  static String? validateStudentId(String? value) {
    if (value == null || value.isEmpty) {
      return '학번을 입력해주세요.';
    }

    final studentIdRegex = RegExp(r'^[0-9]{8}$');

    if (!studentIdRegex.hasMatch(value)) {
      return '학번은 8자리 숫자여야 합니다.';
    }

    return null;
  }

  /// 숫자만 입력 검증
  static String? validateNumeric(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return '${fieldName ?? '숫자'}를 입력해주세요.';
    }

    final numericRegex = RegExp(r'^[0-9]+$');

    if (!numericRegex.hasMatch(value)) {
      return '숫자만 입력 가능합니다.';
    }

    return null;
  }

  /// 최소 길이 검증
  static String? validateMinLength(String? value, int minLength, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return '${fieldName ?? '필수 항목'}을(를) 입력해주세요.';
    }

    if (value.length < minLength) {
      return '${fieldName ?? '입력값'}은(는) 최소 $minLength자 이상이어야 합니다.';
    }

    return null;
  }

  /// 최대 길이 검증
  static String? validateMaxLength(String? value, int maxLength, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return null;
    }

    if (value.length > maxLength) {
      return '${fieldName ?? '입력값'}은(는) 최대 $maxLength자까지 입력 가능합니다.';
    }

    return null;
  }

  /// 범위 검증
  static String? validateRange(String? value, int min, int max, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return '${fieldName ?? '숫자'}를 입력해주세요.';
    }

    final number = int.tryParse(value);
    if (number == null) {
      return '숫자만 입력 가능합니다.';
    }

    if (number < min || number > max) {
      return '${fieldName ?? '값'}은(는) $min ~ $max 범위여야 합니다.';
    }

    return null;
  }

  /// URL 검증
  static String? validateUrl(String? value) {
    if (value == null || value.isEmpty) {
      return 'URL을 입력해주세요.';
    }

    final urlRegex = RegExp(
      r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
    );

    if (!urlRegex.hasMatch(value)) {
      return '올바른 URL 형식이 아닙니다.';
    }

    return null;
  }

  /// 이름 검증 (한글, 영문만 허용)
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return '이름을 입력해주세요.';
    }

    final nameRegex = RegExp(r'^[가-힣a-zA-Z\s]+$');

    if (!nameRegex.hasMatch(value)) {
      return '이름은 한글 또는 영문만 입력 가능합니다.';
    }

    return null;
  }

  /// 날짜 형식 검증 (yyyy-MM-dd)
  static String? validateDate(String? value) {
    if (value == null || value.isEmpty) {
      return '날짜를 입력해주세요.';
    }

    final dateRegex = RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$');

    if (!dateRegex.hasMatch(value)) {
      return '날짜 형식이 올바르지 않습니다. (yyyy-MM-dd)';
    }

    try {
      DateTime.parse(value);
    } catch (e) {
      return '유효하지 않은 날짜입니다.';
    }

    return null;
  }

  /// 시간 형식 검증 (HH:mm)
  static String? validateTime(String? value) {
    if (value == null || value.isEmpty) {
      return '시간을 입력해주세요.';
    }

    final timeRegex = RegExp(r'^([01][0-9]|2[0-3]):[0-5][0-9]$');

    if (!timeRegex.hasMatch(value)) {
      return '시간 형식이 올바르지 않습니다. (HH:mm)';
    }

    return null;
  }

  /// 파일 크기 검증 (바이트 단위)
  static String? validateFileSize(int? fileSize, int maxSize) {
    if (fileSize == null) {
      return '파일을 선택해주세요.';
    }

    if (fileSize > maxSize) {
      final maxSizeMB = (maxSize / (1024 * 1024)).toStringAsFixed(1);
      return '파일 크기는 최대 ${maxSizeMB}MB까지 업로드 가능합니다.';
    }

    return null;
  }

  /// 파일 확장자 검증
  static String? validateFileExtension(String? fileName, List<String> allowedExtensions) {
    if (fileName == null || fileName.isEmpty) {
      return '파일을 선택해주세요.';
    }

    final extension = fileName.split('.').last.toLowerCase();

    if (!allowedExtensions.contains(extension)) {
      return '허용되지 않는 파일 형식입니다. (${allowedExtensions.join(', ')})';
    }

    return null;
  }

  /// 여러 검증 함수를 조합하여 실행
  static String? validateMultiple(String? value, List<String? Function(String?)> validators) {
    for (final validator in validators) {
      final error = validator(value);
      if (error != null) {
        return error;
      }
    }
    return null;
  }
}
