import 'package:fluent_ui/fluent_ui.dart';
import 'package:swu_dormi_admin/services/firestore_service.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:swu_dormi_admin/screens/windows/windows_monthly_plan_screen.dart';

class WindowsDashboard extends StatefulWidget {
  final Function(int index)? onNavigate;

  const WindowsDashboard({super.key, this.onNavigate});

  @override
  State<WindowsDashboard> createState() => _WindowsDashboardState();
}

class _WindowsDashboardState extends State<WindowsDashboard> {
  final _firestoreService = FirestoreService();
  final _dateFormat = DateFormat('yyyy년 MM월 dd일');
  final _timeFormat = DateFormat('HH:mm');

  int _monthlyAttendanceTotal = 0;
  late Future<Map<String, int>> _statisticsFuture;
  List<Map<String, dynamic>> _activeAttendanceEvents = [];
  List<Map<String, dynamic>> _todaySchedules = [];
  Map<String, String> _roleMap = {};

  static const _shiftColors = {
    '주간': Color(0xFF2196F3),
    '야간': Color(0xFF3F51B5),
    '당직': Color(0xFFFF9800),
    '반차': Color(0xFF8BC34A),
    '휴무': Color(0xFF9E9E9E),
  };

  @override
  void initState() {
    super.initState();
    _statisticsFuture = _firestoreService.getStatistics();
    _loadActiveAttendanceEvents();
    _loadTodaySchedules();
  }

  Future<void> _loadTodaySchedules() async {
    try {
      final today = DateTime.now();
      final dayStart = DateTime(today.year, today.month, today.day);
      final dayEnd = DateTime(today.year, today.month, today.day + 1);

      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('work_schedules')
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
            .where('date', isLessThan: Timestamp.fromDate(dayEnd))
            .get(),
        FirebaseFirestore.instance.collection('organization').get(),
      ]);

      if (!mounted) return;

      final schedules = (results[0] as QuerySnapshot).docs
          .map((d) => d.data() as Map<String, dynamic>)
          .toList();
      final roleMap = <String, String>{};
      for (final doc in (results[1] as QuerySnapshot).docs) {
        final data = doc.data() as Map<String, dynamic>;
        final name = data['name'] as String? ?? '';
        final role = data['role'] as String? ?? '';
        if (name.isNotEmpty) roleMap[name] = role;
      }

      const roleOrder = ['실장', '직원', '근로학생'];
      const shiftOrder = ['주간', '야간', '당직', '휴무'];
      schedules.sort((a, b) {
        final ra = roleOrder.indexOf(roleMap[a['workerName'] ?? ''] ?? '');
        final rb = roleOrder.indexOf(roleMap[b['workerName'] ?? ''] ?? '');
        final roleCmp = (ra == -1 ? 99 : ra).compareTo(rb == -1 ? 99 : rb);
        if (roleCmp != 0) return roleCmp;
        final sa = shiftOrder.indexOf(a['shift'] as String? ?? '');
        final sb = shiftOrder.indexOf(b['shift'] as String? ?? '');
        return (sa == -1 ? 99 : sa).compareTo(sb == -1 ? 99 : sb);
      });

