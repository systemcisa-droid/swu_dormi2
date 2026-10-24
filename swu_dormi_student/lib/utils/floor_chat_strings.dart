// 층장단톡방 화면에서 사용하는 다국어 문자열
class FloorChatStrings {
  final bool isEnglish;
  const FloorChatStrings(this.isEnglish);

  String _t(String ko, String en) => isEnglish ? en : ko;

  String get title => _t('층장단톡방', 'Floor Captain Chat');
  String roomChatSubtitle(String room) =>
      _t('$room호 채팅방', 'Room $room Chat');
  String roomChatBanner(String room) =>
      _t('$room호 ↔ 층장 채팅방', 'Room $room ↔ Floor Captain');
  String get usageHours => _t('이용시간 09:00 ~ 00:30', 'Open 09:00 ~ 00:30');

  String get noRoomInfoTitle =>
      _t('기숙사/호실 정보가 없습니다', 'No dormitory/room information');
  String get noRoomInfoHint => _t('프로필에서 기숙사와 호실을 먼저 입력해주세요',
      'Please enter your dormitory and room number in your profile first.');

  String get emptyMessages => _t('첫 메시지를 보내보세요!', 'Send the first message!');

  String get restrictedTime => _t('00:30 ~ 09:00 사이에는 채팅을 이용할 수 없습니다',
      'Chat is unavailable between 00:30 and 09:00');

  String get inputHint => _t('메시지를 입력하세요...', 'Type a message...');
  String get messageCopied => _t('메시지가 복사되었습니다', 'Message copied');

  /// 메시지 길게 누르기 메뉴
  String get menuCopy => _t('복사', 'Copy');
  String get menuSelectCopy => _t('선택 복사', 'Select text');
  String get menuPin => _t('공지', 'Notice');
  String get menuUnpin => _t('공지 해제', 'Remove notice');
  String get menuEdit => _t('수정', 'Edit');
  String get menuDelete => _t('삭제', 'Delete');
  String get deleteMessageTitle => _t('메시지 삭제', 'Delete message');
  String get deleteMessageConfirm =>
      _t('이 메시지를 삭제하시겠습니까?', 'Delete this message?');
  String deleteError(Object e) => _t('삭제 오류: $e', 'Delete error: $e');
  String get cancel => _t('취소', 'Cancel');
  String get save => _t('저장', 'Save');
  String get close => _t('닫기', 'Close');
  String get editMessageTitle => _t('메시지 수정', 'Edit message');
  String editError(Object e) => _t('수정 오류: $e', 'Edit error: $e');
  String get editedLabel => _t('(수정됨)', '(edited)');
  String get attachTooltip => _t('사진/영상 첨부', 'Attach photo/video');
  String get pickImage => _t('사진 선택', 'Choose photo');
  String get pickVideo => _t('영상 선택', 'Choose video');
  String get pickVideoHint =>
      _t('최대 1분 · 업로드 시 압축됩니다', 'Up to 1 min · compressed on upload');

  String get compressingVideo => _t('영상 압축 중...', 'Compressing video...');
  String get uploadingVideo => _t('영상 업로드 중...', 'Uploading video...');
  String get uploadingImage => _t('사진 업로드 중...', 'Uploading photo...');
  String get fileTooLarge => _t('파일이 너무 큽니다. 더 짧은 영상을 선택해주세요',
      'File is too large. Please choose a shorter video.');
  String sendError(Object e) => _t('전송 오류: $e', 'Send error: $e');

  /// 채팅방 목록의 마지막 메시지 표기
  String get lastMessageVideo => _t('[영상]', '[Video]');
  String get lastMessageImage => _t('[사진]', '[Photo]');

  /// 발신자 표기 (층장 / 호실)
  String senderLabel(String name, String roomNumber) => roomNumber == '층장'
      ? _t('$name (층장)', '$name (Floor Captain)')
      : _t('$name ($roomNumber호)', '$name (Room $roomNumber)');

  /// 날짜 구분선 형식
  String get dateFormat => _t('yyyy년 MM월 dd일 (E)', 'MMM d, yyyy (E)');
  String get dateLocale => _t('ko', 'en');

  /// 답장(스와이프) 관련
  String replyingTo(String name) => _t('$name님에게 답장', 'Replying to $name');
  String get replyToSelf => _t('나에게 답장', 'Replying to yourself');
  String get replyMediaImage => _t('[사진]', '[Photo]');
  String get replyMediaVideo => _t('[영상]', '[Video]');
}
