import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../notices/pdf_viewer_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/student_council_strings.dart';

/// 투표 마감 시각. 규정상 종료일 오후 8시에 투표가 종료된다.
DateTime kElectionCloseTime(DateTime endDate) =>
    DateTime(endDate.year, endDate.month, endDate.day, 20, 0, 0);

/// 사생회 공지 화면. 사이드 메뉴의 "사생회" 아코디언에서 "공지"를 누르면 연다.
class CouncilNoticesScreen extends StatelessWidget {
  const CouncilNoticesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s =
        StudentCouncilStrings(Provider.of<LocaleProvider>(context).isEnglish);
    return Scaffold(
      appBar: AppBar(title: Text(s.tabNotices)),
      body: _StudentCouncilShared.buildNoticesTab(s),
    );
  }
}

/// 사생회 캠페인 화면. 사이드 메뉴의 "사생회" 아코디언에서 "캠페인"을 누르면 연다.
class CouncilCampaignsScreen extends StatelessWidget {
  const CouncilCampaignsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s =
        StudentCouncilStrings(Provider.of<LocaleProvider>(context).isEnglish);
    return Scaffold(
      appBar: AppBar(title: Text(s.tabCampaigns)),
      body: _StudentCouncilShared.buildCampaignsTab(s),
    );
  }
}

/// 사생회 선거 화면. 사이드 메뉴의 "사생회" 아코디언에서 "선거"를 누르면 연다.
class CouncilElectionsScreen extends StatelessWidget {
  const CouncilElectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s =
        StudentCouncilStrings(Provider.of<LocaleProvider>(context).isEnglish);
    return Scaffold(
      appBar: AppBar(title: Text(s.tabElections)),
      body: _StudentCouncilShared.buildElectionsTab(s),
    );
  }
}

