import 'package:fluent_ui/fluent_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:swu_dormi_admin/models/student_model.dart';
import 'package:swu_dormi_admin/screens/windows/windows_cleaning_inspection_current_screen.dart';
import 'package:swu_dormi_admin/screens/windows/windows_cleaning_inspection_history_screen.dart';

// ──────────── 점검 구역 목록 (파일 공통) ────────────
const List<String> kFloorOptions = [
  '샬롬하우스 A동 2층',
  '샬롬하우스 A동 3층',
  '샬롬하우스 A동 4층',
  '샬롬하우스 A동 5층',
  '샬롬하우스 A동 6층',
  '샬롬하우스 A동 7층',
  '샬롬하우스 B동 2층',
  '샬롬하우스 B동 3층',
  '샬롬하우스 B동 4층',
  '샬롬하우스 B동 5층',
  '샬롬하우스 B동 6층',
  '샬롬하우스 B동 7층',
  '국제생활관 A동 1층',
  '국제생활관 A동 2층',
  '국제생활관 B동 2층',
  '국제생활관 B동 3층',
  '바롬인성교육관 10층',
  '샬롬하우스(겨울방학) A동 5층',
  '샬롬하우스(겨울방학) A동 6층',
  '샬롬하우스(겨울방학) A동 7층',
];

// ──────────── 건물 색상 (파일 공통) ────────────
Color buildingColor(String? floor) {
  if (floor == null) return const Color(0xFF9E9E9E);
  if (floor.startsWith('샬롬하우스') ||
      floor.startsWith('A동') ||
      floor.startsWith('B동'))
    return const Color(0xFF2196F3);
  if (floor.startsWith('국제생활관')) return const Color(0xFF4CAF50);
  if (floor.startsWith('바롬인성교육관')) return const Color(0xFFFF9800);
  return const Color(0xFF9E9E9E);
}

// ──────────── 인실 레이블 (파일 공통) ────────────
String roomCapacityLabel(String roomNumber) =>
    StudentModel.capacityLabel(roomNumber);

// ──────────── 1-4점 버튼 색상 (파일 공통) ────────────
Color scoreButtonColor(int val) {
  if (val == 4) return const Color(0xFF4CAF50); // green
  if (val == 3) return const Color(0xFF2196F3); // blue
  if (val == 2) return const Color(0xFFFF9800); // orange
  return const Color(0xFFF44336); // red
}

// ──────────── score 헬퍼 (파일 공통) ────────────
String scoreLabel(double? score) {
  if (score == null) return '미평가';
  return '${score.toStringAsFixed(1)}점';
}

Color scoreColor(double? score) {
  if (score == null) return const Color(0xFF9E9E9E); // Colors.grey
  if (score >= 3.5) return const Color(0xFF4CAF50); // Colors.green
  if (score >= 2.5) return const Color(0xFF2196F3); // Colors.blue
  return const Color(0xFFF44336); // Colors.red
}

// ──────────── 이전 검사 이력 (재검사 전 결과, 파일 공통) ────────────
Widget buildEvaluationHistorySection(List history) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.grey.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '이전 검사 이력 (${history.length}회)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey[110],
          ),
        ),
        const SizedBox(height: 6),
        for (int i = 0; i < history.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          _buildEvaluationHistoryEntry(i + 1, history[i] as Map<String, dynamic>),
        ],
      ],
    ),
  );
}

Widget _buildEvaluationHistoryEntry(int round, Map<String, dynamic> entry) {
  final scoreAvg = (entry['scoreAvg'] as num?)?.toDouble();
  final needsRecheck = entry['needsRecheck'] == true;
  final comment = entry['comment'] as String?;
  final evaluatedByEmail = entry['evaluatedByEmail'] as String?;
  final evaluatedAt = (entry['evaluatedAt'] as Timestamp?)?.toDate();

  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$round회차',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[110]),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (scoreAvg != null)
                  Text(
                    '${scoreAvg.toStringAsFixed(1)}점',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scoreColor(scoreAvg)),
                  ),
                if (needsRecheck) ...[
                  const SizedBox(width: 6),
                  Text('재검사 필요', style: TextStyle(fontSize: 11, color: Colors.red)),
                ],
                if (evaluatedAt != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('yyyy.MM.dd HH:mm').format(evaluatedAt),
                    style: TextStyle(fontSize: 10, color: Colors.grey[90]),
                  ),
                ],
              ],
            ),
            if (comment != null && comment.isNotEmpty)
              Text(
                '코멘트: $comment',
                style: TextStyle(fontSize: 11, color: Colors.grey[100]),
              ),
            if (evaluatedByEmail != null)
              Text(
                '검사자: $evaluatedByEmail',
                style: TextStyle(fontSize: 10, color: Colors.grey[90]),
              ),
          ],
        ),
      ),
    ],
  );
}

// ──────────── 청소검사 체크리스트 구조 (파일 공통) ────────────
const Map<String, List<String>> kPersonalCheckStructure = {
  '옷장': ['안', '거울', '서랍'],
  '침대': ['매트리스 얼룩', '서랍'],
  '창문': ['좌', '중', '우'],
  '책상': ['책상 위', '거울', '여닫이', '바닥'],
  '화장대': ['거울'],
  '바닥': ['구석', '바닥'],
  '택배': ['수령확인'],
};

