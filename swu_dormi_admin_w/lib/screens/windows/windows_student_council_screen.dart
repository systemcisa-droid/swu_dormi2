import 'package:flutter/material.dart' hide Colors, FilledButton, IconButton, Card, ListTile, showDialog, Divider, Checkbox, Tooltip, ButtonStyle;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:swu_dormi_admin/services/auth_service.dart';
import 'package:swu_dormi_admin/screens/windows/windows_council_notice_create_screen.dart';
import 'package:swu_dormi_admin/services/storage_service.dart';

/// 사생회 관리 화면. 학생앱의 사생회 페이지와 동일하게
/// 공지 / 캠페인 / 선거 3개 탭으로 구성된다.
class WindowsStudentCouncilTabScreen extends StatefulWidget {
  const WindowsStudentCouncilTabScreen({super.key});

  @override
  State<WindowsStudentCouncilTabScreen> createState() =>
      _WindowsStudentCouncilTabScreenState();
}

class _WindowsStudentCouncilTabScreenState
    extends State<WindowsStudentCouncilTabScreen> {
  int _tabIndex = 0;
  final _accentColor = Colors.purple;

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Column(
        children: [
          // 탭 헤더
          Container(
            color: FluentTheme.of(context).cardColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _buildTab(0, '공지', FluentIcons.megaphone),
                const SizedBox(width: 8),
                _buildTab(1, '캠페인', FluentIcons.party_leader),
                const SizedBox(width: 8),
                _buildTab(2, '선거', FluentIcons.check_list),
              ],
            ),
          ),
          // 탭 콘텐츠
          Expanded(
            child: switch (_tabIndex) {
              0 => const _CouncilSection(kind: _CouncilKind.notice),
              1 => const _CouncilSection(kind: _CouncilKind.campaign),
              _ => const _CouncilSection(kind: _CouncilKind.election),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label, IconData icon) {
    final isSelected = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? _accentColor.withValues(alpha: 0.12)
              : Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color:
                isSelected ? _accentColor : Colors.grey.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? _accentColor : Colors.grey),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? _accentColor : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 탭 종류별 설정 ────────────────────────────────────────────────
enum _CouncilKind { notice, campaign, election }

extension _CouncilKindInfo on _CouncilKind {
  String get collection => switch (this) {
        _CouncilKind.notice => 'council_notices',
        _CouncilKind.campaign => 'council_campaigns',
        _CouncilKind.election => 'council_elections',
      };

  /// 목록 정렬 기준 필드. 공지는 작성일, 캠페인/선거는 시작일 기준이다.
  String get orderByField =>
      this == _CouncilKind.notice ? 'createdAt' : 'startDate';

  String get label => switch (this) {
        _CouncilKind.notice => '공지',
        _CouncilKind.campaign => '캠페인',
        _CouncilKind.election => '선거',
      };

  IconData get icon => switch (this) {
        _CouncilKind.notice => FluentIcons.megaphone,
        _CouncilKind.campaign => FluentIcons.party_leader,
        _CouncilKind.election => FluentIcons.check_list,
      };

  /// 기간(시작일/종료일) 입력이 필요한지 여부
  bool get hasPeriod => this != _CouncilKind.notice;

  /// 후보 목록 입력이 필요한지 여부
  bool get hasCandidates => this == _CouncilKind.election;

  /// 이미지·PDF 첨부 입력이 필요한지 여부 (캠페인 홍보물)
  bool get hasAttachments => this == _CouncilKind.campaign;
}

// ── 목록 + 상세 패널 ──────────────────────────────────────────────
class _CouncilSection extends StatefulWidget {
  final _CouncilKind kind;
  const _CouncilSection({required this.kind});

  @override
  State<_CouncilSection> createState() => _CouncilSectionState();
}

class _CouncilSectionState extends State<_CouncilSection> {
  final _dateFormat = DateFormat('yyyy.MM.dd');
  _CouncilItem? _selected;
  String _searchQuery = '';

  Stream<List<_CouncilItem>> _stream() {
    return FirebaseFirestore.instance
        .collection(widget.kind.collection)
        .orderBy(widget.kind.orderByField, descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_CouncilItem.fromDoc).toList());
  }

  void _openDialog({_CouncilItem? editing}) {
    // 공지는 기숙사 공지사항과 동일한 전체 화면 작성 페이지를 쓴다
    // (이미지·PDF 첨부, 고정 공지, 알림 전송).
    final Future<dynamic> future = widget.kind == _CouncilKind.notice
        ? Navigator.push(
            context,
            FluentPageRoute(
              builder: (ctx) => WindowsCouncilNoticeCreateScreen(
                noticeId: editing?.id,
                notice: editing?.raw,
              ),
            ),
          )
        : showDialog(
            context: context,
            builder: (ctx) =>
                _CouncilDialog(kind: widget.kind, editing: editing),
          );
    future.then((_) {
      // 수정 후 상세 패널이 옛 데이터를 들고 있지 않도록 선택을 비운다.
      if (editing != null && _selected?.id == editing.id) {
        setState(() => _selected = null);
      }
    });
  }

  Future<void> _delete(_CouncilItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: Text('${widget.kind.label} 삭제'),
        content: Text('「${item.title}」을(를) 삭제하시겠습니까?'),
        actions: [
          Button(
              child: const Text('취소'),
              onPressed: () => Navigator.pop(ctx, false)),
          FilledButton(
            style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(Colors.red)),
            child: const Text('삭제'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection(widget.kind.collection)
          .doc(item.id)
          .delete();
      if (_selected?.id == item.id) {
        setState(() => _selected = null);
      }
      if (mounted) {
        displayInfoBar(context,
            builder: (ctx, close) => InfoBar(
                  title: const Text('삭제 완료'),
                  severity: InfoBarSeverity.success,
                  action: IconButton(
                      icon: const Icon(FluentIcons.clear), onPressed: close),
                ));
      }
    } catch (e) {
      if (mounted) {
        displayInfoBar(context,
            builder: (ctx, close) => InfoBar(
                  title: const Text('삭제 실패'),
                  content: Text('$e'),
                  severity: InfoBarSeverity.error,
                  action: IconButton(
                      icon: const Icon(FluentIcons.clear), onPressed: close),
                ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: Text('사생회 ${widget.kind.label}'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.add),
              label: Text('${widget.kind.label} 작성'),
              onPressed: () => _openDialog(),
            ),
          ],
        ),
      ),
      content: Row(
        children: [
          SizedBox(
            width: 340,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextBox(
                    placeholder: '제목 검색',
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(FluentIcons.search, size: 14),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  ),
                ),
                Expanded(child: _buildList()),
              ],
            ),
          ),
          const Divider(direction: Axis.vertical),
          Expanded(
            child: _selected == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(widget.kind.icon,
                            size: 56, color: Colors.grey[80]),
                        const SizedBox(height: 16),
                        Text('${widget.kind.label}을(를) 선택하세요',
                            style: TextStyle(
                                color: Colors.grey[100], fontSize: 15)),
                      ],
                    ),
                  )
                : _buildDetail(_selected!),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return StreamBuilder<List<_CouncilItem>>(
      stream: _stream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: ProgressRing());
        }
        if (snapshot.hasError) {
          return Center(child: Text('오류: ${snapshot.error}'));
        }
        final all = snapshot.data ?? [];

        // 학생이 조회·좋아요를 누를 때마다 숫자가 바뀌므로, 열어 둔 상세 화면의 숫자도 목록과 맞춰 갱신한다.
        final selected = _selected;
        if (selected != null &&
            (widget.kind == _CouncilKind.notice ||
                widget.kind == _CouncilKind.campaign)) {
          final latest = all.where((n) => n.id == selected.id).firstOrNull;
          if (latest != null &&
              (latest.viewCount != selected.viewCount ||
                  latest.likeCount != selected.likeCount)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _selected?.id == latest.id) {
                setState(() => _selected = latest);
              }
            });
          }
        }

        final filtered = _searchQuery.isEmpty
            ? all
            : all.where((n) => n.title.contains(_searchQuery)).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.kind.icon, size: 48),
                const SizedBox(height: 12),
                Text('등록된 ${widget.kind.label}이(가) 없습니다.'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final n = filtered[i];
            final isSelected = _selected?.id == n.id;
            final status = n.statusOf(widget.kind);
            return Card(
              backgroundColor: isSelected
                  ? FluentTheme.of(context).accentColor.withValues(alpha: 0.1)
                  : null,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                onPressed: () => setState(() => _selected = n),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(widget.kind.icon,
                      color: Colors.purple, size: 18),
                ),
                title: Text(
                  n.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  _subtitleOf(n),
                  style: TextStyle(fontSize: 11, color: Colors.grey[100]),
                ),
                trailing: widget.kind == _CouncilKind.notice
                    // 일반 공지 목록과 같은 형태로 조회수를 보여준다.
                    ? Text(
                        '조회 ${n.viewCount}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[80]),
                      )
                    : status == null
                        ? null
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: status.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  status.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: status.color,
                                  ),
                                ),
                              ),
                              // 캠페인은 학생 반응(조회수·좋아요)도 함께 보여준다.
                              if (widget.kind == _CouncilKind.campaign) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '조회 ${n.viewCount} · 좋아요 ${n.likeCount}',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey[80]),
                                ),
                              ],
                            ],
                          ),
              ),
            );
          },
        );
      },
    );
  }

  String _subtitleOf(_CouncilItem n) {
    if (widget.kind.hasPeriod) {
      final parts = [
        if (n.startDate != null) _dateFormat.format(n.startDate!),
        if (n.endDate != null) _dateFormat.format(n.endDate!),
      ];
      if (parts.isNotEmpty) return parts.join(' ~ ');
    }
    return '${n.authorName}  ·  ${_dateFormat.format(n.createdAt)}';
  }

  Widget _buildDetail(_CouncilItem n) {
    final status = n.statusOf(widget.kind);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (status != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: status.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border:
                        Border.all(color: status.color.withValues(alpha: 0.4)),
                  ),
                  child: Text(status.label,
                      style: TextStyle(
                          color: status.color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  n.title,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              Button(
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.edit, size: 14),
                    SizedBox(width: 6),
                    Text('수정')
                  ],
                ),
                onPressed: () => _openDialog(editing: n),
              ),
              const SizedBox(width: 8),
              Button(
                style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(
                        Colors.red.withValues(alpha: 0.1))),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.delete, size: 14, color: Colors.red),
                    const SizedBox(width: 6),
                    Text('삭제', style: TextStyle(color: Colors.red)),
                  ],
                ),
                onPressed: () => _delete(n),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${n.authorName}  ·  ${DateFormat('yyyy-MM-dd HH:mm').format(n.createdAt)}',
                style: TextStyle(fontSize: 13, color: Colors.grey[100]),
              ),
              if (widget.kind == _CouncilKind.notice ||
                  widget.kind == _CouncilKind.campaign) ...[
                const SizedBox(width: 16),
                Icon(FluentIcons.view, size: 14, color: Colors.grey[100]),
                const SizedBox(width: 6),
                Text(
                  '조회 ${n.viewCount}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[100]),
                ),
              ],
              if (widget.kind == _CouncilKind.campaign) ...[
                const SizedBox(width: 16),
                Icon(FluentIcons.heart, size: 14, color: Colors.grey[100]),
                const SizedBox(width: 6),
                Text(
                  '좋아요 ${n.likeCount}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[100]),
                ),
              ],
            ],
          ),
          if (widget.kind.hasPeriod && n.startDate != null) ...[
            const SizedBox(height: 6),
            Text(
              '기간  ${_dateFormat.format(n.startDate!)}'
              '${n.endDate != null ? ' ~ ${_dateFormat.format(n.endDate!)}' : ''}',
              style: TextStyle(fontSize: 13, color: Colors.grey[100]),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          if (widget.kind.hasCandidates && n.candidates.isNotEmpty) ...[
            _ElectionResults(electionId: n.id, candidates: n.candidates),
            const SizedBox(height: 24),
            _VoterRoll(electionId: n.id),
            const SizedBox(height: 20),
          ],
          if (n.content.isNotEmpty)
            Text(n.content,
                style: const TextStyle(fontSize: 15, height: 1.7)),
        ],
      ),
    );
  }
}

