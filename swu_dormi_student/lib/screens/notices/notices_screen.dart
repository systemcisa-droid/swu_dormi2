import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/database_service.dart';
import '../../models/notice_model.dart';
import '../../utils/notices_strings.dart';
import 'pdf_viewer_screen.dart';

// ── 카테고리 색상 (어드민과 동일) ───────────────────────────────
const _kCategoryColors = {
  '행사': Color(0xFF2196F3),
  '청소': Color(0xFF009688),
  '교육': Color(0xFF9C27B0),
  '점검': Color(0xFFFF9800),
  '기타': Color(0xFF757575),
};

// ── 공휴일 ──────────────────────────────────────────────────────
const Map<String, String> _kHolidays = {
  '01-01': '신정', '03-01': '삼일절', '05-05': '어린이날',
  '06-06': '현충일', '07-17': '제헌절', '08-15': '광복절',
  '10-03': '개천절', '10-09': '한글날', '12-25': '성탄절',
};
const Map<String, String> _kLunarHolidays = {
  '2025-01-28': '설날연휴', '2025-01-29': '설날', '2025-01-30': '설날연휴',
  '2025-05-05': '부처님오신날',
  '2025-10-05': '추석연휴', '2025-10-06': '추석', '2025-10-07': '추석연휴',
  '2026-02-16': '설날연휴', '2026-02-17': '설날', '2026-02-18': '설날연휴',
  '2026-05-24': '부처님오신날',
  '2026-09-24': '추석연휴', '2026-09-25': '추석', '2026-09-26': '추석연휴',
  '2027-02-06': '설날연휴', '2027-02-07': '설날', '2027-02-08': '설날연휴',
  '2027-05-13': '부처님오신날',
  '2027-10-14': '추석연휴', '2027-10-15': '추석', '2027-10-16': '추석연휴',
};
const Map<String, String> _kSubstituteHolidays = {
  '2025-03-03': '대체공휴일',
  '2026-03-02': '대체공휴일', '2026-05-25': '대체공휴일', '2026-06-03': '지방선거',
  '2026-08-17': '대체공휴일', '2026-10-05': '대체공휴일',
  '2027-08-16': '대체공휴일', '2027-10-04': '대체공휴일', '2027-10-11': '대체공휴일',
};

String? _getHolidayName(DateTime day) {
  final ymd =
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  if (_kSubstituteHolidays.containsKey(ymd)) return _kSubstituteHolidays[ymd];
  if (_kLunarHolidays.containsKey(ymd)) return _kLunarHolidays[ymd];
  final md =
      '${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  return _kHolidays[md];
}

