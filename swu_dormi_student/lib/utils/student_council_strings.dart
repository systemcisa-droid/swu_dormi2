/// 사생회 화면 문구 (한/영)
class StudentCouncilStrings {
  final bool isEnglish;
  const StudentCouncilStrings(this.isEnglish);

  String _t(String ko, String en) => isEnglish ? en : ko;

  String get title => _t('사생회', 'Resident Council');

  // 탭
  String get tabNotices => _t('공지', 'Notices');
  String get tabCampaigns => _t('캠페인', 'Campaigns');
  String get tabElections => _t('선거', 'Elections');

  // 공통
  String get loadError => _t('불러오는 중 오류가 발생했습니다', 'Failed to load');
  String get noticesEmpty =>
      _t('등록된 사생회 공지가 없습니다', 'No resident council notices yet');
  String get campaignsEmpty =>
      _t('진행 중인 캠페인이 없습니다', 'No campaigns in progress');
  String get electionsEmpty => _t('진행 중인 선거가 없습니다', 'No elections in progress');

  // 캠페인 상태
  String get statusOngoing => _t('진행중', 'Ongoing');
  String get statusUpcoming => _t('예정', 'Upcoming');
  String get statusClosed => _t('종료', 'Closed');

  // 선거
  String get electionPeriod => _t('투표 기간', 'Voting period');
  String get electionCloseNotice =>
      _t('마지막 날 오후 8시에 투표가 종료됩니다.',
          'Voting closes at 8:00 PM on the final day.');
  String get electionCandidates => _t('후보', 'Candidates');

  // 선거 상세
  String get electionDetailTitle => _t('선거 공고', 'Election Notice');
  String get electionNoContent =>
      _t('등록된 공고 내용이 없습니다.', 'No notice content registered.');

  // 투표
  String get voteSelectCandidate => _t('후보를 선택하세요', 'Select a candidate');
  String get voteButton => _t('투표하기', 'Vote');
  String get voteConfirmTitle => _t('투표 확인', 'Confirm Vote');
  String voteConfirmBody(String candidate) => _t(
      '「$candidate」 후보에게 투표하시겠습니까?\n\n투표 후에는 변경하거나 취소할 수 없습니다.',
      'Vote for "$candidate"?\n\nYour vote cannot be changed or canceled.');
  String get voteConfirm => _t('투표', 'Vote');
  String get voteCancel => _t('취소', 'Cancel');
  String get voteDone => _t('투표가 완료되었습니다.', 'Your vote has been submitted.');
  String get voteAlreadyDone =>
      _t('이미 투표하셨습니다.', 'You have already voted.');
  String get voteNotStarted =>
      _t('아직 투표 기간이 아닙니다.', 'Voting has not started yet.');
  String get voteClosed => _t('투표가 종료되었습니다.', 'Voting has closed.');
  String get voteFailed =>
      _t('투표 처리에 실패했습니다. 다시 시도해주세요.', 'Failed to submit your vote. Please try again.');
  String get voteSecretNotice => _t(
      '비밀투표입니다. 누구를 선택했는지는 기록되지 않으며, 투표 여부만 확인됩니다.',
      'This is a secret ballot. Your choice is not recorded with your identity — only that you voted.');
  String get voteNoCandidates =>
      _t('등록된 후보가 없습니다.', 'No candidates registered.');

  // 후보 소개
  String get candidateIntro => _t('소개', 'Profile');
  String get candidateIntroTitle => _t('후보 소개', 'Candidate Profile');
  String get candidateNoIntro =>
      _t('등록된 소개가 없습니다.', 'No profile registered.');
  String get candidateWatchVideo =>
      _t('연설·공약 영상 보기', 'Watch speech & pledges');
  String get candidateNoVideo =>
      _t('등록된 영상이 없습니다.', 'No video registered.');
  String get linkOpenFailed =>
      _t('링크를 열 수 없습니다.', 'Could not open the link.');

  // 선거 포스터
  String get electionPoster => _t('선거 포스터', 'Election Poster');
  String get electionPosterOpen => _t('선거 포스터 보기', 'View election poster');

  // 공지 상세
  String get noticeDetailTitle => _t('사생회 공지', 'Council Notice');
  String get noticeOpenPdf => _t('첨부 PDF 보기', 'View attached PDF');

  // 투표율
  String get electionTurnout => _t('투표율', 'Turnout');

  // 투표 완료 후 안내 (결과 공표·이의 접수)
  String get voteResultNotice => _t(
      '규정에 따라 투표 공식 종료하고 3시간 후 선거 결과를 공표(공지사항)할 예정입니다. '
      '선거 과정 전반에 대해 이의가 있는 각 후보 측은 결과 발표 전까지 정해진 양식에 따라 '
      '선거관리위원회로 이의를 접수해 주시기 바랍니다.',
      'The election results will be announced (in Notices) three hours after voting '
      'officially closes, in accordance with the regulations. Any candidate with an '
      'objection regarding the election process must submit it to the Election '
      'Management Committee using the designated form before the results are announced.');
}
