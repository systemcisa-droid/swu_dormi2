import 'package:fluent_ui/fluent_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:swu_dormi_admin/data/point_codes.dart';

class WindowsPointsStatisticsScreen extends StatefulWidget {
  const WindowsPointsStatisticsScreen({super.key});

  @override
  State<WindowsPointsStatisticsScreen> createState() =>
      _WindowsPointsStatisticsScreenState();
}

class _WindowsPointsStatisticsScreenState
    extends State<WindowsPointsStatisticsScreen> {
  bool _isLoading = true;
  String? _error;

  // 원본 이력: userId, type, points, reason, createdAt
  List<Map<String, dynamic>> _history = [];
  // userId -> {name, studentId, roomNumber}
  Map<String, Map<String, String>> _userInfo = {};

  DateTime? _startDate;
  DateTime? _endDate;

  int _tabIndex = 0; // 0: 순위/빈도, 1: 기간별 리포트
  String _reportUnit = 'day'; // 'day' | 'week' | 'month'
  final Set<DateTime> _expandedBuckets = {};

  final _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final firestore = FirebaseFirestore.instance;
      final historySnap =
          await firestore.collectionGroup('point_history').get();
      final history = historySnap.docs
          .map((d) => {...d.data(), '_ref': d.reference})
          .toList();

      final usersSnap = await firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();
      final userInfo = <String, Map<String, String>>{};
      for (final doc in usersSnap.docs) {
        final data = doc.data();
        userInfo[doc.id] = {
          'name': (data['name'] ?? '').toString(),
          'studentId': (data['studentId'] ?? '').toString(),
          'roomNumber': (data['roomNumber'] ?? '').toString(),
          'dormBuilding': (data['dormBuilding'] ?? '').toString(),
        };
      }

      if (!mounted) return;
      setState(() {
        _history = history;
        _userInfo = userInfo;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredHistory {
    if (_startDate == null && _endDate == null) return _history;
    return _history.where((h) {
      final createdAt = (h['createdAt'] as Timestamp?)?.toDate();
      if (createdAt == null) return false;
      if (_startDate != null && createdAt.isBefore(_startDate!)) return false;
      if (_endDate != null &&
          createdAt.isAfter(_endDate!.add(const Duration(days: 1)))) {
        return false;
      }
      return true;
    }).toList();
  }

  /// reason 텍스트에서 상벌점코드를 추출한다. 예: "화재대피훈련 참여 (0006) - 비고" -> "0006"
  String? _extractCode(String reason) {
    final match = RegExp(r'\(([^)]+)\)').firstMatch(reason);
    return match?.group(1);
  }

  /// 상벌점 이력 한 건을 삭제하고, users.points를 되돌린 뒤 로컬 상태를 갱신한다.
  Future<void> _deleteHistoryEntry(Map<String, dynamic> entry) async {
    final ref = entry['_ref'] as DocumentReference?;
    final uid = entry['userId'] as String?;
    if (ref == null || uid == null) return;

    final type = entry['type'] as String? ?? '';
    final points = (entry['points'] is num) ? (entry['points'] as num).toInt() : 0;
    final delta = type == 'reward' ? -points : points;

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      batch.delete(ref);
      batch.update(firestore.collection('users').doc(uid), {
        'points': FieldValue.increment(delta),
      });
      await batch.commit();

      if (!mounted) return;
      setState(() {
        _history.removeWhere((h) => h['_ref'] == ref);
      });
    } catch (e) {
      if (!mounted) return;
      displayInfoBar(context,
          builder: (ctx, close) => InfoBar(
                title: const Text('오류'),
                content: Text('삭제 실패: $e'),
                severity: InfoBarSeverity.error,
                action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
              ));
    }
  }

  void _showStudentHistoryDialog(String uid, String name, String studentId) {
    final dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final history = _filteredHistory.where((h) => h['userId'] == uid).toList()
            ..sort((a, b) {
              final at = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
              final bt = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
              return bt.compareTo(at);
            });

          return ContentDialog(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
            title: Text('$name ($studentId) 상벌점 이력'),
            content: SizedBox(
              width: 520,
              height: 480,
              child: history.isEmpty
                  ? Center(
                      child: Text('해당 기간 이력이 없습니다',
                          style: TextStyle(fontSize: 14, color: Colors.grey[120])),
                    )
                  : ListView.separated(
                      itemCount: history.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (ctx, i) {
                        final h = history[i];
                        final type = h['type'] as String? ?? '';
                        final isReward = type == 'reward';
                        final points = (h['points'] is num) ? (h['points'] as num).toInt() : 0;
                        final reason = h['reason'] as String? ?? '';
                        final createdAt = (h['createdAt'] as Timestamp?)?.toDate();
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (isReward ? Colors.green : Colors.red).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isReward ? '+$points' : '-$points',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isReward ? Colors.green : Colors.red,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(reason, style: const TextStyle(fontSize: 13)),
                                    if (createdAt != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        dateTimeFormat.format(createdAt),
                                        style: TextStyle(fontSize: 11, color: Colors.grey[100]),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 32,
                                child: IconButton(
                                  icon: const Icon(FluentIcons.delete, size: 14),
                                  onPressed: () async {
                                    await _deleteHistoryEntry(h);
                                    setDialogState(() {});
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              Button(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('닫기'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final result = await showDialog<({DateTime? start, DateTime? end})>(
      context: context,
      builder: (ctx) {
        DateTime? start = _startDate;
        DateTime? end = _endDate;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return ContentDialog(
              title: const Text('기간 선택'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 70, child: Text('시작일')),
                      Expanded(
                        child: DatePicker(
                          selected: start ?? now,
                          onChanged: (v) => setDialogState(() => start = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const SizedBox(width: 70, child: Text('종료일')),
                      Expanded(
                        child: DatePicker(
                          selected: end ?? now,
                          onChanged: (v) => setDialogState(() => end = v),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                Button(
                  onPressed: () => setDialogState(() {
                    start = null;
                    end = null;
                  }),
                  child: const Text('초기화'),
                ),
                Button(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(ctx, (start: start, end: end)),
                  child: const Text('적용'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == null) return;
    setState(() {
      _startDate = result.start;
      _endDate = result.end;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: const Text('상벌 통계'),
        commandBar: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _startDate == null && _endDate == null
                  ? '전체 기간'
                  : '${_startDate != null ? _dateFormat.format(_startDate!) : '~'} '
                      '~ ${_endDate != null ? _dateFormat.format(_endDate!) : '~'}',
              style: TextStyle(fontSize: 12, color: Colors.grey[110]),
            ),
            const SizedBox(width: 8),
            Button(
              onPressed: _pickDateRange,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.calendar, size: 14),
                  SizedBox(width: 6),
                  Text('기간 선택'),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Button(
              onPressed: _isLoading ? null : _loadData,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.refresh, size: 14),
                  SizedBox(width: 6),
                  Text('새로고침'),
                ],
              ),
            ),
          ],
        ),
      ),
      content: _isLoading
          ? const Center(child: ProgressRing())
          : _error != null
              ? Center(child: Text('오류: $_error'))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: Row(
                        children: [
                          _buildMainTab(0, '순위 / 빈도'),
                          const SizedBox(width: 8),
                          _buildMainTab(1, '기간별 리포트'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: _tabIndex == 0
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 3, child: _buildStudentRankingCard()),
                                  const SizedBox(width: 16),
                                  Expanded(flex: 2, child: _buildCodeFrequencyCard()),
                                ],
                              )
                            : _buildPeriodReportCard(),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildMainTab(int index, String label) {
    final selected = _tabIndex == index;
    return Button(
      onPressed: () => setState(() => _tabIndex = index),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(
          selected ? Colors.blue.withValues(alpha: 0.15) : Colors.transparent,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          color: selected ? Colors.blue : null,
        ),
      ),
    );
  }

  Widget _buildStudentRankingCard() {
    final filtered = _filteredHistory;

    // uid -> {reward, penalty, net}
    final totals = <String, ({int reward, int penalty})>{};
    for (final h in filtered) {
      final uid = h['userId'] as String? ?? '';
      if (uid.isEmpty) continue;
      final type = h['type'] as String? ?? '';
      final points = (h['points'] is num) ? (h['points'] as num).toInt() : 0;
      final cur = totals[uid] ?? (reward: 0, penalty: 0);
      totals[uid] = type == 'reward'
          ? (reward: cur.reward + points, penalty: cur.penalty)
          : (reward: cur.reward, penalty: cur.penalty + points);
    }

    final rows = totals.entries.map((e) {
      final info = _userInfo[e.key];
      return (
        uid: e.key,
        name: info?['name'] ?? '알 수 없음',
        studentId: info?['studentId'] ?? '',
        roomNumber: info?['roomNumber'] ?? '',
        dormBuilding: info?['dormBuilding'] ?? '',
        reward: e.value.reward,
        penalty: e.value.penalty,
        net: e.value.reward - e.value.penalty,
      );
    }).toList()
      ..sort((a, b) => a.net.compareTo(b.net)); // 벌점 많은(net 낮은) 순

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('학생별 누적 점수 순위',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${rows.length}명',
                    style: TextStyle(fontSize: 12, color: Colors.grey[100])),
              ],
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text('해당 기간 상벌점 이력이 없습니다',
                      style: TextStyle(fontSize: 14, color: Colors.grey[120])),
                ),
              )
            else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                color: Colors.grey.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    const SizedBox(width: 36, child: Text('순위', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 90, child: Text('학번', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 70, child: Text('성명', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    const Expanded(child: Text('호실', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 60, child: Text('상점', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 60, child: Text('벌점', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 60, child: Text('합계', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
              SizedBox(
                height: 520,
                child: ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (ctx, i) {
                    final r = rows[i];
                    final netColor = r.net < 0
                        ? Colors.red
                        : r.net > 0
                            ? Colors.green
                            : Colors.grey;
                    return HoverButton(
                      onPressed: () => _showStudentHistoryDialog(r.uid, r.name, r.studentId),
                      builder: (ctx, states) => Container(
                        color: states.isHovered
                            ? Colors.grey.withValues(alpha: 0.08)
                            : Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          children: [
                            SizedBox(width: 36, child: Text('${i + 1}', style: const TextStyle(fontSize: 13))),
                            SizedBox(width: 90, child: Text(r.studentId, style: const TextStyle(fontSize: 13))),
                            SizedBox(width: 70, child: Text(r.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                            Expanded(
                              child: Text(
                                r.roomNumber.isNotEmpty ? '${r.dormBuilding} ${r.roomNumber}호' : '-',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 60, child: Text('+${r.reward}', style: TextStyle(fontSize: 13, color: Colors.green))),
                            SizedBox(width: 60, child: Text('-${r.penalty}', style: TextStyle(fontSize: 13, color: Colors.red))),
                            SizedBox(
                              width: 60,
                              child: Text(
                                r.net > 0 ? '+${r.net}' : '${r.net}',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: netColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 주어진 날짜가 속한 버킷의 시작일을 반환한다.
  /// all: 항상 동일 키(전체를 하나로 묶음), day: 해당 날짜, week: 해당 주 월요일, month: 해당 월 1일
  DateTime _bucketStart(DateTime date, String unit) {
    final d = DateTime(date.year, date.month, date.day);
    switch (unit) {
      case 'all':
        return DateTime(0);
      case 'week':
        return d.subtract(Duration(days: d.weekday - 1));
      case 'month':
        return DateTime(d.year, d.month, 1);
      default:
        return d;
    }
  }

  String _bucketLabel(DateTime start, String unit) {
    switch (unit) {
      case 'all':
        return _startDate == null && _endDate == null
            ? '전체 기간'
            : '${_startDate != null ? _dateFormat.format(_startDate!) : '~'} '
                '~ ${_endDate != null ? _dateFormat.format(_endDate!) : '~'}';
      case 'week':
        final end = start.add(const Duration(days: 6));
        return '${DateFormat('MM.dd').format(start)} ~ ${DateFormat('MM.dd').format(end)}';
      case 'month':
        return DateFormat('yyyy년 MM월').format(start);
      default:
        return DateFormat('yyyy-MM-dd (E)', 'ko_KR').format(start);
    }
  }

  Widget _buildPeriodReportCard() {
    final filtered = _filteredHistory;

    // bucketStart -> {reward, penalty, count, events}
    final buckets = <DateTime, ({int reward, int penalty, int count, List<Map<String, dynamic>> events})>{};
    for (final h in filtered) {
      final createdAt = (h['createdAt'] as Timestamp?)?.toDate();
      if (createdAt == null) continue;
      final type = h['type'] as String? ?? '';
      final points = (h['points'] is num) ? (h['points'] as num).toInt() : 0;
      final bucket = _bucketStart(createdAt, _reportUnit);
      final cur = buckets[bucket] ?? (reward: 0, penalty: 0, count: 0, events: <Map<String, dynamic>>[]);
      cur.events.add(h);
      buckets[bucket] = type == 'reward'
          ? (reward: cur.reward + points, penalty: cur.penalty, count: cur.count + 1, events: cur.events)
          : (reward: cur.reward, penalty: cur.penalty + points, count: cur.count + 1, events: cur.events);
    }

    for (final bucket in buckets.values) {
      bucket.events.sort((a, b) {
        final at = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        final bt = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        return bt.compareTo(at);
      });
    }

    final rows = buckets.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key)); // 최근 순

    final unitLabel = switch (_reportUnit) {
      'all' => '전체',
      'week' => '주',
      'month' => '월',
      _ => '일',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(_reportUnit == 'all' ? '전체 리포트' : '$unitLabel별 리포트',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                _buildUnitToggle('all', '전체'),
                const SizedBox(width: 6),
                _buildUnitToggle('day', '일별'),
                const SizedBox(width: 6),
                _buildUnitToggle('week', '주별'),
                const SizedBox(width: 6),
                _buildUnitToggle('month', '월별'),
              ],
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              Expanded(
                child: Center(
                  child: Text('해당 기간 상벌점 이력이 없습니다',
                      style: TextStyle(fontSize: 14, color: Colors.grey[120])),
                ),
              )
            else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                color: Colors.grey.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    const Expanded(flex: 3, child: Text('기간', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 80, child: Text('상점', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 80, child: Text('벌점', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 80, child: Text('합계', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 60, child: Text('건수', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (ctx, i) {
                    final entry = rows[i];
                    final isExpanded = _expandedBuckets.contains(entry.key);
                    final net = entry.value.reward - entry.value.penalty;
                    final netColor = net < 0
                        ? Colors.red
                        : net > 0
                            ? Colors.green
                            : Colors.grey;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HoverButton(
                          onPressed: () => setState(() {
                            if (isExpanded) {
                              _expandedBuckets.remove(entry.key);
                            } else {
                              _expandedBuckets.add(entry.key);
                            }
                          }),
                          builder: (ctx, states) => Container(
                            color: states.isHovered
                                ? Colors.grey.withValues(alpha: 0.08)
                                : Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            child: Row(
                              children: [
                                Icon(
                                  isExpanded ? FluentIcons.chevron_down : FluentIcons.chevron_right,
                                  size: 12,
                                  color: Colors.grey[110],
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    _bucketLabel(entry.key, _reportUnit),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                SizedBox(width: 80, child: Text('+${entry.value.reward}', style: TextStyle(fontSize: 13, color: Colors.green))),
                                SizedBox(width: 80, child: Text('-${entry.value.penalty}', style: TextStyle(fontSize: 13, color: Colors.red))),
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    net > 0 ? '+$net' : '$net',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: netColor),
                                  ),
                                ),
                                SizedBox(width: 60, child: Text('${entry.value.count}건', style: const TextStyle(fontSize: 13))),
                              ],
                            ),
                          ),
                        ),
                        if (isExpanded) _buildBucketEventList(entry.value.events),
                      ],
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBucketEventList(List<Map<String, dynamic>> events) {
    final dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');
    return Container(
      margin: const EdgeInsets.only(left: 26, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          for (final h in events)
            Builder(builder: (ctx) {
              final uid = h['userId'] as String? ?? '';
              final info = _userInfo[uid];
              final name = info?['name'] ?? '알 수 없음';
              final studentId = info?['studentId'] ?? '';
              final type = h['type'] as String? ?? '';
              final isReward = type == 'reward';
              final points = (h['points'] is num) ? (h['points'] as num).toInt() : 0;
              final reason = h['reason'] as String? ?? '';
              final createdAt = (h['createdAt'] as Timestamp?)?.toDate();
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isReward ? Colors.green : Colors.red).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isReward ? '+$points' : '-$points',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isReward ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 110,
                      child: Text(
                        studentId.isNotEmpty ? '$name ($studentId)' : name,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(reason, style: const TextStyle(fontSize: 12)),
                          if (createdAt != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              dateTimeFormat.format(createdAt),
                              style: TextStyle(fontSize: 10, color: Colors.grey[100]),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 28,
                      child: IconButton(
                        icon: const Icon(FluentIcons.delete, size: 12),
                        onPressed: () async {
                          await _deleteHistoryEntry(h);
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildUnitToggle(String unit, String label) {
    final selected = _reportUnit == unit;
    return Button(
      onPressed: () => setState(() {
        _reportUnit = unit;
        _expandedBuckets.clear();
      }),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(
          selected ? Colors.blue.withValues(alpha: 0.15) : Colors.transparent,
        ),
        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          color: selected ? Colors.blue : null,
        ),
      ),
    );
  }

  Widget _buildCodeFrequencyCard() {
    final filtered = _filteredHistory;

    // code -> count
    final codeCounts = <String, int>{};
    int unmatchedCount = 0;
    for (final h in filtered) {
      final reason = h['reason'] as String? ?? '';
      final code = _extractCode(reason);
      if (code == null || !kPointCodeByCode.containsKey(code)) {
        unmatchedCount++;
        continue;
      }
      codeCounts[code] = (codeCounts[code] ?? 0) + 1;
    }

    final rows = codeCounts.entries.map((e) {
      final info = kPointCodeByCode[e.key]!;
      return (
        code: e.key,
        name: info['name'] as String,
        type: info['type'] as String,
        points: info['points'] as int,
        count: e.value,
      );
    }).toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('상벌점 코드별 발생 빈도',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text('해당 기간 상벌점 이력이 없습니다',
                      style: TextStyle(fontSize: 14, color: Colors.grey[120])),
                ),
              )
            else
              SizedBox(
                height: 560,
                child: ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (ctx, i) {
                    final r = rows[i];
                    final isReward = r.type == 'reward';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isReward ? Colors.green : Colors.red).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              r.code,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isReward ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              r.name,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${r.count}건',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            if (unmatchedCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                '코드 미매칭 이력 $unmatchedCount건 (수동 입력 등)',
                style: TextStyle(fontSize: 11, color: Colors.grey[100]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
