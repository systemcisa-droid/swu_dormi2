import 'package:flutter/material.dart';

/// 게시판에 공유된 시간표(PostModel.timetableClasses)를 그리는 읽기 전용 위젯.
/// timetable_page.dart의 ClassItem.toMap() 형태를 그대로 받는다(요일 월~금, 8~22시 고정 범위).
class TimetablePreview extends StatelessWidget {
  final List<Map<String, dynamic>> classes;
  /// 카드 목록 등 좁은 공간에서 쓸 때 높이를 줄인다.
  final bool compact;

  const TimetablePreview({super.key, required this.classes, this.compact = false});

  static const _days = ['월', '화', '수', '목', '금'];
  static const _startHour = 8;
  static const _hourCount = 15; // 8시~22시

  @override
  Widget build(BuildContext context) {
    if (classes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text('등록된 수업이 없습니다', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
      );
    }

    // 실제로 수업이 있는 시간대만 보여줘 카드가 불필요하게 길어지지 않게 한다.
    final startHours = classes.map((c) => (c['startHour'] as num).toInt()).toList();
    final endHours = classes.map((c) {
      final startMin = (c['startHour'] as num).toInt() * 60 + (c['startMinute'] as num).toInt();
      final endMin = startMin + (c['durationMinutes'] as num).toDouble();
      return (endMin / 60).ceil();
    }).toList();
    final rangeStart = (startHours.reduce((a, b) => a < b ? a : b)).clamp(_startHour, _startHour + _hourCount - 1);
    final rangeEnd = (endHours.reduce((a, b) => a > b ? a : b)).clamp(rangeStart + 1, _startHour + _hourCount);
    final hourCount = rangeEnd - rangeStart;
    final rowHeight = compact ? 28.0 : 40.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final dayColWidth = (constraints.maxWidth - 22) / 5;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 요일 헤더
            Row(
              children: [
                const SizedBox(width: 22),
                ..._days.map((d) => SizedBox(
                      width: dayColWidth,
                      child: Center(
                        child: Text(d, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      ),
                    )),
              ],
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: rowHeight * hourCount,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 22,
                    child: Column(
                      children: List.generate(
                        hourCount,
                        (i) => SizedBox(
                          height: rowHeight,
                          child: Text('${rangeStart + i}',
                              style: TextStyle(fontSize: 9, color: Colors.grey[400])),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Column(
                          children: List.generate(
                            hourCount,
                            (i) => Container(
                              height: rowHeight,
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
                              ),
                            ),
                          ),
                        ),
                        ...classes.map((c) => _buildBlock(c, rangeStart, dayColWidth, rowHeight)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBlock(Map<String, dynamic> c, int rangeStart, double dayColWidth, double rowHeight) {
    final dayIndex = (c['dayIndex'] as num).toInt();
    final startHour = (c['startHour'] as num).toInt();
    final startMinute = (c['startMinute'] as num).toInt();
    final duration = (c['durationMinutes'] as num).toDouble();
    final pxPerMinute = rowHeight / 60.0;
    final top = ((startHour - rangeStart) * 60 + startMinute) * pxPerMinute;
    final height = duration * pxPerMinute;
    final color = Color(c['color'] as int);

    return Positioned(
      top: top,
      left: dayColWidth * dayIndex,
      width: dayColWidth,
      height: height,
      child: Container(
        margin: const EdgeInsets.all(1),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        child: Text(
          (c['title'] ?? '').toString(),
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black87),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