/// 공지 / 캠페인 / 선거 화면이 공유하는 목록·카드 빌더.
///
/// 각 목록은 Firestore 컬렉션을 그대로 읽어 표시하며,
/// 아직 등록된 문서가 없으면 빈 상태 안내를 보여준다.
///   - council_notices   : 사생회 공지
///   - council_campaigns : 캠페인
///   - council_elections : 선거
class _StudentCouncilShared {
  // ── 공통 상태 위젯 ──────────────────────────────────────────
  static Widget _buildEmpty(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  /// 컬렉션 하나를 읽어 목록으로 그리는 공통 StreamBuilder.
  static Widget _buildList({
    required String collection,
    required String orderBy,
    required IconData emptyIcon,
    required String emptyMessage,
    required String errorMessage,
    required Widget Function(BuildContext context, String id, Map<String, dynamic> data) itemBuilder,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .orderBy(orderBy, descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildEmpty(Icons.error_outline, errorMessage);
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        var docs = snapshot.data?.docs ?? [];
        // 고정 공지를 목록 상단에 올린다.
        docs = [...docs]..sort((a, b) {
            final ap = ((a.data() as Map<String, dynamic>?) ?? {})['isPinned'] == true;
            final bp = ((b.data() as Map<String, dynamic>?) ?? {})['isPinned'] == true;
            if (ap == bp) return 0;
            return ap ? -1 : 1;
          });
        if (docs.isEmpty) {
          return _buildEmpty(emptyIcon, emptyMessage);
        }
        return SingleChildScrollView(
          child: Column(
            children: [
              Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
              ...docs.map((d) => itemBuilder(
                  context, d.id, (d.data() as Map<String, dynamic>?) ?? {})),
            ],
          ),
        );
      },
    );
  }

  // ── 공지 탭 ────────────────────────────────────────────────
  static Widget buildNoticesTab(StudentCouncilStrings s) {
    return _buildList(
      collection: 'council_notices',
      orderBy: 'createdAt',
      emptyIcon: Icons.inbox,
      emptyMessage: s.noticesEmpty,
      errorMessage: s.loadError,
      itemBuilder: (context, id, data) => _buildNoticeCard(context, data, s),
    );
  }

  static Widget _buildNoticeCard(
      BuildContext context, Map<String, dynamic> data, StudentCouncilStrings s) {
    final title = (data['title'] ?? '').toString();
    final content = (data['content'] ?? '').toString();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final isPinned = data['isPinned'] == true;
    final imageUrls = (data['imageUrls'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];
    final thumbnail = imageUrls.isNotEmpty ? imageUrls.first : null;

    return Column(
      children: [
        InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CouncilNoticeDetailScreen(data: data),
            ),
          ),
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: thumbnail != null
                    ? Image.network(
                        thumbnail,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _noticeIconBox(),
                      )
                    : _noticeIconBox(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (isPinned) ...[
                          Icon(Icons.push_pin,
                              size: 14, color: Colors.orange.shade700),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (content.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                    if (createdAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('yyyy.MM.dd').format(createdAt),
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade400),
            ],
          ),
          ),
        ),
        Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
      ],
    );
  }

  /// 이미지가 없는 공지의 기본 아이콘 박스
  static Widget _noticeIconBox() => Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.indigo.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child:
            Icon(Icons.campaign_outlined, color: Colors.indigo.shade300, size: 26),
      );

  // ── 캠페인 탭 ──────────────────────────────────────────────
  static Widget buildCampaignsTab(StudentCouncilStrings s) {
    return _buildList(
      collection: 'council_campaigns',
      orderBy: 'startDate',
      emptyIcon: Icons.volunteer_activism_outlined,
      emptyMessage: s.campaignsEmpty,
      errorMessage: s.loadError,
      itemBuilder: (context, id, data) => _buildCampaignCard(data, s),
    );
  }

  static Widget _buildCampaignCard(
      Map<String, dynamic> data, StudentCouncilStrings s) {
    final title = (data['title'] ?? '').toString();
    final content = (data['content'] ?? '').toString();
    final start = (data['startDate'] as Timestamp?)?.toDate();
    final end = (data['endDate'] as Timestamp?)?.toDate();

    // 기간으로 진행 상태를 계산한다.
    final now = DateTime.now();
    String statusLabel;
    Color statusColor;
    if (start != null && now.isBefore(start)) {
      statusLabel = s.statusUpcoming;
      statusColor = const Color(0xFFFF9800);
    } else if (end != null && now.isAfter(end)) {
      statusLabel = s.statusClosed;
      statusColor = const Color(0xFF757575);
    } else {
      statusLabel = s.statusOngoing;
      statusColor = const Color(0xFF009688);
    }

    final fmt = DateFormat('yyyy.MM.dd');
    final period = [
      if (start != null) fmt.format(start),
      if (end != null) fmt.format(end),
    ].join(' ~ ');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              if (content.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                ),
              ],
              if (period.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 5),
                    Text(
                      period,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
      ],
    );
  }

  // ── 선거 탭 ────────────────────────────────────────────────
  static Widget buildElectionsTab(StudentCouncilStrings s) {
    return _buildList(
      collection: 'council_elections',
      orderBy: 'startDate',
      emptyIcon: Icons.how_to_vote_outlined,
      emptyMessage: s.electionsEmpty,
      errorMessage: s.loadError,
      itemBuilder: (context, id, data) => _buildElectionCard(context, id, data, s),
    );
  }

  static Widget _buildElectionCard(
      BuildContext context, String id, Map<String, dynamic> data, StudentCouncilStrings s) {
    // 투표율 = 투표수 / 선거인 수. 관리자가 선거를 저장할 때 기록된다.
    // 진행 상태. 캠페인 카드와 같은 기준·색상을 쓴다.
    // 투표는 종료일 오후 8시에 마감된다 (투표 화면과 동일한 기준).
    final now = DateTime.now();
    final start = (data['startDate'] as Timestamp?)?.toDate();
    final end = (data['endDate'] as Timestamp?)?.toDate();
    String statusLabel;
    Color statusColor;
    if (start != null && now.isBefore(start)) {
      statusLabel = s.statusUpcoming;
      statusColor = const Color(0xFFFF9800);
    } else if (end != null && now.isAfter(kElectionCloseTime(end))) {
      statusLabel = s.statusClosed;
      statusColor = const Color(0xFF757575);
    } else {
      statusLabel = s.statusOngoing;
      statusColor = const Color(0xFF009688);
    }

    final voteCount = (data['voteCount'] as num?)?.toInt() ?? 0;
    final eligibleCount = (data['eligibleCount'] as num?)?.toInt() ?? 0;
    final turnout =
        eligibleCount == 0 ? 0.0 : (voteCount / eligibleCount).clamp(0.0, 1.0);
    final title = (data['title'] ?? '').toString();
    final candidates = (data['candidates'] as List?)
            ?.map((c) => c.toString())
            .where((c) => c.isNotEmpty)
            .toList() ??
        [];

    final fmt = DateFormat('yyyy.MM.dd');
    final period = [
      if (start != null) fmt.format(start),
      if (end != null) fmt.format(end),
    ].join(' ~ ');

    return Column(
      children: [
        InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ElectionDetailScreen(id: id, data: data),
            ),
          ),
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.how_to_vote_outlined,
                      size: 18, color: Colors.indigo.shade300),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      size: 20, color: Colors.grey.shade400),
                ],
              ),
              if (period.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${s.electionPeriod}  $period',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
              if (candidates.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  s.electionCandidates,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in candidates)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(c, style: const TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ],
              // 투표율 (선거인 수가 등록된 경우에만 표시)
              if (eligibleCount > 0) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: turnout,
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade200,
                          valueColor:
                              AlwaysStoppedAnimation(Colors.indigo.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${s.electionTurnout} ${(turnout * 100).toStringAsFixed(1)}%'
                      '  ($voteCount/$eligibleCount)',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ],
          ),
          ),
        ),
        Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
      ],
    );
  }
}

