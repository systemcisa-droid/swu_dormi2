import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// ── 체크리스트 구조 (파일 공통) ──
const Map<String, List<String>> kPersonalCheckStructure = {
  '옷장': ['안', '거울', '서랍'],
  '침대': ['매트리스 얼룩', '서랍'],
  '창문': ['좌', '중', '우'],
  '책상': ['책상 위', '거울', '여닫이', '바닥'],
  '화장대': ['거울'],
  '바닥': ['구석', '바닥'],
  '택배': ['수령확인'],
};

const Map<String, List<String>> kCommunalCheckStructure = {
  '현관': ['바닥', '신발장'],
  '화장실': ['변기', '하수구', '타일(물때)'],
  '샤워실': ['거울', '세면(물때)', '하수구', '타일(물때)'],
  '세면대': ['위', '거울', '여닫이'],
  '공동 바닥': ['구석', '바닥'],
  '냉장고': ['안'],
};

// ══════════════════════════════════════════════════════════════
// 청소점검 메인 화면 (탭: 월검사/퇴사검사 / 호실별 이력)
// ══════════════════════════════════════════════════════════════
class CleaningInspectionScreen extends StatefulWidget {
  const CleaningInspectionScreen({super.key});

  @override
  State<CleaningInspectionScreen> createState() =>
      _CleaningInspectionScreenState();
}

