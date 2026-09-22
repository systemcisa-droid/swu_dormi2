class SignupStrings {
  final bool isEnglish;
  const SignupStrings(this.isEnglish);

  String _t(String ko, String en) => isEnglish ? en : ko;

  String get title => _t('회원가입', 'Sign Up');
  String get signupComplete => _t('회원가입이 완료되었습니다!', 'Sign up complete!');

  // 회원가입 학번이 관리프로그램의 사생 명단에 없을 때 띄우는 안내 팝업
  String get studentIdNotInRosterTitle => _t('학번을 확인해주세요', 'Please check your student ID');
  String get studentIdNotInRosterBody => _t(
      '입력한 학번이 기숙사 사생 명단에 없습니다.\n\n'
      '학번을 다시 확인해주세요. 학번이 맞는데도 계속 안 되면 기숙사 행정실에 문의해주세요.',
      'The student ID you entered is not on the dormitory resident list.\n\n'
      'Please double-check your student ID. If it is correct, contact the dormitory office.');
  String get studentIdNotInRosterOk => _t('확인', 'OK');
  String get name => _t('이름', 'Name');
  String get nameRequired => _t('이름을 입력해주세요', 'Please enter your name');
  String get emailId => _t('이메일 아이디 (학번)', 'Email ID (Student ID)');
  String get emailIdHint => _t('예: 2026123456', 'e.g. 2026123456');
  String get emailIdRequired => _t('이메일 아이디를 입력해주세요', 'Please enter your email ID');
  String get emailIdInvalid => _t('학번은 숫자만 입력 가능합니다', 'Student ID must contain numbers only');
  String get emailIdLengthInvalid =>
      _t('입학연도 4자리 + 학번 6자리, 총 10자리 숫자여야 합니다', 'Must be 10 digits: 4-digit admission year + 6-digit student number');
  String get emailIdGuide => _t('*이메일은 "학번(10자리)"만 입력 가능합니다*', '*Only your "student ID number(10 digits)" can be entered for the email*');
  String get password => _t('비밀번호', 'Password');
  String get passwordRequired => _t('비밀번호를 입력해주세요', 'Please enter your password');
  String get passwordTooShort =>
      _t('비밀번호는 최소 6자 이상이어야 합니다', 'Password must be at least 6 characters');
  String get confirmPassword => _t('비밀번호 확인', 'Confirm Password');
  String get confirmPasswordRequired =>
      _t('비밀번호를 다시 입력해주세요', 'Please re-enter your password');
  String get passwordMismatch => _t('비밀번호가 일치하지 않습니다', 'Passwords do not match');
  String get profileUpdateNotice => _t(
        '회원가입 후 프로필(학번, 전화번호, 건물이름, 호실, 자리번호, 학과)은 기숙사 입사날 자동 업데이트됩니다',
        'After signing up, your profile (student ID, phone number, building name, room number, seat number, major) will be automatically updated on the day you move into the dormitory.',
      );
  String get signupButton => _t('가입하기', 'Sign Up');
}