// ── 투표 결과 집계 ────────────────────────────────────────────────
/// 익명 표(ballots)를 후보별로 집계해 보여준다.
/// 표에는 작성자 정보가 없으므로 누가 누구를 뽑았는지는 알 수 없다.
class _ElectionResults extends StatelessWidget {
  final String electionId;
  final List<String> candidates;
  const _ElectionResults({required this.electionId, required this.candidates});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('council_elections')
          .doc(electionId)
          .collection('ballots')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        // 후보별 득표수를 센다. 후보 목록에 없는 값은 무시한다.
        final counts = <String, int>{for (final c in candidates) c: 0};
        for (final d in docs) {
          final data = (d.data() as Map<String, dynamic>?) ?? {};
          final c = (data['candidate'] ?? '').toString();
          if (counts.containsKey(c)) counts[c] = counts[c]! + 1;
        }
        final total = counts.values.fold<int>(0, (a, b) => a + b);
        final maxCount =
            counts.values.isEmpty ? 0 : counts.values.reduce((a, b) => a > b ? a : b);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('투표 결과',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                Text('총 $total표',
                    style: TextStyle(fontSize: 13, color: Colors.grey[100])),
              ],
            ),
            const SizedBox(height: 12),
            for (final c in candidates)
              _buildBar(context, c, counts[c] ?? 0, total, maxCount),
          ],
        );
      },
    );
  }

  Widget _buildBar(BuildContext context, String candidate, int count, int total,
      int maxCount) {
    final ratio = total == 0 ? 0.0 : count / total;
    // 최다 득표 후보를 강조한다 (동점이면 모두 강조).
    final isLeading = count > 0 && count == maxCount;
    final color = isLeading ? Colors.purple : Colors.grey;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(candidate,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isLeading ? FontWeight.bold : FontWeight.normal,
                    )),
              ),
              Text(
                '$count표  (${total == 0 ? 0 : (ratio * 100).round()}%)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isLeading ? FontWeight.bold : FontWeight.normal,
                  color: isLeading ? Colors.purple : Colors.grey[100],
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ProgressBar(
            value: ratio * 100,
            activeColor: color,
            backgroundColor: Colors.grey.withValues(alpha: 0.15),
          ),
        ],
      ),
    );
  }
}

