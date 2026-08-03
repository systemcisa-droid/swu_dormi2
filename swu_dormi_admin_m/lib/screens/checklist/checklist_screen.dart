import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'checklist_data.dart';

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
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
    if (checks == null) return 0;
    return checks.values.where((v) => v == true).length;
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
    final selected = await showDialog<ChecklistTemplate>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('점검표 유형 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: kChecklistTemplates.map((t) => ListTile(
            leading: const Icon(Icons.checklist_rtl, color: Color(0xFFB44F4F)),
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
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: const Color(0xFFB44F4F).withValues(alpha: 0.08),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 18, color: Color(0xFFB44F4F)),
                      const SizedBox(width: 8),
                      Text(
                        _userName != null && _userName!.isNotEmpty
                            ? '작성자: $_userName'
                            : '관내점검표',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFFB44F4F),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showTypeSelectDialog,
        icon: const Icon(Icons.add),
        label: const Text('작성'),
        backgroundColor: const Color(0xFFB44F4F),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> data) {
    final id = data['_id'] as String;
    final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
    final checked = _checkedCount(data);
    final total = _totalItemsForData(data);
    final progress = total > 0 ? checked / total : 0.0;
    final typeId = data['checklistType'] as String?;

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
                      color: const Color(0xFFB44F4F).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      submittedAt != null
                          ? DateFormat('yyyy.MM.dd (E)', 'ko').format(submittedAt)
                          : '-',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFFB44F4F),
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
                  Text(
                    '$checked / $total',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: progress >= 1.0 ? Colors.green : Colors.grey.shade700,
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
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.shade200,
                  color: progress >= 1.0 ? Colors.green : const Color(0xFFB44F4F),
                  minHeight: 6,
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

  const ChecklistFormScreen({
    super.key,
    this.existing,
    required this.template,
  });

  @override
  State<ChecklistFormScreen> createState() => _ChecklistFormScreenState();
}

class _ChecklistFormScreenState extends State<ChecklistFormScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Map<String, bool> _checks = {};
  Map<String, String> _remarks = {};
  final Map<String, TextEditingController> _remarkCtrls = {};
  bool _isSaving = false;
  DateTime? _submittedAt;
  String? _savedDocId;
  String? _userName;

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
    _loadUserName();
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
    _checks = Map<String, bool>.from(
      (data['checks'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as bool)) ??
          {});
    _remarks = Map<String, String>.from(
      (data['remarks'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as String)) ??
          {});
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
        'remarks': _remarks,
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
        title: Text(isEdit ? '점검표 수정' : '점검표 작성'),
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
            color: const Color(0xFFB44F4F).withValues(alpha: 0.08),
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
                    color: Color(0xFFB44F4F),
                  ),
                ),
              ],
            ),
          ),
          LinearProgressIndicator(
            value: _totalItems > 0 ? _checkedItems / _totalItems : 0,
            backgroundColor: Colors.grey.shade200,
            color: const Color(0xFFB44F4F),
            minHeight: 4,
          ),
          // 목록
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _locations.length,
              itemBuilder: (_, i) => _buildLocationCard(_locations[i]),
            ),
          ),
          // 저장 버튼
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
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB44F4F)),
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
              color: const Color(0xFFB44F4F).withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 26, height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFB44F4F), shape: BoxShape.circle,
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
          return CheckboxListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            value: checked,
            onChanged: (val) => setState(() => _checks[cKey] = val ?? false),
            title: Text(item.content,
                style: TextStyle(
                  fontSize: 12,
                  color: checked ? Colors.grey.shade400 : Colors.black87,
                  decoration: checked ? TextDecoration.lineThrough : null,
                )),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: const Color(0xFFB44F4F),
          );
        }),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
          child: TextField(
            controller: ctrl,
            maxLines: null,
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
      ],
    );
  }
}