// 샬롬하우스 퇴사검사 - 공동 구역
const Map<String, List<String>> kCommunalCheckStructure = {
  '현관': ['바닥', '신발장'],
  '화장실': ['변기', '하수구', '타일(물때)'],
  '샤워실': ['거울', '세면(물때)', '하수구', '타일(물때)'],
  '세면대': ['위', '거울', '여닫이'],
  '공동 바닥': ['구석', '바닥'],
  '냉장고': ['안'],
};

// 샬롬하우스 월검사
const Map<String, List<String>> kShalomMonthlyStructure = {
  '현관': ['바닥, 거울(얼룩)'],
  '바닥': ['거실', '개인방, 책상 밑'],
  '창문': ['창틀(먼지)'],
  '냉장고': ['안(얼룩)'],
  '샤워실': ['하수구(머리카락)', '거울(얼룩)', '바닥 모서리, 곰팡이 흘때'],
  '세면대(4인실)': ['세면대(얼룩,물때)', '거울(얼룩)'],
  '화장실': ['하수구(머리카락)', '변기안(얼룩)'],
  '콘센트': ['(먼지)\n문어발식 사용\n접지 이상, 노후\n 흘들때 안에서 소리 나면 안됨'],
};

// 국제생활관 퇴사검사 - 개인 구역
const Map<String, List<String>> kGlobalPersonalCheckStructure = {
  '옷장': ['안', '거울', '서랍'],
  '침대': ['매트리스 얼룩', '서랍'],
  '창문': ['좌', '중', '우'],
  '책상': ['책상 위', '거울', '여닫이', '바닥'],
  '화장대': ['거울'],
  '바닥': ['구석', '바닥'],
  '택배': ['수령확인'],
};

// 국제생활관 퇴사검사 - 공동 구역
const Map<String, List<String>> kGlobalCommunalCheckStructure = {
  '현관': ['바닥', '신발장'],
  '공동 바닥': ['구석', '바닥'],
  '냉장고': ['안'],
};

// 국제생활관 월검사
const Map<String, List<String>> kGlobalMonthlyStructure = {
  '바닥': ['바닥'],
  '창문': ['창틀(먼지)'],
  '냉장고': ['안(얼룩)'],
  '옷장': ['거울(얼룩)'],
  '에어컨 리모콘': ['있음/없음'],
  '콘센트': ['(먼지)\n문어발식 사용\n접지 이상, 노후\n 흘들때 안에서 소리 나면 안됨'],
};

({
  Map<String, List<String>> personal,
  Map<String, List<String>> communal,
})
getCheckStructures(String floor, String inspectionType) {
  final isMoveOut = inspectionType == 'move_out';
  final isGlobal = floor.startsWith('국제생활관');
  if (isMoveOut) {
    if (isGlobal) {
      return (
        personal: kGlobalPersonalCheckStructure,
        communal: kGlobalCommunalCheckStructure,
      );
    }
    return (
      personal: kPersonalCheckStructure,
      communal: kCommunalCheckStructure,
    );
  } else {
    return (
      personal: const {},
      communal: isGlobal ? kGlobalMonthlyStructure : kShalomMonthlyStructure,
    );
  }
}


/// 월검사(monthly) 또는 퇴사검사(move_out) 하나를 "현재 / 이력" 2탭으로 보여주는 화면.
/// 사이드바에서 월검사·월검사이력, 퇴사검사·퇴사검사이력을 각각 하나의 메뉴로 통합할 때 사용한다.
class WindowsInspectionTabScreen extends StatefulWidget {
  final String inspectionType; // 'monthly' | 'move_out'
  const WindowsInspectionTabScreen({super.key, required this.inspectionType});

  @override
  State<WindowsInspectionTabScreen> createState() =>
      _WindowsInspectionTabScreenState();
}

class _WindowsInspectionTabScreenState
    extends State<WindowsInspectionTabScreen> {
  // 0: 현재, 1: 이력
  int _tabIndex = 0;

  bool get _isMoveOut => widget.inspectionType == 'move_out';

  @override
  Widget build(BuildContext context) {
    final accentColor = _isMoveOut ? Colors.orange : Colors.teal;
    final currentLabel = _isMoveOut ? '퇴사검사' : '월검사';
    final historyLabel = _isMoveOut ? '퇴사검사이력' : '월검사이력';

    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Column(
        children: [
          // 탭 헤더
          Container(
            color: FluentTheme.of(context).cardColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _buildTab(0, currentLabel, FluentIcons.calendar, accentColor),
                const SizedBox(width: 8),
                _buildTab(1, historyLabel, FluentIcons.history, accentColor),
              ],
            ),
          ),
          // 탭 콘텐츠
          Expanded(
            child: _tabIndex == 1
                ? RoomInspectionHistoryContent(fixedType: widget.inspectionType)
                : CleaningInspectionContent(fixedType: widget.inspectionType),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label, IconData icon, Color accentColor) {
    final isSelected = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.12)
              : Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? accentColor : Colors.grey.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? accentColor : Colors.grey),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? accentColor : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

