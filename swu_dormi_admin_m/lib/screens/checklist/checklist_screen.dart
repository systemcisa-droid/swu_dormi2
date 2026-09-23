import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'checklist_data.dart';
import '../../services/storage_service.dart';
import '../cleaning/cleaning_inspection_screen.dart' show kFloorOptions;

// "샬롬 각층" 점검표에서 선택 가능한 점검구역 (샬롬하우스 소속 층만, 방학 임시배정 제외)
final List<String> kShalomFloorCheckAreas =
    kFloorOptions.where((f) => f.startsWith('샬롬하우스') && !f.contains('방학')).toList();

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '내 점검표'),
            Tab(text: '전체 점검표'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _MyChecklistTab(),
          _AllChecklistTab(),
        ],
      ),
    );
  }
}

class _MyChecklistTab extends StatefulWidget {
  const _MyChecklistTab();

  @override
  State<_MyChecklistTab> createState() => _MyChecklistTabState();
}

class _MyChecklistTabState extends State<_MyChecklistTab> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _submissions = [];
  bool _isLoading = true;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadSubmissions();
  }

  Future<void> _loadUserName() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final name = doc.data()?['name'] as String?;
      if (name != null && name.isNotEmpty && mounted) {
        setState(() => _userName = name);
        return;
      }
    } catch (_) {}

    final fallback = user.displayName ?? user.email?.split('@').first ?? '';
    if (mounted && fallback.isNotEmpty) {
      setState(() => _userName = fallback);
    }
  }

  Future<void> _loadSubmissions() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) { setState(() => _isLoading = false); return; }
    try {
      final snap = await _firestore
          .collection('checklist_submissions')
          .where('uid', isEqualTo: uid)
          .get();
      final docs = snap.docs.map((d) {
        final data = d.data();
        data['_id'] = d.id;
        return data;
      }).toList();
      docs.sort((a, b) {
        final aT = (a['submittedAt'] as Timestamp?)?.toDate() ?? DateTime(0);
        final bT = (b['submittedAt'] as Timestamp?)?.toDate() ?? DateTime(0);
        return bT.compareTo(aT);
      });
      if (mounted) setState(() { _submissions = docs; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSubmission(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제'),
        content: const Text('이 점검표를 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _firestore.collection('checklist_submissions').doc(id).delete();
      await _loadSubmissions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 오류: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  int _checkedCount(Map<String, dynamic> data) {
    final checks = data['checks'] as Map<String, dynamic>?;
    final issues = data['issues'] as Map<String, dynamic>?;
    final checkedCount = checks?.values.where((v) => v == true).length ?? 0;
    final issueCount = issues?.values.where((v) => v == true).length ?? 0;
    return checkedCount + issueCount;
  }

  int _issueCount(Map<String, dynamic> data) {
    final issues = data['issues'] as Map<String, dynamic>?;
    return issues?.values.where((v) => v == true).length ?? 0;
  }

  int _totalItemsForData(Map<String, dynamic> data) {
    final templateId = data['checklistType'] as String? ?? 'shalom_b1';
    final template = kChecklistTemplates.firstWhere(
      (t) => t.id == templateId,
      orElse: () => kChecklistShalomB1,
    );
    int count = 0;
    for (final loc in template.locations) {
      for (final sub in loc.subjects) { count += sub.items.length; }
    }
    return count;
  }

  Color _badgeColor(String? id) {
    switch (id) {
      case 'shalom_floor': return Colors.blue.shade700;
      case 'guksaeng_floor': return Colors.orange.shade700;
      case 'guksaeng_saenghoei': return Colors.purple.shade700;
      default: return Colors.green.shade700;
    }
  }

  String _templateLabel(String? id) {
    switch (id) {
      case 'shalom_floor': return '샬롬 각층';
      case 'guksaeng_floor': return '국생 모든층';
      case 'guksaeng_saenghoei': return '국생 사생회';
      default: return '샬롬 지하';
    }
  }

  Future<void> _showTypeSelectDialog() async {
    // 샬롬 지하·국생 사생회는 신규 작성 목록에서 제외한다. 다만 kChecklistTemplates
    // 자체(템플릿 데이터)는 그대로 두어야 이미 제출된 옛 점검표를 계속 조회할 수 있다.
    final selectableTemplates = kChecklistTemplates
        .where((t) => t.id != 'shalom_b1' && t.id != 'guksaeng_saenghoei')
        .toList();
    final selected = await showDialog<ChecklistTemplate>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('점검표 유형 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: selectableTemplates.map((t) => ListTile(
            leading: const Icon(Icons.checklist_rtl, color: Color(0xFFA6BF96)),
            title: Text(_templateLabel(t.id)),
            subtitle: Text(t.title, style: const TextStyle(fontSize: 11)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onTap: () => Navigator.pop(ctx, t),
          )).toList(),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChecklistFormScreen(template: selected)),
    );
    _loadSubmissions();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: const Color(0xFFA6BF96).withValues(alpha: 0.08),
                    child: Row(
                      children: [
                        const Icon(Icons.person, size: 18, color: Color(0xFFA6BF96)),
                        const SizedBox(width: 8),
                        Text(
                          _userName != null && _userName!.isNotEmpty
                              ? '작성자: $_userName'
                              : '관내점검표',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFFA6BF96),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '총 ${_submissions.length}건',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _submissions.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.checklist_rtl, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('작성된 점검표가 없습니다', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadSubmissions,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: _submissions.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, i) => _buildCard(_submissions[i]),
                            ),
                          ),
                  ),
                ],
              ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: _showTypeSelectDialog,
            icon: const Icon(Icons.add),
            label: const Text('작성'),
            backgroundColor: const Color(0xFFA6BF96),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(Map<String, dynamic> data) {
    final id = data['_id'] as String;
    final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
    final checked = _checkedCount(data);
    final issueCount = _issueCount(data);
    final okCount = checked - issueCount;
    final total = _totalItemsForData(data);
    final progress = total > 0 ? checked / total : 0.0;
    final okProgress = total > 0 ? okCount / total : 0.0;
    final issueProgress = total > 0 ? issueCount / total : 0.0;
    final typeId = data['checklistType'] as String?;
    final floor = data['floor'] as String?;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final templateId = data['checklistType'] as String? ?? 'shalom_b1';
          final template = kChecklistTemplates.firstWhere(
            (t) => t.id == templateId,
            orElse: () => kChecklistShalomB1,
          );
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChecklistFormScreen(existing: data, template: template),
            ),
          );
          _loadSubmissions();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA6BF96).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      submittedAt != null
                          ? DateFormat('yyyy.MM.dd (E)', 'ko').format(submittedAt)
                          : '-',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFFA6BF96),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _badgeColor(typeId).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _templateLabel(typeId),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _badgeColor(typeId),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      children: [
                        TextSpan(text: '$okCount', style: const TextStyle(color: Colors.green)),
                        if (issueCount > 0) ...[
                          const TextSpan(text: '+', style: TextStyle(color: Colors.grey)),
                          TextSpan(text: '$issueCount', style: const TextStyle(color: Colors.red)),
                        ],
                        TextSpan(text: ' / $total', style: TextStyle(color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'delete') _deleteSubmission(id);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('삭제', style: TextStyle(color: Colors.red)),
                        ]),
                      ),
                    ],
                    icon: const Icon(Icons.more_vert, size: 18),
                  ),
                ],
              ),
              if (floor != null && floor.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 13, color: Colors.grey.shade600),
                    const SizedBox(width: 3),
                    Text(
                      floor,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(
                  children: [
                    Container(height: 6, color: Colors.grey.shade200),
                    FractionallySizedBox(
                      widthFactor: (okProgress + issueProgress).clamp(0.0, 1.0),
                      child: Container(
                        height: 6,
                        color: progress >= 1.0 ? Colors.green : const Color(0xFFA6BF96),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: issueProgress.clamp(0.0, 1.0),
                      child: Container(height: 6, color: Colors.red),
                    ),
                  ],
                ),
              ),
              if (progress >= 1.0) ...[
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(Icons.check_circle, size: 14, color: Colors.green),
                    SizedBox(width: 4),
                    Text('점검 완료', style: TextStyle(fontSize: 12, color: Colors.green)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── 전체 점검표 탭 (모든 층장이 작성한 점검표를 읽기 전용으로 조회) ──
class _AllChecklistTab extends StatefulWidget {
  const _AllChecklistTab();

  @override
  State<_AllChecklistTab> createState() => _AllChecklistTabState();
}

class _AllChecklistTabState extends State<_AllChecklistTab> {
  final _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _submissions = [];
  // 'yyyy.MM.dd (E)' -> 해당 날짜의 제출 목록 (점검구역 순서로 정렬)
  Map<String, List<Map<String, dynamic>>> _grouped = {};
  List<String> _sortedDates = [];
  // 접혀 있는 날짜 키 (기본은 모두 펼침, 단 최초 로드 시 최신 날짜만 펼친다)
  final Set<String> _collapsedDates = {};
  bool _isLoading = true;
  final _dateHeaderFmt = DateFormat('yyyy.MM.dd (E)', 'ko');

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    try {
      final snap = await _firestore.collection('checklist_submissions').get();
      final docs = snap.docs.map((d) {
        final data = d.data();
        data['_id'] = d.id;
        return data;
      }).toList();

      // 작성자 이름을 한 번에 조회해 채워 넣는다.
      // 한 명씩 조회하면 작성자 수만큼 왕복이 생기므로 whereIn으로 묶어 읽는다.
      // (whereIn은 최대 30개까지 지원하므로 청크로 나눈다)
      final uids =
          docs.map((d) => d['uid'] as String?).whereType<String>().toSet().toList();
      final nameByUid = <String, String>{};
      for (var i = 0; i < uids.length; i += 30) {
        final chunk = uids.sublist(i, (i + 30).clamp(0, uids.length));
        try {
          final snap = await _firestore
              .collection('users')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          for (final doc in snap.docs) {
            final name = doc.data()['name'] as String?;
            if (name != null && name.isNotEmpty) nameByUid[doc.id] = name;
          }
        } catch (_) {}
      }
      for (final d in docs) {
        d['_writerName'] = nameByUid[d['uid']] ?? '알 수 없음';
      }

      // 일자별로 묶은 뒤, 각 날짜 안에서는 점검구역 순서로 정렬한다.
      final grouped = <String, List<Map<String, dynamic>>>{};
      final dateKeyOf = <String, DateTime>{};
      for (final d in docs) {
        final submittedAt = (d['submittedAt'] as Timestamp?)?.toDate();
        final key = submittedAt != null ? _dateHeaderFmt.format(submittedAt) : '날짜 없음';
        grouped.putIfAbsent(key, () => []).add(d);
        if (submittedAt != null) {
          final dayOnly = DateTime(submittedAt.year, submittedAt.month, submittedAt.day);
          dateKeyOf[key] = dayOnly;
        }
      }
      for (final list in grouped.values) {
        list.sort((a, b) {
          final ao = _areaOrder(a);
          final bo = _areaOrder(b);
          if (ao != bo) return ao.compareTo(bo);
          final aT = (a['submittedAt'] as Timestamp?)?.toDate() ?? DateTime(0);
          final bT = (b['submittedAt'] as Timestamp?)?.toDate() ?? DateTime(0);
          return aT.compareTo(bT);
        });
      }
      final sortedDates = grouped.keys.toList()
        ..sort((a, b) {
          final aD = dateKeyOf[a];
          final bD = dateKeyOf[b];
          if (aD == null && bD == null) return 0;
          if (aD == null) return 1;
          if (bD == null) return -1;
          return bD.compareTo(aD); // 최신 날짜 먼저
        });

      if (mounted) {
        setState(() {
          _submissions = docs;
          _grouped = grouped;
          _sortedDates = sortedDates;
          // 최초 로드 시에는 가장 최근 날짜만 펼치고 나머지는 접어 둔다.
          if (_collapsedDates.isEmpty && sortedDates.length > 1) {
            _collapsedDates.addAll(sortedDates.skip(1));
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 점검구역 정렬 순위.
  /// "샬롬 각층"은 저장된 floor 값을 kFloorOptions 순서(샬롬 A동 2~7층 → B동 2~7층
  /// → 국생 → 바롬 10층)로 매핑하고, floor가 없는 템플릿은 템플릿 종류로 순위를 준다.
  int _areaOrder(Map<String, dynamic> data) {
    final floor = data['floor'] as String?;
    if (floor != null && floor.isNotEmpty) {
      final idx = kFloorOptions.indexOf(floor);
      if (idx >= 0) return idx;
      return kFloorOptions.length; // 목록에 없는 구역은 뒤로
    }
    // floor 없는 템플릿: 샬롬 지하 → 국생 모든층 → 국생 사생회 순으로 뒤에 붙인다.
    final base = kFloorOptions.length + 1;
    switch (data['checklistType'] as String?) {
      case 'guksaeng_floor': return base + 1;
      case 'guksaeng_saenghoei': return base + 2;
      default: return base; // shalom_b1 (샬롬 지하)
    }
  }

  int _checkedCount(Map<String, dynamic> data) {
    final checks = data['checks'] as Map<String, dynamic>?;
    final issues = data['issues'] as Map<String, dynamic>?;
    final checkedCount = checks?.values.where((v) => v == true).length ?? 0;
    final issueCount = issues?.values.where((v) => v == true).length ?? 0;
    return checkedCount + issueCount;
  }

  int _issueCount(Map<String, dynamic> data) {
    final issues = data['issues'] as Map<String, dynamic>?;
    return issues?.values.where((v) => v == true).length ?? 0;
  }

  int _totalItemsForData(Map<String, dynamic> data) {
    final templateId = data['checklistType'] as String? ?? 'shalom_b1';
    final template = kChecklistTemplates.firstWhere(
      (t) => t.id == templateId,
      orElse: () => kChecklistShalomB1,
    );
    int count = 0;
    for (final loc in template.locations) {
      for (final sub in loc.subjects) { count += sub.items.length; }
    }
    return count;
  }

  Color _badgeColor(String? id) {
    switch (id) {
      case 'shalom_floor': return Colors.blue.shade700;
      case 'guksaeng_floor': return Colors.orange.shade700;
      case 'guksaeng_saenghoei': return Colors.purple.shade700;
      default: return Colors.green.shade700;
    }
  }

  String _templateLabel(String? id) {
    switch (id) {
      case 'shalom_floor': return '샬롬 각층';
      case 'guksaeng_floor': return '국생 모든층';
      case 'guksaeng_saenghoei': return '국생 사생회';
      default: return '샬롬 지하';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFFA6BF96).withValues(alpha: 0.08),
          child: Row(
            children: [
              const Icon(Icons.groups, size: 18, color: Color(0xFFA6BF96)),
              const SizedBox(width: 8),
              const Text(
                '전체 점검표 (읽기 전용)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFFA6BF96),
                ),
              ),
              const Spacer(),
              Text(
                '총 ${_submissions.length}건',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              if (_sortedDates.isNotEmpty) ...[
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: _collapsedDates.length == _sortedDates.length ? '전체 펼치기' : '전체 접기',
                  icon: Icon(
                    _collapsedDates.length == _sortedDates.length
                        ? Icons.unfold_more
                        : Icons.unfold_less,
                    size: 20,
                    color: const Color(0xFFA6BF96),
                  ),
                  onPressed: () => setState(() {
                    if (_collapsedDates.length == _sortedDates.length) {
                      _collapsedDates.clear();
                    } else {
                      _collapsedDates
                        ..clear()
                        ..addAll(_sortedDates);
                    }
                  }),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _submissions.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.checklist_rtl, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('작성된 점검표가 없습니다', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSubmissions,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _sortedDates.length,
                    itemBuilder: (_, i) => _buildDateSection(_sortedDates[i]),
                  ),
                ),
        ),
      ],
    );
  }

  /// 일자 헤더(탭하면 접기/펼치기) + 해당 날짜의 점검표 카드 목록
  Widget _buildDateSection(String dateLabel) {
    final items = _grouped[dateLabel] ?? const [];
    final isCollapsed = _collapsedDates.contains(dateLabel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => setState(() {
            if (isCollapsed) {
              _collapsedDates.remove(dateLabel);
            } else {
              _collapsedDates.add(dateLabel);
            }
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  isCollapsed ? Icons.expand_more : Icons.expand_less,
                  size: 20,
                  color: const Color(0xFFA6BF96),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA6BF96),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    dateLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _ChecklistSummaryScreen(
                        dateLabel: dateLabel,
                        items: items,
                      ),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFA6BF96)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.summarize_outlined, size: 14, color: Color(0xFFA6BF96)),
                        SizedBox(width: 3),
                        Text(
                          '비고 종합',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFA6BF96),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${items.length}건',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Divider(color: Colors.grey.shade300, height: 1),
                ),
              ],
            ),
          ),
        ),
        if (!isCollapsed) ...[
          const SizedBox(height: 4),
          for (final data in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildCard(data),
            ),
        ],
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildCard(Map<String, dynamic> data) {
    final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
    final checked = _checkedCount(data);
    final issueCount = _issueCount(data);
    final okCount = checked - issueCount;
    final total = _totalItemsForData(data);
    final progress = total > 0 ? checked / total : 0.0;
    final okProgress = total > 0 ? okCount / total : 0.0;
    final issueProgress = total > 0 ? issueCount / total : 0.0;
    final typeId = data['checklistType'] as String?;
    final writerName = data['_writerName'] as String? ?? '알 수 없음';
    final floor = data['floor'] as String?;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final templateId = data['checklistType'] as String? ?? 'shalom_b1';
          final template = kChecklistTemplates.firstWhere(
            (t) => t.id == templateId,
            orElse: () => kChecklistShalomB1,
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChecklistFormScreen(existing: data, template: template, readOnly: true),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA6BF96).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      submittedAt != null
                          ? DateFormat('HH:mm').format(submittedAt)
                          : '-',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFFA6BF96),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _badgeColor(typeId).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _templateLabel(typeId),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _badgeColor(typeId),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      children: [
                        TextSpan(text: '$okCount', style: const TextStyle(color: Colors.green)),
                        if (issueCount > 0) ...[
                          const TextSpan(text: '+', style: TextStyle(color: Colors.grey)),
                          TextSpan(text: '$issueCount', style: const TextStyle(color: Colors.red)),
                        ],
                        TextSpan(text: ' / $total', style: TextStyle(color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 13, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '작성자: $writerName',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              if (floor != null && floor.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 13, color: Colors.grey.shade600),
                    const SizedBox(width: 3),
                    Text(
                      floor,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(
                  children: [
                    Container(height: 6, color: Colors.grey.shade200),
                    FractionallySizedBox(
                      widthFactor: (okProgress + issueProgress).clamp(0.0, 1.0),
                      child: Container(
                        height: 6,
                        color: progress >= 1.0 ? Colors.green : const Color(0xFFA6BF96),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: issueProgress.clamp(0.0, 1.0),
                      child: Container(height: 6, color: Colors.red),
                    ),
                  ],
                ),
              ),
              if (progress >= 1.0) ...[
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(Icons.check_circle, size: 14, color: Colors.green),
                    SizedBox(width: 4),
                    Text('점검 완료', style: TextStyle(fontSize: 12, color: Colors.green)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── 점검표 작성/수정 화면 ──
class ChecklistFormScreen extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final ChecklistTemplate template;
  final bool readOnly;

  const ChecklistFormScreen({
    super.key,
    this.existing,
    required this.template,
    this.readOnly = false,
  });

  @override
  State<ChecklistFormScreen> createState() => _ChecklistFormScreenState();
}

class _ChecklistFormScreenState extends State<ChecklistFormScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storageService = StorageService();
  final _picker = ImagePicker();

  Map<String, bool> _checks = {};
  Map<String, bool> _issues = {};
  Map<String, String> _remarks = {};
  // 항목키(checkKey) -> 업로드 완료된 사진 URL 목록
  Map<String, List<String>> _itemImages = {};
  // 항목키 -> 업로드 진행 중 여부 (중복 업로드 방지 및 로딩 표시)
  final Set<String> _uploadingKeys = {};
  final Map<String, TextEditingController> _remarkCtrls = {};
  bool _isSaving = false;
  DateTime? _submittedAt;
  String? _savedDocId;
  String? _userName;
  String? _selectedFloor;

  bool get _needsFloorSelect => widget.template.id == 'shalom_floor';

  // 읽기 전용이거나 저장 처리 중이면 입력을 받지 않는다(저장 도중 값 변경 방지).
  bool get _isInputLocked => widget.readOnly || _isSaving;

  List<CheckLocation> get _locations => widget.template.locations;

  Color _formBadgeColor(String id) {
    switch (id) {
      case 'shalom_floor': return Colors.blue.shade700;
      case 'guksaeng_floor': return Colors.orange.shade700;
      case 'guksaeng_saenghoei': return Colors.purple.shade700;
      default: return Colors.green.shade700;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.readOnly) {
      _userName = widget.existing?['_writerName'] as String?;
    } else {
      _loadUserName();
    }
    _initCtrls();
    if (widget.existing != null) _loadExisting();
  }

  Future<void> _loadUserName() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final name = doc.data()?['name'] as String?;
      if (name != null && name.isNotEmpty && mounted) {
        setState(() => _userName = name);
        return;
      }
    } catch (_) {}

    final fallback = user.displayName ?? user.email?.split('@').first ?? '';
    if (mounted && fallback.isNotEmpty) {
      setState(() => _userName = fallback);
    }
  }

  void _initCtrls() {
    for (final loc in _locations) {
      for (var si = 0; si < loc.subjects.length; si++) {
        _remarkCtrls['${loc.no}_$si'] = TextEditingController();
      }
    }
  }

  void _loadExisting() {
    final data = widget.existing!;
    _savedDocId = data['_id'] as String?;
    _submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
    _selectedFloor = data['floor'] as String?;
    _checks = Map<String, bool>.from(
      (data['checks'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as bool)) ??
          {});
    _issues = Map<String, bool>.from(
      (data['issues'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as bool)) ??
          {});
    _remarks = Map<String, String>.from(
      (data['remarks'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as String)) ??
          {});
    _itemImages = (data['itemImages'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, List<String>.from(v as List)),
        ) ??
        {};
    for (final entry in _remarks.entries) {
      _remarkCtrls[entry.key]?.text = entry.value;
    }
  }

  @override
  void dispose() {
    for (final c in _remarkCtrls.values) { c.dispose(); }
    super.dispose();
  }

  String _checkKey(int no, int si, int ii) => '${no}_${si}_$ii';
  String _remarkKey(int no, int si) => '${no}_$si';

  int get _totalItems {
    int count = 0;
    for (final loc in _locations) {
      for (final sub in loc.subjects) { count += sub.items.length; }
    }
    return count;
  }

  int get _checkedItems => _checks.values.where((v) => v).length;

  Future<void> _save() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    if (_needsFloorSelect && (_selectedFloor == null || _selectedFloor!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('점검구역을 선택해주세요'), backgroundColor: Colors.red),
      );
      return;
    }

    for (final entry in _remarkCtrls.entries) {
      _remarks[entry.key] = entry.value.text.trim();
    }

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now();
      final payload = <String, dynamic>{
        'uid': uid,
        'checklistType': widget.template.id,
        'submittedAt': Timestamp.fromDate(now),
        'checks': _checks,
        'issues': _issues,
        'remarks': _remarks,
        'itemImages': _itemImages,
        if (_needsFloorSelect) 'floor': _selectedFloor,
      };
      if (_savedDocId != null) {
        await _firestore.collection('checklist_submissions').doc(_savedDocId).update(payload);
      } else {
        final ref = await _firestore.collection('checklist_submissions').add(payload);
        _savedDocId = ref.id;
      }
      setState(() { _submittedAt = now; _isSaving = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장되었습니다'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 오류: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickAndUploadImage(String checkKey) async {
    if (widget.readOnly || _uploadingKeys.contains(checkKey)) return;
    final existing = _itemImages[checkKey] ?? [];
    if (existing.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진은 항목당 최대 3장까지 첨부할 수 있습니다'), backgroundColor: Colors.red),
      );
      return;
    }
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image == null) return;

      setState(() => _uploadingKeys.add(checkKey));
      final uid = _auth.currentUser?.uid ?? 'unknown';
      final fileName = '${uid}_${checkKey}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final url = await _storageService.uploadChecklistImage(File(image.path), fileName);
      if (!mounted) return;
      setState(() {
        _itemImages = {..._itemImages};
        _itemImages[checkKey] = <String>[...(_itemImages[checkKey] ?? <String>[]), url];
        _uploadingKeys.remove(checkKey);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingKeys.remove(checkKey));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('사진 업로드 오류: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _pickImageFromGallery(String checkKey) async {
    if (widget.readOnly || _uploadingKeys.contains(checkKey)) return;
    final existing = _itemImages[checkKey] ?? [];
    if (existing.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진은 항목당 최대 3장까지 첨부할 수 있습니다'), backgroundColor: Colors.red),
      );
      return;
    }
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (image == null) return;

      setState(() => _uploadingKeys.add(checkKey));
      final uid = _auth.currentUser?.uid ?? 'unknown';
      final fileName = '${uid}_${checkKey}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final url = await _storageService.uploadChecklistImage(File(image.path), fileName);
      if (!mounted) return;
      setState(() {
        _itemImages = {..._itemImages};
        _itemImages[checkKey] = <String>[...(_itemImages[checkKey] ?? <String>[]), url];
        _uploadingKeys.remove(checkKey);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingKeys.remove(checkKey));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('사진 업로드 오류: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _removeItemImage(String checkKey, int index) {
    setState(() {
      _itemImages = {..._itemImages};
      final list = <String>[...(_itemImages[checkKey] ?? <String>[])];
      list.removeAt(index);
      _itemImages[checkKey] = list;
    });
  }

  void _showImageSourceSheet(String checkKey) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('카메라로 촬영'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadImage(checkKey);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리에서 선택'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImageFromGallery(checkKey);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showImagePreview(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: InteractiveViewer(
          child: Image.network(url),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final typeLabel = switch (widget.template.id) {
      'shalom_floor' => '샬롬 각층',
      'guksaeng_floor' => '국생 모든층',
      'guksaeng_saenghoei' => '국생 사생회',
      _ => '샬롬 지하',
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.readOnly ? '점검표 보기' : (isEdit ? '점검표 수정' : '점검표 작성')),
        actions: [
          if (_submittedAt != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  DateFormat('MM/dd HH:mm').format(_submittedAt!),
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 진행률 헤더
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFA6BF96).withValues(alpha: 0.08),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _formBadgeColor(widget.template.id).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _formBadgeColor(widget.template.id),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _userName != null && _userName!.isNotEmpty
                      ? '작성자: $_userName'
                      : '관내점검표',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const Spacer(),
                Text(
                  '$_checkedItems / $_totalItems',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFFA6BF96),
                  ),
                ),
              ],
            ),
          ),
          LinearProgressIndicator(
            value: _totalItems > 0 ? _checkedItems / _totalItems : 0,
            backgroundColor: Colors.grey.shade200,
            color: const Color(0xFFA6BF96),
            minHeight: 4,
          ),
          if (_needsFloorSelect)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              color: Colors.white,
              child: DropdownButtonFormField<String>(
                initialValue: _selectedFloor,
                items: kShalomFloorCheckAreas
                    .map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: _isInputLocked ? null : (v) => setState(() => _selectedFloor = v),
                decoration: InputDecoration(
                  labelText: '점검구역 *',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
          // 목록
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _locations.length,
              itemBuilder: (_, i) => _buildLocationCard(_locations[i]),
            ),
          ),
          // 저장 버튼 (읽기 전용 모드에서는 숨김)
          if (!widget.readOnly)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save, size: 18),
                    label: const Text('저장'),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFA6BF96)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(CheckLocation loc) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFA6BF96).withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 26, height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFA6BF96), shape: BoxShape.circle,
                  ),
                  child: Text('${loc.no}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(loc.location,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ],
            ),
          ),
          ...loc.subjects.asMap().entries.map((e) =>
              _buildSubjectSection(loc.no, e.key, e.value)),
        ],
      ),
    );
  }

  Widget _buildSubjectSection(int no, int si, CheckSubject sub) {
    final rKey = _remarkKey(no, si);
    final ctrl = _remarkCtrls[rKey]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (si > 0) const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(sub.name,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1565C0))),
        ),
        ...sub.items.asMap().entries.map((entry) {
          final ii = entry.key;
          final item = entry.value;
          final cKey = _checkKey(no, si, ii);
          final checked = _checks[cKey] ?? false;
          final hasIssue = _issues[cKey] ?? false;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: checked,
                    onChanged: _isInputLocked
                        ? null
                        : (val) => setState(() {
                              _checks[cKey] = val ?? false;
                              if (val == true) _issues[cKey] = false;
                            }),
                    activeColor: const Color(0xFFA6BF96),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item.content,
                      style: TextStyle(
                        fontSize: 12,
                        color: hasIssue
                            ? Colors.red
                            : checked
                                ? Colors.grey.shade400
                                : Colors.black87,
                        decoration: checked ? TextDecoration.lineThrough : null,
                      )),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isInputLocked
                      ? null
                      : () => setState(() {
                            _issues[cKey] = !hasIssue;
                            if (!hasIssue) _checks[cKey] = false;
                          }),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: hasIssue ? Colors.red : Colors.transparent,
                      border: Border.all(
                        color: hasIssue ? Colors.red : Colors.grey.shade400,
                        width: 1.5,
                      ),
                    ),
                    child: hasIssue
                        ? const Icon(Icons.close, size: 15, color: Colors.white)
                        : null,
                  ),
                ),
              ],
            ),
          );
        }),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
          child: TextField(
            controller: ctrl,
            maxLines: null,
            readOnly: _isInputLocked,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: '비고',
              hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: _buildItemImages(rKey),
        ),
      ],
    );
  }

  Widget _buildItemImages(String checkKey) {
    final urls = _itemImages[checkKey] ?? [];
    final isUploading = _uploadingKeys.contains(checkKey);
    if (urls.isEmpty && !isUploading && widget.readOnly) return const SizedBox.shrink();

    return SizedBox(
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < urls.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () => _showImagePreview(urls[i]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        urls[i],
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image, size: 20, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                  if (!_isInputLocked)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: GestureDetector(
                        onTap: () => _removeItemImage(checkKey, i),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (isUploading)
            Container(
              width: 60,
              height: 60,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
          if (!_isInputLocked && urls.length < 3 && !isUploading)
            GestureDetector(
              onTap: () => _showImageSourceSheet(checkKey),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.add_a_photo_outlined, size: 18, color: Colors.grey.shade500),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 일자별 점검표 서머리 (구역별 비고 + 사진 모아보기)
// ══════════════════════════════════════════════════════════════
class _ChecklistSummaryScreen extends StatelessWidget {
  final String dateLabel;
  final List<Map<String, dynamic>> items;

  const _ChecklistSummaryScreen({
    required this.dateLabel,
    required this.items,
  });

  static String _templateLabel(String? id) {
    switch (id) {
      case 'shalom_floor': return '샬롬 각층';
      case 'guksaeng_floor': return '국생 모든층';
      case 'guksaeng_saenghoei': return '국생 사생회';
      default: return '샬롬 지하';
    }
  }

  /// 카드 상단에 표시할 구역명. "샬롬 각층"은 저장된 점검구역(예: 샬롬하우스 A동 2층)을 쓰고,
  /// 점검구역 없이 저장된 옛 기록은 구역 미지정으로 표시한다. 그 외 템플릿은 템플릿명이 곧 구역이다.
  static String _areaLabel(Map<String, dynamic> data) {
    final floor = data['floor'] as String?;
    if (floor != null && floor.isNotEmpty) return floor;
    if (data['checklistType'] == 'shalom_floor') return '점검구역 미지정';
    return _templateLabel(data['checklistType'] as String?);
  }

  /// 한 점검표에서 작성된 비고/사진을 점검표 순서대로 모은다.
  static List<_SummaryRemark> _remarksOf(Map<String, dynamic> data) {
    final templateId = data['checklistType'] as String? ?? 'shalom_b1';
    final template = kChecklistTemplates.firstWhere(
      (t) => t.id == templateId,
      orElse: () => kChecklistShalomB1,
    );
    final remarks = data['remarks'] as Map<String, dynamic>? ?? {};
    final itemImages = data['itemImages'] as Map<String, dynamic>? ?? {};

    final result = <_SummaryRemark>[];
    for (final loc in template.locations) {
      for (var si = 0; si < loc.subjects.length; si++) {
        final key = '${loc.no}_$si';
        final text = (remarks[key] as String?)?.trim() ?? '';
        final images =
            (itemImages[key] as List?)?.whereType<String>().toList() ?? const <String>[];
        if (text.isEmpty && images.isEmpty) continue;
        result.add(_SummaryRemark(
          location: loc.location.replaceAll('\n', ' '),
          subject: loc.subjects[si].name.replaceAll('\n', ' '),
          text: text,
          images: images,
        ));
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    // 비고나 사진이 하나라도 있는 점검표만 요약에 싣는다.
    final entries = <_SummaryEntry>[];
    for (final data in items) {
      final remarks = _remarksOf(data);
      if (remarks.isEmpty) continue;
      entries.add(_SummaryEntry(
        area: _areaLabel(data),
        writer: (data['_writerName'] as String?) ?? '알 수 없음',
        remarks: remarks,
      ));
    }

    final totalRemarks = entries.fold<int>(0, (acc, e) => acc + e.remarks.length);

    return Scaffold(
      appBar: AppBar(
        title: const Text('비고 종합'),
        backgroundColor: const Color(0xFFA6BF96),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFA6BF96).withValues(alpha: 0.08),
            child: Row(
              children: [
                const Icon(Icons.event_note, size: 18, color: Color(0xFFA6BF96)),
                const SizedBox(width: 8),
                Text(
                  dateLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFFA6BF96),
                  ),
                ),
                const Spacer(),
                Text(
                  '${entries.length}개 구역 · 비고 $totalRemarks건',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('작성된 비고가 없습니다', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: entries.length,
                    itemBuilder: (_, i) => _buildAreaCard(context, entries[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaCard(BuildContext context, _SummaryEntry entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 구역 헤더 (첨부 표의 "층 담당" 칼럼에 해당)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFA6BF96).withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.area,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Icon(Icons.person_outline, size: 13, color: Colors.grey.shade600),
                const SizedBox(width: 3),
                Text(
                  entry.writer,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          // 비고 목록 (1. 2. 3. ... 번호 매김)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < entry.remarks.length; i++)
                  _buildRemarkRow(context, i + 1, entry.remarks[i]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemarkRow(BuildContext context, int no, _SummaryRemark r) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$no.',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.text.isNotEmpty ? r.text : '(사진만 첨부)',
                      style: TextStyle(
                        fontSize: 13,
                        color: r.text.isNotEmpty ? Colors.black87 : Colors.grey.shade500,
                        fontStyle: r.text.isNotEmpty ? null : FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${r.location} · ${r.subject}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (r.images.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: r.images
                    .map((url) => GestureDetector(
                          onTap: () => _showImagePreview(context, url),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              url,
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 70,
                                height: 70,
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.broken_image,
                                    size: 20, color: Colors.grey),
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showImagePreview(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: Image.network(
                url,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.broken_image, size: 64, color: Colors.white),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryEntry {
  final String area;
  final String writer;
  final List<_SummaryRemark> remarks;

  _SummaryEntry({
    required this.area,
    required this.writer,
    required this.remarks,
  });
}

class _SummaryRemark {
  final String location;
  final String subject;
  final String text;
  final List<String> images;

  _SummaryRemark({
    required this.location,
    required this.subject,
    required this.text,
    required this.images,
  });
}