// ── 진행 상태 ─────────────────────────────────────────────────────
class _Status {
  final String label;
  final Color color;
  const _Status(this.label, this.color);
}

// ── 데이터 모델 ───────────────────────────────────────────────────
class _CouncilItem {
  final String id;
  final String title;
  final String content;
  final String authorName;
  final DateTime createdAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> candidates;
  /// 후보 이름 -> 유튜브 링크. 없는 후보는 키가 없을 수 있다.
  final Map<String, String> candidateProfiles;
  /// 후보 이름 -> 소개글
  final Map<String, String> candidateIntros;
  /// 후보 이름 -> 선거 포스터 PDF. 포스터가 없는 후보는 키가 없다.
  final Map<String, _CandidatePdf> candidatePdfs;
  /// 조회수. 공지·캠페인만 학생앱에서 계정당 1회씩 집계한다 (viewCount/viewedUsers).
  final int viewCount;
  /// 좋아요 수. 캠페인만 학생앱에서 집계한다 (likes/likeCount).
  final int likeCount;
  /// 원본 문서 데이터 (공지 수정 화면에 그대로 넘긴다)
  final Map<String, dynamic> raw;

  _CouncilItem({
    required this.id,
    required this.title,
    required this.content,
    required this.authorName,
    required this.createdAt,
    this.startDate,
    this.endDate,
    this.candidates = const [],
    this.candidateProfiles = const {},
    this.candidateIntros = const {},
    this.candidatePdfs = const {},
    this.viewCount = 0,
    this.likeCount = 0,
    this.raw = const {},
  });

