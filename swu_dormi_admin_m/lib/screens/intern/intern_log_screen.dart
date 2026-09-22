import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

const _kWorkTypes = ['행정실 업무', '입사 업무', '관내 점검', '인원 점검', '화재 대피훈련'];

/// 근무시간을 표시용 문자열로 변환한다.
/// 22:00~24:00 심야 1.5배 가산으로 0.75시간처럼 소수점 둘째 자리가 필요한 값이 생기므로,
/// 정수·1자리는 그대로, 그 외에는 둘째 자리까지 보여준다 (예: 3 → "3", 0.5 → "0.5", 0.75 → "0.75").
String _formatHours(double hours) {
  final rounded2 = (hours * 100).round() / 100;
  if (rounded2 == rounded2.roundToDouble()) return rounded2.toStringAsFixed(0);
  final rounded1 = (hours * 10).round() / 10;
  if (rounded1 == rounded2) return rounded1.toStringAsFixed(1);
  return rounded2.toStringAsFixed(2);
}

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
      // 최신순(내림차순) 표시. 누적 계산과 같은 기준을 쓰도록 _logCompare 를 뒤집는다.
      docs.sort((a, b) => -_logCompare(a, b));
      if (mounted) setState(() { _logs = docs; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 근무일지 정렬 기준: 날짜 → 시작시간 → 문서 id (오름차순, 오래된 것이 먼저).
  /// 표시(_loadLogs)는 이걸 뒤집어 최신순으로, 누적 계산(_runningTotals)은 그대로 쓴다.
  /// 두 곳이 같은 기준을 써야 리스트 순서와 누적값이 어긋나지 않는다.
  static int _logCompare(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aT = (a['workDate'] as Timestamp?)?.toDate() ?? DateTime(0);
    final bT = (b['workDate'] as Timestamp?)?.toDate() ?? DateTime(0);
    // 날짜만 비교 (workDate 에 시각이 섞여 있어도 같은 날은 동일 취급)
    final aDay = DateTime(aT.year, aT.month, aT.day);
    final bDay = DateTime(bT.year, bT.month, bT.day);
    final byDay = aDay.compareTo(bDay);
    if (byDay != 0) return byDay;
    final aStart = (a['startTime'] as String?) ?? '';
    final bStart = (b['startTime'] as String?) ?? '';
    final byStart = aStart.compareTo(bStart);
    if (byStart != 0) return byStart;
    return (a['_id'] as String? ?? '').compareTo(b['_id'] as String? ?? '');
  }

  /// 로그 하나의 인정 근무시간을 반환한다. 시작~종료 시각이 있으면 심야 가산을
  /// 포함해 실시간으로 다시 계산하고(옛 데이터에 저장된 workHours가 가산 반영 전
  /// 값일 수 있으므로), 없으면 저장된 workHours 를 그대로 쓴다.
  double _effectiveHours(Map<String, dynamic> log) {
    final start = _parseMinutes(log['startTime'] as String?, -1);
    final end = _parseMinutes(log['endTime'] as String?, -1);
    if (start >= 0 && end >= 0) return _calcHours(start, end);
    return (log['workHours'] as num?)?.toDouble() ?? 0;
  }

  // 전체 누적시간 = 모든 로그의 인정 근무시간 합산
  double _computeAccumulated({String? excludeId}) {
    double total = 0;
    for (final log in _logs) {
      if (excludeId != null && log['_id'] == excludeId) continue;
      total += _effectiveHours(log);
    }
    return total;
  }

  /// 각 로그의 '그 날짜까지의 누적시간'을 실시간 계산한다.
  /// 저장된 accumulatedHours/workHours 필드는 심야 가산 반영 전의 옛 스냅샷일 수 있으므로
  /// 쓰지 않고, 시작~종료 시각으로 매번 다시 계산해 합산한다.
  /// 반환: 문서 id → (오래된 순으로 자기 자신 포함 러닝 합계)
  Map<String, double> _runningTotals() {
    final sorted = [..._logs]..sort(_logCompare);
    final result = <String, double>{};
    double running = 0;
    for (final log in sorted) {
      running += _effectiveHours(log);
      result[log['_id'] as String] = running;
    }
    return result;
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

  /// 22:00~24:00(심야) 구간 근무는 1.5배로 가산 인정한다.
  /// 예: 22:00~24:00 근무(2시간) → 인정 3.0시간. 21:00~23:00처럼 걸치는 경우도
  /// 심야 구간(22:00~23:00)만 1.5배를 적용해 정확히 계산한다.
  static const _nightStartMinutes = 22 * 60; // 22:00
  static const _nightEndMinutes = 24 * 60; // 24:00(자정)
  static const _nightMultiplier = 1.5;

  double _calcHours(int startMinutes, int endMinutes) {
    final b = _calcHoursBreakdown(startMinutes, endMinutes);
    return b.base + b.bonus;
  }

  /// 근무시간을 '기본(정상 시급 환산 시간)'과 '가산분(심야 1.5배로 추가된 시간)'으로 나눠 반환한다.
  /// 예: 23:30~24:00(30분, 전부 심야) → base 0.5, bonus 0.25 (0.5시간의 절반이 가산).
  ({double base, double bonus}) _calcHoursBreakdown(int startMinutes, int endMinutes) {
    if (endMinutes <= startMinutes) return (base: 0, bonus: 0);
    final overlapStart = startMinutes < _nightStartMinutes ? _nightStartMinutes : startMinutes;
    final overlapEnd = endMinutes > _nightEndMinutes ? _nightEndMinutes : endMinutes;
    final nightMinutes = overlapEnd > overlapStart ? overlapEnd - overlapStart : 0;
    final normalMinutes = (endMinutes - startMinutes) - nightMinutes;
    final base = normalMinutes / 60.0 + nightMinutes / 60.0;
    final bonus = (nightMinutes / 60.0) * (_nightMultiplier - 1);
    return (base: base, bonus: bonus);
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
          final rawHours = (endTime - startTime) > 0 ? (endTime - startTime) / 60.0 : 0.0;
          final hasNightBonus = workHours > rawHours;
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.timer_outlined, size: 14, color: Colors.blue),
                            const SizedBox(width: 6),
                            Text(
                              hasNightBonus
                                  ? '인정 근무시간: ${_formatHours(workHours)}시간'
                                  : '근무시간: ${_formatHours(workHours)}시간 '
                                      '(${(workHours * 60).toInt()}분)',
                              style: const TextStyle(fontSize: 12, color: Colors.blue),
                            ),
                          ],
                        ),
                        if (hasNightBonus) ...[
                          const SizedBox(height: 4),
                          Text(
                            '실제 근무 ${_formatHours(rawHours)}시간 '
                            '(22:00~24:00 구간 1.5배 가산 적용)',
                            style: TextStyle(fontSize: 11, color: Colors.blue.shade300),
                          ),
                        ],
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

                  // 전체 누적시간 (이 일지 저장 후 총 근무시간, 읽기 전용)
                  const Text('전체 누적시간', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
                          '${_formatHours(accumulated)}시간',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFA6BF96),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(기존 ${_formatHours(_computeAccumulated(excludeId: editId))} + 이번 ${_formatHours(workHours)})',
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
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      // accumulatedHours 는 저장하지 않는다 — 누적시간은 화면에서 날짜순으로 실시간 계산한다.
      final payload = <String, dynamic>{
        'uid': uid,
        'workDate': Timestamp.fromDate(workDate),
        'startTime': _formatMinutes(startTime),
        'endTime': _formatMinutes(endTime),
        'workHours': workHours,
        'workTypes': workTypes,
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
                        '누적 ${_formatHours(totalHours)}시간',
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
                      : Builder(builder: (context) {
                          final running = _runningTotals();
                          return RefreshIndicator(
                            onRefresh: _loadLogs,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: _logs.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, i) => _buildLogCard(
                                _logs[i],
                                running[_logs[i]['_id']] ?? 0,
                              ),
                            ),
                          );
                        }),
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

  Widget _buildLogCard(Map<String, dynamic> log, double accHours) {
    final id = log['_id'] as String;
    final workDate = (log['workDate'] as Timestamp?)?.toDate();
    final startTime = log['startTime'] as String?;
    final endTime = log['endTime'] as String?;
    final workHours = (log['workHours'] as num?)?.toDouble();
    final workTypes = log['workTypes'] is List
        ? (log['workTypes'] as List).map((e) => e as String).toList()
        : <String>[];

    // 저장된 workHours 는 이미 심야 가산이 반영된 합계이므로, 시작~종료 시각으로
    // 기본/가산 분을 다시 나눠 뱃지에 "0.5 + 0.25(가산)" 형태로 보여준다.
    double? bonusHours;
    double? baseHours;
    if (startTime != null && endTime != null) {
      final s = _parseMinutes(startTime, -1);
      final e = _parseMinutes(endTime, -1);
      if (s >= 0 && e >= 0) {
        final breakdown = _calcHoursBreakdown(s, e);
        if (breakdown.bonus > 0) {
          baseHours = breakdown.base;
          bonusHours = breakdown.bonus;
        }
      }
    }

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
                      bonusHours != null && baseHours != null
                          ? '${_formatHours(baseHours)}+${_formatHours(bonusHours)}(가산)'
                          : '${_formatHours(workHours)}시간',
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
            // 22:00~24:00 심야 가산 안내
            if (bonusHours != null) ...[
              const SizedBox(height: 4),
              Text(
                '22:00~24:00 근무는 1.5배 인정 (가산 ${_formatHours(bonusHours)}시간)',
                style: TextStyle(fontSize: 11, color: Colors.blue.shade300),
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
            // 누적시간 (해당 날짜까지의 러닝 합계)
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time_filled, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text('누적 ${_formatHours(accHours)}시간',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
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