/// 선거 공고 상세 화면. 목록의 선거 카드를 누르면 열린다.
///
/// 비밀투표 구조:
///   council_elections/{id}/voters/{uid}   - 투표 여부만 기록 (선택 후보 없음)
///   council_elections/{id}/ballots/{auto} - 선택한 후보만 기록 (작성자 없음)
/// 두 문서를 연결할 수 없어 누가 누구를 뽑았는지 알 수 없다.
class ElectionDetailScreen extends StatefulWidget {
  final String id;
  final Map<String, dynamic> data;
  const ElectionDetailScreen({super.key, required this.id, required this.data});

  @override
  State<ElectionDetailScreen> createState() => _ElectionDetailScreenState();
}

class _ElectionDetailScreenState extends State<ElectionDetailScreen> {
  String? _selectedCandidate;
  bool _hasVoted = false;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _checkVoted();
  }

  /// 본인의 투표 여부만 확인한다 (규칙상 본인 문서만 읽을 수 있다).
  Future<void> _checkVoted() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('council_elections')
          .doc(widget.id)
          .collection('voters')
          .doc(uid)
          .get();
      if (!mounted) return;
      setState(() {
        _hasVoted = doc.exists;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  /// 후보 이름 -> 소개글. 관리자가 입력하지 않은 후보는 키가 없다.
  Map<String, String> get _candidateProfiles =>
      (widget.data['candidateProfiles'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ) ??
      const {};

  /// 후보 이름 -> 소개글
  Map<String, String> get _candidateIntros =>
      (widget.data['candidateIntros'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ) ??
      const {};

  /// 후보 이름 -> 선거 포스터 PDF {url, name}
  Map<String, Map<String, String>> get _candidatePdfs =>
      (widget.data['candidatePdfs'] as Map?)?.map((k, v) {
            final m = (v as Map?) ?? const {};
            return MapEntry(k.toString(), {
              'url': (m['url'] ?? '').toString(),
              'name': (m['name'] ?? '').toString(),
            });
          }) ??
      const {};

  DateTime? get _startDate => (widget.data['startDate'] as Timestamp?)?.toDate();
  DateTime? get _endDate => (widget.data['endDate'] as Timestamp?)?.toDate();

  /// 투표 기간인지 판단한다. 종료일 오후 8시에 마감된다.
  bool get _isVotingOpen {
    final now = DateTime.now();
    final start = _startDate;
    final end = _endDate;
    if (start != null && now.isBefore(start)) return false;
    if (end != null && now.isAfter(kElectionCloseTime(end))) return false;
    return true;
  }

  Future<void> _submitVote(StudentCouncilStrings s) async {
    if (_isSubmitting) return;
    final candidate = _selectedCandidate;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (candidate == null || uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.voteConfirmTitle),
        content: Text(s.voteConfirmBody(candidate)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.voteCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.voteConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isSubmitting = true);
    try {
      final election = FirebaseFirestore.instance
          .collection('council_elections')
          .doc(widget.id);

      // 투표 표시를 먼저 만든다. 이미 투표했다면 규칙에서 막혀 여기서 실패하므로
      // 중복 투표가 표에 반영되지 않는다.
      await election.collection('voters').doc(uid).set({
        'votedAt': FieldValue.serverTimestamp(),
      });

      // 익명 표는 별도 문서로 저장한다 (작성자 정보를 담지 않는다).
      await election.collection('ballots').add({'candidate': candidate});

      // 투표율 표시용 합계. 합계만 담으므로 비밀투표에 영향이 없다.
      await election.update({'voteCount': FieldValue.increment(1)});

      if (!mounted) return;
      setState(() {
        _hasVoted = true;
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.voteDone)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      // permission-denied 는 "이미 투표함"일 수도, 규칙 미배포 같은 설정 문제일 수도
      // 있다. 투표 표시 문서가 실제로 있는지 확인해 둘을 구분한다.
      // (확인 없이 투표 완료로 처리하면 저장되지 않았는데도 완료로 보인다.)
      var alreadyVoted = false;
      final uid2 = FirebaseAuth.instance.currentUser?.uid;
      if (uid2 != null) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('council_elections')
              .doc(widget.id)
              .collection('voters')
              .doc(uid2)
              .get();
          alreadyVoted = doc.exists;
        } catch (_) {
          // 조회 자체가 막히면 설정 문제로 본다.
        }
      }

      if (!mounted) return;
      if (alreadyVoted) setState(() => _hasVoted = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(alreadyVoted ? s.voteAlreadyDone : s.voteFailed),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s =
        StudentCouncilStrings(Provider.of<LocaleProvider>(context).isEnglish);

    final title = (widget.data['title'] ?? '').toString();
    final content = (widget.data['content'] ?? '').toString();
    final candidates = (widget.data['candidates'] as List?)
            ?.map((c) => c.toString())
            .where((c) => c.isNotEmpty)
            .toList() ??
        [];

    final fmt = DateFormat('yyyy.MM.dd');
    final period = [
      if (_startDate != null) fmt.format(_startDate!),
      if (_endDate != null) fmt.format(_endDate!),
    ].join(' ~ ');

    return Scaffold(
      appBar: AppBar(title: Text(s.electionDetailTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.how_to_vote_outlined,
                    size: 22, color: Colors.indigo.shade300),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            if (period.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Text(
                    '${s.electionPeriod}  $period',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Text(
                  s.electionCloseNotice,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 20),
            if (content.isNotEmpty) ...[
              Text(content, style: const TextStyle(fontSize: 15, height: 1.7)),
              const SizedBox(height: 20),
            ],
            _buildVoteSection(s, candidates),
          ],
        ),
      ),
    );
  }

  Widget _buildVoteSection(StudentCouncilStrings s, List<String> candidates) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (candidates.isEmpty) {
      return _buildInfoBox(Icons.info_outline, s.voteNoCandidates);
    }

    // 투표 완료 / 기간 외에는 후보만 보여주고 선택은 막는다.
    final String? closedMessage = _hasVoted
        ? s.voteAlreadyDone
        : (_startDate != null && DateTime.now().isBefore(_startDate!))
            ? s.voteNotStarted
            : !_isVotingOpen
                ? s.voteClosed
                : null;
    final canVote = closedMessage == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          canVote ? s.voteSelectCandidate : s.electionCandidates,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        for (final c in candidates) _buildCandidateTile(c, canVote),
        const SizedBox(height: 20),
        if (canVote) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_selectedCandidate == null || _isSubmitting)
                  ? null
                  : () => _submitVote(s),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(s.voteButton,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 14),
          _buildInfoBox(Icons.lock_outline, s.voteSecretNotice),
        ] else ...[
          _buildInfoBox(
            _hasVoted ? Icons.check_circle_outline : Icons.info_outline,
            closedMessage,
          ),
          // 투표를 마친 학생에게만 결과 공표·이의 접수 안내를 보여준다.
          if (_hasVoted) ...[
            const SizedBox(height: 14),
            Text(
              s.voteResultNotice,
              style: const TextStyle(
                fontSize: 13,
                height: 1.6,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildCandidateTile(String candidate, bool canVote) {
    final isSelected = _selectedCandidate == candidate;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap:
            canVote ? () => setState(() => _selectedCandidate = candidate) : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? Colors.indigo.shade50 : null,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? Colors.indigo : Colors.grey.shade300,
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              if (canVote)
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: isSelected ? Colors.indigo : Colors.grey.shade400,
                )
              else
                Icon(Icons.person_outline,
                    size: 20, color: Colors.grey.shade400),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  candidate,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.indigo.shade700 : null,
                  ),
                ),
              ),
              // 소개 버튼은 선택과 별개로 항상 누를 수 있다.
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CandidateProfileScreen(
                      name: candidate,
                      intro: _candidateIntros[candidate] ?? '',
                      videoUrl: _candidateProfiles[candidate] ?? '',
                      pdfUrl: _candidatePdfs[candidate]?['url'] ?? '',
                      pdfName: _candidatePdfs[candidate]?['name'] ?? '',
                    ),
                  ),
                ),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      StudentCouncilStrings(
                              Provider.of<LocaleProvider>(context).isEnglish)
                          .candidateIntro,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBox(IconData icon, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade700, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// 후보 소개 화면. 선거 상세의 후보 목록에서 "소개"를 누르면 열린다.
///
/// 표시 순서: 후보 소개글 → 유튜브 링크 → 선거 포스터(바로 렌더링)
class CandidateProfileScreen extends StatelessWidget {
  final String name;

  /// 유튜브 링크 (연설·공약 영상)
  final String videoUrl;

  /// 후보 소개글
  final String intro;

  final String pdfUrl;
  final String pdfName;

  const CandidateProfileScreen({
    super.key,
    required this.name,
    this.videoUrl = '',
    this.intro = '',
    this.pdfUrl = '',
    this.pdfName = '',
  });

  @override
  Widget build(BuildContext context) {
    final s =
        StudentCouncilStrings(Provider.of<LocaleProvider>(context).isEnglish);

    return Scaffold(
      appBar: AppBar(title: Text(s.candidateIntroTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 이름 ──
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.indigo.shade50,
                  child: Icon(Icons.person,
                      size: 30, color: Colors.indigo.shade300),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 20),

            // ── 후보 소개 (없으면 표시하지 않는다) ──
            if (intro.isNotEmpty)
              Text(
                intro,
                style: const TextStyle(fontSize: 15, height: 1.7),
              ),

            // ── 선거 포스터 (버튼 없이 바로 렌더링) ──
            if (pdfUrl.isNotEmpty) ...[
              // 위에 소개글이 있을 때만 간격을 준다.
              if (intro.isNotEmpty) const SizedBox(height: 24),
              Text(
                s.electionPoster,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              // 스크롤 안에서 렌더링해야 하므로 높이를 고정한다.
              // 확대해서 보려면 우측 상단 버튼으로 전체 화면 뷰어를 연다.
              SizedBox(
                height: 480,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SfPdfViewer.network(
                          pdfUrl,
                          canShowScrollHead: false,
                          canShowScrollStatus: false,
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PdfViewerScreen(
                                  pdfUrl: pdfUrl,
                                  pdfFileName: pdfName.isEmpty
                                      ? s.electionPoster
                                      : pdfName,
                                ),
                              ),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.fullscreen,
                                  size: 20, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // ── 유튜브 링크 ──
            if (videoUrl.isNotEmpty) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () async {
                  final uri = Uri.tryParse(videoUrl);
                  final opened = uri == null
                      ? false
                      : await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                  if (!opened && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(s.linkOpenFailed)),
                    );
                  }
                },
                icon: const Icon(Icons.play_circle_outline, size: 20),
                label: Text(s.candidateWatchVideo),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: const Color(0xFFFF0000),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                videoUrl,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],

          ],
        ),
      ),
    );
  }
}

/// 사생회 공지 상세 화면. 이미지·PDF 첨부를 함께 보여준다.
class CouncilNoticeDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  const CouncilNoticeDetailScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final s =
        StudentCouncilStrings(Provider.of<LocaleProvider>(context).isEnglish);

    final title = (data['title'] ?? '').toString();
    final content = (data['content'] ?? '').toString();
    final authorName = (data['authorName'] ?? '').toString();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final isPinned = data['isPinned'] == true;
    final imageUrls = (data['imageUrls'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];
    final pdfUrl = (data['pdfUrl'] ?? '').toString();
    final pdfFileName = (data['pdfFileName'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(title: Text(s.noticeDetailTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isPinned) ...[
                  Icon(Icons.push_pin, size: 18, color: Colors.orange.shade700),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              [
                if (authorName.isNotEmpty) authorName,
                if (createdAt != null)
                  DateFormat('yyyy.MM.dd HH:mm').format(createdAt),
              ].join('  ·  '),
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // 첨부 이미지
            if (imageUrls.isNotEmpty) ...[
              for (final url in imageUrls)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      url,
                      width: double.infinity,
                      fit: BoxFit.fitWidth,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],

            if (content.isNotEmpty)
              Text(content, style: const TextStyle(fontSize: 15, height: 1.7)),

            // 첨부 PDF
            if (pdfUrl.isNotEmpty) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PdfViewerScreen(
                      pdfUrl: pdfUrl,
                      pdfFileName:
                          pdfFileName.isEmpty ? s.noticeDetailTitle : pdfFileName,
                    ),
                  ),
                ),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: Text(
                  pdfFileName.isEmpty ? s.noticeOpenPdf : pdfFileName,
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 46),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