// ── 메인 스크린 ─────────────────────────────────────────────────
class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  final _db = DatabaseService();
  int _tabIndex = 0;

  // 기숙사일정 상태
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _selectedDay;

  // ── 달력 헬퍼 ──────────────────────────────────────────────
  List<DateTime> _getDaysInMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final days = <DateTime>[];
    final sundayOffset = firstDay.weekday % 7;
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

  Map<DateTime, List<Map<String, dynamic>>> _buildEventMap(
      List<QueryDocumentSnapshot> docs) {
    final map = <DateTime, List<Map<String, dynamic>>>{};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final startTs =
          data['startDate'] as Timestamp? ?? data['date'] as Timestamp?;
      final endTs = data['endDate'] as Timestamp? ?? startTs;
      if (startTs == null) continue;
      final startDate = DateTime(
        startTs.toDate().year,
        startTs.toDate().month,
        startTs.toDate().day,
      );
      final endDate = DateTime(
        endTs!.toDate().year,
        endTs.toDate().month,
        endTs.toDate().day,
      );
      final plan = {
        'id': doc.id,
        'title': data['title'] ?? '',
        'category': data['category'] ?? '기타',
        'description': data['description'] ?? '',
        'startDate': startDate,
        'endDate': endDate,
      };
      DateTime cur = startDate;
      while (!cur.isAfter(endDate)) {
        map.putIfAbsent(DateTime(cur.year, cur.month, cur.day), () => [])
            .add(plan);
        cur = cur.add(const Duration(days: 1));
      }
    }
    return map;
  }

  // ── build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final s = NoticesStrings(Provider.of<LocaleProvider>(context).isEnglish);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.title),
      ),
      body: Column(
        children: [
          // 탭 버튼
          Row(
            children: [
              _buildTabButton(s.tabNotices, 0),
              _buildTabButton(s.tabSchedule, 1),
            ],
          ),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: _tabIndex == 0 ? _buildNoticesTab(s) : _buildCalendarTab(s),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _tabIndex == index;
    final primary = Theme.of(context).colorScheme.primary;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _tabIndex = index;
          _selectedDay = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? primary : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
              color: isSelected ? primary : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  // ── 공지사항 탭 ─────────────────────────────────────────────
  Widget _buildNoticesTab(NoticesStrings s) {
    return StreamBuilder<List<NoticeModel>>(
      stream: _db.getNotices(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(s.noticesLoadError));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inbox, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  s.noticesEmpty,
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          );
        }
        final notices = snapshot.data!;
        return SingleChildScrollView(
          child: Column(
            children: [
              Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
              ...notices.map((n) => _buildNoticeCard(context, n, s)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoticeCard(BuildContext context, NoticeModel notice, NoticesStrings s) {
    final String? thumbnailUrl = notice.imageUrls.isNotEmpty
        ? notice.imageUrls.first
        : notice.imageUrl;

    return InkWell(
      onTap: () => _showNoticeDetail(context, notice, s),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: thumbnailUrl != null
                      ? Image.network(
                          thumbnailUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildThumbnailPlaceholder(notice),
                        )
                      : _buildThumbnailPlaceholder(notice),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        notice.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notice.content,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.visibility_outlined,
                              size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Text(
                            '${notice.viewCount}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500),
                          ),
                          Flexible(
                            child: Text(
                              '  |  ${DateFormat('yyyy.MM.dd').format(notice.createdAt)}  |  ${s.allNotices}',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade500),
                              overflow: TextOverflow.ellipsis,
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
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
        ],
      ),
    );
  }

  Widget _buildThumbnailPlaceholder(NoticeModel notice) {
    return Container(
      width: 80,
      height: 80,
      color: notice.isImportant ? Colors.red.shade50 : Colors.blue.shade50,
      child: Icon(
        notice.isImportant ? Icons.priority_high : Icons.campaign_outlined,
        size: 36,
        color: notice.isImportant
            ? Colors.red.shade300
            : Colors.blue.shade300,
      ),
    );
  }

  void _showNoticeDetail(BuildContext context, NoticeModel notice, NoticesStrings s) {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user != null) {
      _db.incrementNoticeViewCount(notice.id, user.uid);
    }

    if (notice.pdfUrl != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerScreen(
            pdfUrl: notice.pdfUrl!,
            pdfFileName: notice.pdfFileName ?? notice.title,
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notice.title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (notice.isImportant)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(s.important,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${s.author}: ${notice.authorName}',
                    style: const TextStyle(color: Colors.grey)),
                Text(
                    DateFormat('yyyy-MM-dd HH:mm').format(notice.createdAt),
                    style: const TextStyle(color: Colors.grey)),
                const Divider(height: 32),
                if (notice.imageUrls.isNotEmpty) ...[
                  ...notice.imageUrls.map((imageUrl) => Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => Dialog(
                                  backgroundColor: Colors.black,
                                  child: Stack(
                                    children: [
                                      Center(
                                        child: InteractiveViewer(
                                          child: Image.network(imageUrl,
                                              fit: BoxFit.contain),
                                        ),
                                      ),
                                      Positioned(
                                        top: 16,
                                        right: 16,
                                        child: IconButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          icon: const Icon(Icons.close,
                                              color: Colors.white, size: 30),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(imageUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Container(
                                        height: 200,
                                        color: Colors.grey.shade200,
                                        child: const Center(
                                            child: Icon(Icons.broken_image,
                                                size: 50,
                                                color: Colors.grey)),
                                      )),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      )),
                ] else if (notice.imageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(notice.imageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                              height: 200,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.error),
                            )),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  notice.content,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(height: 1.6),
                ),
                if (notice.pdfUrl != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PdfViewerScreen(
                          pdfUrl: notice.pdfUrl!,
                          pdfFileName: notice.pdfFileName ?? s.pdfFile,
                        ),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.red.shade200, width: 2),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.picture_as_pdf,
                              size: 48, color: Colors.red.shade700),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notice.pdfFileName ?? s.pdfFile,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(s.viewPdfFile,
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios,
                              size: 20, color: Colors.red.shade700),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 기숙사일정 탭 ───────────────────────────────────────────
  Widget _buildCalendarTab(NoticesStrings s) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('monthly_plans')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final eventMap = snapshot.hasData
            ? _buildEventMap(snapshot.data!.docs)
            : <DateTime, List<Map<String, dynamic>>>{};
        final days = _getDaysInMonth(_focusedMonth);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 월 네비게이션
              _buildMonthHeader(s),
              // 범례
              _buildLegend(s),
              // 요일 헤더
              _buildWeekdayHeader(s),
              // 달력 그리드
              _buildCalendarGrid(days, eventMap, s),
              const Divider(height: 1),
              // 선택된 날 일정
              _buildSelectedDayPanel(eventMap, s),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonthHeader(NoticesStrings s) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() {
              _focusedMonth = DateTime(
                  _focusedMonth.year, _focusedMonth.month - 1);
              _selectedDay = null;
            }),
          ),
          Expanded(
            child: Text(
              s.yearMonth(_focusedMonth),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() {
              _focusedMonth = DateTime(
                  _focusedMonth.year, _focusedMonth.month + 1);
              _selectedDay = null;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(NoticesStrings s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: _kCategoryColors.entries.map((e) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: e.value,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Text(s.category(e.key),
                  style: const TextStyle(fontSize: 11, color: Colors.black87)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWeekdayHeader(NoticesStrings s) {
    return Container(
      color: Colors.grey.shade100,
      child: Row(
        children: List.generate(7, (index) {
          final isWeekend = index == 0 || index == 6;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                s.weekday(index),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isWeekend ? Colors.red : Colors.grey.shade700,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // 중복 없는 정렬된 일정 목록 추출
  List<Map<String, dynamic>> _getUniquePlans(
      Map<DateTime, List<Map<String, dynamic>>> eventMap) {
    final seen = <String>{};
    final plans = <Map<String, dynamic>>[];
    for (final dayPlans in eventMap.values) {
      for (final plan in dayPlans) {
        final id = plan['id'] as String;
        if (!seen.contains(id)) {
          seen.add(id);
          plans.add(plan);
        }
      }
    }
    plans.sort((a, b) => (a['startDate'] as DateTime)
        .compareTo(b['startDate'] as DateTime));
    return plans;
  }

  // 한 주(week)에 표시할 최대 이벤트 바 슬롯 수 (초과분은 "+N개"로 표시)
  static const int _maxBarSlotsPerWeek = 3;

  Widget _buildCalendarGrid(
      List<DateTime> days,
      Map<DateTime, List<Map<String, dynamic>>> eventMap,
      NoticesStrings s) {
    final today = DateTime.now();
    final allPlans = _getUniquePlans(eventMap);
    final weekCount = days.length ~/ 7;
    const cellH = 92.0;
    final totalH = cellH * weekCount;

    // 각 일정이 걸치는 주(week) 인덱스 목록을 구해, 주별로 슬롯을 배정
    // (같은 일정이 여러 주에 걸치면 각 주에서 같은 슬롯 번호를 쓰도록 유지)
    final planSlot = <String, int>{};
    final weekSlotCount = List<int>.filled(weekCount, 0);
    final weekOverflow = List<int>.filled(weekCount, 0);
    final planBars = <_PlanBarInfo>[];

    for (final plan in allPlans) {
      final startDate = plan['startDate'] as DateTime;
      final endDate = plan['endDate'] as DateTime;
      final normalStart =
          DateTime(startDate.year, startDate.month, startDate.day);
      final normalEnd = DateTime(endDate.year, endDate.month, endDate.day);

      int? startIdx;
      int? endIdx;
      for (int i = 0; i < days.length; i++) {
        final d = DateTime(days[i].year, days[i].month, days[i].day);
        if (d == normalStart) startIdx = i;
        if (d == normalEnd) endIdx = i;
      }
      if (startIdx == null && endIdx == null) continue;
      startIdx ??= 0;
      endIdx ??= days.length - 1;

      final firstWeek = startIdx ~/ 7;
      final lastWeek = endIdx ~/ 7;

      // 이 일정이 걸치는 모든 주 중 이미 배정된 슬롯이 있으면 재사용, 없으면 새로 배정
      final id = plan['id'] as String;
      int slot = planSlot[id] ??
          (() {
            int maxUsed = -1;
            for (int w = firstWeek; w <= lastWeek; w++) {
              if (weekSlotCount[w] - 1 > maxUsed) maxUsed = weekSlotCount[w] - 1;
            }
            return maxUsed + 1;
          })();
      planSlot[id] = slot;

      for (int w = firstWeek; w <= lastWeek; w++) {
        if (slot + 1 > weekSlotCount[w]) weekSlotCount[w] = slot + 1;
      }

      planBars.add(_PlanBarInfo(plan, startIdx, endIdx, slot));
    }

    // 슬롯 제한 초과분 계산 및 표시할 바 필터링
    final visibleBars = <_PlanBarInfo>[];
    for (final bar in planBars) {
      if (bar.slot < _maxBarSlotsPerWeek) {
        visibleBars.add(bar);
      } else {
        final firstWeek = bar.startIdx ~/ 7;
        final lastWeek = bar.endIdx ~/ 7;
        for (int w = firstWeek; w <= lastWeek; w++) {
          weekOverflow[w]++;
        }
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellW = constraints.maxWidth / 7;
        return SizedBox(
          height: totalH,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // 날짜 셀 그리드
              Column(
                children: List.generate(weekCount, (weekIdx) {
                  return Row(
                    children: List.generate(7, (dayIdx) {
                      final day = days[weekIdx * 7 + dayIdx];
                      return SizedBox(
                        width: cellW,
                        height: cellH,
                        child: _buildDayCell(day, today, cellW),
                      );
                    }),
                  );
                }),
              ),
              // 이벤트 바 오버레이 (주당 최대 _maxBarSlotsPerWeek개)
              ...visibleBars.map((bar) => _buildEventBar(
                  bar.plan, days, cellW, cellH, bar.slot)),
              // 더보기 표시
              ...List.generate(weekCount, (weekIdx) {
                if (weekOverflow[weekIdx] == 0) return const SizedBox.shrink();
                return Positioned(
                  left: 0,
                  top: weekIdx * cellH +
                      30.0 +
                      (_maxBarSlotsPerWeek * 20.0),
                  child: GestureDetector(
                    onTap: () => _showWeekMoreSheet(weekIdx, days, eventMap, s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      margin: const EdgeInsets.only(left: 2),
                      child: Text(
                        s.moreCount(weekOverflow[weekIdx]),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showWeekMoreSheet(int weekIdx, List<DateTime> days,
      Map<DateTime, List<Map<String, dynamic>>> eventMap, NoticesStrings s) {
    final weekDays = days.sublist(weekIdx * 7, weekIdx * 7 + 7);
    final seen = <String>{};
    final plans = <Map<String, dynamic>>[];
    for (final day in weekDays) {
      final key = DateTime(day.year, day.month, day.day);
      for (final plan in eventMap[key] ?? []) {
        final id = plan['id'] as String;
        if (seen.add(id)) plans.add(plan);
      }
    }
    plans.sort((a, b) =>
        (a['startDate'] as DateTime).compareTo(b['startDate'] as DateTime));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              s.weekSchedule,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...plans.map((p) => _buildEventTile(p, s)),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCell(DateTime day, DateTime today, double cellW) {
    final isCurrentMonth = day.month == _focusedMonth.month;
    final isToday = day.year == today.year &&
        day.month == today.month &&
        day.day == today.day;
    final isSelected = _selectedDay != null &&
        day.year == _selectedDay!.year &&
        day.month == _selectedDay!.month &&
        day.day == _selectedDay!.day;
    final isSunday = day.weekday == DateTime.sunday;
    final isSaturday = day.weekday == DateTime.saturday;
    final holiday = isCurrentMonth ? _getHolidayName(day) : null;
    final isRed = isSunday || isSaturday || holiday != null;

    Color dayColor;
    if (!isCurrentMonth) {
      dayColor = Colors.grey.shade400;
    } else if (isRed) {
      dayColor = Colors.red;
    } else {
      dayColor = Colors.black87;
    }

    return GestureDetector(
      onTap: isCurrentMonth
          ? () => setState(() {
                _selectedDay = isSelected ? null : day;
              })
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.08)
              : null,
          border: Border.all(
            color: isSelected
                ? Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.5)
                : Colors.grey.shade200,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isToday
                    ? Theme.of(context).colorScheme.primary
                    : null,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isToday ? FontWeight.bold : FontWeight.normal,
                    color: isToday ? Colors.white : dayColor,
                  ),
                ),
              ),
            ),
            if (holiday != null && isCurrentMonth)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Text(
                  holiday,
                  style: const TextStyle(
                      fontSize: 7,
                      color: Colors.red,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 어드민과 동일한 방식: 주 경계에서 바를 분할해 연속 표시
  Widget _buildEventBar(
      Map<String, dynamic> plan,
      List<DateTime> days,
      double cellW,
      double cellH,
      int rowIdx) {
    final startDate = plan['startDate'] as DateTime;
    final endDate = plan['endDate'] as DateTime;
    final cat = plan['category'] as String? ?? '기타';
    final color = _kCategoryColors[cat] ?? const Color(0xFF757575);

    final normalStart =
        DateTime(startDate.year, startDate.month, startDate.day);
    final normalEnd = DateTime(endDate.year, endDate.month, endDate.day);

    int? startIdx;
    int? endIdx;
    for (int i = 0; i < days.length; i++) {
      final d = DateTime(days[i].year, days[i].month, days[i].day);
      if (d == normalStart) startIdx = i;
      if (d == normalEnd) endIdx = i;
    }
    if (startIdx == null && endIdx == null) return const SizedBox.shrink();

    startIdx ??= 0;
    endIdx ??= days.length - 1;

    // 이벤트 바 상단 오프셋: 날짜 숫자 영역(30px) + 슬롯(rowIdx * 20px)
    const barTopBase = 30.0;
    const barSlotH = 20.0;
    const barH = 17.0;
    const barGap = 2.0;

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

      final isFirst = cur == startIdx;
      final isLast = segEnd == endIdx;
      final borderRadius = BorderRadius.horizontal(
        left: isFirst ? const Radius.circular(3) : Radius.zero,
        right: isLast ? const Radius.circular(3) : Radius.zero,
      );

      bars.add(
        Positioned(
          left: segStartCol * cellW + barGap,
          top: segStartRow * cellH + barTopBase + (rowIdx * barSlotH),
          child: GestureDetector(
            onTap: () => setState(() {
              _selectedDay = days[cur];
            }),
            child: Container(
              width: barWidth - barGap * 2,
              height: barH,
              decoration:
                  BoxDecoration(color: color, borderRadius: borderRadius),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                plan['title'] as String? ?? '',
                style: const TextStyle(
                  fontSize: 10,
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

  Widget _buildSelectedDayPanel(
      Map<DateTime, List<Map<String, dynamic>>> eventMap, NoticesStrings s) {
    if (_selectedDay == null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            s.selectDayHint,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ),
      );
    }

    final dayKey =
        DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    final events = eventMap[dayKey] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            s.monthDayWeekday(_selectedDay!),
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(s.noRegisteredSchedule,
                style: TextStyle(
                    color: Colors.grey.shade500, fontSize: 13)),
          )
        else
          ...events.map((e) => _buildEventTile(e, s)),
      ],
    );
  }

  Widget _buildEventTile(Map<String, dynamic> plan, NoticesStrings s) {
    final cat = plan['category'] as String? ?? '기타';
    final color = _kCategoryColors[cat] ?? const Color(0xFF757575);
    final start = plan['startDate'] as DateTime;
    final end = plan['endDate'] as DateTime;
    final sameDay = start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    final desc = plan['description'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        // left accent bar
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        s.category(cat),
                        style: TextStyle(
                            fontSize: 10,
                            color: color,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!sameDay)
                      Flexible(
                        child: Text(
                          '${DateFormat('M.d').format(start)} ~ ${DateFormat('M.d').format(end)}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  plan['title'] as String? ?? '',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    desc,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 이벤트 바 렌더링에 필요한 위치/슬롯 정보
class _PlanBarInfo {
  final Map<String, dynamic> plan;
  final int startIdx;
  final int endIdx;
  final int slot;

  _PlanBarInfo(this.plan, this.startIdx, this.endIdx, this.slot);
}
