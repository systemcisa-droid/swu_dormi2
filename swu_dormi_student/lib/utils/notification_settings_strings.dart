class NotificationSettingsStrings {
  final bool isEnglish;
  const NotificationSettingsStrings(this.isEnglish);

  String _t(String ko, String en) => isEnglish ? en : ko;

  String get title => _t('알림 설정', 'Notification Settings');
  String get manageDescription => _t('알림 설정을 관리하세요', 'Manage your notification settings');
  String get allNotifications => _t('전체 알림', 'All Notifications');
  String get allNotificationsSubtitle => _t('모든 알림을 받습니다', 'Receive all notifications');
  String get typeSettings => _t('알림 유형별 설정', 'Notification Type Settings');
  String get settingsSaved => _t('알림 설정이 저장되었습니다', 'Notification settings saved');

  String get notices => _t('공지사항', 'Notices');
  String get noticesSubtitle => _t('새로운 공지사항 알림', 'New notice alerts');
  String get facilityReport => _t('시설 신고', 'Facility Report');
  String get facilityReportSubtitle => _t('시설 신고 답변 알림', 'Facility report response alerts');
  String get checkInOut => _t('입사/퇴사', 'Move-in/out');
  String get checkInOutSubtitle => _t('입사/퇴사 신청 승인/거부 알림', 'Move-in/out request approval/rejection alerts');
  String get meal => _t('식단표', 'Meal Plan');
  String get mealSubtitle => _t('새로운 식단 등록 알림', 'New meal plan alerts');
  String get floorChat => _t('층장단톡방', 'Floor Captain Chat');
  String get floorChatSubtitle => _t('층장단톡방 새 메시지 알림', 'New message alerts in the floor captain chat');
  String get adminMessage => _t('행정실', 'Admin Office');
  String get adminMessageSubtitle => _t('행정실에서 보낸 메시지 알림', 'Message alerts from the admin office');
}
