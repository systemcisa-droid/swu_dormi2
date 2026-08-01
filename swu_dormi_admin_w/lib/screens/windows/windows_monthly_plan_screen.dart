import 'package:fluent_ui/fluent_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ── 한국 공휴일 ────────────────────────────────────────────────
const Map<String, String> _kHolidays = {
  // 고정 공휴일
  '01-01': '신정',
  '03-01': '삼일절',
  '05-05': '어린이날',
  '06-06': '현충일',
  '07-17': '제헌절',
  '08-15': '광복절',
  '10-03': '개천절',
  '10-09': '한글날',
  '12-25': '성탄절',
};

// 음력 기반 공휴일 (연도별 하드코딩)
const Map<String, String> _kLunarHolidays = {
  // 2025
  '2025-01-28': '설날연휴', '2025-01-29': '설날', '2025-01-30': '설날연휴',
  '2025-05-05': '부처님오신날',
  '2025-10-05': '추석연휴', '2025-10-06': '추석', '2025-10-07': '추석연휴',
  // 2026
  '2026-02-16': '설날연휴', '2026-02-17': '설날', '2026-02-18': '설날연휴',
  '2026-05-24': '부처님오신날',
  '2026-09-24': '추석연휴', '2026-09-25': '추석', '2026-09-26': '추석연휴',
  // 2027
  '2027-02-06': '설날연휴', '2027-02-07': '설날', '2027-02-08': '설날연휴',
  '2027-05-13': '부처님오신날',
  '2027-10-14': '추석연휴', '2027-10-15': '추석', '2027-10-16': '추석연휴',
};

// 대체공휴일 (토·일 겹칠 때 다음 평일로 이동)
const Map<String, String> _kSubstituteHolidays = {
  // 2025 - 삼일절(토) → 월요일
  '2025-03-03': '대체공휴일',
  '2026-05-25': '대체공휴일',   // 부처님오신날(일) → 월요일
  '2026-06-03': '지방선거',
  // 2026 - 삼일절(일) → 월요일, 광복절(토) → 월요일, 개천절(토) → 월요일
  '2026-03-02': '대체공휴일',
  '2026-08-17': '대체공휴일',
  '2026-10-05': '대체공휴일',
  // 2027 - 광복절(일) → 월요일, 개천절(일) → 월요일, 한글날(토) → 월요일
  '2027-08-16': '대체공휴일',
  '2027-10-04': '대체공휴일',
  '2027-10-11': '대체공휴일',
};

String? _getHolidayName(DateTime day) {
  final ymd =
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  if (_kSubstituteHolidays.containsKey(ymd)) return _kSubstituteHolidays[ymd];
  if (_kLunarHolidays.containsKey(ymd)) return _kLunarHolidays[ymd];
  final md = '${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  return _kHolidays[md];
}

// ── 공용 상수 ──────────────────────────────────────────────────
const kPlanCategories = ['행사', '청소', '교육', '점검', '기타'];
const kPlanCategoryColors = {
  '행사': Color(0xFF2196F3),
  '청소': Color(0xFF009688),
  '교육': Color(0xFF9C27B0),
  '점검': Color(0xFFFF9800),
  '기타': Color(0xFF757575),
};

// ── 월간 계획 스크린 (네비게이션용 래퍼) ──────────────────────────
class WindowsMonthlyPlanScreen extends StatelessWidget {
  const WindowsMonthlyPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScaffoldPage(padding: EdgeInsets.zero, content: MonthlyPlanCalendar());
  }
}

// ── 재사용 가능한 캘린더 위젯 ────────────────────────────────────
class MonthlyPlanCalendar extends StatefulWidget {
  const MonthlyPlanCalendar({super.key});

  @override
  State<MonthlyPlanCalendar> createState() => _MonthlyPlanCalendarState();
}

