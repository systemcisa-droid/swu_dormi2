class ChangePasswordStrings {
  final bool isEnglish;
  const ChangePasswordStrings(this.isEnglish);

  String _t(String ko, String en) => isEnglish ? en : ko;

  String get title => _t('비밀번호 변경', 'Change Password');
  String get passwordRule =>
      _t('비밀번호는 최소 6자 이상이어야 하며,\n영문, 숫자를 포함하는 것을 권장합니다.',
          'Password must be at least 6 characters,\nand should include letters and numbers.');
  String get currentPassword => _t('현재 비밀번호', 'Current Password');
  String get currentPasswordHint => _t('현재 비밀번호를 입력하세요', 'Enter your current password');
  String get currentPasswordRequired => _t('현재 비밀번호를 입력해주세요', 'Please enter your current password');
  String get newPassword => _t('새 비밀번호', 'New Password');
  String get newPasswordHint => _t('새 비밀번호를 입력하세요', 'Enter your new password');
  String get newPasswordRequired => _t('새 비밀번호를 입력해주세요', 'Please enter a new password');
  String get passwordTooShort => _t('비밀번호는 최소 6자 이상이어야 합니다', 'Password must be at least 6 characters');
  String get passwordSameAsCurrent =>
      _t('현재 비밀번호와 동일한 비밀번호는 사용할 수 없습니다', 'New password cannot be the same as the current password');
  String get confirmNewPassword => _t('새 비밀번호 확인', 'Confirm New Password');
  String get confirmNewPasswordHint => _t('새 비밀번호를 다시 입력하세요', 'Re-enter your new password');
  String get confirmNewPasswordRequired => _t('새 비밀번호를 다시 입력해주세요', 'Please re-enter your new password');
  String get passwordMismatch => _t('비밀번호가 일치하지 않습니다', 'Passwords do not match');
  String get changePasswordButton => _t('비밀번호 변경', 'Change Password');
  String get logoutWarning =>
      _t('비밀번호 변경 후에는 모든 기기에서 로그아웃됩니다', 'You will be logged out on all devices after changing your password');

  String get userNotFound => _t('사용자 정보를 찾을 수 없습니다', 'User information not found');
  String get changeSuccess => _t('비밀번호가 성공적으로 변경되었습니다', 'Password changed successfully');
  String get wrongPassword => _t('현재 비밀번호가 올바르지 않습니다', 'Current password is incorrect');
  String get weakPassword => _t('비밀번호가 너무 약합니다', 'Password is too weak');
  String get requiresRecentLogin => _t('보안을 위해 다시 로그인해주세요', 'For security, please log in again');
  String changeFailed(String? message) =>
      _t('비밀번호 변경에 실패했습니다: $message', 'Failed to change password: $message');
  String genericError(Object e) => _t('오류가 발생했습니다: $e', 'An error occurred: $e');
}