  factory _CouncilItem.fromDoc(DocumentSnapshot doc) {
    // 빈 문서는 data() 가 null 을 반환할 수 있다.
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return _CouncilItem(
      id: doc.id,
      title: (data['title'] ?? '').toString(),
      content: (data['content'] ?? '').toString(),
      authorName: (data['authorName'] ?? '관리자').toString(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      candidates: (data['candidates'] as List?)
              ?.map((c) => c.toString())
              .where((c) => c.isNotEmpty)
              .toList() ??
          const [],
      candidateProfiles:
          (data['candidateProfiles'] as Map?)?.map(
                (k, v) => MapEntry(k.toString(), v.toString()),
              ) ??
              const {},
      candidateIntros: (data['candidateIntros'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ) ??
          const {},
      candidatePdfs: (data['candidatePdfs'] as Map?)?.map(
            (k, v) {
              final m = (v as Map?) ?? const {};
              return MapEntry(
                k.toString(),
                _CandidatePdf(
                  url: (m['url'] ?? '').toString(),
                  name: (m['name'] ?? '').toString(),
                ),
              );
            },
          ) ??
          const {},
      viewCount: (data['viewCount'] as num?)?.toInt() ?? 0,
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      raw: data,
    );
  }

  /// 기간을 가진 항목(캠페인/선거)만 진행 상태를 갖는다.
  /// 학생앱의 색상·판정 기준과 동일하게 맞춘다.
  _Status? statusOf(_CouncilKind kind) {
    if (!kind.hasPeriod) return null;
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) {
      return const _Status('예정', Color(0xFFFF9800));
    }
    if (endDate != null) {
      final e = endDate!;
      // 선거는 종료일 오후 8시 마감, 캠페인은 종료일 자정까지로 본다.
      final close = kind == _CouncilKind.election
          ? DateTime(e.year, e.month, e.day, 20, 0, 0)
          : DateTime(e.year, e.month, e.day, 23, 59, 59);
      if (now.isAfter(close)) {
        return const _Status('종료', Color(0xFF757575));
      }
    }
    return const _Status('진행중', Color(0xFF009688));
  }
}

// ── 작성/수정 다이얼로그 ──────────────────────────────────────────
class _CouncilDialog extends StatefulWidget {
  final _CouncilKind kind;
  final _CouncilItem? editing;
  const _CouncilDialog({required this.kind, this.editing});

  @override
  State<_CouncilDialog> createState() => _CouncilDialogState();
}

class _CouncilDialogState extends State<_CouncilDialog> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  /// 후보 입력 행 (이름 / 유튜브 링크 / 포스터 PDF)
  final List<_CandidateRow> _candidateRows = [];
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  final _auth = AuthService();
  final _storage = StorageService();

