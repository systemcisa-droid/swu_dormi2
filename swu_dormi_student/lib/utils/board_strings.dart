class BoardStrings {
  final bool isEnglish;
  const BoardStrings(this.isEnglish);

  String _t(String ko, String en) => isEnglish ? en : ko;

  // ── 게시판 목록 ──
  String get title => _t('게시판', 'Board');
  String get all => _t('전체', 'All');
  String get write => _t('글쓰기', 'Write');
  String get loginRequired => _t('로그인이 필요합니다', 'Login required');
  String get postsLoadError => _t('게시글을 불러오는 중 오류가 발생했습니다', 'An error occurred while loading posts');
  String get noPostsYet => _t('아직 게시글이 없습니다', 'No posts yet');
  String noPostsInCategory(String category) =>
      _t("'$category' 게시글이 없습니다", "No posts in '$category'");
  String get nicknameNotice =>
      _t('게시판은 별명으로 이용 가능합니다. 프로필에서 별명을 설정할 수 있어요.',
          'You can use a nickname on the board. You can set a nickname in your profile.');

  static const Map<String, String> _categoryEn = {
    'Lost&Found': 'Lost&Found',
    '배달팟': 'Delivery Group',
    '물품 나눔(당근)': 'Item Giveaway',
    '정보 알림': 'Info & Alerts',
    '세탁실톡': 'Laundry Room Talk',
    '맛집': 'Restaurants',
    '시간표 공유': 'Timetable Share',
  };
  String categoryLabel(String ko) => isEnglish ? (_categoryEn[ko] ?? ko) : ko;

  // ── 글쓰기 ──
  String get editPostTitle => _t('게시글 수정', 'Edit Post');
  String get writeTitle => _t('글쓰기', 'Write');
  String get edit => _t('수정', 'Save');
  String get register => _t('등록', 'Post');
  String get category => _t('카테고리', 'Category');
  String get postTitleLabel => _t('제목', 'Title');
  static const Map<String, String> _titleHintKo = {
    'lost&found': '무엇을 분실 하셨나요?',
    '배달팟': '배달비 아끼고 같이 먹어요^^',
    '물품 나눔': '나눔해요. 교환도 좋아요',
    '정보 알림': '행사, 정보, 팁 공유해요',
    '세탁실톡': '세탁기, 건조기 사용 후에 깜빡 하셨지요?!',
    '맛집': '학교 근처 맛집 추천해요!',
    '시간표 공유': '내 시간표 공유하기',
  };
  static const Map<String, String> _titleHintEn = {
    'lost&found': 'What did you lose?',
    '배달팟': 'Save on delivery fees, let\'s eat together^^',
    '물품 나눔': 'Let\'s share or trade items',
    '정보 알림': 'Share events, info, and tips',
    '세탁실톡': 'Forgot to grab your laundry from the washer/dryer?!',
    '맛집': 'Share a good restaurant near campus!',
    '시간표 공유': 'Share my timetable',
  };
  String postTitleHint(String categoryValue) {
    final map = isEnglish ? _titleHintEn : _titleHintKo;
    return map[categoryValue] ?? map['lost&found']!;
  }
  String get titleRequired => _t('제목을 입력해주세요', 'Please enter a title');
  String get titleTooLong => _t('제목은 100자 이내로 입력해주세요', 'Title must be 100 characters or fewer');
  String get contentLabel => _t('내용', 'Content');

  static const Map<String, String> _contentHintKo = {
    'lost&found': '예) 0000분실 했어요. 보신분 손!!!',
    '배달팟': '예) 배달비 아끼고 맛있는 음식 같이 먹어요. 치킨, 피자 고고~',
    '물품 나눔': '예) 서로 나눔해요~ 남는 샴푸, 사용하지 않는 모자, 갈 수 없는 공연 티켓 ㅠㅠ',
    '정보 알림': '예) 땡땡인의 밤 모여 취업, 행사 등 정보 공유해요~',
    '세탁실톡': '예) 8번 세탁기 완료 빨래 찾아가세요~',
    '맛집': '예) 정문 앞 000집 존맛! 가성비 좋아요~',
    '시간표 공유': '시간표 화면의 공유 체크박스로 자동 등록되는 게시글입니다.',
  };
  static const Map<String, String> _contentHintEn = {
    'lost&found': 'e.g. I lost 0000. If you\'ve seen it, please raise your hand!',
    '배달팟': 'e.g. Split delivery fees and enjoy good food together. Chicken, pizza, let\'s go~',
    '물품 나눔': 'e.g. Let\'s share with each other~ Extra shampoo, unused hats, tickets you can\'t use ㅠㅠ',
    '정보 알림': 'e.g. Gather info on jobs, events, and more with fellow students~',
    '세탁실톡': 'e.g. Washer #8 is done, please pick up your laundry~',
    '맛집': 'e.g. The pasta place by the main gate is amazing and affordable~',
    '시간표 공유': 'This post is auto-created from the share checkbox on the timetable screen.',
  };
  String contentHint(String categoryValue) {
    final map = isEnglish ? _contentHintEn : _contentHintKo;
    return map[categoryValue] ?? map['lost&found']!;
  }
  String get contentRequired => _t('내용을 입력해주세요', 'Please enter content');
  String get contentTooLong => _t('내용은 2000자 이내로 입력해주세요', 'Content must be 2000 characters or fewer');
  String imageAttach(int count) => _t('이미지 첨부 ($count/5)', 'Attach Images ($count/5)');
  String get maxImagesNotice => _t('이미지는 최대 5개까지 첨부할 수 있습니다', 'You can attach up to 5 images');
  String imagePickError(Object e) => _t('이미지를 선택할 수 없습니다: $e', 'Unable to select image: $e');
  String photoTakeError(Object e) => _t('사진을 촬영할 수 없습니다: $e', 'Unable to take photo: $e');
  String get takePhoto => _t('카메라로 촬영', 'Take a Photo');
  String get chooseFromGallery => _t('갤러리에서 선택', 'Choose from Gallery');
  String get postUpdated => _t('게시글이 수정되었습니다', 'Post updated');
  String get postCreated => _t('게시글이 등록되었습니다', 'Post created');
  String genericError(Object e) => _t('오류가 발생했습니다: $e', 'An error occurred: $e');

  String get confirmDialogTitle => _t('잠깐! 확인해 주세요', 'Wait! Please check');
  String get confirmDialogIntro =>
      _t('Clean한 게시판 환경을 위해 아래와 같은 글은 제한됩니다.', 'For a clean board environment, the following types of posts are restricted.');
  List<String> get restrictedRules => isEnglish
      ? [
          'Posts that target or criticize specific individuals or groups',
          'Reckless profanity, abusive language, or personal attacks',
          'Content that may spread false information or defame others',
        ]
      : [
          '특정 개인이나 단체를 저격, 비난하는 글',
          '무분별한 욕설, 비속어, 인신공격성 표현',
          '허위 사실 유포 및 명예훼손 우려가 있는 내용',
        ];
  String get confirmDialogOutro =>
      _t('깨끗하고 즐거운 소통 공간을 위해 슈먼 여러분의 적극적인 동참을 부탁드립니다.',
          'Please help us keep this a clean and enjoyable space for everyone.');
  String get confirmAndPost => _t('확인 후 등록', 'Confirm & Post');

  // ── 게시글 상세 ──
  String get postDetailTitle => _t('게시글', 'Post');
  String detailError(Object e) => _t('오류가 발생했습니다: $e', 'An error occurred: $e');
  String get postNotFound => _t('게시글을 찾을 수 없습니다', 'Post not found');
  String get deletePostTitle => _t('게시글 삭제', 'Delete Post');
  String get deletePostConfirm => _t('게시글을 삭제하시겠습니까?\n삭제된 게시글은 복구할 수 없습니다.', 'Are you sure you want to delete this post?\nDeleted posts cannot be recovered.');
  String get cancel => _t('취소', 'Cancel');
  String get delete => _t('삭제', 'Delete');
  String get postDeleted => _t('게시글이 삭제되었습니다', 'Post deleted');
  String postDeleteError(Object e) => _t('게시글 삭제 중 오류가 발생했습니다: $e', 'An error occurred while deleting the post: $e');

  String get editMenu => _t('수정', 'Edit');
  String get deleteMenu => _t('삭제', 'Delete');
  String get reportMenu => _t('신고하기', 'Report');
  String get blockUser => _t('사용자 차단', 'Block User');
  String get unblockUser => _t('차단 해제', 'Unblock');

  String get reportDialogTitle => _t('신고하기', 'Report');
  String get reportPostPrompt => _t('이 게시글을 신고하는 이유를 선택해주세요.', 'Please select a reason for reporting this post.');
  String get reportCommentPrompt => _t('이 댓글을 신고하는 이유를 선택해주세요.', 'Please select a reason for reporting this comment.');
  static const _reportReasonsKo = ['비방·욕설', '허위 사실 유포', '음란·불건전 내용', '개인정보 침해', '기타'];
  static const _reportReasonsEn = [
    'Abuse/Profanity',
    'Spreading False Information',
    'Obscene/Inappropriate Content',
    'Privacy Violation',
    'Other',
  ];
  List<String> get reportReasons => isEnglish ? _reportReasonsEn : _reportReasonsKo;
  String get otherReasonKey => isEnglish ? 'Other' : '기타';
  String get reportDetailHint => _t('신고 내용을 입력해주세요', 'Please describe the issue');
  String get report => _t('신고', 'Report');
  String get reportSubmitted => _t('신고가 접수되었습니다. 검토 후 조치하겠습니다.', 'Your report has been submitted. We will review it and take action.');
  String reportSubmitError(Object e) => _t('신고 접수 중 오류가 발생했습니다: $e', 'An error occurred while submitting the report: $e');

  String get blockTitle => _t('사용자 차단', 'Block User');
  String get unblockTitle => _t('차단 해제', 'Unblock User');
  String get unblockConfirm => _t('이 사용자의 차단을 해제하시겠습니까?', 'Are you sure you want to unblock this user?');
  String get blockConfirm => _t('이 사용자를 차단하면 해당 사용자의 글과 댓글이 보이지 않습니다.\n차단하시겠습니까?', "If you block this user, their posts and comments will no longer be visible.\nDo you want to block them?");
  String get unblockAction => _t('해제', 'Unblock');
  String get blockAction => _t('차단', 'Block');
  String get unblockedMessage => _t('차단이 해제되었습니다.', 'User has been unblocked.');
  String get blockedMessage => _t('차단되었습니다. 해당 사용자의 글이 더 이상 보이지 않습니다.', "User has been blocked. Their posts will no longer be visible.");

  String commentsCount(int n) => _t('댓글 $n개', '$n Comments');
  String get commentsLoadError => _t('댓글을 불러올 수 없습니다', 'Unable to load comments');
  String get noCommentsYet => _t('첫 댓글을 작성해보세요!', 'Be the first to comment!');
  String get commentHint => _t('댓글을 입력하세요...', 'Write a comment...');
  String get commentPosted => _t('댓글이 등록되었습니다', 'Comment posted');
  String commentPostError(Object e) => _t('댓글 등록 중 오류가 발생했습니다: $e', 'An error occurred while posting the comment: $e');
  String get deleteCommentTitle => _t('댓글 삭제', 'Delete Comment');
  String get deleteCommentConfirm => _t('댓글을 삭제하시겠습니까?', 'Are you sure you want to delete this comment?');
  String get commentDeleted => _t('댓글이 삭제되었습니다', 'Comment deleted');
  String commentDeleteError(Object e) => _t('댓글 삭제 중 오류가 발생했습니다: $e', 'An error occurred while deleting the comment: $e');
  String get anonymous => _t('익명', 'Anonymous');
}