class _MonthlyPlanCalendarState extends State<MonthlyPlanCalendar> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _selectedDay;

  // date → list of plans (다중일 일정 포함)
  Map<DateTime, List<Map<String, dynamic>>> _eventMap = {};

  // 중복 없는 전체 일정 목록
  List<Map<String, dynamic>> _allPlans = [];

  void _prevMonth() => setState(() {
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    _selectedDay = null;
  });

  void _nextMonth() => setState(() {
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    _selectedDay = null;
  });

  /// 해당 월의 전체 셀 목록 (이전·다음달 패딩 포함)
  List<DateTime> _getDaysInMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final days = <DateTime>[];

    final sundayOffset = firstDay.weekday % 7; // 일=0
    for (int i = sundayOffset; i > 0; i--) {
      days.add(firstDay.subtract(Duration(days: i)));
    }
    for (int i = 1; i <= lastDay.day; i++) {
      days.add(DateTime(month.year, month.month, i));
    }
    while (days.length % 7 != 0) {
      days.add(days.last.add(const Duration(days: 1)));
    }
    return days;
  }

  /// Firestore 스냅샷 → _eventMap, _allPlans 갱신
  void _processSnapshot(QuerySnapshot snapshot) {
    final newMap = <DateTime, List<Map<String, dynamic>>>{};
    final allPlans = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final startTs = data['startDate'] as Timestamp? ?? data['date'] as Timestamp?;
      final endTs = data['endDate'] as Timestamp? ?? startTs;
      if (startTs == null) continue;

      final startDate = DateTime(
        startTs.toDate().year,
        startTs.toDate().month,
        startTs.toDate().day,
      );
      final endDate = DateTime(endTs!.toDate().year, endTs.toDate().month, endTs.toDate().day);

      final planEntry = {
        'id': doc.id,
        'title': data['title'] ?? '',
        'category': data['category'] ?? '기타',
        'description': data['description'] ?? '',
        'startDate': startDate,
        'endDate': endDate,
      };

      // eventMap: 시작~종료 모든 날짜에 등록
      DateTime cur = startDate;
      while (!cur.isAfter(endDate)) {
        newMap.putIfAbsent(cur, () => []).add(planEntry);
        cur = cur.add(const Duration(days: 1));
      }

      // allPlans: 중복 제거
      if (!seen.contains(doc.id)) {
        seen.add(doc.id);
        allPlans.add(planEntry);
      }
    }

    // startDate 기준 정렬
    allPlans.sort((a, b) => (a['startDate'] as DateTime).compareTo(b['startDate'] as DateTime));

    _eventMap = newMap;
    _allPlans = allPlans;
  }

  List<Map<String, dynamic>> _plansForDay(DateTime day) =>
      _eventMap[DateTime(day.year, day.month, day.day)] ?? [];

  // ──────────────────── 다이얼로그 ────────────────────────────
  Future<void> _showAddEditDialog({Map<String, dynamic>? plan, DateTime? initialDate}) async {
    final isEdit = plan != null;
    DateTime startDate = isEdit ? plan['startDate'] as DateTime : (initialDate ?? DateTime.now());
    DateTime endDate = isEdit ? plan['endDate'] as DateTime : startDate;

    final titleCtrl = TextEditingController(text: isEdit ? plan['title'] as String? : '');
    final descCtrl = TextEditingController(
      text: isEdit ? (plan['description'] as String?) ?? '' : '',
    );
    String selCat = isEdit ? (plan['category'] as String? ?? '기타') : '기타';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => ContentDialog(
          title: Text(isEdit ? '일정 수정' : '일정 추가'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 시작일 ~ 종료일
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('시작일', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            DatePicker(
                              selected: startDate,
                              onChanged: (d) => setD(() {
                                startDate = d;
                                if (endDate.isBefore(d)) endDate = d;
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('종료일', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            DatePicker(
                              selected: endDate,
                              onChanged: (d) => setD(() {
                                endDate = d;
                                if (d.isBefore(startDate)) startDate = d;
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 카테고리
                  const Text('카테고리', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: kPlanCategories.map((cat) {
                      final color = kPlanCategoryColors[cat]!;
                      final sel = selCat == cat;
                      return GestureDetector(
                        onTap: () => setD(() => selCat = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel
                                ? color.withValues(alpha: 0.15)
                                : Colors.grey.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: sel ? color : Colors.grey.withValues(alpha: 0.25),
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 12,
                              color: sel ? color : null,
                              fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('제목', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextBox(controller: titleCtrl, placeholder: '일정 제목을 입력하세요'),
                  const SizedBox(height: 16),
                  const Text('내용', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextBox(controller: descCtrl, placeholder: '세부 내용 (선택)', maxLines: 3),
                ],
              ),
            ),
          ),
          actions: [
            if (isEdit)
              Button(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(Colors.red.withValues(alpha: 0.1)),
                ),
                child: Text('삭제', style: TextStyle(color: Colors.red)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _deletePlan(plan['id'] as String);
                },
              ),
            Button(child: const Text('취소'), onPressed: () => Navigator.pop(ctx)),
            FilledButton(
              child: Text(isEdit ? '저장' : '추가'),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;
                Navigator.pop(ctx);
                await _savePlan(
                  id: isEdit ? plan['id'] as String : null,
                  title: title,
                  description: descCtrl.text.trim(),
                  category: selCat,
                  startDate: startDate,
                  endDate: endDate,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _savePlan({
    String? id,
    required String title,
    required String description,
    required String category,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final data = {
        'title': title,
        'description': description,
        'category': category,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        // 하위 호환
        'date': Timestamp.fromDate(startDate),
        'updatedAt': Timestamp.now(),
      };
      final col = FirebaseFirestore.instance.collection('monthly_plans');
      if (id == null) {
        data['createdAt'] = Timestamp.now();
        await col.add(data);
      } else {
        await col.doc(id).update(data);
      }
    } catch (e) {
      if (mounted) {
        await displayInfoBar(
          context,
          builder: (c, _) => InfoBar(title: Text('오류: $e'), severity: InfoBarSeverity.error),
        );
      }
    }
  }

  Future<void> _deletePlan(String id) async {
    try {
      await FirebaseFirestore.instance.collection('monthly_plans').doc(id).delete();
    } catch (e) {
      if (mounted) {
        await displayInfoBar(
          context,
          builder: (c, _) => InfoBar(title: Text('오류: $e'), severity: InfoBarSeverity.error),
        );
      }
    }
  }

  // ──────────────────── build ─────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('monthly_plans').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _processSnapshot(snapshot.data!);
        }

        return Column(
          children: [
            // ── 헤더 바 ───────────────────────────────────────
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
                    DateFormat('yyyy년 MM월').format(_focusedMonth),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(FluentIcons.chevron_right, size: 14),
                    onPressed: _nextMonth,
                  ),
                  const Spacer(),
                  // 카테고리 범례
                  ...kPlanCategories.map((cat) {
                    final color = kPlanCategoryColors[cat]!;
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
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(cat, style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: () => _showAddEditDialog(),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.add, size: 12),
                        SizedBox(width: 4),
                        Text('일정 추가', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ── 요일 헤더 ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: ['일', '월', '화', '수', '목', '금', '토']
                    .asMap()
                    .entries
                    .map(
                      (e) => Expanded(
                        child: Center(
                          child: Text(
                            e.value,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: e.key == 0 || e.key == 6 ? Colors.red : null,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const Divider(),
            // ── 캘린더 그리드 ─────────────────────────────────
            Expanded(
              child: snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData
                  ? const Center(child: ProgressRing())
                  : _buildCalendarGrid(),
            ),
            // ── 선택된 날 상세 ────────────────────────────────
            if (_selectedDay != null) _buildDayDetail(_selectedDay!),
          ],
        );
      },
    );
  }

  // ──────────────────── 캘린더 그리드 ─────────────────────────
  Widget _buildCalendarGrid() {
    final days = _getDaysInMonth(_focusedMonth);
    final today = DateTime.now();
    final rowCount = days.length ~/ 7;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellW = constraints.maxWidth / 7;
        final cellH = constraints.maxHeight / rowCount;

        return Stack(
          children: [
            // ── 날짜 숫자 그리드 ─────────────────────────────
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: cellW / cellH,
                crossAxisSpacing: 0,
                mainAxisSpacing: 0,
              ),
              itemCount: days.length,
              itemBuilder: (_, i) {
                final day = days[i];
                final isCurrentMonth = day.month == _focusedMonth.month;
                final isToday =
                    day.year == today.year && day.month == today.month && day.day == today.day;
                final isSelected =
                    _selectedDay != null &&
                    day.year == _selectedDay!.year &&
                    day.month == _selectedDay!.month &&
                    day.day == _selectedDay!.day;
                final isSunday = i % 7 == 0;
                final isSaturday = i % 7 == 6;
                final holiday = isCurrentMonth ? _getHolidayName(day) : null;
                final isRed = isSunday || isSaturday || holiday != null;

                return GestureDetector(
                  onTap: () => setState(() => _selectedDay = isSelected ? null : day),
                  onDoubleTap: () => _showAddEditDialog(initialDate: day),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.withValues(alpha: 0.07) : null,
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey.withValues(alpha: 0.12),
                        width: isSelected ? 1.5 : 0.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 4),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: isToday ? Colors.teal : null,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${day.day}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                color: isToday
                                    ? Colors.white
                                    : !isCurrentMonth
                                    ? Colors.grey.withValues(alpha: 0.35)
                                    : isRed
                                    ? Colors.red
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        if (holiday != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(
                              holiday,
                              style: TextStyle(
                                fontSize: 8,
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            // ── 이벤트 바 오버레이 ───────────────────────────
            ..._allPlans.asMap().entries.map((entry) {
              final rowIdx = entry.key % 4; // 같은 날 겹치지 않도록 행 배분
              return _buildEventBar(entry.value, days, cellW, cellH, rowIdx);
            }),
          ],
        );
      },
    );
  }

  // ──────────────────── 이벤트 바 ─────────────────────────────
  Widget _buildEventBar(
    Map<String, dynamic> plan,
    List<DateTime> days,
    double cellW,
    double cellH,
    int rowIdx,
  ) {
    final startDate = plan['startDate'] as DateTime;
    final endDate = plan['endDate'] as DateTime;
    final cat = plan['category'] as String? ?? '기타';
    final color = kPlanCategoryColors[cat] ?? const Color(0xFF757575);

    final normalStart = DateTime(startDate.year, startDate.month, startDate.day);
    final normalEnd = DateTime(endDate.year, endDate.month, endDate.day);

    int? startIdx;
    int? endIdx;
    for (int i = 0; i < days.length; i++) {
      final d = DateTime(days[i].year, days[i].month, days[i].day);
      if (d == normalStart) startIdx = i;
      if (d == normalEnd) endIdx = i;
    }
    if (startIdx == null && endIdx == null) return const SizedBox.shrink();

    // 시작/끝이 현재 월 그리드 밖인 경우 클램핑
    startIdx ??= 0;
    endIdx ??= days.length - 1;

    final bars = <Widget>[];
    int cur = startIdx;

    while (cur <= endIdx) {
      final segStartCol = cur % 7;
      final segStartRow = cur ~/ 7;

      int segEnd = cur;
      while (segEnd < endIdx && segEnd % 7 != 6) {
        segEnd++;
      }
      final segEndCol = segEnd % 7;
      final barWidth = (segEndCol - segStartCol + 1) * cellW;

      // 둥근 모서리: 세그먼트 첫/마지막만 둥글게
      final isFirst = cur == startIdx;
      final isLast = segEnd == endIdx;
      final borderRadius = BorderRadius.horizontal(
        left: isFirst ? const Radius.circular(3) : Radius.zero,
        right: isLast ? const Radius.circular(3) : Radius.zero,
      );

      bars.add(
        Positioned(
          left: segStartCol * cellW + 2,
          top: segStartRow * cellH + 28 + (rowIdx * 22.0),
          child: GestureDetector(
            onTap: () => _showAddEditDialog(plan: plan),
            child: Container(
              width: barWidth - 4,
              height: 20,
              decoration: BoxDecoration(color: color, borderRadius: borderRadius),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                plan['title'] as String? ?? '',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
        ),
      );

      cur = segEnd + 1;
    }

    return Stack(children: bars);
  }

  // ──────────────────── 날 상세 패널 ──────────────────────────
  Widget _buildDayDetail(DateTime day) {
    final plans = _plansForDay(day);
    return Container(
      height: 130,
      decoration: BoxDecoration(
        color: FluentTheme.of(context).cardColor,
        border: Border(
          top: BorderSide(color: FluentTheme.of(context).resources.dividerStrokeColorDefault),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Row(
              children: [
                Text(
                  DateFormat('M월 d일 (E)', 'ko').format(day),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 6),
                Text('${plans.length}건', style: TextStyle(fontSize: 11, color: Colors.grey[80])),
                const Spacer(),
                Button(
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.add, size: 11),
                      SizedBox(width: 3),
                      Text('추가', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                  onPressed: () => _showAddEditDialog(initialDate: day),
                ),
              ],
            ),
          ),
          Expanded(
            child: plans.isEmpty
                ? Center(
                    child: Text(
                      '등록된 일정이 없습니다',
                      style: TextStyle(fontSize: 12, color: Colors.grey[80]),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                    itemCount: plans.length,
                    itemBuilder: (_, i) {
                      final p = plans[i];
                      final cat = p['category'] as String? ?? '기타';
                      final color = kPlanCategoryColors[cat] ?? const Color(0xFF757575);
                      final start = p['startDate'] as DateTime;
                      final end = p['endDate'] as DateTime;
                      final sameDay = start == end;
                      return GestureDetector(
                        onTap: () => _showAddEditDialog(plan: p),
                        child: Container(
                          width: 190,
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.09),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: color.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      cat,
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: color,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(FluentIcons.edit, size: 10, color: Colors.grey[80]),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                p['title'] as String? ?? '',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (!sameDay)
                                Text(
                                  '${DateFormat('M.d').format(start)} ~ ${DateFormat('M.d').format(end)}',
                                  style: TextStyle(fontSize: 10, color: color),
                                ),
                              if ((p['description'] as String?)?.isNotEmpty == true)
                                Text(
                                  p['description'] as String,
                                  style: TextStyle(fontSize: 10, color: Colors.grey[100]),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