  // 캠페인 홍보물 첨부 (공지 작성 화면과 동일한 스키마: imageUrls / pdfUrl / pdfFileName)
  final List<File> _selectedImages = []; // 새로 추가할 이미지 파일
  List<String> _existingImageUrls = []; // 기존 이미지 URL (수정 모드)
  File? _selectedPdf; // 새로 선택한 PDF 파일
  String? _selectedPdfName;
  String? _existingPdfUrl; // 기존 PDF URL (수정 모드)
  String? _existingPdfFileName; // 기존 PDF 파일명 (수정 모드)

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _titleCtrl.text = e.title;
      _contentCtrl.text = e.content;
      for (final c in e.candidates) {
        _candidateRows.add(_CandidateRow(
          name: c,
          intro: e.candidateIntros[c] ?? '',
          videoUrl: e.candidateProfiles[c] ?? '',
          pdfUrl: e.candidatePdfs[c]?.url ?? '',
          pdfName: e.candidatePdfs[c]?.name ?? '',
        ));
      }
      _startDate = e.startDate;
      _endDate = e.endDate;
      _existingImageUrls = (e.raw['imageUrls'] as List?)
              ?.map((v) => v.toString())
              .where((v) => v.isNotEmpty)
              .toList() ??
          [];
      final pdfUrl = (e.raw['pdfUrl'] ?? '').toString();
      if (pdfUrl.isNotEmpty) {
        _existingPdfUrl = pdfUrl;
        _existingPdfFileName = (e.raw['pdfFileName'] ?? '').toString();
      }
    }
    // 선거는 입력할 행이 최소 하나는 보이도록 한다.
    if (widget.kind.hasCandidates && _candidateRows.isEmpty) {
      _addCandidateRow();
    }
  }

  /// 투표권이 있는 학생 수를 센다 (선거인 명부와 동일한 기준).
  Future<int> _countEligibleVoters() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'student')
        .get();
    var count = 0;
    for (final d in snap.docs) {
      final data = (d.data() as Map<String, dynamic>?) ?? {};
      final dorm = (data['dormBuilding'] ?? '').toString();
      final room = (data['roomNumber'] ?? '').toString();
      final status = (data['residentStatus'] ?? '').toString();
      if (dorm.isEmpty || dorm.contains('방학')) continue;
      if (_kMoveOutStatuses.contains(status)) continue;
      if (room.isEmpty || room == '000') continue;
      count++;
    }
    return count;
  }

  /// 후보 한 명의 포스터 PDF 를 고른다.
  Future<void> _pickPdf(_CandidateRow row) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() {
      row.pendingPdf = File(path);
      row.pdfName = result!.files.single.name;
    });
  }

  void _addCandidateRow() {
    _candidateRows.add(_CandidateRow());
  }

  /// 캠페인 홍보 이미지를 여러 장 고른다.
  Future<void> _pickCampaignImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) return;
    setState(() {
      for (final file in result.files) {
        if (file.path != null) _selectedImages.add(File(file.path!));
      }
    });
  }

  /// 캠페인 홍보 PDF 를 고른다.
  Future<void> _pickCampaignPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    setState(() {
      _selectedPdf = File(path);
      _selectedPdfName = result!.files.single.name;
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    for (final row in _candidateRows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    // 처리 중 재진입(중복 등록) 방지
    if (_isLoading) return;
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty) {
      displayInfoBar(context,
          builder: (ctx, close) => InfoBar(
                title: const Text('입력 오류'),
                content: const Text('제목을 입력해주세요.'),
                severity: InfoBarSeverity.warning,
                action: IconButton(
                    icon: const Icon(FluentIcons.clear), onPressed: close),
              ));
      return;
    }
    if (widget.kind.hasPeriod &&
        _startDate != null &&
        _endDate != null &&
        _endDate!.isBefore(_startDate!)) {
      displayInfoBar(context,
          builder: (ctx, close) => InfoBar(
                title: const Text('입력 오류'),
                content: const Text('종료일이 시작일보다 빠릅니다.'),
                severity: InfoBarSeverity.warning,
                action: IconButton(
                    icon: const Icon(FluentIcons.clear), onPressed: close),
              ));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      final data = <String, dynamic>{
        'title': title,
        'content': content,
        'authorId': user?.uid ?? '',
        'authorName': user?.email?.split('@').first ?? '관리자',
      };

      if (widget.kind.hasPeriod) {
        data['startDate'] =
            _startDate == null ? null : Timestamp.fromDate(_startDate!);
        data['endDate'] =
            _endDate == null ? null : Timestamp.fromDate(_endDate!);
      }
      if (widget.kind.hasCandidates) {
        final names = <String>[];
        final profiles = <String, String>{};
        final intros = <String, String>{};
        final pdfs = <String, dynamic>{};
        for (final row in _candidateRows) {
          final name = row.nameCtrl.text.trim();
          if (name.isEmpty) continue;
          names.add(name);

          final video = row.videoCtrl.text.trim();
          if (video.isNotEmpty) profiles[name] = video;

          final intro = row.introCtrl.text.trim();
          if (intro.isNotEmpty) intros[name] = intro;

          // 새로 고른 포스터가 있으면 업로드해 URL 을 교체한다.
          if (row.pendingPdf != null) {
            final fileName = 'council_${DateTime.now().millisecondsSinceEpoch}'
                '_${names.length}_${row.pdfName}';
            row.pdfUrl =
                await _storage.uploadNoticePdf(row.pendingPdf!, fileName);
            row.pendingPdf = null;
          }
          if (row.pdfUrl.isNotEmpty) {
            pdfs[name] = {'url': row.pdfUrl, 'name': row.pdfName};
          }
        }
        data['candidates'] = names;
        data['candidateProfiles'] = profiles;
        data['candidateIntros'] = intros;
        data['candidatePdfs'] = pdfs;

        // 학생앱 투표율 표시용 선거인 수. 명부와 같은 기준으로 센다.
        data['eligibleCount'] = await _countEligibleVoters();
      }
      if (widget.kind.hasAttachments) {
        final docPrefix = 'council_campaign_${DateTime.now().millisecondsSinceEpoch}';

        // 새 이미지 업로드
        final imageUrls = List<String>.from(_existingImageUrls);
        for (int i = 0; i < _selectedImages.length; i++) {
          final fileName = '${docPrefix}_img_$i.jpg';
          imageUrls.add(
              await _storage.uploadNoticeImage(_selectedImages[i], fileName));
        }
        data['imageUrls'] = imageUrls;

        // PDF 처리
        String? pdfUrl = _existingPdfUrl;
        String? pdfFileName = _existingPdfFileName;
        if (_selectedPdf != null && _selectedPdfName != null) {
          pdfUrl = await _storage.uploadNoticePdf(
              _selectedPdf!, '${docPrefix}_$_selectedPdfName');
          pdfFileName = _selectedPdfName;
        }
        data['pdfUrl'] = pdfUrl;
        data['pdfFileName'] = pdfFileName;
      }

      final col =
          FirebaseFirestore.instance.collection(widget.kind.collection);
      if (widget.editing != null) {
        await col.doc(widget.editing!.id).update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await col.add(data);
      }

      if (!mounted) return;
      Navigator.pop(context);
      displayInfoBar(context,
          builder: (ctx, close) => InfoBar(
                title: Text(widget.editing != null ? '수정 완료' : '등록 완료'),
                severity: InfoBarSeverity.success,
                action: IconButton(
                    icon: const Icon(FluentIcons.clear), onPressed: close),
              ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      displayInfoBar(context,
          builder: (ctx, close) => InfoBar(
                title: const Text('저장 실패'),
                content: Text('$e'),
                severity: InfoBarSeverity.error,
                action: IconButton(
                    icon: const Icon(FluentIcons.clear), onPressed: close),
              ));
    }
  }

  /// 후보 한 명의 입력 행 (이름 / 유튜브 링크 / 포스터 PDF)
  Widget _buildCandidateRow(int i) {
    final row = _candidateRows[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 120,
                child: TextBox(
                  controller: row.nameCtrl,
                  placeholder: '이름',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextBox(
                  controller: row.videoCtrl,
                  placeholder: '유튜브 링크 (연설·공약 영상)',
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(FluentIcons.delete, size: 14),
                onPressed: _candidateRows.length <= 1
                    ? null
                    : () => setState(() {
                          _candidateRows.removeAt(i).dispose();
                        }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextBox(
            controller: row.introCtrl,
            placeholder: '후보 소개 (선택)',
            maxLines: 4,
            minLines: 2,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Button(
                onPressed: () => _pickPdf(row),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.pdf, size: 14),
                    SizedBox(width: 6),
                    Text('선거 포스터'),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  row.pdfName.isEmpty ? '선택된 파일 없음' : row.pdfName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: row.pdfName.isEmpty ? Colors.grey[100] : null,
                  ),
                ),
              ),
              if (row.pdfName.isNotEmpty)
                IconButton(
                  icon: const Icon(FluentIcons.clear, size: 12),
                  onPressed: () => setState(() {
                    row.pendingPdf = null;
                    row.pdfUrl = '';
                    row.pdfName = '';
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 캠페인 홍보물 첨부 섹션 (이미지 여러 장 + PDF 1개)
  Widget _buildAttachmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Button(
              onPressed: _isLoading ? null : _pickCampaignImages,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.photo2, size: 14),
                  SizedBox(width: 6),
                  Text('이미지 추가'),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Button(
              onPressed: _isLoading ? null : _pickCampaignPdf,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.pdf, size: 14),
                  SizedBox(width: 6),
                  Text('PDF 추가'),
                ],
              ),
            ),
          ],
        ),
        if (_existingImageUrls.isNotEmpty || _selectedImages.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ..._existingImageUrls.asMap().entries.map((entry) =>
                  _buildAttachmentThumb(
                    image: NetworkImage(entry.value),
                    onRemove: () => setState(
                        () => _existingImageUrls.removeAt(entry.key)),
                  )),
              ..._selectedImages.asMap().entries.map((entry) =>
                  _buildAttachmentThumb(
                    image: FileImage(entry.value),
                    onRemove: () =>
                        setState(() => _selectedImages.removeAt(entry.key)),
                  )),
            ],
          ),
        ],
        if (_existingPdfUrl != null && _selectedPdf == null) ...[
          const SizedBox(height: 10),
          _buildAttachmentPdfRow(
            _existingPdfFileName?.isNotEmpty == true
                ? _existingPdfFileName!
                : 'PDF 첨부됨',
            onRemove: () => setState(() {
              _existingPdfUrl = null;
              _existingPdfFileName = null;
            }),
          ),
        ],
        if (_selectedPdf != null) ...[
          const SizedBox(height: 10),
          _buildAttachmentPdfRow(
            _selectedPdfName ?? 'PDF',
            onRemove: () => setState(() {
              _selectedPdf = null;
              _selectedPdfName = null;
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildAttachmentThumb(
      {required ImageProvider image, required VoidCallback onRemove}) {
    return Stack(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[60], width: 1),
            image: DecorationImage(image: image, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(3),
              decoration:
                  BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child:
                  const Icon(FluentIcons.clear, size: 10, color: Colors.white),
            ),
            onPressed: _isLoading ? null : onRemove,
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentPdfRow(String fileName,
      {required VoidCallback onRemove}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[60], width: 1),
      ),
      child: Row(
        children: [
          Icon(FluentIcons.pdf, size: 16, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(fileName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
          ),
          IconButton(
            icon: const Icon(FluentIcons.clear, size: 11),
            onPressed: _isLoading ? null : onRemove,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 620),
      title: Text(
          '사생회 ${kind.label} ${widget.editing != null ? '수정' : '작성'}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            InfoLabel(
              label: '제목',
              child: TextBox(
                controller: _titleCtrl,
                placeholder: '제목을 입력하세요',
              ),
            ),
            const SizedBox(height: 14),
            if (kind.hasPeriod) ...[
              Row(
                children: [
                  Expanded(
                    child: InfoLabel(
                      label: '시작일',
                      child: DatePicker(
                        selected: _startDate,
                        onChanged: (d) => setState(() => _startDate = d),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InfoLabel(
                      label: '종료일',
                      child: DatePicker(
                        selected: _endDate,
                        onChanged: (d) => setState(() => _endDate = d),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            if (kind.hasCandidates) ...[
              InfoLabel(
                label: '후보',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < _candidateRows.length; i++)
                      _buildCandidateRow(i),
                    Button(
                      onPressed: () => setState(_addCandidateRow),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(FluentIcons.add, size: 12),
                          SizedBox(width: 6),
                          Text('후보 추가'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (kind.hasAttachments) ...[
              InfoLabel(
                label: '첨부 파일',
                child: _buildAttachmentsSection(),
              ),
              const SizedBox(height: 14),
            ],
            InfoLabel(
              label: '내용',
              child: TextBox(
                controller: _contentCtrl,
                placeholder: '내용을 입력하세요',
                maxLines: 10,
                minLines: 6,
              ),
            ),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 16, height: 16, child: ProgressRing(strokeWidth: 2))
              : Text(widget.editing != null ? '수정' : '등록'),
        ),
      ],
    );
  }
}

// ── 후보 입력 행 ──────────────────────────────────────────────────
/// 다이얼로그에서 후보 한 명의 입력 상태(이름/영상/포스터)를 담는다.
class _CandidateRow {
  final TextEditingController nameCtrl;
  final TextEditingController introCtrl;
  final TextEditingController videoCtrl;

  /// 아직 업로드하지 않은 새 PDF. 저장 시 업로드 후 null 로 되돌린다.
  File? pendingPdf;
  String pdfUrl;
  String pdfName;

  _CandidateRow({
    String name = '',
    String intro = '',
    String videoUrl = '',
    this.pdfUrl = '',
    this.pdfName = '',
  })  : nameCtrl = TextEditingController(text: name),
        introCtrl = TextEditingController(text: intro),
        videoCtrl = TextEditingController(text: videoUrl);

  void dispose() {
    nameCtrl.dispose();
    introCtrl.dispose();
    videoCtrl.dispose();
  }
}

/// 후보별 선거 포스터 PDF 정보
class _CandidatePdf {
  final String url;
  final String name;
  const _CandidatePdf({required this.url, required this.name});
}

// ── 선거인 명부 ───────────────────────────────────────────────────
/// 퇴사 계열 재실상태. 이 상태의 학생은 투표권이 없다.
/// ('퇴사'는 세분화 전 레거시 데이터에 남아있을 수 있어 함께 인식한다)
const _kMoveOutStatuses = {
  '퇴사',
  '만기퇴사',
  '자진퇴사',
  '강제퇴사',
  '영구퇴사',
};

/// 학생 전체를 명부로 보여주고, 각자의 투표 여부와 투표 시각을 표시한다.
///
/// voters 문서에는 선택한 후보가 담겨 있지 않으므로,
/// 명부를 봐도 누가 누구를 뽑았는지는 알 수 없다(비밀투표 유지).
class _VoterRoll extends StatefulWidget {
  final String electionId;
  const _VoterRoll({required this.electionId});

  @override
  State<_VoterRoll> createState() => _VoterRollState();
}

class _VoterRollState extends State<_VoterRoll> {
  final _dateFormat = DateFormat('yyyy.MM.dd HH:mm');

  /// uid -> 학생 정보
  Map<String, _Voter> _students = {};
  bool _isLoading = true;
  String _search = '';

  /// 0 = 전체, 1 = 투표함, 2 = 미투표
  int _filter = 0;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();
      final map = <String, _Voter>{};
      for (final d in snap.docs) {
        final data = (d.data() as Map<String, dynamic>?) ?? {};
        final dorm = (data['dormBuilding'] ?? '').toString();
        final room = (data['roomNumber'] ?? '').toString();
        final status = (data['residentStatus'] ?? '').toString();

        // 투표권은 학기중 사생에게만 있다.
        // 방학 구역, 퇴사자, 호실 미배정(000호)은 명부에서 제외한다.
        if (dorm.isEmpty || dorm.contains('방학')) continue;
        if (_kMoveOutStatuses.contains(status)) continue;
        if (room.isEmpty || room == '000') continue;

        map[d.id] = _Voter(
          uid: d.id,
          name: (data['name'] ?? '').toString(),
          studentId: (data['studentId'] ?? '').toString(),
          dormBuilding: dorm,
          roomNumber: room,
        );
      }
      if (!mounted) return;
      setState(() {
        _students = map;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportToExcel(List<_Voter> rows) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel[excel.getDefaultSheet()!];
      sheet.appendRow([
        TextCellValue('학번'),
        TextCellValue('성명'),
        TextCellValue('호실'),
        TextCellValue('투표 여부'),
        TextCellValue('투표 시각'),
      ]);
      for (final v in rows) {
        sheet.appendRow([
          TextCellValue(v.studentId),
          TextCellValue(v.name),
          TextCellValue(v.room),
          TextCellValue(v.votedAt != null ? '투표함' : '미투표'),
          TextCellValue(
              v.votedAt != null ? _dateFormat.format(v.votedAt!) : ''),
        ]);
      }
      final bytes = excel.encode();
      if (bytes == null) throw Exception('엑셀 파일 생성 실패');

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: '선거인 명부 저장',
        fileName: '선거인명부.xlsx',
        allowedExtensions: ['xlsx'],
        type: FileType.custom,
      );
      if (savePath == null) return;
      await File(savePath).writeAsBytes(bytes);

      if (!mounted) return;
      displayInfoBar(context,
          builder: (ctx, close) => InfoBar(
                title: const Text('저장 완료'),
                severity: InfoBarSeverity.success,
                action: IconButton(
                    icon: const Icon(FluentIcons.clear), onPressed: close),
              ));
    } catch (e) {
      if (!mounted) return;
      displayInfoBar(context,
          builder: (ctx, close) => InfoBar(
                title: const Text('저장 실패'),
                content: Text('$e'),
                severity: InfoBarSeverity.error,
                action: IconButton(
                    icon: const Icon(FluentIcons.clear), onPressed: close),
              ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: Padding(padding: EdgeInsets.all(20), child: ProgressRing()));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('council_elections')
          .doc(widget.electionId)
          .collection('voters')
          .snapshots(),
      builder: (context, snapshot) {
        // uid -> 투표 시각
        final votedAt = <String, DateTime?>{};
        for (final d in snapshot.data?.docs ?? []) {
          final data = (d.data() as Map<String, dynamic>?) ?? {};
          votedAt[d.id] = (data['votedAt'] as Timestamp?)?.toDate();
        }

        // 명부 = 학생 전체 + 투표 정보
        final all = _students.values
            .map((v) => v.copyWith(
                  hasVoted: votedAt.containsKey(v.uid),
                  votedAt: votedAt[v.uid],
                ))
            .toList()
          // 건물 -> 호실 -> 이름 순으로 정렬한다.
          ..sort((a, b) {
            final byBuilding = a.buildingRank.compareTo(b.buildingRank);
            if (byBuilding != 0) return byBuilding;
            final byRoom = a.roomSortKey.compareTo(b.roomSortKey);
            if (byRoom != 0) return byRoom;
            return a.name.compareTo(b.name);
          });

        final votedCount = all.where((v) => v.hasVoted).length;
        final rate = all.isEmpty ? 0.0 : votedCount / all.length;

        // 필터 + 검색 적용
        var rows = switch (_filter) {
          1 => all.where((v) => v.hasVoted).toList(),
          2 => all.where((v) => !v.hasVoted).toList(),
          _ => all,
        };
        if (_search.isNotEmpty) {
          rows = rows
              .where((v) =>
                  v.name.contains(_search) ||
                  v.studentId.contains(_search) ||
                  v.room.contains(_search))
              .toList();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('선거인 명부',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                Tooltip(
                  message: '학기중 사생만 투표권이 있습니다.\n'
                      '방학 구역·퇴사자·호실 미배정은 제외됩니다.',
                  child: Icon(FluentIcons.info,
                      size: 12, color: Colors.grey[100]),
                ),
                const SizedBox(width: 10),
                Text(
                  '$votedCount / ${all.length}명  (투표율 ${(rate * 100).toStringAsFixed(1)}%)',
                  style: TextStyle(fontSize: 13, color: Colors.grey[100]),
                ),
                const Spacer(),
                Button(
                  onPressed: rows.isEmpty ? null : () => _exportToExcel(rows),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.excel_document, size: 13),
                      SizedBox(width: 6),
                      Text('엑셀 다운로드', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildFilterChip('전체', 0, all.length),
                const SizedBox(width: 6),
                _buildFilterChip('투표함', 1, votedCount),
                const SizedBox(width: 6),
                _buildFilterChip('미투표', 2, all.length - votedCount),
                const SizedBox(width: 12),
                SizedBox(
                  width: 220,
                  child: TextBox(
                    placeholder: '이름, 학번, 호실 검색',
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(FluentIcons.search, size: 13),
                    ),
                    onChanged: (v) => setState(() => _search = v.trim()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 표 머리글
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6)),
              ),
              child: Row(
                children: const [
                  SizedBox(
                      width: 40,
                      child: Text('번호',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold))),
                  SizedBox(
                      width: 110,
                      child: Text('학번',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold))),
                  SizedBox(
                      width: 90,
                      child: Text('성명',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold))),
                  Expanded(
                      child: Text('호실',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold))),
                  SizedBox(
                      width: 70,
                      child: Text('투표 여부',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold))),
                  SizedBox(
                      width: 130,
                      child: Text('투표 시각',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            if (rows.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 30),
                alignment: Alignment.center,
                child: Text('해당하는 학생이 없습니다.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[100])),
              )
            else
              // 상세 패널이 스크롤되므로 명부는 높이를 제한해 자체 스크롤한다.
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: rows.length,
                  itemBuilder: (context, i) => _buildRow(rows[i], i),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String label, int index, int count) {
    final isSelected = _filter == index;
    final accent = FluentTheme.of(context).accentColor;
    return GestureDetector(
      onTap: () => setState(() => _filter = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.12) : null,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected
                ? accent
                : FluentTheme.of(context).resources.dividerStrokeColorDefault,
          ),
        ),
        child: Text(
          '$label $count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? accent : null,
          ),
        ),
      ),
    );
  }

  Widget _buildRow(_Voter v, int i) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: i.isOdd ? Colors.grey.withValues(alpha: 0.03) : null,
        border: Border(
          bottom: BorderSide(
            color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
              width: 40,
              child: Text('${i + 1}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[100]))),
          SizedBox(
              width: 110,
              child: Text(v.studentId, style: const TextStyle(fontSize: 12))),
          SizedBox(
              width: 90,
              child: Text(v.name, style: const TextStyle(fontSize: 12))),
          Expanded(
              child: Text(v.room,
                  style: TextStyle(fontSize: 12, color: Colors.grey[100]))),
          SizedBox(
            width: 70,
            child: v.hasVoted
                ? Row(
                    children: [
                      Icon(FluentIcons.completed,
                          size: 12, color: Colors.green),
                      const SizedBox(width: 4),
                      Text('투표함',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.w600)),
                    ],
                  )
                : Text('미투표',
                    style: TextStyle(fontSize: 12, color: Colors.grey[100])),
          ),
          SizedBox(
            width: 130,
            child: Text(
              v.votedAt != null ? _dateFormat.format(v.votedAt!) : '-',
              style: TextStyle(fontSize: 12, color: Colors.grey[100]),
            ),
          ),
        ],
      ),
    );
  }
}

/// 선거인 명부 한 줄
class _Voter {
  final String uid;
  final String name;
  final String studentId;
  final String dormBuilding;
  final String roomNumber;
  final bool hasVoted;
  final DateTime? votedAt;

  const _Voter({
    required this.uid,
    required this.name,
    required this.studentId,
    required this.dormBuilding,
    required this.roomNumber,
    this.hasVoted = false,
    this.votedAt,
  });

  String get room =>
      [dormBuilding, if (roomNumber.isNotEmpty) '$roomNumber호']
          .where((e) => e.isNotEmpty)
          .join(' ');

  /// 건물 정렬 순서 (샬롬하우스 -> 국제생활관 -> 바롬인성교육관 -> 기타)
  int get buildingRank {
    if (dormBuilding.startsWith('샬롬하우스')) return 0;
    if (dormBuilding.startsWith('국제생활관')) return 1;
    if (dormBuilding.startsWith('바롬인성교육관')) return 2;
    return 3;
  }

  /// 호실 정렬 키. 숫자로 비교해 '109호'가 '1001-B호'보다 앞에 오도록 한다.
  /// 숫자로 못 읽으면 맨 뒤로 보낸다.
  int get roomSortKey {
    final digits = RegExp(r'^\d+').firstMatch(roomNumber)?.group(0);
    return int.tryParse(digits ?? '') ?? 999999;
  }

  _Voter copyWith({bool? hasVoted, DateTime? votedAt}) => _Voter(
        uid: uid,
        name: name,
        studentId: studentId,
        dormBuilding: dormBuilding,
        roomNumber: roomNumber,
        hasVoted: hasVoted ?? this.hasVoted,
        votedAt: votedAt ?? this.votedAt,
      );
}