      setState(() {
        _todaySchedules = schedules;
        _roleMap = roleMap;
      });
    } catch (_) {}
  }

  Future<void> _loadActiveAttendanceEvents() async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('attendance_events')
            .where('status', isEqualTo: 'active')
            .get(),
        FirebaseFirestore.instance.collection('attendance_events').get(),
      ]);
      if (!mounted) return;
      final activeSnap = results[0] as QuerySnapshot;
      final totalSnap = results[1] as QuerySnapshot;
      setState(() {
        _activeAttendanceEvents = activeSnap.docs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          data['_id'] = d.id;
          return data;
        }).toList();
        _monthlyAttendanceTotal = totalSnap.docs.length;
      });
    } catch (_) {}
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
    int? total,
    VoidCallback? onPressed,
  }) {
    return Card(
      child: Button(
        onPressed: onPressed,
        style: ButtonStyle(padding: WidgetStateProperty.all(EdgeInsets.zero)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[120],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: Colors.grey[100]),
                  textAlign: TextAlign.center,
                ),
              if (total != null)
                Text(
                  '누적 $total건',
                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleGroup(List<Map<String, dynamic>> schedules) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: schedules.map((s) {
        final shift = s['shift'] as String? ?? '주간';
        final color = _shiftColors[shift] ?? const Color(0xFF9E9E9E);
        final name = s['workerName'] as String? ?? '';
        final start = s['startTime'] as String? ?? '';
        final end = s['endTime'] as String? ?? '';
        final timeStr = (start.isNotEmpty && end.isNotEmpty) ? '$start~$end' : '';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(name,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: color)),
              if (timeStr.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(timeStr,
                    style: TextStyle(
                        fontSize: 10, color: color.withValues(alpha: 0.75))),
              ],
              const SizedBox(width: 4),
              Text('[$shift]',
                  style: TextStyle(
                      fontSize: 10, color: color.withValues(alpha: 0.6))),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTodayScheduleSection() {
    return Card(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(FluentIcons.calendar_agenda, size: 15),
              const SizedBox(width: 6),
              Text(
                '오늘 근무자현황 (${DateFormat('M월 d일').format(DateTime.now())})',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Builder(builder: (_) {
                final staffCount = _todaySchedules
                    .where((s) => ['실장', '직원'].contains(_roleMap[s['workerName'] as String? ?? ''] ?? ''))
                    .length;
                final studentCount = _todaySchedules
                    .where((s) => (_roleMap[s['workerName'] as String? ?? ''] ?? '') == '근로학생')
                    .length;
                return Text(
                  '직원 $staffCount명  근로학생 $studentCount명',
                  style: TextStyle(fontSize: 12, color: Colors.grey.withValues(alpha: 0.7)),
                );
              }),
            ],
          ),
          if (_todaySchedules.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '등록된 근무 일정이 없습니다',
                style: TextStyle(fontSize: 12, color: Colors.grey.withValues(alpha: 0.5)),
              ),
            )
          else ...[
            const SizedBox(height: 10),
            _buildScheduleGroup(_todaySchedules
                .where((s) {
                  final role = _roleMap[s['workerName'] as String? ?? ''] ?? '';
                  return role != '근로학생';
                })
                .toList()),
            if (_todaySchedules.any((s) =>
                (_roleMap[s['workerName'] as String? ?? ''] ?? '') == '근로학생')) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Divider(),
              ),
              _buildScheduleGroup(_todaySchedules
                  .where((s) =>
                      (_roleMap[s['workerName'] as String? ?? ''] ?? '') == '근로학생')
                  .toList()),
            ],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Column(
        children: [
          // 커스텀 헤더 (높이 20% 축소)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              color: FluentTheme.of(context).micaBackgroundColor,
              border: Border(
                bottom: BorderSide(
                  color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '대시보드(2026 2학기/겨울방학)',
                  style: FluentTheme.of(context).typography.subtitle?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  _dateFormat.format(DateTime.now()),
                  style: TextStyle(fontSize: 13, color: Colors.grey[120]),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, int>>(
        future: _statisticsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: ProgressRing());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(FluentIcons.error_badge, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    '통계 데이터를 불러올 수 없습니다',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[100]),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    child: const Text('다시 시도'),
                    onPressed: () {
                      setState(() {});
                    },
                  ),
                ],
              ),
            );
          }

          final statistics = snapshot.data ?? {};

          return Column(
            children: [
              // 월간 캘린더 (상단, 나머지 공간 사용)
              const Expanded(child: MonthlyPlanCalendar()),
              // 통계 카드 + 근무자현황 (하단 좌우 배치)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 통계 카드 (좌측)
                    Expanded(
                      flex: 4,
                      child: SizedBox(
                        height: 160,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                title: '총 학생수',
                                value: '${statistics['totalStudents'] ?? 0}',
                                icon: FluentIcons.people,
                                color: Colors.orange,
                                subtitle: '입사 완료 학생',
                              ),
                            ),
                            Expanded(
                              child: _buildStatCard(
                                title: '시설 신고',
                                value: '${statistics['pendingFacilities'] ?? 0}',
                                icon: FluentIcons.repair,
                                color: Colors.red,
                                total:
                                    (statistics['pendingFacilities'] ?? 0) +
                                    (statistics['inProgressFacilities'] ?? 0) +
                                    (statistics['completedFacilities'] ?? 0),
                              ),
                            ),
                            Expanded(
                              child: _buildStatCard(
                                title: '청소점검',
                                value: '${statistics['pendingCleaning'] ?? 0}',
                                icon: FluentIcons.broom,
                                color: Colors.teal,
                                total:
                                    (statistics['pendingCleaning'] ?? 0) +
                                    (statistics['inProgressCleaning'] ?? 0) +
                                    (statistics['completedCleaning'] ?? 0),
                              ),
                            ),
                            Expanded(
                              child: _buildStatCard(
                                title: '출석체크',
                                value: '${_activeAttendanceEvents.length}',
                                icon: FluentIcons.check_list,
                                color: Colors.blue,
                                total: _monthlyAttendanceTotal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 근무자현황 (우측)
                    Expanded(flex: 6, child: _buildTodayScheduleSection()),
                  ],
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
