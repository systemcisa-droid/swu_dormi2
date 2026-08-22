import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

const _kWorkTypes = ['행정실 업무', '입사 업무', '관내 점검', '인원 점검', '화재 대피훈련'];

class InternLogScreen extends StatefulWidget {
  const InternLogScreen({super.key});

  @override
  State<InternLogScreen> createState() => _InternLogScreenState();
}

class _InternLogScreenState extends State<InternLogScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadLogs();
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

  Future<void> _loadLogs() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await _firestore
          .collection('intern_logs')
          .where('uid', isEqualTo: uid)
          .get();
      final docs = snap.docs.map((d) {
        final data = d.data();
        data['_id'] = d.id;
        return data;
      }).toList();
      docs.sort((a, b) {
        final aT = (a['workDate'] as Timestamp?)?.toDate() ?? DateTime(0);
        final bT = (b['workDate'] as Timestamp?)?.toDate() ?? DateTime(0);
        return bT.compareTo(aT);
      });
      if (mounted) setState(() { _logs = docs; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 전체 누적시간 = 모든 로그의 workHours 합산
  double _computeAccumulated({String? excludeId}) {
    double total = 0;
    for (final log in _logs) {
      if (excludeId != null && log['_id'] == excludeId) continue;
      total += (log['workHours'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  /// 자정 기준 분 단위를 'HH:mm' 로 변환한다.
  /// TimeOfDay 는 hour 24 를 표현할 수 없어 분 단위로 다룬다 (24:00 = 1440).
  String _formatMinutes(int totalMinutes) {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// 'HH:mm' 문자열을 자정 기준 분으로 변환한다. 실패 시 기본값 반환.
  int _parseMinutes(String? value, int fallback) {
    if (value == null) return fallback;
    final parts = value.split(':');
    if (parts.length != 2) return fallback;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return fallback;
    return h * 60 + m;
  }

  double _calcHours(int startMinutes, int endMinutes) {
    final mins = endMinutes - startMinutes;
    return mins > 0 ? mins / 60.0 : 0;
  }

  Future<void> _showAddDialog({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final editId = existing?['_id'] as String?;

    DateTime workDate = (existing?['workDate'] as Timestamp?)?.toDate() ?? DateTime.now();

    // 기존 시작/종료 시각 파싱 (자정 기준 분 단위)
    int startTime = _parseMinutes(existing?['startTime'] as String?, 9 * 60);
    int endTime = _parseMinutes(existing?['endTime'] as String?, 18 * 60);

    // 기존 업무내용 선택 목록
    final existingTypes = existing?['workTypes'] is List
        ? Set<String>.from((existing!['workTypes'] as List).map((e) => e as String))
        : <String>{};
    // 기타 항목 분리 (_kWorkTypes에 없는 항목)
    final etcInitial = existingTypes
        .where((t) => !_kWorkTypes.contains(t))
        .join(', ');
    final selectedTypes = Set<String>.from(
        existingTypes.where((t) => _kWorkTypes.contains(t)));
    final etcCtrl = TextEditingController(text: etcInitial);
    bool etcChecked = etcInitial.isNotEmpty;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final workHours = _calcHours(startTime, endTime);
          final accumulated = _computeAccumulated(excludeId: editId) + workHours;

          Future<void> pickTime(bool isStart) async {
            // 기본 showTimePicker 는 24:00 을 허용하지 않으므로 직접 입력받는다.
            final picked = await _showHourMinuteDialog(
              ctx,
              initialMinutes: isStart ? startTime : endTime,
              title: isStart ? '시작시간' : '종료시간',
            );
            if (picked != null) {
              setDialogState(() {
                if (isStart) { startTime = picked; }
                else { endTime = picked; }
              });
            }
          }

          return AlertDialog(
            title: Text(isEdit ? '근무일지 수정' : '근무일지 작성'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 작성일시
                  const Text('작성일시', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: workDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked != null) setDialogState(() => workDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('yyyy년 MM월 dd일 (E)', 'ko').format(workDate),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 근무시간 (시작 ~ 종료)
                  const Text('근무시간', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _TimePickerButton(
                          label: '시작',
                          timeLabel: _formatMinutes(startTime),
                          onTap: () => pickTime(true),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('~', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        child: _TimePickerButton(
                          label: '종료',
                          timeLabel: _formatMinutes(endTime),
                          onTap: () => pickTime(false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 14, color: Colors.blue),
                        const SizedBox(width: 6),
                        Text(
                          '근무시간: ${workHours.toStringAsFixed(1)}시간 '
                          '(${(workHours * 60).toInt()}분)',
                          style: const TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 업무내용 (다중선택)
                  const Text('업무내용', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  ...(_kWorkTypes.map((type) => CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(type, style: const TextStyle(fontSize: 14)),
                    value: selectedTypes.contains(type),
                    onChanged: (val) {
                      setDialogState(() {
                        if (val == true) { selectedTypes.add(type); }
                        else { selectedTypes.remove(type); }
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ))),
                  // 기타
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('기타', style: TextStyle(fontSize: 14)),
                    value: etcChecked,
                    onChanged: (val) {
                      setDialogState(() => etcChecked = val ?? false);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (etcChecked) ...[
                    const SizedBox(height: 4),
                    TextField(
                      controller: etcCtrl,
                      decoration: const InputDecoration(
                        hintText: '기타 업무 내용을 입력하세요',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // 누적시간 (자동 계산, 읽기 전용)
                  const Text('누적시간', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA6BF96).withValues(alpha: 0.06),
                      border: Border.all(color: const Color(0xFFA6BF96).withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_filled, size: 16, color: Color(0xFFA6BF96)),
                        const SizedBox(width: 8),
                        Text(
                          '${accumulated.toStringAsFixed(1)}시간',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFA6BF96),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(이전 ${_computeAccumulated(excludeId: editId).toStringAsFixed(1)} + 이번 ${workHours.toStringAsFixed(1)})',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () {
                  final etcText = etcCtrl.text.trim();
                  final allTypes = [
                    ...selectedTypes,
                    if (etcChecked && etcText.isNotEmpty) etcText,
                  ];
                  if (allTypes.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('업무내용을 하나 이상 선택하세요')),
                    );
                    return;
                  }
                  if (workHours <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('종료시간이 시작시간보다 늦어야 합니다')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  _saveLog(
                    id: editId,
                    workDate: workDate,
                    startTime: startTime,
                    endTime: endTime,
                    workHours: workHours,
                    workTypes: allTypes,
                    accumulatedHours: accumulated,
                  );
                },
                child: Text(isEdit ? '수정' : '저장'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveLog({
    String? id,
    required DateTime workDate,
    required int startTime,
    required int endTime,
    required double workHours,
    required List<String> workTypes,
    required double accumulatedHours,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final payload = <String, dynamic>{
        'uid': uid,
        'workDate': Timestamp.fromDate(workDate),
        'startTime': _formatMinutes(startTime),
        'endTime': _formatMinutes(endTime),
        'workHours': workHours,
        'workTypes': workTypes,
        'accumulatedHours': accumulatedHours,
        'updatedAt': Timestamp.now(),
      };
      if (id != null) {
        await _firestore.collection('intern_logs').doc(id).update(payload);
      } else {
        payload['createdAt'] = Timestamp.now();
        await _firestore.collection('intern_logs').doc().set(payload);
      }
      await _loadLogs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 오류: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteLog(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제'),
        content: const Text('이 근무일지를 삭제하시겠습니까?'),
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
      await _firestore.collection('intern_logs').doc(id).delete();
      await _loadLogs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 오류: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalHours = _computeAccumulated();
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  color: const Color(0xFFA6BF96).withValues(alpha: 0.08),
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: Color(0xFFA6BF96), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        _userName != null && _userName!.isNotEmpty
                            ? '작성자: $_userName'
                            : '인턴근무일지',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFFA6BF96),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(총 ${_logs.length}건)',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const Spacer(),
                      Text(
                        '누적 ${totalHours.toStringAsFixed(1)}시간',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFFA6BF96),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _logs.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('작성된 근무일지가 없습니다', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadLogs,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _logs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) => _buildLogCard(_logs[i]),
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(),
        icon: const Icon(Icons.add),
        label: const Text('작성'),
        backgroundColor: const Color(0xFFA6BF96),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final id = log['_id'] as String;
    final workDate = (log['workDate'] as Timestamp?)?.toDate();
    final startTime = log['startTime'] as String?;
    final endTime = log['endTime'] as String?;
    final workHours = (log['workHours'] as num?)?.toDouble();
    final accHours = (log['accumulatedHours'] as num?)?.toDouble();
    final workTypes = log['workTypes'] is List
        ? (log['workTypes'] as List).map((e) => e as String).toList()
        : <String>[];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 날짜 + 근무시간 + 메뉴
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA6BF96).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    workDate != null ? DateFormat('yyyy.MM.dd (E)', 'ko').format(workDate) : '-',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFFA6BF96),
                    ),
                  ),
                ),
                const Spacer(),
                if (workHours != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${workHours.toStringAsFixed(1)}시간',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') _showAddDialog(existing: log);
                    if (v == 'delete') _deleteLog(id);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [Icon(Icons.edit, size: 18, color: Colors.blue), SizedBox(width: 8), Text('수정')]),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('삭제', style: TextStyle(color: Colors.red))]),
                    ),
                  ],
                  icon: const Icon(Icons.more_vert, size: 18),
                ),
              ],
            ),
            // 시작~종료 시각
            if (startTime != null && endTime != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('$startTime ~ $endTime', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ],
            // 업무내용 칩
            if (workTypes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: workTypes.map((t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                  ),
                  child: Text(t, style: const TextStyle(fontSize: 12, color: Colors.teal)),
                )).toList(),
              ),
            ],
            // 누적시간
            if (accHours != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time_filled, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('누적 ${accHours.toStringAsFixed(1)}시간',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 시/분을 직접 입력받는 다이얼로그. 자정 기준 분 단위를 주고받는다.
///
/// 기본 [showTimePicker] 는 시(hour)를 0~23 으로 제한해 24:00 을 입력할 수 없다.
/// 근무 종료시각을 24:00 으로 적는 경우가 있어 직접 입력 폼을 사용한다.
Future<int?> _showHourMinuteDialog(
  BuildContext context, {
  required int initialMinutes,
  required String title,
}) {
  return showDialog<int>(
    context: context,
    builder: (ctx) => _HourMinuteDialog(
      initialMinutes: initialMinutes,
      title: title,
    ),
  );
}

/// 컨트롤러의 생명주기를 위젯이 직접 관리한다.
/// (다이얼로그가 닫히는 애니메이션 도중에도 TextField 가 살아 있으므로
///  showDialog 반환 직후 dispose 하면 안 된다)
class _HourMinuteDialog extends StatefulWidget {
  final int initialMinutes;
  final String title;

  const _HourMinuteDialog({
    required this.initialMinutes,
    required this.title,
  });

  @override
  State<_HourMinuteDialog> createState() => _HourMinuteDialogState();
}

class _HourMinuteDialogState extends State<_HourMinuteDialog> {
  late final TextEditingController _hourCtrl;
  late final TextEditingController _minuteCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _hourCtrl = TextEditingController(
        text: (widget.initialMinutes ~/ 60).toString().padLeft(2, '0'));
    _minuteCtrl = TextEditingController(
        text: (widget.initialMinutes % 60).toString().padLeft(2, '0'));
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final h = int.tryParse(_hourCtrl.text.trim());
    final m = int.tryParse(_minuteCtrl.text.trim());
    if (h == null || m == null || h < 0 || h > 24 || m < 0 || m > 59) {
      setState(() => _error = '유효한 시간을 입력하세요');
      return;
    }
    // 24시는 24:00 만 허용한다.
    if (h == 24 && m != 0) {
      setState(() => _error = '24시는 24:00 만 입력할 수 있습니다');
      return;
    }
    Navigator.pop(context, h * 60 + m);
  }

  Widget _numberField(TextEditingController ctrl, {bool autofocus = false}) {
    return SizedBox(
      width: 70,
      child: TextField(
        controller: ctrl,
        autofocus: autofocus,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 2,
        style: const TextStyle(fontSize: 28),
        decoration: const InputDecoration(
          counterText: '',
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _numberField(_hourCtrl, autofocus: true),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(':',
                    style:
                        TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              ),
              _numberField(_minuteCtrl),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _error ?? '00:00 ~ 24:00 사이로 입력하세요',
            style: TextStyle(
              fontSize: 12,
              color: _error != null ? Colors.red : Colors.grey.shade600,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('확인'),
        ),
      ],
    );
  }
}

class _TimePickerButton extends StatelessWidget {
  final String label;
  final String timeLabel;
  final VoidCallback onTap;

  const _TimePickerButton({required this.label, required this.timeLabel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = timeLabel;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.access_time, size: 15, color: Colors.grey),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
