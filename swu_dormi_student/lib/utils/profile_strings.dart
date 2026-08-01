class ProfileStrings {
  final bool isEnglish;
  const ProfileStrings(this.isEnglish);

  String _t(String ko, String en) => isEnglish ? en : ko;

  String get title => _t('프로필', 'Profile');
  String get userDataUnavailable => _t('사용자 정보를 불러올 수 없습니다', 'Unable to load user information');
  String get imageUploadError => _t('프로필 사진 업로드 중 오류가 발생했습니다', 'An error occurred while uploading the profile photo');
  String get takePhoto => _t('카메라로 촬영', 'Take a Photo');
  String get chooseFromGallery => _t('갤러리에서 선택', 'Choose from Gallery');
  String get rewardPenalty => _t('상벌점', 'Reward/Penalty');
  String get pointNotice =>
      _t('상벌점 발생 시 알림 메시지는 발송되지 않습니다.', 'Notification messages are not sent when reward/penalty points occur.');
  String get personalInfo => _t('개인 정보', 'Personal Information');
  String get email => _t('이메일', 'Email');
  String get phoneNumber => _t('전화번호', 'Phone Number');
  String get department => _t('학과, 전공', 'Department/Major');
  String get dormBuilding => _t('기숙사 건물', 'Dormitory Building');
  String get room => _t('호실', 'Room');
  String get seatNumber => _t('자리번호', 'Seat Number');
  String get joinDate => _t('가입일', 'Join Date');
  String get notificationSettings => _t('알림 설정', 'Notification Settings');
  String get changePassword => _t('비밀번호 변경', 'Change Password');
  String get privacyPolicyAndWithdrawal => _t('개인정보 처리방침 및 회원탈퇴', 'Privacy Policy & Account Deletion');
  String get appInfo => _t('앱 정보', 'App Info');
  String get logoutTitle => _t('로그아웃', 'Log Out');
  String get logoutConfirm => _t('정말 로그아웃 하시겠습니까?', 'Are you sure you want to log out?');
  String get appInfoTitle => _t('SWU 기숙사 앱', 'SWU Dormitory App');
  String get appVersion => _t('버전: 1.0.0', 'Version: 1.0.0');
  String get appInfoSubtitle => _t('기숙사 관리 시스템', 'Dormitory Management System');
  String get appInfoDescription =>
      _t('이 앱은 기숙사생들의 편의를 위해 제작되었습니다.', 'This app was created for the convenience of dormitory residents.');

  String joinDateFormatted(DateTime date) {
    if (isEnglish) {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }
}