class _CleaningInspectionScreenState extends State<CleaningInspectionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
          tabs: const [
            Tab(icon: Icon(Icons.calendar_month, size: 18), text: '월검사/퇴사검사'),
            Tab(icon: Icon(Icons.history, size: 18), text: '호실별 이력'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CleaningInspectionContent(
            key: const ValueKey('monthly'),
            inspectionType: 'monthly',
            tabLabel: '월검사/퇴사검사',
          ),
          const RoomInspectionHistoryContent(),
        ],
      ),
    );
  }
}

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
    if (_selectedFloorFilter == null) return _schedules;
    return _schedules.where((doc) {
      final floor = (doc.data() as Map<String, dynamic>)['floor'] as String?;
      return floor == _selectedFloorFilter;
    }).toList();
  }

  // ── 체크리스트 구조 (top-level kPersonalCheckStructure / kCommunalCheckStructure 사용) ──

  static const List<String> _floorOptions = [
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
  ];

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
    final doc = await _firestore.collection('users').doc(uid).get();
    final floor = doc.data()?['assignedFloor'] as String?;
    if (mounted && floor != null && _floorOptions.contains(floor)) {
      setState(() => _selectedFloorFilter = floor);
    }
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
    return _requests.where((req) {
      final data = req.data() as Map<String, dynamic>;
      return data['scheduleId'] == scheduleId;
    }).toList();
  }

  Map<String, int> _makePersonalScores() => {
        for (final e in kPersonalCheckStructure.entries)
          for (final item in e.value) '${e.key}_$item': 4,
      };

  Map<String, int> _makeCommunalScores() => {
        for (final e in kCommunalCheckStructure.entries)
          for (final item in e.value) '${e.key}_$item': 4,
      };

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
                            padding: const EdgeInsets.all(12),
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
        label: const Text('일정 추가'),
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
    final deadline = (data['applicationDeadline'] as Timestamp?)?.toDate();
    final isSelected = _selectedScheduleId == doc.id;
    final inspectionType = (data['inspectionType'] ?? 'monthly') as String;
    final isMoveOut = inspectionType == 'move_out';
    final isDeadlinePassed = deadline != null && deadline.isBefore(DateTime.now());

    final scheduleRequests = _requestsForSchedule(doc.id);
    final requestsCount = scheduleRequests.length;
    final completedCount = scheduleRequests.where((r) {
      final d = r.data() as Map<String, dynamic>;
      return (d['status'] ?? '') == 'completed';
    }).length;
    final incompleteCount = requestsCount - completedCount;

    // 검사 유형 색상
    final typeColor = isMoveOut ? Colors.deepOrange : Colors.blue;
    final typeLabel = isMoveOut ? '퇴사검사' : '월검사';

    Color statusColor;
    String statusText;
    if (isDeadlinePassed && status == 'open') {
      statusColor = Colors.grey;
      statusText = '신청만료';
    } else {
      switch (status) {
        case 'open':
          statusColor = Colors.green;
          statusText = '신청가능';
          break;
        case 'full':
          statusColor = Colors.red;
          statusText = '정원초과';
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

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
            : BorderSide(color: typeColor.withValues(alpha: 0.3), width: 1),
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
            onTap: () {
              setState(() {
                _selectedScheduleId = isSelected ? null : doc.id;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
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
                              date != null
                                  ? DateFormat('MM/dd').format(date)
                                  : '--',
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
                            Text(
                              floor.isNotEmpty ? floor : '점검 스케줄',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.access_time,
                                    size: 14,
                                    color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  '$startTime ~ $endTime',
                                  style:
                                      TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.people,
                                    size: 14,
                                    color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  '정원 $currentCount/$maxCapacity',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                if (requestsCount > 0) ...[
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
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
                            if (deadline != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                '신청기한: ${DateFormat('MM/dd HH:mm').format(deadline)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: statusColor.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (requestsCount > 0 && incompleteCount > 0) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: Colors.purple.withValues(alpha: 0.4)),
                              ),
                              child: const Text(
                                '검사필요',
                                style: TextStyle(
                                  color: Colors.purple,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          if (requestsCount > 0 && incompleteCount == 0) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: Colors.green.withValues(alpha: 0.4)),
                              ),
                              child: const Text(
                                '검사완료',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'delete') _deleteSchedule(doc.id);
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete,
                                        color: Colors.red, size: 18),
                                    SizedBox(width: 8),
                                    Text('삭제',
                                        style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                            icon: const Icon(Icons.more_vert, size: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      typeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: typeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 선택된 경우 신청 목록 표시
          if (isSelected) _buildRequestsSection(doc.id),
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
    final comment = data['comment'] as String?;
    final memo = data['memo'] as String?;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

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
      gradeText = '${scoreAvg.toStringAsFixed(1)}점';
      if (scoreAvg >= 3.5) {
        gradeColor = Colors.green;
      } else if (scoreAvg >= 2.5) {
        gradeColor = Colors.blue;
      } else {
        gradeColor = Colors.red;
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
                  '$userName ($roomNumber호)',
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
              if (status == 'pending' || status == 'in_progress') ...[
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'evaluate') {
                      _showEvaluateDialog(doc.id, data);
                    } else if (value == 'reject') {
                      _rejectRequest(doc.id);
                    } else if (value == 'delete') {
                      _deleteRequest(doc.id);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'evaluate',
                      child: Row(children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                        SizedBox(width: 8),
                        Text('점검 평가'),
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

  // ── 일정 추가 다이얼로그 ──
  Future<void> _showAddScheduleDialog() async {
    if (!mounted) return;

    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    DateTime deadlineDate = DateTime.now();
    final deadlineTimeCtrl = TextEditingController(text: '23:00');
    final startTimeCtrl = TextEditingController(text: '10:00');
    final endTimeCtrl = TextEditingController(text: '12:00');
    final capacityCtrl = TextEditingController(text: '8');
    String selectedFloor = _floorOptions.first;
    String selectedInspectionType = 'monthly';

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
                const Text('점검 구역', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedFloor,
                  isExpanded: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.layers_outlined, size: 18),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: _floorOptions.map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (val) { if (val != null) setDialogState(() => selectedFloor = val); },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.assignment_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    const Text('점검 유형: ', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedInspectionType,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: 'monthly', child: Text('월검사')),
                              DropdownMenuItem(value: 'move_out', child: Text('퇴사검사')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => selectedInspectionType = val);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
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
                const Text('최대 정원',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: capacityCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    suffixText: '명',
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('신청 기한',
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
                  deadlineDate,
                  deadlineTimeCtrl.text.trim(),
                  selectedInspectionType,
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
    DateTime deadlineDate,
    String deadlineTime,
    String inspectionType,
  ) async {
    try {
      final parts = deadlineTime.split(':');
      final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '23') ?? 23;
      final minute = int.tryParse(parts.length > 1 ? parts[1] : '59') ?? 59;
      final deadline = DateTime(
          deadlineDate.year, deadlineDate.month, deadlineDate.day, hour, minute);

      final batch = _firestore.batch();
      for (int i = 0; i < 4; i++) {
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
          'applicationDeadline': Timestamp.fromDate(deadline),
        });
      }
      await batch.commit();

      await _loadSchedules();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('4일 연속 일정이 추가되었습니다'),
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
      await _firestore
          .collection('cleaning_schedules')
          .doc(scheduleId)
          .delete();
      setState(() {
        if (_selectedScheduleId == scheduleId) _selectedScheduleId = null;
      });
      await _loadSchedules();
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
      String requestId, Map<String, dynamic> data) async {
    final userName = (data['userName'] ?? '') as String;
    final roomNumber = (data['roomNumber'] ?? '') as String;

    // 같은 호실 학생 목록 조회
    List<String> roomStudents = [];
    try {
      final snap = await _firestore
          .collection('users')
          .where('roomNumber', isEqualTo: roomNumber)
          .where('role', isEqualTo: 'student')
          .get();
      roomStudents = snap.docs
          .map((d) => (d.data()['name'] as String?) ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
    } catch (_) {}
    if (roomStudents.isEmpty) roomStudents = [userName];

    if (!mounted) return;

    final Map<String, Map<String, int>> studentScores = {
      for (final name in roomStudents) name: _makePersonalScores(),
    };
    final Map<String, int> communalScores = _makeCommunalScores();
    int selectedTabIndex = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final avg = _calcAvg(studentScores, communalScores);
          final avgColor = avg >= 3.5 ? Colors.green : avg >= 2.5 ? Colors.blue : Colors.red;

          final tabs = [...roomStudents, '공동 구역'];
          final isStudentTab = selectedTabIndex < roomStudents.length;

          // 탭 내 최저 점수 (1~2점 항목 수)
          int tabLowCount(int idx) {
            if (idx < roomStudents.length) {
              return studentScores[roomStudents[idx]]!.values.where((v) => v <= 2).length;
            }
            return communalScores.values.where((v) => v <= 2).length;
          }

          return Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 550),
              child: Padding(
                padding: const EdgeInsets.all(20),
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
                            '청소 점검 — $roomNumber호 (${roomStudents.length}명)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 탭 바
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
                                kPersonalCheckStructure,
                                studentScores[
                                    roomStudents[selectedTabIndex]]!,
                                setDialogState,
                                Colors.blue,
                              )
                            : _buildScoreSection(
                                '공동 구역',
                                kCommunalCheckStructure,
                                communalScores,
                                setDialogState,
                                Colors.purple,
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 평균 점수 요약
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
                          const Text(
                            '평균 점수',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                          const Spacer(),
                          Text(
                            '${avg.toStringAsFixed(1)}점 / 4점',
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
                                studentScores);
                          },
                          child: const Text('평가 완료'),
                        ),
                      ],
                    ),
                  ],
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
    Color color,
  ) {
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
                  final score = scores[key] ?? 4;
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
                          child: Row(
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
                }).toList(),
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
  ) async {
    try {
      final needsRecheck = studentScores.values.expand((m) => m.values).any((v) => v <= 2) ||
          communalScores.values.any((v) => v <= 2);
      await _firestore.collection('cleaning_requests').doc(requestId).update({
        'status': 'completed',
        'scoreAvg': scoreAvg,
        'needsRecheck': needsRecheck,
        'evaluatedAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'scoresCommunal': communalScores,
        'scoresPersonal': {
          for (final e in studentScores.entries) e.key: e.value,
        },
      });
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
      await _firestore.collection('cleaning_requests').doc(requestId).update({
        'status': 'rejected',
        'updatedAt': Timestamp.now(),
      });
      await _loadRequests();
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
      await _firestore.collection('cleaning_requests').doc(requestId).delete();
      await _loadRequests();
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
  const RoomInspectionHistoryContent({super.key});

  @override
  State<RoomInspectionHistoryContent> createState() =>
      _RoomInspectionHistoryContentState();
}

class _RoomInspectionHistoryContentState
    extends State<RoomInspectionHistoryContent> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, Map<String, dynamic>> _scheduleMap = {};
  bool _isLoading = true;
  String _errorMessage = '';

  Map<String, List<QueryDocumentSnapshot>> _grouped = {};
  List<String> _sortedRooms = [];

  String? _assignedFloor; // e.g. "A동 3층"
  String? _parsedBuilding;
  int? _parsedFloor;

  static String _getBuilding(String roomNumber) {
    final n = int.tryParse(roomNumber);
    if (n == null) return '';
    final last = n % 100;
    if (last >= 1 && last <= 20) return 'A';
    if (last >= 21 && last <= 35) return 'B';
    return '';
  }

  static int _getFloor(String roomNumber) {
    final n = int.tryParse(roomNumber);
    if (n == null) return 0;
    return n ~/ 100;
  }

  static String _getHistoryGradeLabel(Map<String, dynamic> data) {
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

  static String _categorizeHistoryGrade(Map<String, dynamic> data) {
    final scoreAvg = (data['scoreAvg'] as num?)?.toDouble();
    if (scoreAvg != null) {
      if (scoreAvg >= 3.5) return 'excellent';
      if (scoreAvg >= 2.5) return 'good';
      return 'poor';
    }
    return data['grade'] as String? ?? 'none';
  }

  @override
  void initState() {
    super.initState();
    _loadProfileFloor();
    _loadData();
  }

  Future<void> _loadProfileFloor() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await _firestore.collection('users').doc(uid).get();
    final floor = doc.data()?['assignedFloor'] as String?;
    if (floor != null && mounted) {
      // Parse "A동 3층" → building='A', floor=3
      final buildingMatch = RegExp(r'^([A-Za-z]+)동').firstMatch(floor);
      final floorMatch = RegExp(r'(\d+)층').firstMatch(floor);
      setState(() {
        _assignedFloor = floor;
        _parsedBuilding = buildingMatch?.group(1)?.toUpperCase();
        _parsedFloor = floorMatch != null ? int.tryParse(floorMatch.group(1)!) : null;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final requestsSnap =
          await _firestore.collection('cleaning_requests').get();
      final schedulesSnap =
          await _firestore.collection('cleaning_schedules').get();

      final scheduleMap = <String, Map<String, dynamic>>{};
      for (final doc in schedulesSnap.docs) {
        scheduleMap[doc.id] = doc.data();
      }

      final grouped = <String, List<QueryDocumentSnapshot>>{};
      for (final req in requestsSnap.docs) {
        final data = req.data();
        final room = (data['roomNumber'] ?? '') as String;
        if (room.isEmpty) continue;
        grouped.putIfAbsent(room, () => []).add(req);
      }

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

      final sortedRooms = grouped.keys.toList()
        ..sort((a, b) {
          final numA = int.tryParse(a) ?? 0;
          final numB = int.tryParse(b) ?? 0;
          if (numA != 0 && numB != 0) return numA.compareTo(numB);
          return a.compareTo(b);
        });

      if (mounted) {
        setState(() {
          _scheduleMap = scheduleMap;
          _grouped = grouped;
          _sortedRooms = sortedRooms;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  List<String> get _filteredRooms {
    return _sortedRooms.where((r) {
      if (_parsedBuilding != null && _getBuilding(r) != _parsedBuilding) {
        return false;
      }
      if (_parsedFloor != null && _getFloor(r) != _parsedFloor) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            const Text('데이터를 불러오는 중 오류가 발생했습니다'),
            const SizedBox(height: 8),
            Text(_errorMessage,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: _loadData, child: const Text('다시 시도')),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 담당 구역 표시
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.layers, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                '담당 구역: ${_assignedFloor ?? '미설정'}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _loadData,
                tooltip: '새로고침',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // 호실 목록
        Expanded(
          child: _filteredRooms.isEmpty
              ? const Center(
                  child: Text(
                    '이력이 없습니다',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filteredRooms.length,
                    itemBuilder: (context, index) =>
                        _buildRoomCard(_filteredRooms[index]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildRoomCard(String roomNumber) {
    final requests = _grouped[roomNumber] ?? [];

    DateTime? latestDate;
    Map<String, dynamic>? latestData;
    if (requests.isNotEmpty) {
      latestData = requests.first.data() as Map<String, dynamic>;
      final ts = latestData['createdAt'] as Timestamp?;
      latestDate = ts?.toDate();
    }

    final gradeColor = latestData != null ? _getHistoryGradeColor(latestData) : Colors.grey;
    final gradeLabel = latestData != null ? _getHistoryGradeLabel(latestData) : '미평가';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showRoomHistory(roomNumber),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // 호실 번호 박스
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    roomNumber,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$roomNumber호',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '총 ${requests.length}회 점검',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                    if (latestDate != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '최근: ${DateFormat('yyyy.MM.dd').format(latestDate)}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ],
                ),
              ),
              // 등급 + 화살표
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: gradeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border:
                          Border.all(color: gradeColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      gradeLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: gradeColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRoomHistory(String roomNumber) {
    final requests = _grouped[roomNumber] ?? [];

    int excellentCount = 0;
    int goodCount = 0;
    int poorCount = 0;
    String studentName = '';

    for (final req in requests) {
      final data = req.data() as Map<String, dynamic>;
      if (studentName.isEmpty) {
        studentName = (data['userName'] ?? '') as String;
      }
      switch (_categorizeHistoryGrade(data)) {
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

  const _RoomHistoryDetailScreen({
    required this.roomNumber,
    required this.studentName,
    required this.requests,
    required this.scheduleMap,
    required this.excellentCount,
    required this.goodCount,
    required this.poorCount,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$roomNumber호 점검 이력'),
      ),
      body: Column(
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
                            '$roomNumber호',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (studentName.isNotEmpty)
                            Text(
                              studentName,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600),
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
    final status = (data['status'] ?? 'pending') as String;
    final grade = data['grade'] as String?;
    final comment = data['comment'] as String?;
    final memo = data['memo'] as String?;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final evaluatedAt = (data['evaluatedAt'] as Timestamp?)?.toDate();

    final rawCommunal = data['checklistCommunal'] as Map<String, dynamic>?;
    final rawPersonal = data['checklistPersonal'] as Map<String, dynamic>?;
    final scoresCommunal = data['scoresCommunal'] as Map<String, dynamic>?;
    final scoresPersonal = data['scoresPersonal'] as Map<String, dynamic>?;

    int totalFails = 0;
    int totalItems = 0;
    bool hasChecklist = false;

    if (scoresCommunal != null || scoresPersonal != null) {
      final cFails = scoresCommunal?.values.where((v) => (v as int) <= 2).length ?? 0;
      final pFails = scoresPersonal?.values.expand((m) => (m as Map<String, dynamic>).values).where((v) => (v as int) <= 2).length ?? 0;
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

    final scheduleData = scheduleId != null ? scheduleMap[scheduleId] : null;
    final floor = (scheduleData?['floor'] ?? '') as String;
    final inspectionType =
        (scheduleData?['inspectionType'] ?? 'monthly') as String;
    final scheduleDate =
        (scheduleData?['date'] as Timestamp?)?.toDate();
    final inspectionTypeLabel =
        inspectionType == 'move_out' ? '퇴사검사' : '월검사';

    final statusColor = _statusColor(status);
    final statusLabel = _statusLabel(status);
    final gradeColor = _getHistoryGradeColor(data);
    final gradeLabel = _getHistoryGradeLabel(data);

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
                  createdAt != null
                      ? DateFormat('yyyy.MM.dd HH:mm').format(createdAt)
                      : '-',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade700),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor),
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
            // 구역 + 점검 유형 + 날짜
            Wrap(
              spacing: 8,
              runSpacing: 4,
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
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                    border:
                        Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    inspectionTypeLabel,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.teal,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                if (scheduleDate != null)
                  Text(
                    DateFormat('yyyy.MM.dd').format(scheduleDate),
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500),
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
                    '평가: ${DateFormat('yyyy.MM.dd HH:mm').format(evaluatedAt)}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
            if (comment != null && comment.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('코멘트: $comment',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600)),
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
                          '미흡 $totalFails / $totalItems',
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
                                  ...items.entries
                                      .where((e) => (e.value is int ? (e.value as int) <= 2 : e.value != true))
                                      .map((e) =>
                                          _buildHistoryItemChip(e.key, e.value)),
                                  ...items.entries
                                      .where((e) => (e.value is int ? (e.value as int) >= 3 : e.value == true))
                                      .map((e) =>
                                          _buildHistoryItemChip(e.key, e.value)),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    // 공동 구역
                    if (scoresCommunal != null || rawCommunal != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '공동 구역',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          ...(scoresCommunal?.entries ?? rawCommunal!.entries)
                              .where((e) => (e.value is int ? (e.value as int) <= 2 : e.value != true))
                              .map((e) =>
                                  _buildHistoryItemChip(e.key, e.value)),
                          ...(scoresCommunal?.entries ?? rawCommunal!.entries)
                              .where((e) => (e.value is int ? (e.value as int) >= 3 : e.value == true))
                              .map((e) => _buildHistoryItemChip(e.key, e.value)),
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

  Widget _buildHistoryItemChip(String key, dynamic value) {
    if (value is int) {
      final score = value;
      final parts = key.split('_');
      final label = parts.length >= 2 ? '${parts[0]} ${parts[1]}' : key;
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
        return Colors.orange;
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
