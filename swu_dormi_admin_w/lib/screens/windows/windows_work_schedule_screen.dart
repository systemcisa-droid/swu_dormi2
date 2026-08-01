import 'package:fluent_ui/fluent_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ── 상수 ────────────────────────────────────────────────────────
const _shifts = ['주간', '야간', '당직', '반차', '휴무'];
const _shiftColors = {
  '주간': Color(0xFF2196F3),
  '야간': Color(0xFF3F51B5),
  '반차': Color(0xFF8BC34A),
  '당직': Color(0xFFFF9800),
  '휴무': Color(0xFFFFC107),
};

const _roles = ['실장', '직원', '근로학생'];
const _roleColors = {
  '실장': Color(0xFF1565C0),
  '직원': Color(0xFF2E7D32),
  '근로학생': Color(0xFF6A1B9A),
};
const _roleIcons = {
  '실장': FluentIcons.manager_self_service,
  '직원': FluentIcons.contact,
  '근로학생': FluentIcons.education,
};

class WindowsWorkScheduleScreen extends StatefulWidget {
  const WindowsWorkScheduleScreen({super.key});

  @override
  State<WindowsWorkScheduleScreen> createState() =>
      _WindowsWorkScheduleScreenState();
}

class _WindowsWorkScheduleScreenState
    extends State<WindowsWorkScheduleScreen> {
  DateTime _focusedMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);

  final ScrollController _orgScrollController = ScrollController();
  final ScrollController _listScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToToday();
    });
  }

  @override
  void dispose() {
    _orgScrollController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  // 오늘 날짜로 스크롤 (오늘 위로 3일 여유)
  void _scrollToToday() {
    final today = DateTime.now();
    if (_focusedMonth.year != today.year ||
        _focusedMonth.month != today.month) {
      return;
    }
    final targetIndex = (today.day - 4).clamp(0, today.day - 1);
    // 카드 평균 높이(헤더+내용+마진) ≈ 78px
    _listScrollController.jumpTo(targetIndex * 78.0);
  }

  // ── 월 이동 ──────────────────────────────────────────────────
  void _prevMonth() => setState(() {
        _focusedMonth =
            DateTime(_focusedMonth.year, _focusedMonth.month - 1);
      });

  void _nextMonth() => setState(() {
        _focusedMonth =
            DateTime(_focusedMonth.year, _focusedMonth.month + 1);
      });

  // ── 이번 달의 날짜 목록 ──────────────────────────────────────
  List<DateTime> _getDaysOfMonth(DateTime month) {
    final daysInMonth =
        DateTime(month.year, month.month + 1, 0).day;
    return List.generate(
      daysInMonth,
      (i) => DateTime(month.year, month.month, i + 1),
    );
  }

  // ── 스냅샷 → scheduleMap 변환 ───────────────────────────────
  Map<DateTime, List<Map<String, dynamic>>> _buildScheduleMap(
      QuerySnapshot snap) {
    final map = <DateTime, List<Map<String, dynamic>>>{};
    for (final doc in snap.docs) {
      final d = doc.data() as Map<String, dynamic>;
      final ts = d['date'] as Timestamp?;
      if (ts == null) continue;
      final dt = ts.toDate();
      final key = DateTime(dt.year, dt.month, dt.day);
      map.putIfAbsent(key, () => []).add({'id': doc.id, ...d});
    }
    return map;
  }

  // ── 멤버 정렬 ────────────────────────────────────────────────
  List<Map<String, dynamic>> _sortedMembers(
      List<Map<String, dynamic>> members) {
    final sorted = [...members];
    sorted.sort((a, b) {
      final ri = _roles.indexOf(a['role'] as String? ?? '');
      final rj = _roles.indexOf(b['role'] as String? ?? '');
      if (ri != rj) return ri.compareTo(rj);
      return (a['name'] as String? ?? '')
          .compareTo(b['name'] as String? ?? '');
    });
    return sorted;
  }

  // ── 근무 일정 저장/삭제 ──────────────────────────────────────
  Future<void> _saveSchedule({
    String? id,
    required DateTime date,
    required String shift,
    required String workerName,
    required String startTime,
    required String endTime,
    required String note,
  }) async {
    try {
      final data = <String, dynamic>{
        'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
        'shift': shift,
        'workerName': workerName,
        'startTime': startTime,
        'endTime': endTime,
        'note': note,
        'updatedAt': Timestamp.now(),
      };
      final col =
          FirebaseFirestore.instance.collection('work_schedules');
      if (id == null) {
        data['createdAt'] = Timestamp.now();
        await col.add(data);
      } else {
        await col.doc(id).update(data);
      }
    } catch (e) {
      if (mounted) {
        await displayInfoBar(context,
            builder: (c, _) => InfoBar(
                title: Text('오류: $e'),
                severity: InfoBarSeverity.error));
      }
    }
  }

  Future<void> _deleteSchedule(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection('work_schedules')
          .doc(id)
          .delete();
    } catch (e) {
      if (mounted) {
        await displayInfoBar(context,
            builder: (c, _) => InfoBar(
                title: Text('오류: $e'),
                severity: InfoBarSeverity.error));
      }
    }
  }

  // ── 구성원 저장/삭제 ─────────────────────────────────────────
  Future<void> _saveMember({
    String? id,
    required String role,
    required String name,
    required String phone,
    required String email,
    required String note,
    required String defaultShift,
    required String defaultStartTime,
    required String defaultEndTime,
  }) async {
    try {
      final data = <String, dynamic>{
        'role': role,
        'name': name,
        'phone': phone,
        'email': email,
        'note': note,
        'order': _roles.indexOf(role),
        'defaultShift': defaultShift,
        'defaultStartTime': defaultStartTime,
        'defaultEndTime': defaultEndTime,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final col = FirebaseFirestore.instance.collection('organization');
      if (id == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await col.add(data);
      } else {
        await col.doc(id).update(data);
      }
    } catch (e) {
      if (mounted) {
        await displayInfoBar(context,
            builder: (c, _) => InfoBar(
                title: Text('오류: $e'),
                severity: InfoBarSeverity.error));
      }
    }
  }

  // ── 특정 날짜 하루 자동등록 ────────────────────────────────────
  Future<void> _autoRegisterDay(
    DateTime day,
    List<Map<String, dynamic>> members,
  ) async {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = DateTime(day.year, day.month, day.day + 1);
    final existing = await FirebaseFirestore.instance
        .collection('work_schedules')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('date', isLessThan: Timestamp.fromDate(dayEnd))
        .get();

    final existingNames = <String>{};
    for (final doc in existing.docs) {
      final name = doc.data()['workerName'] as String? ?? '';
      if (name.isNotEmpty) existingNames.add(name);
    }

    final batch = FirebaseFirestore.instance.batch();
    int count = 0;

    for (final member in members) {
      final name = member['name'] as String? ?? '';
      final shift = member['defaultShift'] as String? ?? '';
      if (name.isEmpty || shift.isEmpty) continue;
      if (existingNames.contains(name)) continue;

      final ref =
          FirebaseFirestore.instance.collection('work_schedules').doc();
      batch.set(ref, {
        'date': Timestamp.fromDate(dayStart),
        'workerName': name,
        'shift': shift,
        'startTime': member['defaultStartTime'] as String? ?? '',
        'endTime': member['defaultEndTime'] as String? ?? '',
        'note': '',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
      count++;
    }

    if (count == 0) {
      if (mounted) {
        await displayInfoBar(context,
            builder: (c, _) => const InfoBar(
                title: Text('이미 모든 일정이 등록되어 있습니다.'),
                severity: InfoBarSeverity.info));
      }
      return;
    }

    try {
      await batch.commit();
      if (mounted) {
        await displayInfoBar(context,
            builder: (c, _) => InfoBar(
                title: Text('$count명의 근무 일정이 자동 등록되었습니다.'),
                severity: InfoBarSeverity.success));
      }
    } catch (e) {
      if (mounted) {
        await displayInfoBar(context,
            builder: (c, _) => InfoBar(
                title: Text('자동등록 오류: $e'),
                severity: InfoBarSeverity.error));
      }
    }
  }

  Future<void> _deleteMember(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection('organization')
          .doc(id)
          .delete();
    } catch (e) {
      if (mounted) {
        await displayInfoBar(context,
            builder: (c, _) => InfoBar(
                title: Text('오류: $e'),
                severity: InfoBarSeverity.error));
      }
    }
  }

  // ── 근무 일정 다이얼로그 ─────────────────────────────────────
  Future<void> _showAddEditScheduleDialog({
    Map<String, dynamic>? schedule,
    DateTime? initialDate,
    List<Map<String, dynamic>> members = const [],
  }) async {
    final isEdit = schedule != null;
    DateTime pickedDate;
    if (isEdit) {
      final raw = schedule['date'];
      if (raw is DateTime) {
        pickedDate = raw;
      } else if (raw is Timestamp) {
        pickedDate = raw.toDate();
      } else {
        pickedDate = DateTime.now();
      }
    } else {
      pickedDate = initialDate ?? DateTime.now();
    }

    String selShift =
        isEdit ? (schedule['shift'] as String? ?? '주간') : '주간';
    final nameCtrl = TextEditingController(
        text: isEdit ? schedule['workerName'] as String? ?? '' : '');
    final startCtrl = TextEditingController(
        text: isEdit ? schedule['startTime'] as String? ?? '' : '09:00');
    final endCtrl = TextEditingController(
        text: isEdit ? schedule['endTime'] as String? ?? '' : '17:30');
    final noteCtrl = TextEditingController(
        text: isEdit ? schedule['note'] as String? ?? '' : '');

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => ContentDialog(
          title: Text(isEdit ? '근무 일정 수정' : '근무 일정 추가'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('날짜',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DatePicker(
                    selected: pickedDate,
                    onChanged: (d) => setD(() => pickedDate = d),
                  ),
                  const SizedBox(height: 16),
                  const Text('근무자 이름',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  members.isNotEmpty
                      ? ComboBox<String>(
                          value: nameCtrl.text.isNotEmpty
                              ? nameCtrl.text
                              : null,
                          placeholder: const Text('근무자를 선택하세요'),
                          items: members
                              .map((m) => ComboBoxItem<String>(
                                    value: m['name'] as String? ?? '',
                                    child:
                                        Text(m['name'] as String? ?? ''),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setD(() => nameCtrl.text = v);
                            }
                          },
                        )
                      : TextBox(
                          controller: nameCtrl,
                          placeholder: '근무자 이름을 입력하세요'),
                  const SizedBox(height: 16),
                  const Text('근무 형태',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: _shifts.map((shift) {
                      final color = _shiftColors[shift]!;
                      final sel = selShift == shift;
                      return GestureDetector(
                        onTap: () => setD(() => selShift = shift),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: sel
                                ? color.withValues(alpha: 0.15)
                                : Colors.grey.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: sel
                                  ? color
                                  : Colors.grey.withValues(alpha: 0.25),
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          child: Text(shift,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: sel ? color : null,
                                  fontWeight: sel
                                      ? FontWeight.w600
                                      : FontWeight.normal)),
                        ),
                      );
                    }).toList(),
                  ),
                  if (selShift != '휴무') ...[
                    const SizedBox(height: 16),
                    const Text('근무 시간',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextBox(
                            controller: startCtrl,
                            placeholder: '09:00',
                            prefix: const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Text('시작',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('~'),
                        ),
                        Expanded(
                          child: TextBox(
                            controller: endCtrl,
                            placeholder: '17:30',
                            prefix: const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Text('종료',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text('메모',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextBox(
                      controller: noteCtrl,
                      placeholder: '메모 (선택)',
                      maxLines: 2),
                ],
              ),
            ),
          ),
          actions: [
            if (isEdit)
              Button(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(
                      Colors.red.withValues(alpha: 0.1)),
                ),
                child: Text('삭제', style: TextStyle(color: Colors.red)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _deleteSchedule(schedule['id'] as String);
                },
              ),
            Button(
                child: const Text('취소'),
                onPressed: () => Navigator.pop(ctx)),
            FilledButton(
              child: Text(isEdit ? '저장' : '추가'),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                await _saveSchedule(
                  id: isEdit ? schedule['id'] as String : null,
                  date: pickedDate,
                  shift: selShift,
                  workerName: name,
                  startTime:
                      selShift == '휴무' ? '' : startCtrl.text.trim(),
                  endTime:
                      selShift == '휴무' ? '' : endCtrl.text.trim(),
                  note: noteCtrl.text.trim(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── 구성원 다이얼로그 ─────────────────────────────────────────
  Future<void> _showAddEditMemberDialog({
    Map<String, dynamic>? member,
    String? defaultRole,
  }) async {
    final isEdit = member != null;
    String selRole =
        isEdit ? (member['role'] as String? ?? '직원') : (defaultRole ?? '직원');
    // 기본근무 형태 (휴무 제외)
    const defaultableShifts = ['주간', '야간', '당직'];
    String selDefaultShift = isEdit
        ? (member['defaultShift'] as String? ?? '주간')
        : '주간';
    final nameCtrl = TextEditingController(
        text: isEdit ? member['name'] as String? ?? '' : '');
    final phoneCtrl = TextEditingController(
        text: isEdit ? member['phone'] as String? ?? '' : '');
    final emailCtrl = TextEditingController(
        text: isEdit ? member['email'] as String? ?? '' : '');
    final noteCtrl = TextEditingController(
        text: isEdit ? member['note'] as String? ?? '' : '');
    final startCtrl = TextEditingController(
        text: isEdit ? member['defaultStartTime'] as String? ?? '09:00' : '09:00');
    final endCtrl = TextEditingController(
        text: isEdit ? member['defaultEndTime'] as String? ?? '17:30' : '17:30');

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => ContentDialog(
          title: Text(isEdit ? '구성원 수정' : '구성원 추가'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('직책',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: _roles.map((role) {
                      final color = _roleColors[role]!;
                      final sel = selRole == role;
                      return GestureDetector(
                        onTap: () => setD(() => selRole = role),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: sel
                                ? color.withValues(alpha: 0.15)
                                : Colors.grey.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: sel
                                  ? color
                                  : Colors.grey.withValues(alpha: 0.25),
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          child: Text(role,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: sel ? color : null,
                                  fontWeight: sel
                                      ? FontWeight.w600
                                      : FontWeight.normal)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('이름',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextBox(
                      controller: nameCtrl,
                      placeholder: '이름을 입력하세요'),
                  const SizedBox(height: 14),
                  const Text('연락처',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextBox(
                      controller: phoneCtrl,
                      placeholder: '010-0000-0000 (선택)'),
                  const SizedBox(height: 14),
                  const Text('이메일',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextBox(
                      controller: emailCtrl,
                      placeholder: '이메일 (선택)'),
                  const SizedBox(height: 14),
                  const Text('메모',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextBox(
                      controller: noteCtrl,
                      placeholder: '메모 (선택)',
                      maxLines: 2),
                  const SizedBox(height: 18),
                  // ── 기본 근무 형태 ──────────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(FluentIcons.calendar_settings,
                              size: 13, color: Color(0xFF1976D2)),
                          const SizedBox(width: 6),
                          const Text('기본 근무 형태 (월~금 자동등록 시 사용)',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1976D2))),
                        ]),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          children: defaultableShifts.map((shift) {
                            final color = _shiftColors[shift]!;
                            final sel = selDefaultShift == shift;
                            return GestureDetector(
                              onTap: () =>
                                  setD(() => selDefaultShift = shift),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 100),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? color.withValues(alpha: 0.15)
                                      : Colors.grey.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: sel
                                        ? color
                                        : Colors.grey.withValues(alpha: 0.25),
                                    width: sel ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(shift,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: sel ? color : null,
                                        fontWeight: sel
                                            ? FontWeight.w600
                                            : FontWeight.normal)),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextBox(
                                controller: startCtrl,
                                placeholder: '09:00',
                                prefix: const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Text('시작',
                                      style: TextStyle(fontSize: 12)),
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text('~'),
                            ),
                            Expanded(
                              child: TextBox(
                                controller: endCtrl,
                                placeholder: '17:30',
                                prefix: const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Text('종료',
                                      style: TextStyle(fontSize: 12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (isEdit)
              Button(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(
                      Colors.red.withValues(alpha: 0.1)),
                ),
                child: Text('삭제', style: TextStyle(color: Colors.red)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _deleteMember(member['id'] as String);
                },
              ),
            Button(
                child: const Text('취소'),
                onPressed: () => Navigator.pop(ctx)),
            FilledButton(
              child: Text(isEdit ? '저장' : '추가'),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                await _saveMember(
                  id: isEdit ? member['id'] as String : null,
                  role: selRole,
                  name: name,
                  phone: phoneCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  note: noteCtrl.text.trim(),
                  defaultShift: selDefaultShift,
                  defaultStartTime: startCtrl.text.trim(),
                  defaultEndTime: endCtrl.text.trim(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: const Text('근무자 현황'),
        commandBar: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: () => _showAddEditMemberDialog(),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.add, size: 13),
                  SizedBox(width: 6),
                  Text('구성원 추가'),
                ],
              ),
            ),
          ],
        ),
      ),
      content: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('organization')
            .orderBy('order')
            .snapshots(),
        builder: (context, orgSnap) {
          final orgDocs = orgSnap.data?.docs ?? [];
          final allMembers = orgDocs
              .map((d) =>
                  {'id': d.id, ...(d.data() as Map<String, dynamic>)})
              .toList();
          final sortedMembers = _sortedMembers(allMembers);
          // 모든 구성원 자동등록 대상 (defaultShift 없으면 주간으로 기본 처리)
          final autoMembers = sortedMembers
              .where((m) => (m['name'] as String? ?? '').isNotEmpty)
              .map((m) => {
                    ...m,
                    'defaultShift':
                        (m['defaultShift'] as String? ?? '').isNotEmpty
                            ? m['defaultShift']
                            : '주간',
                    'defaultStartTime':
                        (m['defaultStartTime'] as String? ?? '').isNotEmpty
                            ? m['defaultStartTime']
                            : '09:00',
                    'defaultEndTime':
                        (m['defaultEndTime'] as String? ?? '').isNotEmpty
                            ? m['defaultEndTime']
                            : '17:30',
                  })
              .toList();
          final firstDay =
              DateTime(_focusedMonth.year, _focusedMonth.month, 1);
          final nextMonthFirst =
              DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('work_schedules')
                .where('date',
                    isGreaterThanOrEqualTo:
                        Timestamp.fromDate(firstDay))
                .where('date',
                    isLessThan: Timestamp.fromDate(nextMonthFirst))
                .snapshots(),
            builder: (context, schedSnap) {
              final scheduleMap = schedSnap.hasData
                  ? _buildScheduleMap(schedSnap.data!)
                  : <DateTime, List<Map<String, dynamic>>>{};

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 왼쪽: 조직도 ────────────────────────────
                  SizedBox(
                    width: 300,
                    child: _buildOrgPanel(sortedMembers, allMembers),
                  ),
                  Container(
                    width: 1,
                    color: FluentTheme.of(context)
                        .resources
                        .dividerStrokeColorDefault,
                  ),
                  // ── 오른쪽: 근무 일정 리스트 ─────────────────
                  Expanded(
                    child: _buildSchedulePanel(
                        sortedMembers, scheduleMap, autoMembers),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ── 왼쪽 조직도 패널 ──────────────────────────────────────────
  Widget _buildOrgPanel(
    List<Map<String, dynamic>> sortedMembers,
    List<Map<String, dynamic>> allMembers,
  ) {
    final byRole = <String, List<Map<String, dynamic>>>{};
    for (final role in _roles) {
      byRole[role] =
          allMembers.where((m) => m['role'] == role).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 헤더
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: FluentTheme.of(context).cardColor,
          child: Row(
            children: [
              const Icon(FluentIcons.org, size: 16),
              const SizedBox(width: 8),
              const Text('조직도',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${allMembers.length}명',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey)),
            ],
          ),
        ),
        Container(
          height: 1,
          color: FluentTheme.of(context)
              .resources
              .dividerStrokeColorDefault,
        ),
        // 스크롤 가능한 조직도 섹션
        Expanded(
          child: SingleChildScrollView(
            controller: _orgScrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildOrgSection('실장', byRole['실장'] ?? []),
                //_buildConnector(),
                const SizedBox(height: 16),
                _buildOrgSection('직원', byRole['직원'] ?? []),
               // _buildConnector(),
                const SizedBox(height: 16),
                _buildOrgSection('근로학생', byRole['근로학생'] ?? []),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrgSection(
      String role, List<Map<String, dynamic>> members) {
    final color = _roleColors[role]!;
    final icon = _roleIcons[role]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 직책 레이블
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 13, color: color),
                  const SizedBox(width: 5),
                  Text(role,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color)),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${members.length}명',
                        style: TextStyle(
                            fontSize: 10,
                            color: color,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 멤버 카드 목록
        if (members.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('등록된 $role 없음',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.withValues(alpha: 0.5))),
          )
        else
          ...members.map((m) => _buildCompactMemberCard(m, color)),
      ],
    );
  }

  Widget _buildCompactMemberCard(
      Map<String, dynamic> m, Color color) {
    final name = m['name'] as String? ?? '';
    final phone = m['phone'] as String? ?? '';
    final shift = m['defaultShift'] as String? ?? '';
    final shiftColor = _shiftColors[shift];

    return GestureDetector(
      onTap: () => _showAddEditMemberDialog(member: m),
      child: Container(
        height: 52,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: FluentTheme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                    color: color.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0] : '?',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(name,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (shift.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: (shiftColor ?? Colors.grey)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: (shiftColor ?? Colors.grey)
                                    .withValues(alpha: 0.4)),
                          ),
                          child: Text(shift,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: shiftColor ?? Colors.grey,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                  if (phone.isNotEmpty)
                    Text(phone,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey),
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(FluentIcons.chevron_right,
                size: 12, color: Colors.grey.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  // Widget _buildConnector() {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(vertical: 8),
  //     child: CustomPaint(
  //       size: const Size(double.infinity, 24),
  //       painter: _ConnectorPainter(),
  //     ),
  //   );
  // }

  // ── 오른쪽: 일별 리스트 패널 ──────────────────────────────────
  Widget _buildSchedulePanel(
    List<Map<String, dynamic>> workers,
    Map<DateTime, List<Map<String, dynamic>>> scheduleMap,
    List<Map<String, dynamic>> autoMembers,
  ) {
    final days = _getDaysOfMonth(_focusedMonth);
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final dowLabels = ['월', '화', '수', '목', '금', '토', '일'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 월 네비게이터 헤더 ──────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: FluentTheme.of(context).cardColor,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(FluentIcons.chevron_left, size: 14),
                onPressed: _prevMonth,
              ),
              const SizedBox(width: 4),
              Text(
                DateFormat('yyyy년 M월').format(_focusedMonth),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(FluentIcons.chevron_right, size: 14),
                onPressed: _nextMonth,
              ),
              const Spacer(),
              // 범례
              ..._shifts.map((s) {
                final color = _shiftColors[s]!;
                return Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(width: 3),
                      Text(s, style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        Container(
          height: 1,
          color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
        ),
        // ── 일별 리스트 ─────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            controller: _listScrollController,
            padding: const EdgeInsets.all(12),
            itemCount: days.length,
            itemBuilder: (_, i) {
              final day = days[i];
              final key = DateTime(day.year, day.month, day.day);
              final daySchedules = scheduleMap[key] ?? [];
              final isToday = key == todayKey;
              final isSunday = day.weekday == 7;
              final isSaturday = day.weekday == 6;
              final dowLabel = dowLabels[day.weekday - 1];

              // 실장→직원→근로학생, 주간→야간→당직→휴무 순 정렬
              int getRoleOrder(String name) {
                final m = workers.firstWhere(
                  (w) => w['name'] == name,
                  orElse: () => {},
                );
                final idx = _roles.indexOf(m['role'] as String? ?? '');
                return idx == -1 ? 99 : idx;
              }

              final sortedDay = [...daySchedules]..sort((a, b) {
                  final ra = getRoleOrder(a['workerName'] as String? ?? '');
                  final rb = getRoleOrder(b['workerName'] as String? ?? '');
                  if (ra != rb) return ra.compareTo(rb);
                  final sa = _shifts.indexOf(a['shift'] as String? ?? '');
                  final sb = _shifts.indexOf(b['shift'] as String? ?? '');
                  return (sa == -1 ? 99 : sa).compareTo(sb == -1 ? 99 : sb);
                });

              // 역할별 그룹핑
              final roleGrouped = <String, List<Map<String, dynamic>>>{};
              for (final s in sortedDay) {
                final name = s['workerName'] as String? ?? '';
                final m = workers.firstWhere(
                  (w) => w['name'] == name,
                  orElse: () => {},
                );
                final role = m['role'] as String? ?? '기타';
                roleGrouped.putIfAbsent(role, () => []).add(s);
              }

              final dateColor = isSunday
                  ? const Color(0xFFE53935)
                  : isSaturday
                      ? const Color(0xFFE57373)
                      : null;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isToday
                      ? const Color(0xFF00897B).withValues(alpha: 0.04)
                      : FluentTheme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isToday
                        ? const Color(0xFF00897B).withValues(alpha: 0.4)
                        : FluentTheme.of(context)
                            .resources
                            .dividerStrokeColorDefault,
                    width: isToday ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 날짜 헤더 행
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
                      child: Row(
                        children: [
                          // 날짜
                          if (isToday)
                            Container(
                              width: 26,
                              height: 26,
                              decoration: const BoxDecoration(
                                color: Color(0xFF00897B),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${day.day}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ),
                              ),
                            )
                          else
                            Text(
                              '${day.day}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: dateColor,
                              ),
                            ),
                          const SizedBox(width: 6),
                          Text(
                            '$dowLabel요일',
                            style: TextStyle(
                              fontSize: 12,
                              color: dateColor ??
                                  Colors.grey.withValues(alpha: 0.7),
                            ),
                          ),
                          if (isToday) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00897B)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('오늘',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF00897B),
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                          const Spacer(),
                          Text(
                            '${daySchedules.length}명',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.withValues(alpha: 0.6)),
                          ),
                          const SizedBox(width: 8),
                          // 자동생성 버튼
                          GestureDetector(
                            onTap: autoMembers.isEmpty
                                ? null
                                : () => _autoRegisterDay(day, autoMembers),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: const Color(0xFF00897B)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(FluentIcons.sync,
                                  size: 11, color: Color(0xFF00897B)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // 추가 버튼
                          GestureDetector(
                            onTap: () => _showAddEditScheduleDialog(
                              initialDate: day,
                              members: workers,
                            ),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(FluentIcons.add,
                                  size: 12, color: Color(0xFF1976D2)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 근무 내용
                    if (daySchedules.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                        child: Text('등록된 근무 일정이 없습니다',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.withValues(alpha: 0.45))),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _roles
                              .where((role) => roleGrouped.containsKey(role))
                              .map((role) {
                            final roleColor = _roleColors[role] ?? Colors.grey;
                            final entries = roleGrouped[role]!;
                            // 그룹 내 shift 정렬
                            final sortedEntries = [...entries]..sort((a, b) {
                                final sa = _shifts.indexOf(a['shift'] as String? ?? '');
                                final sb = _shifts.indexOf(b['shift'] as String? ?? '');
                                return (sa == -1 ? 99 : sa).compareTo(sb == -1 ? 99 : sb);
                              });
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 역할 레이블
                                  Row(children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: roleColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                            color: roleColor.withValues(alpha: 0.35)),
                                      ),
                                      child: Text(role,
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: roleColor)),
                                    ),
                                  ]),
                                  const SizedBox(height: 4),
                                  // 근무자 행 목록
                                  ...sortedEntries.map((s) {
                                    final shift = s['shift'] as String? ?? '주간';
                                    final color = _shiftColors[shift] ?? Colors.grey;
                                    final name =
                                        s['workerName'] as String? ?? '';
                                    final start =
                                        s['startTime'] as String? ?? '';
                                    final end =
                                        s['endTime'] as String? ?? '';
                                    final note =
                                        s['note'] as String? ?? '';
                                    final hasTime = start.isNotEmpty &&
                                        end.isNotEmpty &&
                                        shift != '휴무';
                                    return MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: Container(
                                        margin: const EdgeInsets.only(
                                            bottom: 3, left: 4),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.05),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                              color:
                                                  color.withValues(alpha: 0.18)),
                                        ),
                                        child: Row(
                                          children: [
                                            // shift 배지
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: color.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                              child: Text(shift,
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w700,
                                                      color: color)),
                                            ),
                                            const SizedBox(width: 6),
                                            // 이름
                                            Text(name,
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600)),
                                            // 시간
                                            if (hasTime) ...[
                                              const SizedBox(width: 8),
                                              Text('$start ~ $end',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: color.withValues(
                                                          alpha: 0.75))),
                                            ],
                                            // 메모
                                            if (note.isNotEmpty) ...[
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(note,
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey
                                                            .withValues(
                                                                alpha: 0.7)),
                                                    overflow:
                                                        TextOverflow.ellipsis),
                                              ),
                                            ] else
                                              const Spacer(),
                                            // 수정 버튼
                                            GestureDetector(
                                              onTap: () =>
                                                  _showAddEditScheduleDialog(
                                                      schedule: s),
                                              child: Container(
                                                width: 26,
                                                height: 26,
                                                decoration: BoxDecoration(
                                                  color: color.withValues(
                                                      alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Icon(FluentIcons.edit,
                                                    size: 12, color: color),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            // 삭제 버튼
                                            GestureDetector(
                                              onTap: () => _deleteSchedule(
                                                  s['id'] as String),
                                              child: Container(
                                                width: 26,
                                                height: 26,
                                                decoration: BoxDecoration(
                                                  color: Colors.red
                                                      .withValues(alpha: 0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Icon(
                                                    FluentIcons.delete,
                                                    size: 12,
                                                    color: Colors.red),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── 계층 연결선 Painter ────────────────────────────────────────
class _ConnectorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF9E9E9E).withValues(alpha: 0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), paint);
    canvas.drawLine(
        Offset(cx, size.height),
        Offset(cx - 6, size.height - 8),
        paint);
    canvas.drawLine(
        Offset(cx, size.height),
        Offset(cx + 6, size.height - 8),
        paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
