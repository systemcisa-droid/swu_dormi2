class LoginStrings {
  final bool isEnglish;
  const LoginStrings(this.isEnglish);

  String _t(String ko, String en) => isEnglish ? en : ko;

  String get dormNames => _t('샬롬하우스 & 국제생활관', 'Shalom House & International Hall');
  String get baromNote => _t('(바롬인성교육관 10층)', '(Barom Character Education Hall, 10F)');
  String get verse => _t(
        '시편 4:8\n내가 편안하게 누워 잘 수 있는 것은 주께서\n 나를 안전하게 지켜 주시기 때문입니다.',
        'Psalm 4:8\nIn peace I will lie down and sleep,\nfor you alone, Lord, make me dwell in safety.',
      );
  String get emailId => _t('이메일 아이디', 'Email ID');
  String get emailIdRequired => _t('이메일 아이디를 입력해주세요', 'Please enter your email ID');
  String get password => _t('비밀번호', 'Password');
  String get passwordRequired => _t('비밀번호를 입력해주세요', 'Please enter your password');
  String get login => _t('로그인', 'Log In');
  String get signup => _t('회원가입', 'Sign Up');
  String get forgotPassword => _t('비밀번호를 잊으셨나요?', 'Forgot your password?');
  String get resetPasswordTitle => _t('비밀번호 재설정', 'Reset Password');
  String get enterIdHint => _t('아이디를 입력하세요', 'Enter your ID');
  String get resetPasswordEmailSent =>
      _t('비밀번호 재설정 이메일이 발송되었습니다', 'Password reset email has been sent');
  String get orDivider => _t('또는', 'OR');
  String get googleLogin => _t('Google 계정으로 로그인', 'Sign in with Google');
  String get googleLoginNotStudent =>
      _t('학생 계정만 로그인할 수 있습니다.', 'Only student accounts can log in.');
  String get googleStudentIdLabel => _t('학번', 'Student ID');
  String get googleStudentIdHint => _t('예: 2026123456', 'e.g. 2026123456');
  String get googleStudentIdInvalid =>
      _t('학번 10자리 숫자를 입력해주세요 (입학연도 4자리 + 학번 6자리)', 'Please enter a 10-digit student ID (4-digit admission year + 6-digit number)');
  String get googleStudentIdCheck => _t('학번 사용가능 확인', 'Check availability');
  String get googleStudentIdAvailable => _t('사용 가능한 학번입니다', 'This student ID is available');
  String get googleStudentIdDuplicate =>
      _t('이미 사용 중인 학번입니다', 'This student ID is already in use');
  String get googleStudentIdVerifyFirst =>
      _t('먼저 학번 사용가능 확인을 해주세요', 'Please check student ID availability first');
  String get googleStudentIdPageTitle => _t('학번 입력', 'Enter Student ID');
  String get googleStudentIdPageGuide =>
      _t('Google 계정으로 처음 로그인하셨습니다.\n학번을 입력하고 완료해주세요.', 'This is your first sign-in with this Google account.\nPlease enter your student ID to continue.');
  String get googleStudentIdComplete => _t('완료', 'Done');
  String get cancelSignUp => _t('가입 취소', 'Cancel sign-up');
}
