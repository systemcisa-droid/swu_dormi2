import 'package:fluent_ui/fluent_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:swu_dormi_admin/screens/windows/windows_cleaning_inspection_screen.dart';

class CleaningInspectionContent extends StatefulWidget {
  // 'monthly' 또는 'move_out' 고정 (null이면 전체)
  final String? fixedType;
  const CleaningInspectionContent({super.key, this.fixedType});

  @override
  State<CleaningInspectionContent> createState() =>
      _CleaningInspectionContentState();
}

class _CleaningInspectionContentState extends State<CleaningInspectionContent> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<QueryDocumentSnapshot> _allSchedules = [];
  List<QueryDocumentSnapshot> _requests = [];
  Map<String, String> _userDormBuildings = {}; // userId → dormBuilding
  bool _isLoadingSchedules = true;
  bool _isLoadingRequests = true;

  // fixedType이 있으면 해당 타입 고정, 없으면 내부 필터 사용
  String? get _typeFilter => widget.fixedType;
  // 층 필터: null=전체
  String? _floorFilter;

  QueryDocumentSnapshot? _selectedSchedule;

  List<QueryDocumentSnapshot> get _schedules {
    var list = _allSchedules;
    if (_typeFilter != null) {
      if (_typeFilter == 'monthly') {
        list = list.where((doc) {
          final t =
              (doc.data() as Map<String, dynamic>)['inspectionType'] as String?;
          return t == null || t == 'monthly';
        }).toList();
      } else {
        list = list.where((doc) {
          final t =
              (doc.data() as Map<String, dynamic>)['inspectionType'] as String?;
          return t == _typeFilter;
        }).toList();
      }
    }
    if (_floorFilter != null) {
      list = list.where((doc) {
        final f =
            (doc.data() as Map<String, dynamic>)['floor'] as String? ?? '';
        return f == _floorFilter;
      }).toList();
    }
    list = List.from(list)
      ..sort((a, b) {
        final da = ((a.data() as Map<String, dynamic>)['date'] as Timestamp?)
            ?.toDate();
        final db = ((b.data() as Map<String, dynamic>)['date'] as Timestamp?)
            ?.toDate();
        if (da == null && db != null) return 1;
        if (da != null && db == null) return -1;
        if (da != null && db != null && da != db) return da.compareTo(db);
        final fa =
            ((a.data() as Map<String, dynamic>)['floor'] ?? '') as String;
        final fb =
            ((b.data() as Map<String, dynamic>)['floor'] ?? '') as String;
        final ia = kFloorOptions.indexOf(fa);
        final ib = kFloorOptions.indexOf(fb);
        final sa = ia < 0 ? 999 : ia;
        final sb = ib < 0 ? 999 : ib;
        return sa.compareTo(sb);
      });
    return list;
  }

  @override
  void initState() {
    super.initState();
    _loadSchedules();
    _loadRequests();
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoadingSchedules = true);
    try {
      final allSnap = await _firestore
          .collection('cleaning_schedules')
          .orderBy('date', descending: false)
          .get();
      if (mounted) {
        setState(() {
          _allSchedules = allSnap.docs;
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
      final snapshot = await _firestore
          .collection('cleaning_requests')
          .orderBy('createdAt', descending: true)
          .get();

      // userId 목록 수집 후 dormBuilding 일괄 조회
      final userIds = snapshot.docs
          .map(
            (d) =>
                (d.data() as Map<String, dynamic>)['userId'] as String? ?? '',
          )
          .where((id) => id.isNotEmpty)
          .toSet();

      final Map<String, String> dormMap = {};
      for (final uid in userIds) {
        try {
          final userDoc = await _firestore.collection('users').doc(uid).get();
          final dorm = userDoc.data()?['dormBuilding'] as String?;
          if (dorm != null) dormMap[uid] = dorm;
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _requests = snapshot.docs;
          _userDormBuildings = dormMap;
          _isLoadingRequests = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRequests = false);
    }
  }

  /// 스케줄의 floor 문자열에서 건물명 추출 (예: "국제생활관 A동 2층" → "국제생활관")
  static String? _extractBuildingFromFloor(String floor) {
    if (floor.startsWith('샬롬하우스(여름방학)')) return '샬롬하우스(여름방학)';
    if (floor.startsWith('샬롬하우스')) return '샬롬하우스';
    if (floor.startsWith('국제생활관')) return '국제생활관';
    if (floor.startsWith('바롬인성교육관')) return '바롬인성교육관';
    return null;
  }

  List<QueryDocumentSnapshot> get _filteredRequests {
    if (_selectedSchedule == null) return [];
    final scheduleId = _selectedSchedule!.id;
    final scheduleData = _selectedSchedule!.data() as Map<String, dynamic>;
    final scheduleFloor = (scheduleData['floor'] ?? '') as String;
    final scheduleBuilding = _extractBuildingFromFloor(scheduleFloor);

    final filtered = _requests.where((req) {
      final data = req.data() as Map<String, dynamic>;
      if (data['scheduleId'] != scheduleId) return false;

      // 건물 정보가 있는 스케줄은 해당 건물 학생만 표출
      if (scheduleBuilding != null) {
        final uid = (data['userId'] ?? '') as String;
        // dormBuilding이 빈 문자열이면 null로 취급해 users에서 조회한 값으로 대체
        final rawDorm = data['dormBuilding'] as String?;
        final studentDorm = (rawDorm != null && rawDorm.isNotEmpty)
            ? rawDorm
            : _userDormBuildings[uid];
        if (studentDorm == null || studentDorm != scheduleBuilding) {
          return false;
        }
      }
      return true;
    }).toList();

    // 신청시간(createdAt) 오름차순 정렬
    filtered.sort((a, b) {
      final aTs = ((a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      final bTs = ((b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
      return aTs.compareTo(bTs);
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 왼쪽: 스케줄 목록
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              color: FluentTheme.of(context).micaBackgroundColor,
              border: Border(
                right: BorderSide(
                  color: FluentTheme.of(
                    context,
                  ).resources.dividerStrokeColorDefault,
                ),
              ),
            ),
            child: Column(
              children: [
                // 헤더
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: FluentTheme.of(context).cardColor,
                    border: Border(
                      bottom: BorderSide(
                        color: FluentTheme.of(
                          context,
                        ).resources.dividerStrokeColorDefault,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        '단위실 청소검사 스케줄',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _showAddScheduleDialog,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(FluentIcons.add, size: 14),
                            SizedBox(width: 6),
                            Text('추가'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(FluentIcons.refresh, size: 14),
                        onPressed: () {
                          _loadSchedules();
                          _loadRequests();
                        },
                      ),
                    ],
                  ),
                ),
                // 서브필터
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: FluentTheme.of(
                          context,
                        ).resources.dividerStrokeColorDefault,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 점검 구역 드롭다운
                      ComboBox<String>(
                        value: _floorFilter ?? '전체',
                        isExpanded: true,
                        items: [
                          const ComboBoxItem(value: '전체', child: Text('전체 구역')),
                          for (final floor in kFloorOptions)
                            ComboBoxItem(value: floor, child: Text(floor)),
                        ],
                        onChanged: (v) => setState(() {
                          _floorFilter = (v == '전체') ? null : v;
                          _selectedSchedule = null;
                        }),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildScheduleList()),
              ],
            ),
          ),
        ),
        // 오른쪽: 신청 목록
        Expanded(flex: 3, child: _buildRequestPanel()),
      ],
    );
  }

  // ──────────── 스케줄 목록 ────────────
  Widget _buildScheduleList() {
    if (_isLoadingSchedules) return const Center(child: ProgressRing());

    if (_schedules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FluentIcons.calendar, size: 64, color: Colors.grey[60]),
            const SizedBox(height: 16),
            const Text('등록된 스케줄이 없습니다', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            const Text('스케줄 추가 버튼을 눌러 새 스케줄을 등록하세요'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _schedules.length,
      itemBuilder: (context, index) {
        final doc = _schedules[index];
        final data = doc.data() as Map<String, dynamic>;
        final dateVal = data['date'];
        if (dateVal == null || dateVal is! Timestamp)
          return const SizedBox.shrink();

        final date = dateVal.toDate();
        final startTime = (data['startTime'] ?? '') as String;
        final endTime = (data['endTime'] ?? '') as String;
        final floor = (data['floor'] ?? '') as String;
        final maxCapacity = (data['maxCapacity'] is num)
            ? (data['maxCapacity'] as num).toInt()
            : 1;
        final currentCount = (data['currentCount'] is num)
            ? (data['currentCount'] as num).toInt()
            : 0;
        final status = (data['status'] ?? 'open') as String;
        final createdAtVal = data['createdAt'];
        final createdAt = (createdAtVal is Timestamp)
            ? createdAtVal.toDate()
            : null;
        final isSelected = _selectedSchedule?.id == doc.id;
        final applyStartVal = data['applicationStart'];
        final applyStart = (applyStartVal is Timestamp)
            ? applyStartVal.toDate()
            : null;
        final deadlineVal = data['applicationDeadline'];
        final deadline = (deadlineVal is Timestamp)
            ? deadlineVal.toDate()
            : null;
        final isDeadlinePassed =
            deadline != null && deadline.isBefore(DateTime.now());
        final isNotStartedYet =
            applyStart != null && applyStart.isAfter(DateTime.now());

        final scheduleRequests = _requests.where((req) {
          final reqData = req.data() as Map<String, dynamic>;
          return reqData['scheduleId'] == doc.id;
        }).toList();
        final completedCount = scheduleRequests.where((r) {
          final d = r.data() as Map<String, dynamic>;
          return (d['status'] ?? '') == 'completed';
        }).length;
        final incompleteCount = scheduleRequests.length - completedCount;

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
            case 'closed':
              statusColor = Colors.grey;
              statusText = '마감';
              break;
            case 'full':
              statusColor = Colors.red;
              statusText = '정원초과';
              break;
            default:
              statusColor = Colors.grey;
              statusText = '알 수 없음';
          }
        }

        final requestCount = scheduleRequests.length;

        final isMoveOut = (data['inspectionType'] as String?) == 'move_out';
        final typeColor = isMoveOut ? Colors.orange : Colors.teal;
        final typeLabel = isMoveOut ? '퇴사검사' : '월검사';

        final bldColor = buildingColor(floor);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border(left: BorderSide(color: bldColor, width: 4)),
          ),
          child: Card(
            backgroundColor: isSelected
                ? FluentTheme.of(context).accentColor.withOpacity(0.1)
                : null,
            margin: EdgeInsets.zero,
            child: ListTile(
              onPressed: () => setState(() => _selectedSchedule = doc),
              leading: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: typeColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('MM/dd').format(date),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: typeColor,
                      ),
                    ),
                    Text(
                      DateFormat('E', 'ko').format(date),
                      style: TextStyle(fontSize: 10, color: typeColor),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        typeLabel,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: typeColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              title: Text(
                floor.isNotEmpty ? floor : '점검 스케줄',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    '$startTime ~ $endTime',
                    style: TextStyle(fontSize: 12, color: Colors.grey[100]),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '호실: $currentCount/$maxCapacity',
                        style: TextStyle(fontSize: 11, color: Colors.grey[90]),
                      ),
                      const SizedBox(width: 8),
                      if (requestCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '완료 $completedCount / 미완료 $incompleteCount',
                            style: TextStyle(fontSize: 10, color: Colors.blue),
                          ),
                        ),
                    ],
                  ),
                  if (applyStart != null || deadline != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '신청기간: '
                      '${applyStart != null ? DateFormat('MM/dd HH:mm').format(applyStart) : '-'}'
                      ' ~ '
                      '${deadline != null ? DateFormat('MM/dd HH:mm').format(deadline) : '-'}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDeadlinePassed ? Colors.red : Colors.grey[80],
                      ),
                    ),
                  ],
                  if (createdAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '등록: ${DateFormat('yyyy.MM.dd HH:mm').format(createdAt)}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[80]),
                    ),
                  ],
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                  if (requestCount > 0 && incompleteCount > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '검사필요',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.purple,
                        ),
                      ),
                    ),
                  ],
                  if (requestCount > 0 && incompleteCount == 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '검사완료',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(FluentIcons.delete, size: 14, color: Colors.red),
                    onPressed: () => _deleteSchedule(doc.id),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ──────────── 건물별 색상 ────────────
  // ──────────── 신청 목록 패널 ────────────
  Widget _buildRequestPanel() {
    if (_selectedSchedule == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FluentIcons.clipboard_list, size: 64, color: Colors.grey[60]),
            const SizedBox(height: 16),
            const Text('스케줄을 선택해주세요', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              '왼쪽에서 스케줄을 선택하면\n해당 스케줄의 신청 목록이 표시됩니다',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[100]),
            ),
          ],
        ),
      );
    }

    final scheduleData = _selectedSchedule!.data() as Map<String, dynamic>;
    final dateVal = scheduleData['date'];
    final date = (dateVal is Timestamp) ? dateVal.toDate() : DateTime.now();
    final startTime = (scheduleData['startTime'] ?? '') as String;
    final endTime = (scheduleData['endTime'] ?? '') as String;
    final floor = (scheduleData['floor'] ?? '') as String;
    final requests = _filteredRequests;
    final panelIsMoveOut =
        (scheduleData['inspectionType'] as String?) == 'move_out';
    final panelTypeColor = panelIsMoveOut ? Colors.orange : Colors.teal;
    final panelTypeLabel = panelIsMoveOut ? '퇴사검사' : '월검사';

    return Container(
      color: FluentTheme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          // 스케줄 정보 헤더
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FluentTheme.of(context).cardColor,
              border: Border(
                bottom: BorderSide(
                  color: FluentTheme.of(
                    context,
                  ).resources.dividerStrokeColorDefault,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: panelTypeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    FluentIcons.calendar,
                    color: panelTypeColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            floor.isNotEmpty ? floor : '점검 스케줄',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: panelTypeColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: panelTypeColor.withOpacity(0.4),
                              ),
                            ),
                            child: Text(
                              panelTypeLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: panelTypeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${DateFormat('yyyy.MM.dd (E)', 'ko').format(date)} | $startTime ~ $endTime',
                        style: TextStyle(fontSize: 13, color: Colors.grey[100]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '신청 ${requests.length}건',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 신청 목록
          Expanded(
            child: _isLoadingRequests
                ? const Center(child: ProgressRing())
                : requests.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FluentIcons.clipboard_list,
                          size: 48,
                          color: Colors.grey[60],
                        ),
                        const SizedBox(height: 12),
                        const Text('신청 내역이 없습니다'),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final doc = requests[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final uid = (data['userId'] ?? '') as String;
                      final dormBuilding = _userDormBuildings[uid];
                      final originalRequestId = data['recheckOfRequestId'] as String?;
                      Map<String, dynamic>? originalRequestData;
                      if (originalRequestId != null && originalRequestId.isNotEmpty) {
                        final originalDoc = _requests.where((d) => d.id == originalRequestId).firstOrNull;
                        if (originalDoc != null) {
                          originalRequestData = originalDoc.data() as Map<String, dynamic>;
                        }
                      }
                      return _buildRequestCard(
                        doc.id,
                        data,
                        dormBuilding: dormBuilding,
                        isMoveOut: _typeFilter == 'move_out',
                        originalRequestData: originalRequestData,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ──────────── 신청 카드 ────────────
  Widget _buildRequestCard(
    String requestId,
    Map<String, dynamic> data, {
    String? dormBuilding,
    bool isMoveOut = false,
    Map<String, dynamic>? originalRequestData,
  }) {
    final userName = (data['userName'] ?? '') as String;
    final roomNumber = (data['roomNumber'] ?? '') as String;
    final status = (data['status'] ?? 'pending') as String;
    final memo = data['memo'] as String?;
    final scoreAvg = (data['scoreAvg'] as num?)?.toDouble();
    final needsRecheck = data['needsRecheck'] == true;
    final isRecheckSubmission = data['isRecheck'] == true;
    final comment = data['comment'] as String?;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final evaluatedByEmail = data['evaluatedByEmail'] as String?;
    final commonAreas = () {
      if (!isMoveOut) return null;
      final raw = data['commonAreas'];
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      } else if (raw is String && raw.isNotEmpty) {
        return [raw];
      }
      return null;
    }();

    Color statusColor;
    String statusText;
    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        statusText = '점검 대기중';
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
        statusText = '알 수 없음';
    }

    final scoreText = scoreAvg != null ? '${scoreAvg.toStringAsFixed(1)}점' : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(FluentIcons.contact, size: 16, color: Colors.grey[100]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    () {
                      final cap = roomCapacityLabel(roomNumber);
                      final capStr = cap.isNotEmpty ? ' · $cap' : '';
                      final dormStr = dormBuilding != null
                          ? ' · $dormBuilding'
                          : '';
                      return '$userName ($roomNumber호$capStr)$dormStr';
                    }(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isRecheckSubmission) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.purple.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      '재검사 신청',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(FluentIcons.delete, size: 16, color: Colors.red),
                  onPressed: () => _deleteRequest(requestId),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (createdAt != null)
              Row(
                children: [
                  Icon(FluentIcons.calendar, size: 14, color: Colors.grey[80]),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('yyyy.MM.dd HH:mm').format(createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[120]),
                  ),
                ],
              ),
            if (commonAreas != null && commonAreas.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    FluentIcons.home,
                    size: 13,
                    color: const Color(0xFF00BCD4),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '공동구역: ${commonAreas.join(' · ')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF00BCD4),
                    ),
                  ),
                ],
              ),
            ],
            if (memo != null && memo.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '메모: $memo',
                style: TextStyle(fontSize: 12, color: Colors.grey[120]),
              ),
            ],
            if (status == 'completed' && scoreAvg != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    FluentIcons.check_mark,
                    size: 14,
                    color: scoreColor(scoreAvg),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '점수: $scoreText / 4점',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scoreColor(scoreAvg),
                    ),
                  ),
                  if (needsRecheck) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        '재검사 필요',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  if (comment != null && comment.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '코멘트: $comment',
                        style: TextStyle(fontSize: 12, color: Colors.grey[120]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              if (evaluatedByEmail != null) ...[
                const SizedBox(height: 4),
                Text(
                  '검사자: $evaluatedByEmail',
                  style: TextStyle(fontSize: 11, color: Colors.grey[100]),
                ),
              ],
            ],
            if (status == 'pending' || status == 'in_progress') ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (status == 'pending') ...[
                    Button(
                      onPressed: () => _rejectRequest(requestId),
                      child: const Text('반려'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  FilledButton(
                    onPressed: () => _showEvaluateDialog(requestId, data),
                    child: Text(status == 'pending' ? '점검 평가' : '평가하기'),
                  ),
                ],
              ),
            ],
            if (isRecheckSubmission && originalRequestData != null) ...[
              const SizedBox(height: 10),
              buildEvaluationHistorySection([originalRequestData]),
            ],
          ],
        ),
      ),
    );
  }

  // ──────────── 스케줄 추가 ────────────
  void _showAddScheduleDialog() {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    DateTime applyStartDate = DateTime.now();
    final applyStartTimeController = TextEditingController(text: '00:00');
    DateTime deadlineDate = DateTime.now();
    final deadlineTimeController = TextEditingController(text: '23:00');
    final startTimeController = TextEditingController(text: '10:00');
    final endTimeController = TextEditingController(text: '12:00');
    final capacityController = TextEditingController(text: '8');
    String selectedFloor = kFloorOptions.first;
    String selectedInspectionType = _typeFilter ?? 'monthly';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => ContentDialog(
          title: const Text('단위실 청소검사 스케줄 추가'),
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 640),
          content: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('검사 유형', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ComboBox<String>(
                  value: selectedInspectionType,
                  items: const [
                    ComboBoxItem(value: 'monthly', child: Text('월 검사')),
                    ComboBoxItem(value: 'move_out', child: Text('퇴사 검사')),
                  ],
                  onChanged: widget.fixedType != null
                      ? null
                      : (v) { if (v != null) setDialogState(() => selectedInspectionType = v); },
                  isExpanded: true,
                ),
                const SizedBox(height: 24),
                const Text('점검 구역', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ComboBox<String>(
                  value: selectedFloor,
                  items: kFloorOptions
                      .map((floor) => ComboBoxItem<String>(value: floor, child: Text(floor)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => selectedFloor = value);
                  },
                  isExpanded: true,
                ),
                const SizedBox(height: 24),
                const Text('점검 날짜', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DatePicker(
                  selected: selectedDate,
                  onChanged: (date) => setDialogState(() => selectedDate = date),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('시작 시간', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          TextBox(controller: startTimeController, placeholder: 'HH:MM'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('종료 시간', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          TextBox(controller: endTimeController, placeholder: 'HH:MM'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('최대 정원', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: TextBox(controller: capacityController, placeholder: '정원'),
                    ),
                    const SizedBox(width: 8),
                    const Text('명'),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('신청 시작', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DatePicker(
                      selected: applyStartDate,
                      onChanged: (date) => setDialogState(() => applyStartDate = date),
                    ),
                    SizedBox(
                      width: 90,
                      child: TextBox(controller: applyStartTimeController, placeholder: 'HH:MM'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('신청기한(마감)', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DatePicker(
                      selected: deadlineDate,
                      onChanged: (date) => setDialogState(() => deadlineDate = date),
                    ),
                    SizedBox(
                      width: 90,
                      child: TextBox(controller: deadlineTimeController, placeholder: 'HH:MM'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            Button(child: const Text('취소'), onPressed: () => Navigator.pop(dialogContext)),
            FilledButton(
              child: const Text('추가'),
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _addSchedule(
                  selectedDate,
                  startTimeController.text.trim(),
                  endTimeController.text.trim(),
                  int.tryParse(capacityController.text.trim()) ?? 5,
                  selectedFloor,
                  applyStartDate,
                  applyStartTimeController.text.trim(),
                  deadlineDate,
                  deadlineTimeController.text.trim(),
                  selectedInspectionType,
                );
              },
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
  ) async {
    try {
      final asParts = applyStartTime.split(':');
      final asHour = int.tryParse(asParts.isNotEmpty ? asParts[0] : '0') ?? 0;
      final asMinute = int.tryParse(asParts.length > 1 ? asParts[1] : '0') ?? 0;
      final applyStart = DateTime(applyStartDate.year, applyStartDate.month, applyStartDate.day, asHour, asMinute);

      final dlParts = deadlineTime.split(':');
      final dlHour = int.tryParse(dlParts.isNotEmpty ? dlParts[0] : '23') ?? 23;
      final dlMinute = int.tryParse(dlParts.length > 1 ? dlParts[1] : '59') ?? 59;
      final deadline = DateTime(deadlineDate.year, deadlineDate.month, deadlineDate.day, dlHour, dlMinute);

      final isMoveOut = inspectionType == 'move_out';
      final dayCount = isMoveOut ? 1 : 4;

      final batch = _firestore.batch();
      for (int i = 0; i < dayCount; i++) {
        final scheduleDate = date.add(Duration(days: i));
        final ref = _firestore.collection('cleaning_schedules').doc();
        batch.set(ref, {
          'date': Timestamp.fromDate(DateTime(scheduleDate.year, scheduleDate.month, scheduleDate.day)),
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
        });
      }
      await batch.commit();

      if (!mounted) return;
      _loadSchedules();
      await displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: Text(isMoveOut ? '퇴사검사 일정이 추가되었습니다' : '4일 연속 일정이 추가되었습니다'),
            severity: InfoBarSeverity.success,
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      await displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(title: Text('오류: $e'), severity: InfoBarSeverity.error);
        },
      );
    }
  }

  Future<void> _deleteSchedule(String scheduleId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: const Text('스케줄 삭제'),
        content: const Text('이 스케줄을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          Button(
            child: const Text('취소'),
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.red),
            ),
            child: const Text('삭제'),
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // 삭제 전: 스케줄에서 dormBuilding·inspectionType을 request에 보존
      // (스케줄 삭제 후에도 _loadData에서 탭 필터·건물 파악 가능하도록)
      final scheduleDoc = await _firestore.collection('cleaning_schedules').doc(scheduleId).get();
      final scheduleData = scheduleDoc.data() ?? {};
      final inspType = scheduleData['inspectionType'] as String? ?? widget.fixedType;
      final floorStr = scheduleData['floor']?.toString() ?? '';
      final String? scheduleBuilding;
      if (floorStr.startsWith('샬롬하우스(여름방학)')) {
        scheduleBuilding = '샬롬하우스(여름방학)';
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
          if (data['inspectionType'] == null) update['inspectionType'] = inspType;
          if ((data['dormBuilding'] == null || (data['dormBuilding'] as String? ?? '').isEmpty) && scheduleBuilding != null) {
            update['dormBuilding'] = scheduleBuilding;
          }
          if (update.isNotEmpty) batch.update(doc.reference, update);
        }
        await batch.commit();
      }
      await _firestore
          .collection('cleaning_schedules')
          .doc(scheduleId)
          .delete();
      if (!mounted) return;
      setState(() {
        if (_selectedSchedule?.id == scheduleId) _selectedSchedule = null;
      });
      _loadSchedules();
      await displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: const Text('스케줄이 삭제되었습니다'),
            severity: InfoBarSeverity.success,
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      await displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: Text('삭제 오류: $e'),
            severity: InfoBarSeverity.error,
          );
        },
      );
    }
  }


  static Map<String, int> _makeScores(
    Map<String, List<String>> structure, {
    bool isMoveOut = false,
  }) => {
    for (final e in structure.entries)
      for (final item in e.value) '${e.key}_$item': isMoveOut ? 1 : 4,
  };

  static double _calcAvg(
    Map<String, Map<String, int>> studentScores,
    Map<String, int> communalScores,
  ) {
    final all = [
      ...studentScores.values.expand((m) => m.values),
      ...communalScores.values,
    ];
    if (all.isEmpty) return 4.0;
    return all.reduce((a, b) => a + b) / all.length;
  }

  void _showEvaluateDialog(String requestId, Map<String, dynamic> data) async {
    final userName = (data['userName'] ?? '') as String;
    final roomNumber = (data['roomNumber'] ?? '') as String;
    // 스케줄에서 floor + inspectionType 조회
    String scheduleFloor = '';
    String inspectionType = 'monthly';
    final scheduleId = (data['scheduleId'] ?? '') as String;
    if (scheduleId.isNotEmpty) {
      try {
        final scheduleDoc = await _firestore
            .collection('cleaning_schedules')
            .doc(scheduleId)
            .get();
        if (scheduleDoc.exists) {
          final sd = scheduleDoc.data()!;
          scheduleFloor = (sd['floor'] ?? '') as String;
          inspectionType = (sd['inspectionType'] ?? 'monthly') as String;
        }
      } catch (_) {}
    }
    final isMoveOut = inspectionType == 'move_out';
    var structures = getCheckStructures(scheduleFloor, inspectionType);

    // 퇴사검사: 학생이 선택한 공동구역만 필터링
    if (isMoveOut) {
      final rawCommonAreas = data['commonAreas'];
      List<String> parsedCommonAreas = [];
      if (rawCommonAreas is List) {
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
      if (parsedCommonAreas.isNotEmpty) {
        final selected = parsedCommonAreas.toSet();
        // 학생 앱 키 → 점검 구조 키 매핑
        const areaKeyMap = {'바닥': '공동 바닥'};
        final mappedSelected = selected.map((a) => areaKeyMap[a] ?? a).toSet();
        final filteredCommunal = Map.fromEntries(
          structures.communal.entries.where(
            (e) => mappedSelected.contains(e.key),
          ),
        );
        structures = (
          personal: structures.personal,
          communal: filteredCommunal,
        );
      }
    }

    // 퇴사검사: 신청한 학생 1명만 평가
    final List<String> roomStudents = isMoveOut
        ? (userName.isNotEmpty ? [userName] : [])
        : [];

    if (!mounted) return;

    final Map<String, Map<String, int>> studentScores = {
      for (final name in roomStudents)
        name: _makeScores(structures.personal, isMoveOut: isMoveOut),
    };
    final Map<String, int> communalScores = _makeScores(
      structures.communal,
      isMoveOut: isMoveOut,
    );

    int selectedTabIndex = 0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final avg = _calcAvg(studentScores, communalScores);
          final avgColor = avg >= 3.5
              ? Colors.green
              : avg >= 2.5
              ? Colors.blue
              : Colors.red;

          final tabs = isMoveOut ? [...roomStudents, '공동 구역'] : ['점검'];
          final isStudentTab =
              isMoveOut && selectedTabIndex < roomStudents.length;

          // 탭 내 불량 항목 수 (isMoveOut: X(0) 개수, monthly: 2점 이하 개수)
          int tabLowCount(int idx) {
            if (isMoveOut && idx < roomStudents.length) {
              return studentScores[roomStudents[idx]]!.values
                  .where((v) => v == 0)
                  .length;
            }
            if (isMoveOut)
              return communalScores.values.where((v) => v == 0).length;
            return communalScores.values.where((v) => v <= 2).length;
          }

          return ContentDialog(
            constraints: const BoxConstraints(maxWidth: 550),
            title: Row(
              children: [
                Icon(FluentIcons.clipboard_list, color: Colors.teal, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    () {
                      final cap = roomCapacityLabel(roomNumber);
                      final capStr = cap.isNotEmpty ? ' · $cap' : '';
                      return isMoveOut
                          ? '청소 점검 — $roomNumber호$capStr (${roomStudents.length}명)'
                          : '청소 점검 — $roomNumber호$capStr';
                    }(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 700,
              height: 560,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 탭 바 (탭 2개 이상일 때만) ──
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
                            onTap: () =>
                                setDialogState(() => selectedTabIndex = idx),
                            child: Container(
                              margin: const EdgeInsets.only(
                                right: 6,
                                bottom: 10,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
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
                                  Icon(
                                    idx < roomStudents.length
                                        ? FluentIcons.contact
                                        : FluentIcons.home,
                                    size: 12,
                                    color: isSelected
                                        ? Colors.teal
                                        : Colors.grey[100],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    tabLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: isSelected ? Colors.teal : null,
                                    ),
                                  ),
                                  if (lowCount > 0) ...[
                                    const SizedBox(width: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$lowCount',
                                        style: TextStyle(
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
                  // ── 점수 입력 ──
                  Expanded(
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
                              structures.communal,
                              communalScores,
                              setDialogState,
                              Colors.purple,
                              isMoveOut: isMoveOut,
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ── 요약 ──
                  Builder(
                    builder: (_) {
                      if (isMoveOut) {
                        final allScores = [
                          ...studentScores.values.expand((m) => m.values),
                          ...communalScores.values,
                        ];
                        final failCount = allScores.where((v) => v == 0).length;
                        final isPassed = failCount == 0;
                        final summaryColor = isPassed
                            ? Colors.green
                            : Colors.red;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: summaryColor.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: summaryColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Text(
                                '결과',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: summaryColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isPassed
                                      ? 'Pass (O)'
                                      : 'Fail (X) — $failCount개 불합격',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: summaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: avgColor.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: avgColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              '평균 점수',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
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
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  // ── 점검자 코멘트 ──
                  TextBox(
                    controller: commentController,
                    placeholder: '점검자 코멘트 (선택)',
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              Button(
                child: const Text('취소'),
                onPressed: () => Navigator.pop(dialogContext),
              ),
              FilledButton(
                child: const Text('평가 완료'),
                onPressed: () {
                  final comment = commentController.text.trim();
                  Navigator.pop(dialogContext);
                  _submitEvaluation(
                    requestId,
                    avg,
                    communalScores,
                    studentScores,
                    isMoveOut: isMoveOut,
                    inspectionComment: comment.isEmpty ? null : comment,
                    floor: scheduleFloor,
                  );
                },
              ),
            ],
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color,
            ),
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
                    fontWeight: FontWeight.bold,
                    color: color,
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
                        SizedBox(
                          width: 120,
                          child: Text(
                            item,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[120],
                            ),
                          ),
                        ),
                        if (isMoveOut) ...[
                          // O 버튼 (pass = 1)
                          GestureDetector(
                            onTap: () => setDialogState(() => scores[key] = 1),
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              width: 52,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: score == 1
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : Colors.grey.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: score == 1
                                      ? Colors.green
                                      : Colors.grey.withValues(alpha: 0.3),
                                  width: score == 1 ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                'O',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: score == 1
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: score == 1
                                      ? Colors.green
                                      : Colors.grey[100],
                                ),
                              ),
                            ),
                          ),
                          // X 버튼 (fail = 0)
                          GestureDetector(
                            onTap: () => setDialogState(() => scores[key] = 0),
                            child: Container(
                              width: 52,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: score == 0
                                    ? Colors.red.withValues(alpha: 0.15)
                                    : Colors.grey.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: score == 0
                                      ? Colors.red
                                      : Colors.grey.withValues(alpha: 0.3),
                                  width: score == 0 ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                'X',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: score == 0
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: score == 0
                                      ? Colors.red
                                      : Colors.grey[100],
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          ...List.generate(4, (i) {
                            final val = i + 1;
                            final isSelected = score == val;
                            final Color btnColor = val == 4
                                ? Colors.green
                                : val == 3
                                ? Colors.blue
                                : val == 2
                                ? Colors.orange
                                : Colors.red;
                            return GestureDetector(
                              onTap: () =>
                                  setDialogState(() => scores[key] = val),
                              child: Container(
                                margin: const EdgeInsets.only(right: 6),
                                width: 46,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
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
                                        : Colors.grey[100],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
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
    Map<String, Map<String, int>> studentScores, {
    bool isMoveOut = false,
    String? inspectionComment,
    String? floor,
  }) async {
    try {
      final bool needsRecheck;
      if (isMoveOut) {
        needsRecheck =
            studentScores.values.expand((m) => m.values).any((v) => v == 0) ||
            communalScores.values.any((v) => v == 0);
      } else {
        needsRecheck =
            studentScores.values.expand((m) => m.values).any((v) => v <= 2) ||
            communalScores.values.any((v) => v <= 2);
      }
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
        if (inspectionComment != null) 'inspectionComment': inspectionComment,
        // 스케줄이 삭제되어도 점검 항목 구조를 복원할 수 있도록 평가 시점의 구역 정보를 함께 저장
        if (floor != null && floor.isNotEmpty) 'floor': floor,
        'evaluatedAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'scoresCommunal': communalScores,
        'scoresPersonal': {
          for (final e in studentScores.entries) e.key: e.value,
        },
        'evaluatedById': currentUser?.uid,
        'evaluatedByEmail': currentUser?.email,
        'evaluatedByName': evaluatedByName ?? currentUser?.email,
      };
      await _firestore
          .collection('cleaning_requests')
          .doc(requestId)
          .update(updateData);

      if (!mounted) return;
      _loadRequests();
      await displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: const Text('평가가 완료되었습니다'),
            severity: InfoBarSeverity.success,
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      await displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: Text('평가 오류: $e'),
            severity: InfoBarSeverity.error,
          );
        },
      );
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: const Text('신청 반려'),
        content: const Text('이 신청을 반려하시겠습니까?'),
        actions: [
          Button(
            child: const Text('취소'),
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.red),
            ),
            child: const Text('반려'),
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _firestore.collection('cleaning_requests').doc(requestId).update({
        'status': 'rejected',
        'updatedAt': Timestamp.now(),
      });

      if (!mounted) return;
      _loadRequests();
      await displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: const Text('신청이 반려되었습니다'),
            severity: InfoBarSeverity.warning,
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      await displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: Text('오류: $e'),
            severity: InfoBarSeverity.error,
          );
        },
      );
    }
  }

  Future<void> _deleteRequest(String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: const Text('신청 삭제'),
        content: const Text('이 신청을 삭제하시겠습니까?\n삭제한 신청은 복구할 수 없습니다.'),
        actions: [
          Button(
            child: const Text('취소'),
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.red),
            ),
            child: const Text('삭제'),
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _firestore.collection('cleaning_requests').doc(requestId).delete();

      if (!mounted) return;
      _loadRequests();
      await displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: const Text('신청이 삭제되었습니다'),
            severity: InfoBarSeverity.success,
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      await displayInfoBar(
        context,
        builder: (context, close) {
          return InfoBar(
            title: Text('삭제 오류: $e'),
            severity: InfoBarSeverity.error,
          );
        },
      );
    }
  }
}
