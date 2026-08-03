import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:excel/excel.dart' hide Border;
import '../../utils/building_utils.dart';
import '../../models/excel_student_row.dart';

// ── 체크리스트 구조 (파일 공통) ──

// 샬롬하우스 퇴사검사 - 개인 구역
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

// 샬롬하우스 월검사 - 4인실
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

// 샬롬하우스 월검사 - 2인실 (세면대가 샤워실 안에 포함, 화장실 별도)
const Map<String, List<String>> kShalomMonthlyStructure2Person = {
  '현관': ['바닥, 거울(얼룩)'],
  '바닥': ['거실', '개인방, 책상 밑'],
  '창문': ['창틀(먼지)'],
  '냉장고': ['안(얼룩)'],
  '샤워실': ['하수구(머리카락)', '거울(얼룩)', '바닥 모서리, 곰팡이 흘때', '세면대(얼룩,물때)'],
  '화장실': ['하수구(머리카락)', '변기안(얼룩)'],
  '콘센트': ['(먼지)\n문어발식 사용\n접지 이상, 노후\n 흘들때 안에서 소리 나면 안됨'],
};

// 샬롬하우스 월검사 - 1인실 (샤워실+화장실 통합)
const Map<String, List<String>> kShalomMonthlyStructure1Person = {
  '현관': ['바닥, 거울(얼룩)'],
  '바닥': ['거실', '개인방, 책상 밑'],
  '창문': ['창틀(먼지)'],
  '냉장고': ['안(얼룩)'],
  '샤워실/화장실': ['하수구(머리카락)', '거울(얼룩)', '바닥 모서리, 곰팡이 흘때', '세면대(얼룩,물때)', '변기안(얼룩)'],
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


// floor + inspectionType + roomNumber → (personal, communal) 구조 반환
({Map<String, List<String>> personal, Map<String, List<String>> communal})
    getCheckStructures(String floor, String inspectionType, {String roomNumber = ''}) {
  final isMoveOut = inspectionType == 'move_out';
  final isGlobal = floor.startsWith('국제생활관');
  if (isMoveOut) {
    // 퇴사검사: 건물별 개인 + 공동 구분
    if (isGlobal) {
      return (personal: kGlobalPersonalCheckStructure, communal: kGlobalCommunalCheckStructure);
    }
    return (personal: kPersonalCheckStructure, communal: kCommunalCheckStructure);
  } else {
    // 월검사: 인실 수에 따라 구조 선택
    if (isGlobal) return (personal: const {}, communal: kGlobalMonthlyStructure);
    final cap = shalomRoomCapacity(roomNumber);
    final monthly = cap == 1
        ? kShalomMonthlyStructure1Person
        : cap == 2
            ? kShalomMonthlyStructure2Person
            : kShalomMonthlyStructure;
    return (personal: const {}, communal: monthly);
  }
}

// ══════════════════════════════════════════════════════════════
// 청소점검 메인 화면 (탭: 월검사/퇴사검사 / 호실 이력/ 학생 이력)
// ══════════════════════════════════════════════════════════════
class CleaningInspectionScreen extends StatefulWidget {
  final String inspectionType;

  const CleaningInspectionScreen({
    super.key,
    required this.inspectionType,
  });

  @override
  State<CleaningInspectionScreen> createState() =>
      CleaningInspectionScreenState();
}

class CleaningInspectionScreenState extends State<CleaningInspectionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _historyKey = GlobalKey<_RoomInspectionHistoryContentState>();

  void resetToFirstTab() {
    if (_tabController.index != 0) {
      _tabController.animateTo(0);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // 이력 탭(index 1)으로 전환될 때마다 데이터 새로고침
      if (_tabController.index == 1 && !_tabController.indexIsChanging) {
        _historyKey.currentState?._loadData();
      }
    });
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
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              icon: const Icon(Icons.calendar_month, size: 18),
              text: widget.inspectionType == 'move_out' ? '퇴사청소 점검' : '월청소 점검',
            ),
            Tab(icon: const Icon(Icons.history, size: 18), text: widget.inspectionType == 'move_out' ? '학생 이력' : '호실 이력'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CleaningInspectionContent(
            key: ValueKey(widget.inspectionType),
            inspectionType: widget.inspectionType,
            tabLabel: widget.inspectionType == 'move_out' ? '퇴사청소 점검' : '월청소 점검',
          ),
          RoomInspectionHistoryContent(key: _historyKey, fixedType: widget.inspectionType),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 점검 구역 목록
// ══════════════════════════════════════════════════════════════
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

// ══════════════════════════════════════════════════════════════
// 월검사/퇴사검사 탭 콘텐츠
// ══════════════════════════════════════════════════════════════
class CleaningInspectionContent extends StatefulWidget {
  final String inspectionType;
  final String tabLabel;

  const CleaningInspectionContent({
    super.key,
    required this.inspectionType,
    required this.tabLabel,
  });

  @override
  State<CleaningInspectionContent> createState() =>
      _CleaningInspectionContentState();
}

class _CleaningInspectionContentState
    extends State<CleaningInspectionContent> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<QueryDocumentSnapshot> _schedules = [];
  List<QueryDocumentSnapshot> _requests = [];
  bool _isLoadingSchedules = true;
  bool _isLoadingRequests = true;
  String? _selectedScheduleId;
  String? _selectedFloorFilter;

  List<QueryDocumentSnapshot> get _filteredSchedules {
    final list = _schedules.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final type = (data['inspectionType'] ?? 'monthly') as String;
      return type == widget.inspectionType;
    }).toList();

    if (_selectedFloorFilter == null) return list;
    return list.where((doc) {
      final floor = (doc.data() as Map<String, dynamic>)['floor'] as String?;
      return floor == _selectedFloorFilter;
    }).toList();
  }

  // ── 체크리스트 구조 (top-level kPersonalCheckStructure / kCommunalCheckStructure 사용) ──

  @override
  void initState() {
    super.initState();
    _loadAssignedFloor();
    _loadSchedules();
    _loadRequests();
  }

  Future<void> _loadAssignedFloor() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final floor = doc.data()?['assignedFloor'] as String?;
      if (mounted) setState(() => _selectedFloorFilter = floor);
    } catch (_) {}
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoadingSchedules = true);
    try {
      final snap = await _firestore
          .collection('cleaning_schedules')
          .orderBy('date', descending: false)
          .get();
      if (mounted) {
        setState(() {
          _schedules = snap.docs;
          _isLoadingSchedules = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSchedules = false);
    }
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoadingRequests = true);
    try {
      final snap = await _firestore
          .collection('cleaning_requests')
          .orderBy('createdAt', descending: true)
          .get();
      if (mounted) {
        setState(() {
          _requests = snap.docs;
          _isLoadingRequests = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRequests = false);
    }
  }

  List<QueryDocumentSnapshot> _requestsForSchedule(String scheduleId) {
    // 스케줄의 floor에서 건물명 추출 → 해당 건물 학생만 포함
    final scheduleDoc = _schedules.where((s) => s.id == scheduleId).firstOrNull;
    final scheduleFloor = scheduleDoc != null
        ? ((scheduleDoc.data() as Map<String, dynamic>)['floor'] ?? '') as String
        : '';
    String? scheduleBuilding;
    if (scheduleFloor.startsWith('샬롬하우스(겨울방학)')) { scheduleBuilding = '샬롬하우스(겨울방학)'; }
    else if (scheduleFloor.startsWith('샬롬하우스')) { scheduleBuilding = '샬롬하우스'; }
    else if (scheduleFloor.startsWith('국제생활관')) { scheduleBuilding = '국제생활관'; }
    else if (scheduleFloor.startsWith('바롬인성교육관')) { scheduleBuilding = '바롬인성교육관'; }

    final list = _requests.where((req) {
      final data = req.data() as Map<String, dynamic>;
      if (data['scheduleId'] != scheduleId) return false;
      if (scheduleBuilding != null) {
        final studentDorm = data['dormBuilding'] as String?;
        if (studentDorm == null || studentDorm != scheduleBuilding) return false;
      }
      return true;
    }).toList();
    list.sort((a, b) {
      final aTs = ((a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      final bTs = ((b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      return aTs.compareTo(bTs);
    });
    return list;
  }

  static Map<String, int> _makeScores(Map<String, List<String>> structure, {bool isMoveOut = false}) => {
        for (final e in structure.entries)
          for (final item in e.value) '${e.key}_$item': isMoveOut ? 1 : 4,
      };

  static int _countFail(Map<String, Map<String, int>> studentScores, Map<String, int> communalScores) {
    return studentScores.values.expand((m) => m.values).where((v) => v == 0).length +
        communalScores.values.where((v) => v == 0).length;
  }

  static double _calcAvg(Map<String, Map<String, int>> studentScores, Map<String, int> communalScores) {
    final all = [...studentScores.values.expand((m) => m.values), ...communalScores.values];
    if (all.isEmpty) return 4.0;
    return all.reduce((a, b) => a + b) / all.length;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSchedules;
    return Scaffold(
      body: _isLoadingSchedules
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 스케줄 목록
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: () async {
                            await _loadSchedules();
                            await _loadRequests();
                          },
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) =>
                                _buildScheduleCard(filtered[index]),
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddScheduleDialog,
        icon: const Icon(Icons.add),
        label: const Text('점검일정 추가'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cleaning_services, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('등록된 ${widget.tabLabel} 일정이 없습니다',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _showAddScheduleDialog,
            icon: const Icon(Icons.add),
            label: const Text('일정 추가'),
          ),
        ],
      ),
    );
  }

  // ── 스케줄 카드 ──
  Widget _buildScheduleCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final date = (data['date'] as Timestamp?)?.toDate();
    final startTime = (data['startTime'] ?? '') as String;
    final endTime = (data['endTime'] ?? '') as String;
    final floor = (data['floor'] ?? '') as String;
    final maxCapacity =
        (data['maxCapacity'] is num) ? (data['maxCapacity'] as num).toInt() : 1;
    final currentCount = (data['currentCount'] is num)
        ? (data['currentCount'] as num).toInt()
        : 0;
    final status = (data['status'] ?? 'open') as String;
    final applyStart = (data['applicationStart'] as Timestamp?)?.toDate();
    final deadline = (data['applicationDeadline'] as Timestamp?)?.toDate();
    final isSelected = _selectedScheduleId == doc.id;
    final isDeadlinePassed = deadline != null && deadline.isBefore(DateTime.now());
    final isNotStartedYet = applyStart != null && applyStart.isAfter(DateTime.now());

    final scheduleRequests = _requestsForSchedule(doc.id);
    final requestsCount = scheduleRequests.length;
    final completedCount = scheduleRequests.where((r) {
      final d = r.data() as Map<String, dynamic>;
      return (d['status'] ?? '') == 'completed';
    }).length;
    final incompleteCount = requestsCount - completedCount;

    final stripeColor = buildingColor(floor);

    Color statusColor;
    String statusText;
    if (isDeadlinePassed && status == 'open') {
      statusColor = Colors.grey;
      statusText = '신청만료';
    } else if (isNotStartedYet && status == 'open') {
      statusColor = Colors.blue;
      statusText = '예정';
    } else {
      switch (status) {
        case 'open':
          statusColor = Colors.green;
          statusText = '신청가능';
          break;
        case 'full':
          statusColor = Colors.red;
          statusText = '신청초과';
          break;
        case 'closed':
          statusColor = Colors.grey;
          statusText = '마감';
          break;
        default:
          statusColor = Colors.grey;
          statusText = status;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Stack(
        children: [
          Card(
            margin: EdgeInsets.zero,
            elevation: isSelected ? 4 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isSelected
                  ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
                  : BorderSide(color: stripeColor.withValues(alpha: 0.5), width: 1.5),
            ),
            child: Column(
              children: [
                InkWell(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  onTap: () => setState(() {
                    _selectedScheduleId = isSelected ? null : doc.id;
                  }),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(21, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // 날짜 박스
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    date != null ? DateFormat('MM/dd').format(date) : '--',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                  if (date != null)
                                    Text(
                                      DateFormat('E', 'ko').format(date),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // 정보
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        floor.isNotEmpty ? floor : '점검 스케줄',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Text('$startTime ~ $endTime', style: TextStyle(color: Colors.grey.shade600)),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(Icons.people, size: 14, color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Text(
                                        '호실 $currentCount/$maxCapacity',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                      if (requestsCount > 0) ...[
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '완료 $completedCount / 미완료 $incompleteCount',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.blue,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (applyStart != null || deadline != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '신청기간: '
                                      '${applyStart != null ? DateFormat('MM/dd HH:mm').format(applyStart) : '-'}'
                                      ' ~ '
                                      '${deadline != null ? DateFormat('MM/dd HH:mm').format(deadline) : '-'}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // 상태 + 메뉴
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (requestsCount > 0 && incompleteCount > 0) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.purple.withValues(alpha: 0.4)),
                                    ),
                                    child: const Text(
                                      '검사필요',
                                      style: TextStyle(color: Colors.purple, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                                if (requestsCount > 0 && incompleteCount == 0) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                                    ),
                                    child: const Text(
                                      '검사완료',
                                      style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _showEditTimeDialog(doc.id, date, startTime, endTime);
                                    } else if (value == 'delete') {
                                      _deleteSchedule(doc.id);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(children: [
                                        Icon(Icons.edit, color: Colors.blue, size: 18),
                                        SizedBox(width: 8),
                                        Text('시간 수정'),
                                      ]),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(children: [
                                        Icon(Icons.delete, color: Colors.red, size: 18),
                                        SizedBox(width: 8),
                                        Text('삭제', style: TextStyle(color: Colors.red)),
                                      ]),
                                    ),
                                  ],
                                  icon: const Icon(Icons.more_vert, size: 18),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // 선택된 경우 신청 목록 표시
                if (isSelected) _buildRequestsSection(doc.id),
              ],
            ),
          ),
          // 좌측 건물 색상 스트라이프
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 5,
              decoration: BoxDecoration(
                color: stripeColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 신청 목록 섹션 ──
  Widget _buildRequestsSection(String scheduleId) {
    if (_isLoadingRequests) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final requests = _requestsForSchedule(scheduleId);

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Text(
                  '신청 목록 (${requests.length}건)',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _loadRequests,
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('새로고침', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          if (requests.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '해당 일정에 대한 신청이 없습니다',
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _buildRequestCard(requests[index]),
            ),
        ],
      ),
    );
  }

  // ── 신청 카드 ──
  Widget _buildRequestCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final userName = (data['userName'] ?? '') as String;
    final roomNumber = (data['roomNumber'] ?? '') as String;
    final status = (data['status'] ?? 'pending') as String;
    final grade = data['grade'] as String?;
    final scoreAvg = (data['scoreAvg'] as num?)?.toDouble();
    final needsRecheck = data['needsRecheck'] == true;
    final comment = (data['inspectionComment'] ?? data['comment']) as String?;
    final memo = data['memo'] as String?;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final inspectionType = data['inspectionType'] as String?;
    final isMoveOut = inspectionType == 'move_out';

    Color statusColor;
    String statusText;
    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        statusText = '대기중';
        break;
      case 'in_progress':
        statusColor = Colors.blue;
        statusText = '점검중';
        break;
      case 'completed':
        statusColor = Colors.green;
        statusText = '완료';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = '반려됨';
        break;
      default:
        statusColor = Colors.grey;
        statusText = status;
    }

    String gradeText = '';
    Color gradeColor = Colors.grey;
    if (scoreAvg != null) {
      if (isMoveOut) {
        gradeText = needsRecheck ? 'Fail' : 'Pass';
        gradeColor = needsRecheck ? Colors.red : Colors.green;
      } else {
        gradeText = '${scoreAvg.toStringAsFixed(1)}점';
        if (scoreAvg >= 3.5) {
          gradeColor = Colors.green;
        } else if (scoreAvg >= 2.5) {
          gradeColor = Colors.blue;
        } else {
          gradeColor = Colors.red;
        }
      }
    } else if (grade != null) {
      switch (grade) {
        case 'excellent':
          gradeText = '매우양호';
          gradeColor = Colors.green;
          break;
        case 'good':
          gradeText = '양호';
          gradeColor = Colors.blue;
          break;
        case 'poor':
          gradeText = '미흡';
          gradeColor = Colors.red;
          break;
      }
    }

    final scheduleId = (data['scheduleId'] ?? '') as String;
    QueryDocumentSnapshot? scheduleDoc;
    for (final s in _schedules) {
      if (s.id == scheduleId) {
        scheduleDoc = s;
        break;
      }
    }
    String scheduleFloor = '';
    if (scheduleDoc != null) {
      final sd = scheduleDoc.data() as Map<String, dynamic>?;
      scheduleFloor = (sd?['floor'] as String?) ?? '';
    }
    final isShalom = scheduleFloor.startsWith('샬롬하우스');
    final capacity = isShalom ? shalomRoomCapacity(roomNumber) : null;

    final roomDisplay = capacity != null
        ? '$roomNumber호 ($capacity인실) — $userName'
        : '$roomNumber호 — $userName';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  roomDisplay,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor),
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'evaluate') {
                    _showEvaluateDialog(doc.id, data);
                  } else if (value == 'copy_prev') {
                    final prev = _requests.where((d) {
                      final dd = d.data() as Map<String, dynamic>;
                      return dd['roomNumber'] == roomNumber &&
                          dd['status'] == 'completed' &&
                          d.id != doc.id;
                    }).toList()
                      ..sort((a, b) {
                        final ta = ((a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?)?.toDate();
                        final tb = ((b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?)?.toDate();
                        if (ta == null) return 1;
                        if (tb == null) return -1;
                        return tb.compareTo(ta);
                      });
                    if (prev.isNotEmpty) {
                      _showEvaluateDialog(doc.id, data, prefillData: prev.first.data() as Map<String, dynamic>);
                    }
                  } else if (value == 'edit') {
                    _showEvaluateDialog(doc.id, data);
                  } else if (value == 'reject') {
                    _rejectRequest(doc.id);
                  } else if (value == 'delete') {
                    _deleteRequest(doc.id);
                  } else if (value == 'history') {
                    _navigateToRoomHistory(roomNumber);
                  }
                },
                itemBuilder: (_) => [
                  if (status == 'pending' || status == 'in_progress')
                    const PopupMenuItem(
                      value: 'evaluate',
                      child: Row(children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                        SizedBox(width: 8),
                        Text('점검 평가'),
                      ]),
                    ),
                  if (status == 'pending' && _requests.any((d) {
                    final dd = d.data() as Map<String, dynamic>;
                    return dd['roomNumber'] == roomNumber && dd['status'] == 'completed' && d.id != doc.id;
                  }))
                    const PopupMenuItem(
                      value: 'copy_prev',
                      child: Row(children: [
                        Icon(Icons.copy, color: Colors.teal, size: 18),
                        SizedBox(width: 8),
                        Text('검사 2차,3차...'),
                      ]),
                    ),
                  if (status == 'completed')
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit, color: Colors.blue, size: 18),
                        SizedBox(width: 8),
                        Text('평가 수정'),
                      ]),
                    ),
                  const PopupMenuItem(
                    value: 'history',
                    child: Row(children: [
                      Icon(Icons.history, color: Colors.teal, size: 18),
                      SizedBox(width: 8),
                      Text('호실 이력 보기'),
                    ]),
                  ),
                  if (status == 'pending')
                    const PopupMenuItem(
                      value: 'reject',
                      child: Row(children: [
                        Icon(Icons.cancel, color: Colors.orange, size: 18),
                        SizedBox(width: 8),
                        Text('반려'),
                      ]),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete, color: Colors.red, size: 18),
                      SizedBox(width: 8),
                      Text('삭제', style: TextStyle(color: Colors.red)),
                    ]),
                  ),
                ],
                icon: const Icon(Icons.more_vert, size: 18),
              ),
            ],
          ),
          if (createdAt != null) ...[
            const SizedBox(height: 4),
            Text(
              '신청: ${DateFormat('yyyy.MM.dd HH:mm').format(createdAt)}',
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
          if (isMoveOut) ...[
            () {
              final raw = data['commonAreas'];
              List<String> areas = [];
              if (raw is List) {
                areas = raw.map((e) => e.toString()).toList();
              } else if (raw is String && raw.isNotEmpty) {
                areas = [raw];
              }
              if (areas.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Icon(Icons.home_work_outlined, size: 14, color: Colors.cyan),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '공동구역: ${areas.join(' · ')}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.cyan,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }(),
          ],
          if (memo != null && memo.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('메모: $memo',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade600)),
          ],
          if (scoreAvg != null || grade != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: gradeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border:
                        Border.all(color: gradeColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '평가: $gradeText',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: gradeColor),
                  ),
                ),
                if (needsRecheck) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      '재검사 필요',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ),
                ],
                if (comment != null && comment.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      comment,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _navigateToRoomHistory(String roomNumber) async {
    try {
      final snap = await _firestore
          .collection('cleaning_requests')
          .where('roomNumber', isEqualTo: roomNumber)
          .get();
      final requests = snap.docs
        ..sort((a, b) {
          final aT = (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
          final bT = (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
          return bT.compareTo(aT);
        });

      int excellentCount = 0, goodCount = 0, poorCount = 0;
      String studentName = '';
      for (final req in requests) {
        final d = req.data();
        if (studentName.isEmpty) studentName = (d['userName'] ?? '') as String;
        switch (_RoomInspectionHistoryContentState._categorizeHistoryGrade(d)) {
          case 'excellent':
            excellentCount++;
            break;
          case 'good':
            goodCount++;
            break;
          case 'poor':
            poorCount++;
            break;
        }
      }

      final scheduleIds = requests
          .map((r) => (r.data()['scheduleId'] ?? '') as String)
          .where((id) => id.isNotEmpty)
          .toSet();
      final Map<String, Map<String, dynamic>> scheduleMap = {};
      for (final id in scheduleIds) {
        try {
          final s = await _firestore.collection('cleaning_schedules').doc(id).get();
          if (s.exists) scheduleMap[id] = s.data()!;
        } catch (_) {}
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _RoomHistoryDetailScreen(
            roomNumber: roomNumber,
            studentName: studentName,
            requests: requests,
            scheduleMap: scheduleMap,
            excellentCount: excellentCount,
            goodCount: goodCount,
            poorCount: poorCount,
            inspectionType: widget.inspectionType,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이력 조회 오류: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── 일정 추가 다이얼로그 ──
  Future<void> _showAddScheduleDialog() async {
    if (!mounted) return;

    DateTime selectedDate =
        DateTime.now().add(const Duration(days: 1));
    DateTime applyStartDate = DateTime.now();
    final applyStartTimeCtrl = TextEditingController(text: '00:00');
    DateTime deadlineDate = DateTime.now();
    final deadlineTimeCtrl = TextEditingController(text: '23:00');
    final startTimeCtrl = TextEditingController(text: '10:00');
    final endTimeCtrl = TextEditingController(text: '12:00');
    final capacityCtrl = TextEditingController(text: '6');
    final cleaningNoteCtrl = TextEditingController();
    // 담당 구역이 있으면 그 값으로 고정, 없으면 첫 번째 옵션
    final fixedFloor = _selectedFloorFilter;
    String selectedFloor = fixedFloor ?? kFloorOptions.first;
    String selectedInspectionType = widget.inspectionType;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('${widget.tabLabel} 일정 추가'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (fixedFloor != null)
                  Row(
                    children: [
                      Icon(Icons.layers_outlined, size: 20, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        fixedFloor,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ],
                  )
                else
                  DropdownButtonFormField<String>(
                    value: selectedFloor,
                    decoration: const InputDecoration(
                      labelText: '점검 구역',
                      prefixIcon: Icon(Icons.layers_outlined),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: kFloorOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value, style: const TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != null) {
                        setDialogState(() => selectedFloor = newValue);
                      }
                    },
                  ),
                const SizedBox(height: 16),

                const Text('점검 날짜',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now()
                          .add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16),
                        const SizedBox(width: 8),
                        Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('시작 시간',
                              style:
                                  TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: startTimeCtrl,
                            decoration: const InputDecoration(
                              hintText: 'HH:MM',
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('종료 시간',
                              style:
                                  TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: endTimeCtrl,
                            decoration: const InputDecoration(
                              hintText: 'HH:MM',
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('최대 검사 가능 호실',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: capacityCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    suffixText: '호실',
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('신청 시작',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: applyStartDate,
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 7)),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setDialogState(
                                () => applyStartDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border:
                                Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.event, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('MM/dd')
                                    .format(applyStartDate),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: applyStartTimeCtrl,
                        decoration: const InputDecoration(
                          hintText: 'HH:MM',
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('신청 기한(마감)',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: deadlineDate,
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 7)),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setDialogState(
                                () => deadlineDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border:
                                Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.event, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('MM/dd')
                                    .format(deadlineDate),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: deadlineTimeCtrl,
                        decoration: const InputDecoration(
                          hintText: 'HH:MM',
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('중점 청소 필요사항',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: cleaningNoteCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: '중점적으로 청소해야 할 사항을 입력하세요',
                    contentPadding: EdgeInsets.all(12),
                    border: OutlineInputBorder(),
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
                Navigator.pop(ctx);
                _addSchedule(
                  selectedDate,
                  startTimeCtrl.text.trim(),
                  endTimeCtrl.text.trim(),
                  int.tryParse(capacityCtrl.text.trim()) ?? 5,
                  selectedFloor,
                  applyStartDate,
                  applyStartTimeCtrl.text.trim(),
                  deadlineDate,
                  deadlineTimeCtrl.text.trim(),
                  selectedInspectionType,
                  cleaningNoteCtrl.text.trim(),
                );
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addSchedule(
    DateTime date,
    String startTime,
    String endTime,
    int maxCapacity,
    String floor,
    DateTime applyStartDate,
    String applyStartTime,
    DateTime deadlineDate,
    String deadlineTime,
    String inspectionType,
    String cleaningNote,
  ) async {
    try {
      final asParts = applyStartTime.split(':');
      final asHour = int.tryParse(asParts.isNotEmpty ? asParts[0] : '0') ?? 0;
      final asMinute = int.tryParse(asParts.length > 1 ? asParts[1] : '0') ?? 0;
      final applyStart = DateTime(
          applyStartDate.year, applyStartDate.month, applyStartDate.day, asHour, asMinute);

      final parts = deadlineTime.split(':');
      final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '23') ?? 23;
      final minute = int.tryParse(parts.length > 1 ? parts[1] : '59') ?? 59;
      final deadline = DateTime(
          deadlineDate.year, deadlineDate.month, deadlineDate.day, hour, minute);

      final isMoveOut = inspectionType == 'move_out';
      final dayCount = isMoveOut ? 1 : 4;

      final batch = _firestore.batch();
      for (int i = 0; i < dayCount; i++) {
        final scheduleDate = date.add(Duration(days: i));
        final ref = _firestore.collection('cleaning_schedules').doc();
        batch.set(ref, {
          'date': Timestamp.fromDate(
              DateTime(scheduleDate.year, scheduleDate.month, scheduleDate.day)),
          'startTime': startTime,
          'endTime': endTime,
          'maxCapacity': maxCapacity,
          'floor': floor,
          'currentCount': 0,
          'status': 'open',
          'inspectionType': inspectionType,
          'createdAt': Timestamp.now(),
          'applicationStart': Timestamp.fromDate(applyStart),
          'applicationDeadline': Timestamp.fromDate(deadline),
          if (cleaningNote.isNotEmpty) 'cleaningNote': cleaningNote,
        });
      }
      await batch.commit();

      await _loadSchedules();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isMoveOut ? '퇴사 검사 일정이 추가되었습니다' : '4일 연속 일정이 추가되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showEditTimeDialog(
      String scheduleId, DateTime? currentDate, String currentStart, String currentEnd) async {
    DateTime selectedDate = currentDate ?? DateTime.now();
    final startCtrl = TextEditingController(text: currentStart);
    final endCtrl = TextEditingController(text: currentEnd);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('날짜 및 시간 수정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('날짜', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setDialogState(() => selectedDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        '${selectedDate.year}.${selectedDate.month.toString().padLeft(2, '0')}.${selectedDate.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: startCtrl,
                decoration: const InputDecoration(
                  labelText: '시작 시간',
                  hintText: '예: 10:00',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: endCtrl,
                decoration: const InputDecoration(
                  labelText: '종료 시간',
                  hintText: '예: 12:00',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    try {
      await _firestore
          .collection('cleaning_schedules')
          .doc(scheduleId)
          .update({
        'date': Timestamp.fromDate(selectedDate),
        'startTime': startCtrl.text.trim(),
        'endTime': endCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('수정되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
      }
    }
  }

  Future<void> _deleteSchedule(String scheduleId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('일정 삭제'),
        content: const Text('이 일정을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
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
      // 삭제 전: 스케줄에서 dormBuilding·inspectionType을 request에 보존
      // (스케줄 삭제 후에도 _loadData에서 탭 필터·건물 파악 가능하도록)
      // 삭제 전: 스케줄에서 dormBuilding·inspectionType을 request에 보존
      // (스케줄 삭제 후에도 _loadData에서 탭 필터·건물 파악 가능하도록)
      final scheduleDoc = await _firestore.collection('cleaning_schedules').doc(scheduleId).get();
      final scheduleData = scheduleDoc.data() ?? {};
      final scheduleInspType = scheduleData['inspectionType'] as String? ?? widget.inspectionType;
      final floorStr = scheduleData['floor']?.toString() ?? '';
      final String? scheduleBuilding;
      if (floorStr.startsWith('샬롬하우스(겨울방학)')) {
        scheduleBuilding = '샬롬하우스(겨울방학)';
      } else if (floorStr.startsWith('샬롬하우스')) {
        scheduleBuilding = '샬롬하우스';
      } else if (floorStr.startsWith('국제생활관')) {
        scheduleBuilding = '국제생활관';
      } else if (floorStr.startsWith('바롬인성교육관')) {
        scheduleBuilding = '바롬인성교육관';
      } else {
        scheduleBuilding = null;
      }

      final requestsSnap = await _firestore
          .collection('cleaning_requests')
          .where('scheduleId', isEqualTo: scheduleId)
          .get();
      if (requestsSnap.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in requestsSnap.docs) {
          final data = doc.data();
          final update = <String, dynamic>{};
          if (data['inspectionType'] == null) update['inspectionType'] = scheduleInspType;
          if ((data['dormBuilding'] == null || (data['dormBuilding'] as String? ?? '').isEmpty) && scheduleBuilding != null) {
            update['dormBuilding'] = scheduleBuilding;
          }
          if (update.isNotEmpty) batch.update(doc.reference, update);
        }
        await batch.commit();
      }
      await _firestore.collection('cleaning_schedules').doc(scheduleId).delete();

      setState(() {
        if (_selectedScheduleId == scheduleId) _selectedScheduleId = null;
      });
      await Future.wait([_loadSchedules(), _loadRequests()]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('일정이 삭제되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── 평가 다이얼로그 ──
  void _showEvaluateDialog(
      String requestId, Map<String, dynamic> data, {Map<String, dynamic>? prefillData}) async {
    final userName = (data['userName'] ?? '') as String;
    final roomNumber = (data['roomNumber'] ?? '') as String;

    // 스케줄에서 inspectionType + floor 조회
    String scheduleFloor = '';
    String inspectionType = 'monthly';
    final scheduleId = (data['scheduleId'] ?? '') as String;
    if (scheduleId.isNotEmpty) {
      try {
        final scheduleSnap = await _firestore
            .collection('cleaning_schedules')
            .doc(scheduleId)
            .get();
        final sd = scheduleSnap.data();
        scheduleFloor = (sd?['floor'] ?? '') as String;
        inspectionType = (sd?['inspectionType'] ?? 'monthly') as String;
      } catch (_) {}
    }

    // 건물+검사유형에 맞는 체크리스트 구조 선택
    final structures = getCheckStructures(scheduleFloor, inspectionType, roomNumber: roomNumber);
    final isMoveOut = inspectionType == 'move_out';

    // 퇴사검사: 학생이 신청 시 선택한 공동구역만 평가
    Map<String, List<String>> filteredCommunal = structures.communal;
    if (isMoveOut) {
      final rawCommonAreas = data['commonAreas'];
      debugPrint('[공동구역] rawCommonAreas runtimeType: ${rawCommonAreas.runtimeType}');
      debugPrint('[공동구역] rawCommonAreas value: $rawCommonAreas');
      List<String> parsedCommonAreas = [];
      if (rawCommonAreas is List) {
        // List 내부 원소가 쉼표 구분 문자열인 경우도 분리
        for (final e in rawCommonAreas) {
          final s = e.toString().trim();
          if (s.contains(',')) {
            parsedCommonAreas.addAll(s.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty));
          } else if (s.isNotEmpty) {
            parsedCommonAreas.add(s);
          }
        }
      } else if (rawCommonAreas is String && rawCommonAreas.isNotEmpty) {
        parsedCommonAreas = rawCommonAreas
            .split(',')
            .map((x) => x.trim())
            .where((x) => x.isNotEmpty)
            .toList();
      }
      debugPrint('[공동구역] parsedCommonAreas: $parsedCommonAreas');
      if (parsedCommonAreas.isNotEmpty) {
        final selected = parsedCommonAreas.toSet();
        // 학생 앱 키 → 점검 구조 키 매핑
        const areaKeyMap = {'바닥': '공동 바닥'};
        final mappedSelected = selected.map((a) => areaKeyMap[a] ?? a).toSet();
        debugPrint('[공동구역] mappedSelected: $mappedSelected');
        debugPrint('[공동구역] structures.communal keys: ${structures.communal.keys.toList()}');
        filteredCommunal = Map.fromEntries(
          structures.communal.entries.where((e) => mappedSelected.contains(e.key)),
        );
        debugPrint('[공동구역] filteredCommunal keys: ${filteredCommunal.keys.toList()}');
      }
    }

    // 퇴사검사: 신청한 학생 1명만 평가
    final List<String> roomStudents = isMoveOut
        ? (userName.isNotEmpty ? [userName] : [])
        : [];

    if (!mounted) return;

    // 기존 저장된 점수 우선, 없으면 prefillData 값 사용 (이전 검사값 복사)
    final savedPersonal = data['scoresPersonal'] as Map<String, dynamic>?;
    final savedCommunal = data['scoresCommunal'] as Map<String, dynamic>?;
    final prefillPersonal = prefillData?['scoresPersonal'] as Map<String, dynamic>?;
    final prefillCommunal = prefillData?['scoresCommunal'] as Map<String, dynamic>?;

    Map<String, int> loadOrMake(Map<String, List<String>> structure, Map<String, dynamic>? saved, {Map<String, dynamic>? prefill}) {
      final defaults = _makeScores(structure, isMoveOut: isMoveOut);
      final source = saved ?? prefill;
      if (source == null) return defaults;
      return {
        for (final key in defaults.keys)
          key: (source[key] as num?)?.toInt() ?? defaults[key]!,
      };
    }

    final Map<String, Map<String, int>> studentScores = {
      for (final name in roomStudents)
        name: loadOrMake(
          structures.personal,
          savedPersonal != null ? (savedPersonal[name] as Map<String, dynamic>?) : null,
          prefill: prefillPersonal != null ? (prefillPersonal[name] as Map<String, dynamic>?) : null,
        ),
    };
    final Map<String, int> communalScores = loadOrMake(filteredCommunal, savedCommunal, prefill: prefillCommunal);
    int selectedTabIndex = 0;
    final existingComment = (data['inspectionComment'] as String?) ?? '';
    final inspectionCommentCtrl = TextEditingController(text: existingComment);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final avg = _calcAvg(studentScores, communalScores);
          final failCount = isMoveOut ? _countFail(studentScores, communalScores) : 0;
          final avgColor = isMoveOut
              ? (failCount == 0 ? Colors.green : Colors.red)
              : (avg >= 3.5 ? Colors.green : avg >= 2.5 ? Colors.blue : Colors.red);

          // 월검사: 탭 없이 단일 체크리스트 / 퇴사검사: 학생탭 + 공동구역
          final tabs = isMoveOut ? [...roomStudents, '공동 구역'] : ['점검'];
          final isStudentTab = isMoveOut && selectedTabIndex < roomStudents.length;

          int tabLowCount(int idx) {
            if (isMoveOut && idx < roomStudents.length) {
              return studentScores[roomStudents[idx]]!.values.where((v) => v == 0).length;
            }
            return isMoveOut
                ? communalScores.values.where((v) => v == 0).length
                : communalScores.values.where((v) => v <= 2).length;
          }

          return Dialog(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 550,
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 타이틀
                    Row(
                      children: [
                        const Icon(Icons.checklist,
                            color: Colors.teal, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isMoveOut
                                ? '청소 점검 — $roomNumber호${scheduleFloor.startsWith('샬롬하우스') ? ' (${shalomRoomCapacity(roomNumber)}인실)' : ''} (${roomStudents.length}명)'
                                : '월검사 — $roomNumber호${scheduleFloor.startsWith('샬롬하우스') ? ' (${shalomRoomCapacity(roomNumber)}인실)' : ''}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 탭 바 (월검사는 탭 1개라 숨김)
                    if (tabs.length > 1)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: tabs.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final tabLabel = entry.value;
                          final isSelected = selectedTabIndex == idx;
                          final lowCount = tabLowCount(idx);
                          return GestureDetector(
                            onTap: () => setDialogState(
                                () => selectedTabIndex = idx),
                            child: Container(
                              margin: const EdgeInsets.only(right: 6, bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.teal.withValues(alpha: 0.1)
                                    : Colors.grey.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.teal
                                      : Colors.grey.withValues(alpha: 0.3),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    tabLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? Colors.teal
                                          : null,
                                    ),
                                  ),
                                  if (lowCount > 0) ...[
                                    const SizedBox(width: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$lowCount',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 점수 입력
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 340),
                      child: SingleChildScrollView(
                        child: isStudentTab
                            ? _buildScoreSection(
                                '개인 구역 — ${roomStudents[selectedTabIndex]}',
                                structures.personal,
                                studentScores[roomStudents[selectedTabIndex]]!,
                                setDialogState,
                                Colors.blue,
                                isMoveOut: isMoveOut,
                              )
                            : _buildScoreSection(
                                isMoveOut ? '공동 구역' : '점검 항목',
                                filteredCommunal,
                                communalScores,
                                setDialogState,
                                isMoveOut ? Colors.purple : Colors.teal,
                                isMoveOut: isMoveOut,
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 요약
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: avgColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: avgColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            isMoveOut ? 'O/X 결과' : '평균 점수',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                          const Spacer(),
                          Text(
                            isMoveOut
                                ? (failCount == 0 ? 'O (통과)' : 'X ($failCount항목 불합격)')
                                : '${avg.toStringAsFixed(1)}점 / 4점',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: avgColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('점검의견',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: inspectionCommentCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: '점검 결과에 대한 의견을 입력하세요',
                        contentPadding: EdgeInsets.all(12),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 버튼
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text('취소'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            Navigator.pop(dialogCtx);
                            _submitEvaluation(
                                requestId, avg, communalScores,
                                studentScores,
                                inspectionCommentCtrl.text.trim(),
                                isMoveOut: isMoveOut,
                                floor: scheduleFloor);
                          },
                          child: const Text('평가 완료'),
                        ),
                      ],
                    ),
                  ],
                ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScoreSection(
    String title,
    Map<String, List<String>> structure,
    Map<String, int> scores,
    StateSetter setDialogState,
    Color color, {
    bool isMoveOut = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            title,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: color),
          ),
        ),
        const SizedBox(height: 10),
        ...structure.entries.map((category) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.key,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                ...category.value.map((item) {
                  final key = '${category.key}_$item';
                  final score = scores[key] ?? (isMoveOut ? 1 : 4);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            item,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: isMoveOut
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setDialogState(() => scores[key] = 1),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 6),
                                          decoration: BoxDecoration(
                                            color: score == 1
                                                ? Colors.green.withValues(alpha: 0.15)
                                                : Colors.grey.withValues(alpha: 0.04),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: score == 1 ? Colors.green : Colors.grey.withValues(alpha: 0.3),
                                              width: score == 1 ? 2 : 1,
                                            ),
                                          ),
                                          child: Text(
                                            'O',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: score == 1 ? FontWeight.bold : FontWeight.normal,
                                              color: score == 1 ? Colors.green : Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setDialogState(() => scores[key] = 0),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 6),
                                          decoration: BoxDecoration(
                                            color: score == 0
                                                ? Colors.red.withValues(alpha: 0.15)
                                                : Colors.grey.withValues(alpha: 0.04),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: score == 0 ? Colors.red : Colors.grey.withValues(alpha: 0.3),
                                              width: score == 0 ? 2 : 1,
                                            ),
                                          ),
                                          child: Text(
                                            'X',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: score == 0 ? FontWeight.bold : FontWeight.normal,
                                              color: score == 0 ? Colors.red : Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  children: List.generate(4, (i) {
                                    final val = i + 1;
                                    final isSelected = score == val;
                                    final Color btnColor = val == 4
                                        ? Colors.green
                                        : val == 3
                                            ? Colors.blue
                                            : val == 2
                                                ? Colors.orange
                                                : Colors.red;
                                    return Expanded(
                                      child: GestureDetector(
                                        onTap: () =>
                                            setDialogState(() => scores[key] = val),
                                        child: Container(
                                          margin: EdgeInsets.only(left: i == 0 ? 0 : 4),
                                          padding: const EdgeInsets.symmetric(vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? btnColor.withValues(alpha: 0.15)
                                                : Colors.grey.withValues(alpha: 0.04),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isSelected
                                                  ? btnColor
                                                  : Colors.grey.withValues(alpha: 0.3),
                                              width: isSelected ? 2 : 1,
                                            ),
                                          ),
                                          child: Text(
                                            '$val점',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: isSelected
                                                  ? btnColor
                                                  : Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }

  Future<void> _submitEvaluation(
    String requestId,
    double scoreAvg,
    Map<String, int> communalScores,
    Map<String, Map<String, int>> studentScores,
    String inspectionComment, {
    bool isMoveOut = false,
    String? floor,
  }) async {
    try {
      final needsRecheck = isMoveOut
          ? (studentScores.values.expand((m) => m.values).any((v) => v == 0) ||
              communalScores.values.any((v) => v == 0))
          : (studentScores.values.expand((m) => m.values).any((v) => v <= 2) ||
              communalScores.values.any((v) => v <= 2));
      final currentUser = FirebaseAuth.instance.currentUser;
      String? evaluatedByName;
      if (currentUser != null) {
        try {
          final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
          evaluatedByName = doc.data()?['name'] as String?;
        } catch (_) {}
      }
      final Map<String, dynamic> updateData = {
        'status': 'completed',
        if (!isMoveOut) 'scoreAvg': scoreAvg,
        'needsRecheck': needsRecheck,
        'inspectionType': isMoveOut ? 'move_out' : 'monthly',
        // 스케줄이 삭제되어도 점검 항목 구조를 복원할 수 있도록 평가 시점의 구역 정보를 함께 저장
        if (floor != null && floor.isNotEmpty) 'floor': floor,
        'evaluatedAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'scoresCommunal': communalScores,
        'scoresPersonal': {
          for (final e in studentScores.entries) e.key: e.value,
        },
        'inspectionComment': inspectionComment,
        'evaluatedById': currentUser?.uid,
        'evaluatedByEmail': currentUser?.email,
        'evaluatedByName': evaluatedByName ?? currentUser?.email,
      };
      await _firestore.collection('cleaning_requests').doc(requestId).update(updateData);
      await _loadRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('평가가 완료되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('신청 반려'),
        content: const Text('이 신청을 반려하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('반려'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final requestDoc = await _firestore.collection('cleaning_requests').doc(requestId).get();
      final scheduleId = requestDoc.data()?['scheduleId'] as String?;

      final batch = _firestore.batch();
      batch.update(_firestore.collection('cleaning_requests').doc(requestId), {
        'status': 'rejected',
        'updatedAt': Timestamp.now(),
      });
      if (scheduleId != null && scheduleId.isNotEmpty) {
        batch.update(
          _firestore.collection('cleaning_schedules').doc(scheduleId),
          {'currentCount': FieldValue.increment(-1), 'status': 'open'},
        );
      }
      await batch.commit();

      await Future.wait([_loadRequests(), _loadSchedules()]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('신청이 반려되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteRequest(String requestId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('신청 삭제'),
        content: const Text('이 신청을 삭제하시겠습니까?\n삭제한 신청은 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
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
      // 신청 문서에서 scheduleId 읽어서 currentCount도 감소
      final requestDoc = await _firestore.collection('cleaning_requests').doc(requestId).get();
      final scheduleId = requestDoc.data()?['scheduleId'] as String?;

      final batch = _firestore.batch();
      batch.delete(_firestore.collection('cleaning_requests').doc(requestId));
      if (scheduleId != null && scheduleId.isNotEmpty) {
        batch.update(
          _firestore.collection('cleaning_schedules').doc(scheduleId),
          {'currentCount': FieldValue.increment(-1), 'status': 'open'},
        );
      }
      await batch.commit();

      await Future.wait([_loadRequests(), _loadSchedules()]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('신청이 삭제되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ══════════════════════════════════════════════════════════════
// 호실별 청소점검 이력 탭
// ══════════════════════════════════════════════════════════════
class RoomInspectionHistoryContent extends StatefulWidget {
  final String? fixedType;
  const RoomInspectionHistoryContent({super.key, this.fixedType});

  @override
  State<RoomInspectionHistoryContent> createState() =>
      _RoomInspectionHistoryContentState();
}

class _RoomInspectionHistoryContentState
    extends State<RoomInspectionHistoryContent> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, Map<String, dynamic>> _scheduleMap = {};
  Map<String, List<QueryDocumentSnapshot>> _grouped = {};
  List<String> _sortedRooms = [];
  Map<String, String> _userFloorLabels = {};
  Set<String> _occupiedRoomKeys = {}; // 거주 학생이 있는 호실 키('건물|호실')
  Map<String, int> _residentCountByRoom = {}; // 호실 키('건물|호실') → 현재 거주 인원 수
  // 퇴사검사 그룹 키('건물|호실|uid') → {name} : 학생 정보
  Map<String, Map<String, String>> _personInfoByKey = {};

  bool _isLoading = true;
  String _errorMessage = '';
  String? _floorFilter;
  // 스케줄 필터 값: 'sid:신청' 또는 'sid:미신청'
  String? _scheduleFilter;

  @override
  void initState() {
    super.initState();
    _loadFloorThenData();
  }

  Future<void> _loadFloorThenData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (mounted) _floorFilter = doc.data()?['assignedFloor'] as String?;
      } catch (_) {}
    }
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ── 헬퍼 ──
  static String _roomBuilding(String room) {
    final n = int.tryParse(room);
    if (n == null) return '바롬인성교육관';
    if ((n >= 101 && n <= 132) || (n >= 201 && n <= 260) || (n >= 301 && n <= 329)) {
      return '국제생활관';
    }
    return '샬롬하우스';
  }

  static String? _buildingFromFloor(String? floor) {
    if (floor == null || floor.isEmpty) return null;
    if (floor.startsWith('샬롬하우스(겨울방학)')) return '샬롬하우스(겨울방학)';
    if (floor.startsWith('샬롬하우스')) return '샬롬하우스';
    if (floor.startsWith('국제생활관')) return '국제생활관';
    if (floor.startsWith('바롬인성교육관')) return '바롬인성교육관';
    return null;
  }

  static String? _computeWing(String dormBuilding, int roomNum) {
    if (dormBuilding == '국제생활관') {
      if ((roomNum >= 101 && roomNum <= 132) || (roomNum >= 201 && roomNum <= 229)) return 'A동';
      if ((roomNum >= 233 && roomNum <= 260) || (roomNum >= 301 && roomNum <= 329)) return 'B동';
      return null;
    }
    if (dormBuilding == '샬롬하우스(겨울방학)') return 'A동'; // 201~220, 301~320, 401~420 모두 A동
    final last = roomNum % 100;
    if (last >= 1 && last <= 20) return 'A동';
    if (last >= 21 && last <= 35) return 'B동';
    return null;
  }

  static int _buildingOrder(String key) {
    if (key.startsWith('샬롬하우스(겨울방학)')) return 3;
    if (key.startsWith('샬롬하우스')) return 0;
    if (key.startsWith('국제생활관')) return 1;
    if (key.startsWith('바롬인성교육관')) return 2;
    return 4;
  }

  // 그룹 키 → 호실번호: '샬롬하우스|302|uid' → '302', '샬롬하우스|302' → '302', '302' → '302'
  static String _keyRoom(String key) {
    final parts = key.split('|');
    if (parts.length >= 3) return parts[1];
    return parts.length == 2 ? parts[1] : key;
  }

  // 그룹 키 → 건물명: '샬롬하우스|302' → '샬롬하우스', '샬롬하우스|302|uid' → '샬롬하우스', '302' → null
  static String? _keyBuilding(String key) {
    final parts = key.split('|');
    if (parts.length < 2) return null;
    return parts.first.isEmpty ? null : parts.first;
  }

  // 그룹 키 → userId: '샬롬하우스|302|uid' → 'uid', 그 외 → null
  static String? _keyUserId(String key) {
    final parts = key.split('|');
    return parts.length >= 3 ? parts[2] : null;
  }

  static String _getHistoryGradeLabel(Map<String, dynamic> data) {
    final isMoveOut = (data['inspectionType'] as String?) == 'move_out';
    if (isMoveOut) {
      final status = data['status'] as String?;
      if (status != 'completed') return '대기중';
      return data['needsRecheck'] == true ? 'Fail' : 'Pass';
    }
    final status = data['status'] as String?;
    final scoreAvg = (data['scoreAvg'] as num?)?.toDouble();
    if (scoreAvg == null && status != null && status != 'completed') {
      return '대기중';
    }
    if (scoreAvg != null) return '${scoreAvg.toStringAsFixed(1)}점';
    switch (data['grade'] as String?) {
      case 'excellent': return '매우양호';
      case 'good': return '양호';
      case 'poor': return '미흡';
      default: return '미평가';
    }
  }

  static Color _getHistoryGradeColor(Map<String, dynamic> data) {
    final isMoveOut = (data['inspectionType'] as String?) == 'move_out';
    if (isMoveOut) {
      final status = data['status'] as String?;
      if (status != 'completed') return Colors.lightBlueAccent;
      return data['needsRecheck'] == true ? Colors.red : Colors.green;
    }
    final status = data['status'] as String?;
    final scoreAvg = (data['scoreAvg'] as num?)?.toDouble();
    if (scoreAvg == null && status != null && status != 'completed') {
      return const Color(0xFF87CEEB);
    }
    if (scoreAvg != null) {
      if (scoreAvg >= 3.5) return Colors.green;
      if (scoreAvg >= 2.5) return Colors.blue;
      return Colors.red;
    }
    switch (data['grade'] as String?) {
      case 'excellent': return Colors.green;
      case 'good': return Colors.blue;
      case 'poor': return Colors.red;
      default: return Colors.grey;
    }
  }

  static String _categorizeHistoryGrade(Map<String, dynamic> data) {
    final isMoveOut = (data['inspectionType'] as String?) == 'move_out';
    if (isMoveOut) return data['needsRecheck'] == true ? 'poor' : 'excellent';
    final scoreAvg = (data['scoreAvg'] as num?)?.toDouble();
    if (scoreAvg != null) {
      if (scoreAvg >= 3.5) return 'excellent';
      if (scoreAvg >= 2.5) return 'good';
      return 'poor';
    }
    return data['grade'] as String? ?? 'none';
  }

  // 사생 기본 정보 엑셀에서 전체 명단을 로드한다.
  // 부가 기능이므로 실패해도 조용히 빈 리스트를 반환한다.
  Future<List<ExcelStudentRow>> _loadExcelStudentRows() async {
    try {
      final settingsDoc =
          await FirebaseFirestore.instance.collection('settings').doc('home').get();
      final excelUrl = settingsDoc.data()?['studentInfoExcelUrl'] as String?;
      if (excelUrl == null || excelUrl.trim().isEmpty) return [];

      final response = await http.get(Uri.parse(excelUrl));
      if (response.statusCode != 200) return [];

      final excel = Excel.decodeBytes(response.bodyBytes);
      final sheet = excel.sheets.values.first;
      final rows = sheet.rows
          .map((row) => row.map((cell) => cell?.value?.toString() ?? '').toList())
          .toList();
      if (rows.isEmpty) return [];

      final header = rows.first;
      return rows.skip(1).map((row) => ExcelStudentRow.fromRow(header, row)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── 데이터 로드 ──
  Future<void> _loadData() async {
    setState(() { _isLoading = true; _errorMessage = ''; });
    try {
      final requestsSnap = await _firestore.collection('cleaning_requests').get();
      final schedulesSnap = await _firestore.collection('cleaning_schedules').get();
      final usersSnap = await _firestore.collection('users').get();
      final excelRows = widget.fixedType == 'move_out'
          ? await _loadExcelStudentRows()
          : <ExcelStudentRow>[];

      final scheduleMap = <String, Map<String, dynamic>>{};
      for (final doc in schedulesSnap.docs) {
        scheduleMap[doc.id] = doc.data();
      }

      // users에서 uid→자리번호 맵 + 호실별 층 정보 + 거주 학생 키 구성
      final userSeatNumbers = <String, String>{};
      final userFloorLabels = <String, String>{};
      final userResidentStatuses = <String, String>{};
      final occupiedRoomKeys = <String>{};
      final residentCountByRoom = <String, int>{};
      for (final doc in usersSnap.docs) {
        final data = doc.data();
        final seat = data['seatNumber']?.toString();
        if (seat != null && seat.isNotEmpty) userSeatNumbers[doc.id] = seat;
        if (data['role']?.toString() != 'student') continue;
        final residentStatus = data['residentStatus']?.toString() ?? '재실중';
        userResidentStatuses[doc.id] = residentStatus;
        final dorm = data['dormBuilding']?.toString();
        final room = data['roomNumber']?.toString();
        if (dorm == null || room == null || room.isEmpty) continue;
        final roomKey = '$dorm|$room';
        if (residentStatus == '재실중') {
          occupiedRoomKeys.add(roomKey);
          residentCountByRoom[roomKey] = (residentCountByRoom[roomKey] ?? 0) + 1;
        }
        final String floorNum;
        if (room.length == 3) {
          floorNum = room[0];
        } else if (room.length >= 4) {
          floorNum = room.substring(0, 2);
        } else {
          continue;
        }
        if (dorm == '바롬인성교육관') {
          userFloorLabels[roomKey] = '$dorm $floorNum층';
        } else {
          final n = int.tryParse(room) ?? 0;
          final wing = _computeWing(dorm, n);
          if (wing != null) {
            userFloorLabels[roomKey] = '$dorm $wing $floorNum층';
          } else if (dorm == '샬롬하우스(겨울방학)') {
            userFloorLabels[roomKey] = '$dorm A동 $floorNum층';
          }
        }
      }

      final grouped = <String, List<QueryDocumentSnapshot>>{};
      final personInfoByKey = <String, Map<String, String>>{};
      final moveOutKeysByUid = <String, String>{};

      for (final req in requestsSnap.docs) {
        final data = req.data();
        final room = data['roomNumber']?.toString() ?? '';
        if (room.isEmpty) continue;

        final sid = data['scheduleId']?.toString();
        String? dorm = data['dormBuilding']?.toString();
        if ((dorm == null || dorm.isEmpty) && sid != null) {
          dorm = _buildingFromFloor(scheduleMap[sid]?['floor']?.toString());
        }

        String? reqType;
        if (sid != null) reqType = scheduleMap[sid]?['inspectionType'] as String?;
        reqType ??= data['inspectionType'] as String?;
        // 현재 탭 타입 필터
        if (widget.fixedType != null && reqType != widget.fixedType) continue;

        final String groupKey;
        if (reqType == 'move_out') {
          // 퇴사검사: 학생(uid) 기준 그룹핑
          final uid = data['userId']?.toString() ?? '';
          groupKey = dorm != null && dorm.isNotEmpty ? '$dorm|$room|$uid' : '|$room|$uid';
          if (uid.isNotEmpty) moveOutKeysByUid[uid] = groupKey;
          personInfoByKey[groupKey] = {
            'name': data['userName']?.toString() ?? '',
            'seatNumber': userSeatNumbers[uid] ?? data['seatNumber']?.toString() ?? '',
            'residentStatus': userResidentStatuses[uid] ?? '재실중',
          };
        } else {
          // 월검사: 호실 기준 그룹핑
          groupKey = dorm != null && dorm.isNotEmpty ? '$dorm|$room' : room;
        }
        grouped.putIfAbsent(groupKey, () => []).add(req);
      }

      // 퇴사검사: 이력이 없는 학생도 빈 카드 추가
      if (widget.fixedType == 'move_out') {
        for (final doc in usersSnap.docs) {
          final data = doc.data();
          if (data['role']?.toString() != 'student') continue;
          final uid = doc.id;
          if (moveOutKeysByUid.containsKey(uid)) continue;
          final room = data['roomNumber']?.toString() ?? '';
          if (room.isEmpty) continue;
          final dorm = data['dormBuilding']?.toString();
          final groupKey = dorm != null && dorm.isNotEmpty ? '$dorm|$room|$uid' : '|$room|$uid';
          grouped.putIfAbsent(groupKey, () => []);
          personInfoByKey[groupKey] = {
            'name': data['name']?.toString() ?? '',
            'seatNumber': userSeatNumbers[uid] ?? '',
            'residentStatus': userResidentStatuses[uid] ?? '재실중',
          };
        }

        // 퇴사검사: 엑셀 명단에만 있고 아직 회원가입하지 않은 학생도 빈 카드 추가.
        // 가입 여부 판단은 이메일만 기준으로 한다(학번 사용 금지).
        if (excelRows.isNotEmpty) {
          final registeredEmails = usersSnap.docs
              .map((d) => (d.data()['email']?.toString() ?? '').trim().toLowerCase())
              .where((v) => v.isNotEmpty)
              .toSet();

          for (final row in excelRows) {
            if (!row.hasMatchKey) continue;
            final rowEmail = row.normalizedEmail;
            if (rowEmail != null && registeredEmails.contains(rowEmail)) continue;
            final room = (row.roomNumber ?? '').trim();
            if (room.isEmpty) continue;
            final dorm = (row.dormBuilding ?? '').trim();
            final excelId = rowEmail ?? (row.studentId ?? '').trim();
            if (excelId.isEmpty) continue;
            final groupKey = dorm.isNotEmpty
                ? '$dorm|$room|excel:$excelId'
                : '|$room|excel:$excelId';
            grouped.putIfAbsent(groupKey, () => []);
            personInfoByKey[groupKey] = {
              'name': row.name ?? '',
              'seatNumber': (row.seatNumber ?? '').trim(),
              'residentStatus': '재실중',
              'isUnregistered': 'true',
            };
          }
        }
      }

      // 월검사: 거주 학생 호실 + 고정 호실 목록 추가 (이력 없어도 표시)
      if (widget.fixedType != 'move_out') {
        for (final roomKey in userFloorLabels.keys) {
          grouped.putIfAbsent(roomKey, () => []);
        }
        // 샬롬하우스 2~7층 (A동 1~20, B동 21~40)
        for (final floor in kFloorOptions) {
          final dorm = floor.startsWith('샬롬하우스(겨울방학)') ? '샬롬하우스(겨울방학)'
              : floor.startsWith('샬롬하우스') ? '샬롬하우스'
              : floor.startsWith('국제생활관') ? '국제생활관'
              : floor.startsWith('바롬인성교육관') ? '바롬인성교육관'
              : null;
          if (dorm == null) continue;
          final floorNumMatch = RegExp(r'(\d+)층').firstMatch(floor);
          if (floorNumMatch == null) continue;
          final floorNum = int.parse(floorNumMatch.group(1)!);

          final List<int> roomNums;
          if (dorm == '국제생활관') {
            final wing = floor.contains('A동') ? 'A동' : floor.contains('B동') ? 'B동' : null;
            if (wing == null) continue;
            if (wing == 'A동' && floorNum == 1) { roomNums = [for (var i = 101; i <= 132; i++) i]; }
            else if (wing == 'A동' && floorNum == 2) { roomNums = [for (var i = 201; i <= 229; i++) i]; }
            else if (wing == 'B동' && floorNum == 2) { roomNums = [for (var i = 233; i <= 260; i++) i]; }
            else if (wing == 'B동' && floorNum == 3) { roomNums = [for (var i = 301; i <= 329; i++) i]; }
            else { roomNums = []; }
          } else if (dorm == '바롬인성교육관') {
            for (final r in ['1001-A','1001-B','1001-C','1002-A','1002-B','1002-C','1003-A','1003-B','1003-C']) {
              final roomKey = '$dorm|$r';
              grouped.putIfAbsent(roomKey, () => []);
              userFloorLabels.putIfAbsent(roomKey, () => floor);
            }
            continue;
          } else if (dorm == '샬롬하우스(겨울방학)') {
            final base = floorNum * 100;
            roomNums = [for (var i = base + 1; i <= base + 20; i++) i];
          } else {
            // 샬롬하우스: A동 1~20, B동 21~35
            final wing = floor.contains('A동') ? 'A동' : floor.contains('B동') ? 'B동' : null;
            if (wing == null) continue;
            final base = floorNum * 100;
            roomNums = wing == 'A동'
                ? [for (var i = base + 1; i <= base + 20; i++) i]
                : [for (var i = base + 21; i <= base + 35; i++) i];
          }

          for (final roomNum in roomNums) {
            final roomKey = '$dorm|$roomNum';
            grouped.putIfAbsent(roomKey, () => []);
            userFloorLabels.putIfAbsent(roomKey, () => floor);
          }
        }
      }

      // 각 호실 이력 createdAt 역순 정렬
      for (final list in grouped.values) {
        list.sort((a, b) {
          final aTs = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          final bTs = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return bTs.compareTo(aTs);
        });
      }

      // 건물(샬롬→국제→바롬) → 호실번호 오름차순 정렬
      final sortedRooms = grouped.keys.toList()
        ..sort((a, b) {
          final bo = _buildingOrder(a).compareTo(_buildingOrder(b));
          if (bo != 0) return bo;
          final numA = int.tryParse(_keyRoom(a)) ?? 0;
          final numB = int.tryParse(_keyRoom(b)) ?? 0;
          if (numA != 0 && numB != 0) return numA.compareTo(numB);
          return _keyRoom(a).compareTo(_keyRoom(b));
        });

      if (mounted) {
        setState(() {
          _scheduleMap = scheduleMap;
          _grouped = grouped;
          _sortedRooms = sortedRooms;
          _userFloorLabels = userFloorLabels;
          _occupiedRoomKeys = occupiedRoomKeys;
          _residentCountByRoom = residentCountByRoom;
          _personInfoByKey = personInfoByKey;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = e.toString(); });
    }
  }

  // ── 필터된 호실 목록 ──
  List<String> get _filteredRooms {
    return _sortedRooms.where((r) {
      // 구역 필터
      if (_floorFilter != null) {
        final roomFloor = _getRoomFloorOption(r);
        if (roomFloor == null || roomFloor != _floorFilter) return false;
      }
      // 퇴사검사 탭: 사람 기준 키만 표시
      if (widget.fixedType == 'move_out' && _keyUserId(r) == null) return false;
      // 신청 스케줄 필터
      if (_scheduleFilter != null) {
        final filter = _scheduleFilter!;
        final requests = _grouped[r] ?? [];
        if (widget.fixedType == 'monthly') {
          // monthly: 필터 값이 scheduleId — 해당 스케줄에 이력이 있는 호실만 표시
          final hasSchedule = requests.any((req) {
            return (req.data() as Map<String, dynamic>)['scheduleId'] == filter;
          });
          if (!hasSchedule) return false;
        } else if (filter == '미신청') {
          // 어떤 활성 스케줄에도 신청하지 않은 학생
          final hasAnyActive = requests.any((req) {
            final sid = (req.data() as Map<String, dynamic>)['scheduleId']?.toString();
            return sid != null && _scheduleMap.containsKey(sid);
          });
          if (hasAnyActive) return false;
        } else {
          // 'sid:신청' 형식 — 해당 스케줄에 신청한 학생
          final parts = filter.split(':');
          if (parts.length == 2) {
            final sid = parts[0];
            final hasSchedule = requests.any((req) {
              return (req.data() as Map<String, dynamic>)['scheduleId'] == sid;
            });
            if (!hasSchedule) return false;
          }
        }
      }
      return true;
    }).toList();
  }

  // 월청소 스케줄 목록: 스케줄별 항목, 날짜 내림차순
  List<MapEntry<String, String>> get _monthlyScheduleOptions {
    final entries = <({String id, String label, DateTime? date})>[];
    _scheduleMap.forEach((id, data) {
      if (data['inspectionType'] != 'monthly') return;
      final floor = data['floor']?.toString() ?? '';
      if (_floorFilter != null && floor != _floorFilter) return;
      final ts = data['date'] as Timestamp?;
      final dateLabel = ts != null
          ? DateFormat('yyyy.MM.dd').format(ts.toDate())
          : '날짜 미상';
      entries.add((id: id, label: '$dateLabel $floor', date: ts?.toDate()));
    });
    entries.sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return b.date!.compareTo(a.date!);
    });
    return entries.map((e) => MapEntry(e.id, e.label)).toList();
  }

  // 퇴사검사 스케줄 목록: 미신청 1개 + 스케줄별 신청 항목, 날짜 내림차순
  List<MapEntry<String, String>> get _moveOutScheduleOptions {
    final entries = <({String id, String label, DateTime? date})>[];
    _scheduleMap.forEach((id, data) {
      if (data['inspectionType'] != 'move_out') return;
      final floor = data['floor']?.toString() ?? '';
      if (_floorFilter != null && floor != _floorFilter) return;
      final ts = data['date'] as Timestamp?;
      final dateLabel = ts != null
          ? DateFormat('yyyy.MM.dd').format(ts.toDate())
          : '날짜 미상';
      entries.add((id: id, label: '$dateLabel $floor', date: ts?.toDate()));
    });
    entries.sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return b.date!.compareTo(a.date!);
    });
    final result = <MapEntry<String, String>>[];
    // 스케줄별 신청 항목
    for (final e in entries) {
      result.add(MapEntry('${e.id}:신청', '${e.label} 신청'));
    }
    // 미신청은 마지막 하나
    result.add(const MapEntry('미신청', '미신청'));
    return result;
  }

  String? _getRoomFloorOption(String key) {
    final requests = _grouped[key] ?? [];
    for (final req in requests) {
      final data = req.data() as Map<String, dynamic>;
      final sid = data['scheduleId'] as String?;
      if (sid != null) {
        final floor = _scheduleMap[sid]?['floor'] as String?;
        if (floor != null && floor.isNotEmpty) return floor;
      }
    }
    if (_userFloorLabels.containsKey(key)) return _userFloorLabels[key];
    // 건물|호실 키로 재조회
    final building = _keyBuilding(key);
    final room = _keyRoom(key);
    final roomKey2 = building != null ? '$building|$room' : room;
    return _userFloorLabels[roomKey2];
  }

  // ── UI ──
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            const Text('데이터를 불러오는 중 오류가 발생했습니다'),
            const SizedBox(height: 8),
            Text(_errorMessage, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadData, child: const Text('다시 시도')),
          ],
        ),
      );
    }

    final rooms = _filteredRooms;
    return Column(
      children: [
        if (widget.fixedType == 'monthly' && _monthlyScheduleOptions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: DropdownButtonFormField<String?>(
              initialValue: _scheduleFilter,
              decoration: const InputDecoration(
                labelText: '스케줄 필터',
                prefixIcon: Icon(Icons.event_note_outlined),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('전체', style: TextStyle(fontSize: 14)),
                ),
                ..._monthlyScheduleOptions.map((entry) => DropdownMenuItem<String?>(
                  value: entry.key,
                  child: Text(entry.value, style: const TextStyle(fontSize: 14)),
                )),
              ],
              onChanged: (v) => setState(() => _scheduleFilter = v),
            ),
          ),
        if (widget.fixedType == 'move_out')
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: DropdownButtonFormField<String?>(
              initialValue: _scheduleFilter,
              decoration: const InputDecoration(
                labelText: '신청 스케줄 필터',
                prefixIcon: Icon(Icons.event_note_outlined),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(_floorFilter ?? '전체', style: const TextStyle(fontSize: 14)),
                ),
                ..._moveOutScheduleOptions.map((entry) => DropdownMenuItem<String?>(
                  value: entry.key,
                  child: Text(entry.value, style: const TextStyle(fontSize: 14)),
                )),
              ],
              onChanged: (v) => setState(() => _scheduleFilter = v),
            ),
          ),
        // 호실 목록
        Expanded(
          child: rooms.isEmpty
              ? const Center(child: Text('이력이 없습니다', style: TextStyle(fontSize: 16, color: Colors.grey)))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: rooms.length,
                    itemBuilder: (context, index) => _buildRoomCard(rooms[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildRoomCard(String key) {
    final requests = _grouped[key] ?? [];
    final building = _keyBuilding(key) ?? _roomBuilding(_keyRoom(key));
    final roomNumber = _keyRoom(key);
    final personUid = _keyUserId(key);
    final personInfo = _personInfoByKey[key];
    final personName = personInfo?['name'] ?? '';
    final personSeat = personInfo?['seatNumber'] ?? '';
    final personResidentStatus = personInfo?['residentStatus'];
    final isUnregisteredStudent = personInfo?['isUnregistered'] == 'true';
    final isNotResident = personUid != null &&
        personResidentStatus != null &&
        personResidentStatus != '재실중';

    // 월청소 전용: 활성 스케줄에 연결된 request 여부 (뱃지/미신청 판단용)
    final isMonthly = widget.fixedType == 'monthly';
    final hasActiveScheduleRequest = isMonthly && requests.any((r) {
      final d = r.data() as Map<String, dynamic>;
      final sid = d['scheduleId']?.toString();
      return sid != null && _scheduleMap.containsKey(sid);
    });

    Map<String, dynamic>? latestData;
    if (requests.isNotEmpty) {
      final raw = requests.first.data() as Map<String, dynamic>;
      latestData = raw['inspectionType'] != null
          ? raw
          : {...raw, 'inspectionType': widget.fixedType ?? 'monthly'};
    }

    final isOccupied = personUid != null
        ? true
        : _occupiedRoomKeys.contains(key);

    // 퇴사검사: 스케줄 무관하게 request 이력 자체로 뱃지 결정
    // 월청소: 활성 스케줄 없으면 미신청
    final showAsMishinchung = isMonthly
        ? (!hasActiveScheduleRequest && isOccupied && !isNotResident)
        : (requests.isEmpty && isOccupied && !isNotResident);

    final gradeColor = isNotResident
        ? Colors.red.shade300
        : showAsMishinchung
            ? Colors.orange.shade300
            : (latestData != null
                ? _getHistoryGradeColor(latestData)
                : (isOccupied ? Colors.orange.shade300 : Colors.grey.shade300));
    final gradeLabel = isNotResident
        ? personResidentStatus
        : showAsMishinchung
            ? '미신청'
            : (latestData != null
                ? _getHistoryGradeLabel(latestData)
                : (isOccupied ? '미신청' : '거주학생 없음'));


    // monthly 카드용: 거주인원/인실수
    final roomKey = '$building|$roomNumber';
    final residentCount = _residentCountByRoom[roomKey] ?? 0;
    final roomCapacity = (building == '샬롬하우스' || building == '샬롬하우스(겨울방학)')
        ? shalomRoomCapacity(roomNumber)
        : null;

    final isMishinchung = showAsMishinchung && personUid != null && !isUnregisteredStudent;

    // 점검 대기중인 활성 스케줄의 날짜/시간 찾기
    String? scheduleDateTime;
    if (hasActiveScheduleRequest) {
      final gradeText = latestData != null ? _getHistoryGradeLabel(latestData) : '';
      if (gradeText == '대기중') {
        final activeRequest = requests.firstWhere((r) {
          final d = r.data() as Map<String, dynamic>;
          final sid = d['scheduleId']?.toString();
          return sid != null && _scheduleMap.containsKey(sid);
        }, orElse: () => requests.first);
        final sid = (activeRequest.data() as Map<String, dynamic>)['scheduleId']?.toString();
        if (sid != null && _scheduleMap.containsKey(sid)) {
          final sch = _scheduleMap[sid]!;
          final ts = (sch['date'] as Timestamp?)?.toDate();
          final startTime = (sch['startTime'] as String?) ?? '';
          if (ts != null) {
            scheduleDateTime = DateFormat('MM/dd').format(ts);
            if (startTime.isNotEmpty) scheduleDateTime = '$scheduleDateTime $startTime';
          }
        }
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetail(key),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: isMonthly
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1행: 호실 · 거주인원/인실수 [뱃지]
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            children: [
                              Text(
                                roomCapacity != null
                                    ? '$roomNumber호 · $residentCount/$roomCapacity인'
                                    : '$roomNumber호',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              if (scheduleDateTime != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    scheduleDateTime,
                                    style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.w600),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          // 2행: 건물이름  점검 N회
                          Text(
                            '$building  점검 ${requests.length}회',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1행: 이름 호수(자리번호) [미가입 배지]
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            children: [
                              Text(
                                personUid != null
                                    ? '${personName.isNotEmpty ? '$personName ' : ''}$roomNumber호${personSeat.isNotEmpty ? '($personSeat)' : ''}'
                                    : '$roomNumber호',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              if (isUnregisteredStudent)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.orange.withValues(alpha: 0.6)),
                                  ),
                                  child: const Text(
                                    '미가입',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.orange),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          // 2행: 건물이름 점검N회
                          Text(
                            '$building  점검 ${requests.length}회',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: gradeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: gradeColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          gradeLabel,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: gradeColor),
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (isMishinchung)
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _showApplyScheduleDialog(key, personUid),
                          child: const Text('층장신청', style: TextStyle(fontSize: 12)),
                        )
                      else
                        const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 층장 대리 신청 ──
  Future<void> _showApplyScheduleDialog(String key, String? uid) async {
    if (uid == null) return;
    // move_out 스케줄 목록 구성 (해당 학생 호실의 실제 구역으로 자동 필터)
    final roomFloor = _getRoomFloorOption(key);
    final schedules = _scheduleMap.entries
        .where((e) {
          if (e.value['inspectionType'] != 'move_out') return false;
          if (roomFloor != null && e.value['floor'] != roomFloor) return false;
          return true;
        })
        .toList()
      ..sort((a, b) {
        final ta = (a.value['date'] as Timestamp?)?.toDate();
        final tb = (b.value['date'] as Timestamp?)?.toDate();
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });

    if (!mounted) return;
    if (schedules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            roomFloor != null
                ? '$roomFloor 구역에 등록된 퇴사검사 스케줄이 없습니다'
                : '등록된 퇴사검사 스케줄이 없습니다',
          ),
        ),
      );
      return;
    }

    final selectedId = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('스케줄 선택'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: schedules.length,
            itemBuilder: (context, i) {
              final sid = schedules[i].key;
              final data = schedules[i].value;
              final floor = data['floor']?.toString() ?? '';
              final ts = data['date'] as Timestamp?;
              final dateLabel = ts != null
                  ? DateFormat('yyyy.MM.dd').format(ts.toDate())
                  : '날짜 미상';
              final start = data['startTime']?.toString() ?? '';
              final end = data['endTime']?.toString() ?? '';
              return ListTile(
                title: Text('$dateLabel $floor'),
                subtitle: start.isNotEmpty ? Text('$start ~ $end') : null,
                onTap: () => Navigator.pop(ctx, sid),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
        ],
      ),
    );

    if (selectedId == null || !mounted) return;
    await _submitApplyByFloorCaptain(key, uid, selectedId);
  }

  Future<void> _submitApplyByFloorCaptain(String key, String uid, String scheduleId) async {
    try {
      final scheduleData = _scheduleMap[scheduleId];
      if (scheduleData == null) throw Exception('스케줄 정보 없음');

      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userData = userDoc.data();
      if (userData == null) throw Exception('학생 정보 없음');

      final scheduleDate = (scheduleData['date'] as Timestamp).toDate();
      final startTime = (scheduleData['startTime'] ?? '') as String;
      final endTime = (scheduleData['endTime'] ?? '') as String;

      final rawDorm = userData['dormBuilding']?.toString() ?? '';
      final dormBuilding = rawDorm.isNotEmpty
          ? rawDorm
          : _buildingFromFloor(scheduleData['floor']?.toString()) ?? '';

      final batch = _firestore.batch();
      final requestRef = _firestore.collection('cleaning_requests').doc();
      final floorCaptain = FirebaseAuth.instance.currentUser;
      String? floorCaptainName;
      if (floorCaptain != null) {
        try {
          final fcDoc = await _firestore.collection('users').doc(floorCaptain.uid).get();
          floorCaptainName = fcDoc.data()?['name'] as String?;
        } catch (_) {}
      }
      batch.set(requestRef, {
        'userId': uid,
        'userName': userData['name'] ?? '',
        'roomNumber': userData['roomNumber'] ?? '',
        'dormBuilding': dormBuilding,
        'scheduleId': scheduleId,
        'inspectionType': 'move_out',
        'availableDates': [Timestamp.fromDate(scheduleDate)],
        'availableTimeSlot': '$startTime~$endTime',
        'availableTimeSlotLabel': '${DateFormat('MM/dd').format(scheduleDate)} $startTime~$endTime',
        'status': 'pending',
        'createdByFloorCaptain': true,
        'floorCaptainId': floorCaptain?.uid,
        'floorCaptainEmail': floorCaptain?.email,
        'floorCaptainName': floorCaptainName ?? floorCaptain?.email,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
      batch.update(
        _firestore.collection('cleaning_schedules').doc(scheduleId),
        {'currentCount': FieldValue.increment(1)},
      );
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('신청이 완료되었습니다'), backgroundColor: Colors.green),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openDetail(String key) {
    final requests = _grouped[key] ?? [];
    final roomNumber = _keyRoom(key);
    final building = _keyBuilding(key) ?? _roomBuilding(roomNumber);

    int excellentCount = 0, goodCount = 0, poorCount = 0;
    String studentName = _personInfoByKey[key]?['name'] ?? '';
    for (final req in requests) {
      final data = req.data() as Map<String, dynamic>;
      if (studentName.isEmpty) studentName = (data['userName'] ?? '') as String;
      switch (_categorizeHistoryGrade(data)) {
        case 'excellent': excellentCount++; break;
        case 'good': goodCount++; break;
        case 'poor': poorCount++; break;
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _RoomHistoryDetailScreen(
          roomNumber: roomNumber,
          studentName: studentName,
          requests: requests,
          scheduleMap: _scheduleMap,
          excellentCount: excellentCount,
          goodCount: goodCount,
          poorCount: poorCount,
          inspectionType: widget.fixedType ?? 'monthly',
          building: building,
        ),
      ),
    );
  }
}

// ── 호실 이력 상세 화면 ──
class _RoomHistoryDetailScreen extends StatelessWidget {
  final String roomNumber;
  final String studentName;
  final List<QueryDocumentSnapshot> requests;
  final Map<String, Map<String, dynamic>> scheduleMap;
  final int excellentCount;
  final int goodCount;
  final int poorCount;
  final String inspectionType;
  final String? building;

  const _RoomHistoryDetailScreen({
    required this.roomNumber,
    required this.studentName,
    required this.requests,
    required this.scheduleMap,
    required this.excellentCount,
    required this.goodCount,
    required this.poorCount,
    required this.inspectionType,
    this.building,
  });

  String? _detectBuilding() {
    for (final req in requests) {
      final data = req.data() as Map<String, dynamic>;
      final sId = data['scheduleId'] as String?;
      if (sId != null && scheduleMap.containsKey(sId)) {
        final floor = (scheduleMap[sId]?['floor'] ?? '') as String;
        if (floor.startsWith('샬롬하우스')) return '샬롬하우스';
        if (floor.startsWith('국제생활관')) return '국제생활관';
        if (floor.startsWith('바롬인성교육관')) return '바롬인성교육관';
      }
    }
    return null;
  }

  // 사생 기본 정보 엑셀에서 전체 명단을 로드한다.
  // 부가 기능이므로 실패해도 조용히 빈 리스트를 반환한다.
  Future<List<ExcelStudentRow>> _loadExcelStudentRows() async {
    try {
      final settingsDoc =
          await FirebaseFirestore.instance.collection('settings').doc('home').get();
      final excelUrl = settingsDoc.data()?['studentInfoExcelUrl'] as String?;
      if (excelUrl == null || excelUrl.trim().isEmpty) return [];

      final response = await http.get(Uri.parse(excelUrl));
      if (response.statusCode != 200) return [];

      final excel = Excel.decodeBytes(response.bodyBytes);
      final sheet = excel.sheets.values.first;
      final rows = sheet.rows
          .map((row) => row.map((cell) => cell?.value?.toString() ?? '').toList())
          .toList();
      if (rows.isEmpty) return [];

      final header = rows.first;
      return rows.skip(1).map((row) => ExcelStudentRow.fromRow(header, row)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRoomStudents() async {
    final building = _detectBuilding();
    List<Map<String, dynamic>> students;
    try {
      var query = FirebaseFirestore.instance
          .collection('users')
          .where('roomNumber', isEqualTo: roomNumber)
          .where('role', isEqualTo: 'student');
      if (building != null) {
        query = query.where('dormBuilding', isEqualTo: building);
      }
      final snap = await query.get();
      // 재실중인 학생만 표시 (퇴사/바롬인성교육관 등은 제외)
      students = snap.docs
          .map((d) => d.data())
          .where((data) => (data['residentStatus']?.toString() ?? '재실중') == '재실중')
          .toList();
    } catch (_) {
      students = [];
    }

    // 엑셀 명단에는 있으나 아직 앱에 가입하지 않은 학생을 덧붙인다.
    // 가입 여부 판단 기준은 이메일뿐이다(학번은 기준으로 쓰지 않는다).
    final excelRows = await _loadExcelStudentRows();
    if (excelRows.isNotEmpty) {
      final registeredEmails = students
          .map((s) => (s['email']?.toString() ?? '').trim().toLowerCase())
          .where((v) => v.isNotEmpty)
          .toSet();

      for (final row in excelRows) {
        if (!row.hasMatchKey) continue;
        if ((row.roomNumber ?? '').trim() != roomNumber) continue;
        final rowBuilding = (row.dormBuilding ?? '').trim();
        if (building != null && rowBuilding.isNotEmpty && rowBuilding != building) {
          continue;
        }
        final rowEmail = row.normalizedEmail;
        if (rowEmail != null && registeredEmails.contains(rowEmail)) continue;

        students.add({
          'name': row.name ?? '',
          'studentId': (row.studentId ?? '').trim(),
          'seatNumber': (row.seatNumber ?? '').trim(),
          'isUnregistered': true,
        });
      }
    }

    return students;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(inspectionType == 'move_out' ? '퇴사검사 이력 상세' : '월검사 이력 상세'),
      ),
      body: SafeArea(
        child: Column(
        children: [
          // 헤더 통계
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.history,
                          color: Theme.of(context).primaryColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _detectBuilding() == '샬롬하우스'
                                ? '$roomNumber호 (${shalomRoomCapacity(roomNumber)}인실)'
                                : '$roomNumber호',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          FutureBuilder<List<Map<String, dynamic>>>(
                            future: _fetchRoomStudents(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '학생 정보 로딩 중...',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                        fontStyle: FontStyle.italic),
                                  ),
                                );
                              }
                              final students = snapshot.data ?? [];
                              if (students.isEmpty) {
                                if (studentName.isNotEmpty) {
                                  return Text(
                                    studentName,
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                  );
                                }
                                return Text(
                                  '거주학생 없음',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade400,
                                    fontStyle: FontStyle.italic,
                                  ),
                                );
                              }
                              return Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: students.map((s) {
                                  final name = (s['name'] ?? '') as String;
                                  final sId = (s['studentId'] ?? '') as String;
                                  final seat = (s['seatNumber'] ?? '') as String;
                                  final isUnregistered = s['isUnregistered'] == true;

                                  final infoParts = [
                                    if (sId.isNotEmpty) sId,
                                    if (seat.isNotEmpty) '자리 $seat',
                                  ];
                                  final details = infoParts.isNotEmpty ? ' (${infoParts.join(', ')})' : '';

                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isUnregistered
                                          ? Colors.orange.withValues(alpha: 0.05)
                                          : Theme.of(context).primaryColor.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isUnregistered
                                            ? Colors.orange.withValues(alpha: 0.6)
                                            : Theme.of(context).primaryColor.withValues(alpha: 0.15),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.person,
                                          size: 13,
                                          color: isUnregistered
                                              ? Colors.orange
                                              : Theme.of(context).primaryColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$name$details',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                        if (isUnregistered) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: Colors.orange.withValues(alpha: 0.6),
                                              ),
                                            ),
                                            child: const Text(
                                              '미가입',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.orange,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '총 ${requests.length}회',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (inspectionType == 'move_out')
                  Row(
                    children: [
                      _buildStatChip('Pass', excellentCount, Colors.green),
                      const SizedBox(width: 8),
                      _buildStatChip('Fail', poorCount, Colors.red),
                    ],
                  )
                else
                  Row(
                    children: [
                      _buildStatChip('매우양호', excellentCount, Colors.green),
                      const SizedBox(width: 8),
                      _buildStatChip('양호', goodCount, Colors.blue),
                      const SizedBox(width: 8),
                      _buildStatChip('미흡', poorCount, Colors.red),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 이력 목록
          Expanded(
            child: requests.isEmpty
                ? const Center(
                    child: Text('점검 이력이 없습니다',
                        style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final data = requests[index].data()
                          as Map<String, dynamic>;
                      return _buildHistoryCard(context, data);
                    },
                  ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, Map<String, dynamic> data) {
    final scheduleId = data['scheduleId'] as String?;
    final roomNumber = (data['roomNumber'] ?? '') as String;
    final status = (data['status'] ?? 'pending') as String;
    final grade = data['grade'] as String?;
    final comment = (data['inspectionComment'] ?? data['comment']) as String?;
    final memo = data['memo'] as String?;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final evaluatedAt = (data['evaluatedAt'] as Timestamp?)?.toDate();
    final evaluatedByEmail = data['evaluatedByEmail'] as String?;
    final userName = (data['userName'] ?? '') as String;

    final rawCommunal = data['checklistCommunal'] as Map<String, dynamic>?;
    final rawPersonal = data['checklistPersonal'] as Map<String, dynamic>?;
    final scoresCommunal = data['scoresCommunal'] as Map<String, dynamic>?;
    final scoresPersonal = data['scoresPersonal'] as Map<String, dynamic>?;

    // 스케줄이 삭제된 경우 평가 시점에 요청 문서에 저장된 값으로 폴백
    final scheduleData = scheduleId != null ? scheduleMap[scheduleId] : null;
    final floor = (scheduleData?['floor'] ?? data['floor'] ?? '') as String;
    final inspectionType =
        (scheduleData?['inspectionType'] ?? data['inspectionType'] ?? 'monthly') as String;
    final isMoveOut = inspectionType == 'move_out';
    final scheduleDate = (scheduleData?['date'] as Timestamp?)?.toDate();
    final scheduleStartTime = scheduleData?['startTime'] as String?;
    final scheduleEndTime = scheduleData?['endTime'] as String?;

    int totalFails = 0;
    int totalItems = 0;
    bool hasChecklist = false;

    if (scoresCommunal != null || scoresPersonal != null) {
      final cFails = scoresCommunal?.values.where((v) => isMoveOut ? (v == 0 || v == 2) : v <= 2).length ?? 0;
      // ignore: unnecessary_cast
      final pFails = scoresPersonal?.values.expand((m) => (m as Map<String, dynamic>).values).where((v) => isMoveOut ? ((v as int) == 0 || (v as int) == 2) : (v as int) <= 2).length ?? 0;
      totalFails = cFails + pFails;
      totalItems = (scoresCommunal?.length ?? 0) + (scoresPersonal?.values.expand((m) => (m as Map<String, dynamic>).values).length ?? 0);
      hasChecklist = totalItems > 0;
    } else {
      final cFails = rawCommunal?.values.where((v) => v != true).length ?? 0;
      final pFails = rawPersonal?.values.expand((m) => (m as Map<String, dynamic>).values).where((v) => v != true).length ?? 0;
      totalFails = cFails + pFails;
      totalItems = (rawCommunal?.length ?? 0) + (rawPersonal?.values.expand((m) => (m as Map<String, dynamic>).values).length ?? 0);
      hasChecklist = totalItems > 0;
    }

    final statusColor = _statusColor(status);
    final statusLabel = _statusLabel(status);
    final gradeColor = _getHistoryGradeColor(data);
    final gradeLabel = _getHistoryGradeLabel(data);

    final displayStatusLabel = (totalFails > 0) ? '재검사 필요' : statusLabel;
    final displayStatusColor = (totalFails > 0) ? Colors.red : statusColor;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 날짜 + 상태 + 등급
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text(
                  scheduleDate != null
                      ? '${DateFormat('yyyy.MM.dd').format(scheduleDate)}${scheduleStartTime != null ? ' $scheduleStartTime' : ''}${scheduleEndTime != null ? '~$scheduleEndTime' : ''}'
                      : (createdAt != null ? DateFormat('yyyy.MM.dd HH:mm').format(createdAt) : '-'),
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade700),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: displayStatusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border:
                        Border.all(color: displayStatusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    displayStatusLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: displayStatusColor),
                  ),
                ),
                if (grade != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: gradeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border:
                          Border.all(color: gradeColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      gradeLabel,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: gradeColor),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            // 구역 + 점검 유형 + 날짜 + 대상 학생
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (floor.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.layers,
                          size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(floor,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700)),
                    ],
                  ),
                if (scheduleDate != null)
                  Text(
                    DateFormat('yyyy.MM.dd').format(scheduleDate),
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500),
                  ),
                if (userName.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person,
                          size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        userName,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
              ],
            ),
            if (evaluatedAt != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 13, color: Colors.green),
                  const SizedBox(width: 5),
                  Text(
                    '평가: ${DateFormat('yyyy.MM.dd HH:mm').format(evaluatedAt)}'
                    '${evaluatedByEmail != null ? ' · $evaluatedByEmail' : ''}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
            if (isMoveOut) ...[
              () {
                final raw = data['commonAreas'];
                List<String> areas = [];
                if (raw is List) {
                  areas = raw.map((e) => e.toString()).toList();
                } else if (raw is String && raw.isNotEmpty) {
                  areas = [raw];
                }
                if (areas.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.home_work_outlined, size: 13, color: Colors.cyan),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '공동구역: ${areas.join(' · ')}',
                          style: const TextStyle(fontSize: 12, color: Colors.cyan),
                        ),
                      ),
                    ],
                  ),
                );
              }(),
            ],
            if (comment != null && comment.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('점검자 멘트: $comment',
                  style: TextStyle(
                      fontSize: 12, color: Colors.blueAccent.shade700)),
            ],
            if (memo != null && memo.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('메모: $memo',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600)),
            ],
            // 체크리스트 상세 (ExpansionTile)
            if (hasChecklist) ...[
              const SizedBox(height: 8),
              Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(top: 8),
                  title: Row(
                    children: [
                      const Icon(Icons.checklist,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      const Text(
                        '체크리스트 상세',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (totalFails > 0
                                  ? Colors.red
                                  : Colors.green)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isMoveOut
                              ? 'fail $totalFails / $totalItems'
                              : '미흡 $totalFails / $totalItems',
                          style: TextStyle(
                            fontSize: 10,
                            color: totalFails > 0
                                ? Colors.red
                                : Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                  children: [
                    // 개인 구역
                    if (scoresPersonal != null || rawPersonal != null)
                      ...(scoresPersonal?.entries ?? rawPersonal!.entries).map((studentEntry) {
                        final items = studentEntry.value as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.08),
                                  borderRadius:
                                      BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '개인 — ${studentEntry.key}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  ...() {
                                    final histStructures = getCheckStructures(floor, inspectionType, roomNumber: roomNumber);
                                    final ordered = <MapEntry<String, dynamic>>[];
                                    for (final cat in histStructures.personal.entries) {
                                      for (final sub in cat.value) {
                                        final key = '${cat.key}_$sub';
                                        if (items.containsKey(key)) {
                                          ordered.add(MapEntry(key, items[key]));
                                        }
                                      }
                                    }
                                    final fails = ordered.where((e) => e.value is int
                                        ? (isMoveOut ? ((e.value as int) == 0 || (e.value as int) == 2) : (e.value as int) <= 2)
                                        : e.value != true);
                                    final passes = ordered.where((e) => e.value is int
                                        ? (isMoveOut ? ((e.value as int) == 1 || (e.value as int) == 3 || (e.value as int) == 4) : (e.value as int) >= 3)
                                        : e.value == true);
                                    return [...fails, ...passes].map((e) => _buildHistoryItemChip(e.key, e.value, isMoveOut: isMoveOut));
                                  }(),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    // 공동 구역 / 월검사 점검 항목
                    if (scoresCommunal != null || rawCommunal != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: inspectionType == 'move_out'
                              ? Colors.purple.withValues(alpha: 0.08)
                              : Colors.teal.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          inspectionType == 'move_out' ? '공동 구역' : '점검 항목',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: inspectionType == 'move_out' ? Colors.purple : Colors.teal),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          ...() {
                            final histStructures = getCheckStructures(floor, inspectionType);
                            final communalMap = scoresCommunal ?? rawCommunal!;
                            final ordered = <MapEntry<String, dynamic>>[];
                            for (final cat in histStructures.communal.entries) {
                              for (final sub in cat.value) {
                                final key = '${cat.key}_$sub';
                                if (communalMap.containsKey(key)) {
                                  ordered.add(MapEntry(key, communalMap[key]));
                                }
                              }
                            }
                            final fails = ordered.where((e) => e.value is int
                                ? (isMoveOut ? ((e.value as int) == 0 || (e.value as int) == 2) : (e.value as int) <= 2)
                                : e.value != true);
                            final passes = ordered.where((e) => e.value is int
                                ? (isMoveOut ? ((e.value as int) == 1 || (e.value as int) == 3 || (e.value as int) == 4) : (e.value as int) >= 3)
                                : e.value == true);
                            return [...fails, ...passes].map((e) => _buildHistoryItemChip(e.key, e.value, isMoveOut: isMoveOut));
                          }(),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItemChip(String key, dynamic value, {bool isMoveOut = false}) {
    if (value is int) {
      final score = value;
      final parts = key.split('_');
      final label = parts.length >= 2 ? '${parts[0]} ${parts[1]}' : key;

      if (isMoveOut) {
        final isPassed = score == 1 || score == 3 || score == 4;
        final Color color = isPassed ? Colors.green : Colors.red;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPassed ? Icons.check : Icons.close,
                size: 10,
                color: color,
              ),
              const SizedBox(width: 3),
              Text(
                '$label: ${isPassed ? 'O' : 'X'}',
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: isPassed ? FontWeight.normal : FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }

      final isPassed = score >= 3;
      final Color color = score == 4 ? Colors.green : score == 3 ? Colors.blue : score == 2 ? Colors.orange : Colors.red;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPassed ? Icons.check : Icons.close,
              size: 10,
              color: color,
            ),
            const SizedBox(width: 3),
            Text(
              '$label: $score점',
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: isPassed ? FontWeight.normal : FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    
    final isPassed = value == true;
    final parts = key.split('_');
    final label =
        parts.length >= 2 ? '${parts[0]} ${parts[1]}' : key;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isPassed
            ? Colors.green.withValues(alpha: 0.07)
            : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isPassed
              ? Colors.green.withValues(alpha: 0.4)
              : Colors.red.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPassed ? Icons.check : Icons.close,
            size: 10,
            color: isPassed ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isPassed ? Colors.green : Colors.red,
              fontWeight:
                  isPassed ? FontWeight.normal : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return '대기중';
      case 'in_progress':
        return '점검중';
      case 'completed':
        return '완료';
      case 'rejected':
        return '반려됨';
      default:
        return '알 수 없음';
    }
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFF87CEEB);
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  static String _getHistoryGradeLabel(Map<String, dynamic> data) {
    final isMoveOut = data['inspectionType'] == 'move_out';
    if (isMoveOut) {
      final status = data['status'] as String?;
      if (status != 'completed') return '대기중';
      return data['needsRecheck'] == true ? 'Fail' : 'Pass';
    }
    final scoreAvg = (data['scoreAvg'] as num?)?.toDouble();
    if (scoreAvg != null) return '${scoreAvg.toStringAsFixed(1)}점';
    final grade = data['grade'] as String?;
    switch (grade) {
      case 'excellent': return '매우양호';
      case 'good': return '양호';
      case 'poor': return '미흡';
      default: return '미평가';
    }
  }

  static Color _getHistoryGradeColor(Map<String, dynamic> data) {
    final isMoveOut = data['inspectionType'] == 'move_out';
    if (isMoveOut) {
      final status = data['status'] as String?;
      if (status != 'completed') return Colors.orange;
      return data['needsRecheck'] == true ? Colors.red : Colors.green;
    }
    final scoreAvg = (data['scoreAvg'] as num?)?.toDouble();
    if (scoreAvg != null) {
      if (scoreAvg >= 3.5) return Colors.green;
      if (scoreAvg >= 2.5) return Colors.blue;
      return Colors.red;
    }
    final grade = data['grade'] as String?;
    switch (grade) {
      case 'excellent': return Colors.green;
      case 'good': return Colors.blue;
      case 'poor': return Colors.red;
      default: return Colors.grey;
    }
  }
}
