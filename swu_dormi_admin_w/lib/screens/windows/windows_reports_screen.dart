import 'package:flutter/material.dart' hide Colors, FilledButton, IconButton, Card, ListTile, showDialog, Divider, Checkbox, Tooltip, ButtonStyle;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class WindowsReportsScreen extends StatefulWidget {
  const WindowsReportsScreen({super.key});

  @override
  State<WindowsReportsScreen> createState() => _WindowsReportsScreenState();
}

class _WindowsReportsScreenState extends State<WindowsReportsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _dateFormat = DateFormat('yyyy.MM.dd HH:mm');

  String _filterStatus = '전체';
  String _filterType = '전체';
  _ReportItem? _selected;

  static const _statusOptions = ['전체', 'pending', 'reviewed', 'deleted'];
  static const _typeOptions = ['전체', 'post', 'comment'];

  static const _statusLabel = {
    'pending': '검토 대기',
    'reviewed': '검토 완료',
    'deleted': '삭제됨',
  };

  static const _typeLabel = {
    'post': '게시글',
    'comment': '댓글',
  };

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'reviewed':
        return Colors.blue;
      case 'deleted':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Stream<QuerySnapshot> _buildStream() {
    Query q = _firestore.collection('reports').orderBy('createdAt', descending: true);
    return q.snapshots();
  }

  Future<Map<String, String>> _fetchTargetContent(String targetId, String targetType) async {
    try {
      final col = targetType == 'post' ? 'board_posts' : 'board_comments';
      final doc = await _firestore.collection(col).doc(targetId).get();
      if (!doc.exists) return {'content': '[삭제된 콘텐츠]', 'author': ''};
      final data = doc.data() as Map<String, dynamic>;
      final content = targetType == 'post'
          ? '[${data['title'] ?? ''}]\n${data['content'] ?? ''}'
          : data['content'] as String? ?? '';
      final authorId = data['authorId'] as String? ?? '';
      String authorName = data['authorName'] as String? ?? '';
      if (authorName.isEmpty && authorId.isNotEmpty) {
        final userDoc = await _firestore.collection('users').doc(authorId).get();
        if (userDoc.exists) {
          final ud = userDoc.data() as Map<String, dynamic>;
          authorName = ud['nickname'] as String? ?? ud['name'] as String? ?? '';
        }
      }
      return {'content': content, 'author': authorName};
    } catch (_) {
      return {'content': '[불러오기 실패]', 'author': ''};
    }
  }

  Future<String> _fetchReporterName(String reporterId) async {
    try {
      final doc = await _firestore.collection('users').doc(reporterId).get();
      if (!doc.exists) return reporterId;
      final data = doc.data() as Map<String, dynamic>;
      return data['name'] as String? ?? reporterId;
    } catch (_) {
      return reporterId;
    }
  }

  Future<void> _updateStatus(String reportId, String status) async {
    await _firestore.collection('reports').doc(reportId).update({
      'status': status,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteContent(_ReportItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('콘텐츠 삭제'),
        content: Text(
          '이 ${_typeLabel[item.targetType] ?? '콘텐츠'}를 삭제하시겠습니까?\n삭제 후 복구할 수 없습니다.',
        ),
        actions: [
          Button(
            child: const Text('취소'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.red),
            ),
            child: const Text('삭제'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final col = item.targetType == 'post' ? 'board_posts' : 'board_comments';
      await _firestore.collection(col).doc(item.targetId).delete();

      // 게시글 삭제 시 댓글도 삭제
      if (item.targetType == 'post') {
        final comments = await _firestore
            .collection('board_comments')
            .where('postId', isEqualTo: item.targetId)
            .get();
        for (final c in comments.docs) {
          await c.reference.delete();
        }
      }

      // 신고 상태를 deleted로
      await _firestore.collection('reports').doc(item.id).update({
        'status': 'deleted',
        'reviewedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _selected = null);
        await showDialog(
          context: context,
          builder: (ctx) => ContentDialog(
            title: const Text('삭제 완료'),
            content: const Text('콘텐츠가 삭제되었습니다.'),
            actions: [
              FilledButton(
                child: const Text('확인'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => ContentDialog(
            title: const Text('오류'),
            content: Text('삭제 실패: $e'),
            actions: [
              Button(child: const Text('확인'), onPressed: () => Navigator.pop(ctx)),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: const Text('신고 관리'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.filter),
              label: const Text('상태'),
              onPressed: null,
            ),
          ],
        ),
      ),
      content: Column(
        children: [
          // 필터 바
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Row(
              children: [
                const Text('상태: ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                ..._statusOptions.map((s) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ToggleButton(
                        checked: _filterStatus == s,
                        onChanged: (_) => setState(() {
                          _filterStatus = s;
                          _selected = null;
                        }),
                        child: Text(s == '전체' ? '전체' : (_statusLabel[s] ?? s)),
                      ),
                    )),
                const SizedBox(width: 24),
                const Text('유형: ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                ..._typeOptions.map((t) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ToggleButton(
                        checked: _filterType == t,
                        onChanged: (_) => setState(() {
                          _filterType = t;
                          _selected = null;
                        }),
                        child: Text(t == '전체' ? '전체' : (_typeLabel[t] ?? t)),
                      ),
                    )),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: ProgressRing());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('오류: ${snapshot.error}'));
                }

                var docs = snapshot.data?.docs ?? [];

                // 클라이언트 필터
                if (_filterStatus != '전체') {
                  docs = docs.where((d) => (d.data() as Map)['status'] == _filterStatus).toList();
                }
                if (_filterType != '전체') {
                  docs = docs.where((d) => (d.data() as Map)['targetType'] == _filterType).toList();
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(FluentIcons.flag, size: 48, color: Colors.grey[80]),
                        const SizedBox(height: 16),
                        const Text('신고 내역이 없습니다', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  );
                }

                final items = docs.map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return _ReportItem(
                    id: d.id,
                    reporterId: data['reporterId'] as String? ?? '',
                    targetId: data['targetId'] as String? ?? '',
                    targetType: data['targetType'] as String? ?? '',
                    targetAuthorId: data['targetAuthorId'] as String? ?? '',
                    reason: data['reason'] as String? ?? '',
                    detail: data['detail'] as String? ?? '',
                    status: data['status'] as String? ?? 'pending',
                    createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
                    reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
                  );
                }).toList();

                // 24시간 경과 pending 건수
                final urgentCount = items.where((r) {
                  if (r.status != 'pending' || r.createdAt == null) return false;
                  return DateTime.now().difference(r.createdAt!).inHours >= 24;
                }).length;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 목록 패널
                    SizedBox(
                      width: 420,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (urgentCount > 0)
                            Container(
                              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  Icon(FluentIcons.warning, color: Colors.red, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '24시간 초과 미검토 신고 $urgentCount건',
                                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: items.length,
                              itemBuilder: (ctx, i) {
                                final item = items[i];
                                final isSelected = _selected?.id == item.id;
                                final isOverdue = item.status == 'pending' &&
                                    item.createdAt != null &&
                                    DateTime.now().difference(item.createdAt!).inHours >= 24;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: GestureDetector(
                                    onTap: () => setState(() => _selected = item),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.blue.withValues(alpha: 0.12)
                                            : Colors.grey.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.blue
                                              : isOverdue
                                                  ? Colors.red.withValues(alpha: 0.5)
                                                  : Colors.grey.withValues(alpha: 0.2),
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: _statusColor(item.status).withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: _statusColor(item.status).withValues(alpha: 0.5)),
                                                ),
                                                child: Text(
                                                  _statusLabel[item.status] ?? item.status,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: _statusColor(item.status),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  _typeLabel[item.targetType] ?? item.targetType,
                                                  style: const TextStyle(fontSize: 11),
                                                ),
                                              ),
                                              const Spacer(),
                                              if (isOverdue)
                                                Row(
                                                  children: [
                                                    Icon(FluentIcons.warning, size: 12, color: Colors.red),
                                                    const SizedBox(width: 4),
                                                    Text('24h 초과',
                                                        style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                                                  ],
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '신고 사유: ${item.reason}',
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                          ),
                                          if (item.detail.isNotEmpty)
                                            Text(
                                              item.detail,
                                              style: TextStyle(fontSize: 12, color: Colors.grey[100]),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          const SizedBox(height: 6),
                                          Text(
                                            item.createdAt != null
                                                ? _dateFormat.format(item.createdAt!)
                                                : '',
                                            style: TextStyle(fontSize: 11, color: Colors.grey[80]),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 구분선
                    Container(width: 1, color: Colors.grey.withValues(alpha: 0.2)),
                    // 상세 패널
                    Expanded(
                      child: _selected == null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(FluentIcons.flag, size: 48, color: Colors.grey[80]),
                                  const SizedBox(height: 16),
                                  const Text('신고 항목을 선택하세요', style: TextStyle(fontSize: 15)),
                                ],
                              ),
                            )
                          : _ReportDetailPanel(
                              key: ValueKey(_selected!.id),
                              item: _selected!,
                              dateFormat: _dateFormat,
                              statusLabel: _statusLabel,
                              statusColor: _statusColor,
                              typeLabel: _typeLabel,
                              onFetchContent: _fetchTargetContent,
                              onFetchReporter: _fetchReporterName,
                              onUpdateStatus: _updateStatus,
                              onDelete: _deleteContent,
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── 데이터 클래스 ──
class _ReportItem {
  final String id;
  final String reporterId;
  final String targetId;
  final String targetType;
  final String targetAuthorId;
  final String reason;
  final String detail;
  final String status;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  const _ReportItem({
    required this.id,
    required this.reporterId,
    required this.targetId,
    required this.targetType,
    required this.targetAuthorId,
    required this.reason,
    required this.detail,
    required this.status,
    this.createdAt,
    this.reviewedAt,
  });
}

// ── 상세 패널 ──
class _ReportDetailPanel extends StatefulWidget {
  final _ReportItem item;
  final DateFormat dateFormat;
  final Map<String, String> statusLabel;
  final Color Function(String) statusColor;
  final Map<String, String> typeLabel;
  final Future<Map<String, String>> Function(String, String) onFetchContent;
  final Future<String> Function(String) onFetchReporter;
  final Future<void> Function(String, String) onUpdateStatus;
  final Future<void> Function(_ReportItem) onDelete;

  const _ReportDetailPanel({
    super.key,
    required this.item,
    required this.dateFormat,
    required this.statusLabel,
    required this.statusColor,
    required this.typeLabel,
    required this.onFetchContent,
    required this.onFetchReporter,
    required this.onUpdateStatus,
    required this.onDelete,
  });

  @override
  State<_ReportDetailPanel> createState() => _ReportDetailPanelState();
}

class _ReportDetailPanelState extends State<_ReportDetailPanel> {
  String? _content;
  String? _contentAuthor;
  String? _reporterName;
  bool _isLoading = true;
  bool _isActing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      widget.onFetchContent(widget.item.targetId, widget.item.targetType),
      widget.onFetchReporter(widget.item.reporterId),
    ]);
    if (!mounted) return;
    final contentMap = results[0] as Map<String, String>;
    setState(() {
      _content = contentMap['content'];
      _contentAuthor = contentMap['author'];
      _reporterName = results[1] as String;
      _isLoading = false;
    });
  }

  Future<void> _act(String status) async {
    setState(() => _isActing = true);
    await widget.onUpdateStatus(widget.item.id, status);
    if (mounted) setState(() => _isActing = false);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isOverdue = item.status == 'pending' &&
        item.createdAt != null &&
        DateTime.now().difference(item.createdAt!).inHours >= 24;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.statusColor(item.status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: widget.statusColor(item.status).withValues(alpha: 0.5)),
                ),
                child: Text(
                  widget.statusLabel[item.status] ?? item.status,
                  style: TextStyle(
                    color: widget.statusColor(item.status),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.typeLabel[item.targetType] ?? item.targetType,
                style: const TextStyle(fontSize: 13),
              ),
              if (isOverdue) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.warning, size: 13, color: Colors.red),
                      const SizedBox(width: 4),
                      Text('24시간 초과 — 즉시 검토 필요',
                          style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),

          // 신고 정보
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('신고 정보', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _InfoRow(label: '신고 사유', value: item.reason),
                  if (item.detail.isNotEmpty) _InfoRow(label: '상세 내용', value: item.detail),
                  _InfoRow(
                    label: '신고자',
                    value: _reporterName != null ? '$_reporterName (${item.reporterId.substring(0, 8)}...)' : item.reporterId,
                  ),
                  _InfoRow(
                    label: '신고 일시',
                    value: item.createdAt != null ? widget.dateFormat.format(item.createdAt!) : '-',
                  ),
                  if (item.reviewedAt != null)
                    _InfoRow(
                      label: '검토 일시',
                      value: widget.dateFormat.format(item.reviewedAt!),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 신고된 콘텐츠
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '신고된 ${widget.typeLabel[item.targetType] ?? '콘텐츠'}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      if (_contentAuthor != null && _contentAuthor!.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Text('작성자: $_contentAuthor',
                            style: TextStyle(fontSize: 12, color: Colors.grey[80])),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_isLoading)
                    const Center(child: ProgressRing())
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        _content ?? '-',
                        style: const TextStyle(fontSize: 14, height: 1.6),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 액션 버튼
          if (item.status != 'deleted')
            Row(
              children: [
                if (item.status == 'pending') ...[
                  FilledButton(
                    onPressed: _isActing ? null : () => _act('reviewed'),
                    child: _isActing
                        ? const ProgressRing(strokeWidth: 2)
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(FluentIcons.check_mark, size: 14),
                              SizedBox(width: 6),
                              Text('검토 완료'),
                            ],
                          ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (item.status == 'reviewed') ...[
                  Button(
                    onPressed: _isActing ? null : () => _act('pending'),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.history, size: 14),
                        SizedBox(width: 6),
                        Text('대기로 되돌리기'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Button(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(Colors.red.withValues(alpha: 0.1)),
                    foregroundColor: WidgetStateProperty.all(Colors.red),
                  ),
                  onPressed: _isActing ? null : () => widget.onDelete(item),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.delete, size: 14),
                      SizedBox(width: 6),
                      Text('콘텐츠 삭제'),
                    ],
                  ),
                ),
              ],
            ),
          if (item.status == 'deleted')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.delete, size: 14, color: Colors.red),
                  const SizedBox(width: 6),
                  Text('이미 삭제된 콘텐츠입니다', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[100])),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
