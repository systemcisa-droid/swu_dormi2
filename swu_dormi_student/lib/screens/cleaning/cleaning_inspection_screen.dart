import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/cleaning_inspection_strings.dart';

class CleaningInspectionScreen extends StatefulWidget {
  final String inspectionType; // 'monthly' or 'move_out'

  const CleaningInspectionScreen({
    super.key,
    required this.inspectionType,
  });

  @override
  State<CleaningInspectionScreen> createState() =>
      _CleaningInspectionScreenState();
}

class _CleaningInspectionScreenState extends State<CleaningInspectionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _schedules = [];
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  String? _error;
  int _viewMode = 0; // 0: 스케줄, 1: 내역, 2: 안내

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// 사용자의 dormBuilding + 동/층 정보를 기반으로 스케줄 floor 필드 매칭 문자열 생성
  /// 예: dormBuilding="샬롬하우스", building="A동", roomNumber="201" → "샬롬하우스 A동 2층"
  /// 구형식 호환: dormBuilding 없으면 "A동 2층"
  String? _getUserFloorLabel(dynamic user) {
    if (user == null) return null;
    final dormBuilding = user.dormBuilding as String?;
    final building = user.building as String?;
    final roomNumber = user.roomNumber as String?;
    final seatNumber = user.seatNumber as String?;

    if (dormBuilding == null || dormBuilding.isEmpty ||
        building == null || building.isEmpty || building == '미배정' ||
        roomNumber == null || roomNumber.isEmpty || roomNumber == '000' ||
        seatNumber == null || seatNumber.isEmpty) {
      return null;
    }

    final String floorNum;
    if (roomNumber.length == 3) {
      floorNum = roomNumber[0];
    } else if (roomNumber.length >= 4) {
      floorNum = roomNumber.substring(0, 2);
    } else {
      return null;
    }

    final floorStr = '$floorNum층';

    if (dormBuilding == '바롬인성교육관') {
      return '$dormBuilding $floorStr';
    }
    return '$dormBuilding $building $floorStr';
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      final userFloorLabel = _getUserFloorLabel(user);

      // 사용자 층 기준으로 Firestore 필터링 (정확히 일치)
      Query<Map<String, dynamic>> query = _firestore.collection('cleaning_schedules');
      if (userFloorLabel != null) {
        query = query.where('floor', isEqualTo: userFloorLabel);
      } else {
        // dormBuilding 미설정 시 빈 결과 반환 (다른 건물 스케줄 노출 방지)
        if (!mounted) return;
        setState(() {
          _schedules = [];
          _requests = [];
          _isLoading = false;
          _error = CleaningInspectionStrings(
                  Provider.of<LocaleProvider>(context, listen: false).isEnglish)
              .residenceInfoMissing;
        });
        return;
      }
      final scheduleSnap = await query.get();

      final scheduleList = <Map<String, dynamic>>[];
      for (final doc in scheduleSnap.docs) {
        final m = Map<String, dynamic>.from(doc.data());
        m['_id'] = doc.id;
        scheduleList.add(m);
      }
      scheduleList.sort((a, b) {
        final da = (a['date'] as Timestamp?)?.toDate() ?? DateTime(2000);
        final db = (b['date'] as Timestamp?)?.toDate() ?? DateTime(2000);
        return da.compareTo(db);
      });

      final requestList = <Map<String, dynamic>>[];
      if (user != null) {
        final reqSnap = await _firestore
            .collection('cleaning_requests')
            .where('userId', isEqualTo: user.uid)
            .get();
        for (final doc in reqSnap.docs) {
          final m = Map<String, dynamic>.from(doc.data());
          m['_id'] = doc.id;
          requestList.add(m);
        }
        requestList.sort((a, b) {
          final ta = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
          final tb = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
          return tb.compareTo(ta);
        });
      }

      if (!mounted) return;
      setState(() {
        _schedules = scheduleList;
        _requests = requestList;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final s = CleaningInspectionStrings(
          Provider.of<LocaleProvider>(context, listen: false).isEnglish);
      setState(() {
        _isLoading = false;
        _error = s.loadError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final s = CleaningInspectionStrings(Provider.of<LocaleProvider>(context).isEnglish);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadData, child: Text(s.retry)),
                    ],
                  ),
                )
              : _buildContent(user, s),
    );
  }

  Widget _buildContent(dynamic user, CleaningInspectionStrings strs) {
    final items = <Widget>[];

    items.add(
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _viewMode == 2 ? Colors.cyan : Colors.grey.shade200,
                  foregroundColor: _viewMode == 2 ? Colors.white : Colors.black,
                ),
                onPressed: () => setState(() => _viewMode = 2),
                child: Text(strs.tabGuide),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _viewMode == 0 ? Colors.cyan : Colors.grey.shade200,
                  foregroundColor: _viewMode == 0 ? Colors.white : Colors.black,
                ),
                onPressed: () => setState(() => _viewMode = 0),
                child: FittedBox(fit: BoxFit.scaleDown, child: Text(strs.tabSchedule, style: const TextStyle(fontWeight: FontWeight.bold))),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _viewMode == 1 ? Colors.cyan : Colors.grey.shade200,
                  foregroundColor: _viewMode == 1 ? Colors.white : Colors.black,
                ),
                onPressed: () => setState(() => _viewMode = 1),
                child: Text(strs.tabHistory),
              ),
            ),
          ],
        ),
      ),
    );

    // 삭제된 스케줄에 연결된 신청을 무시하기 위한 유효 ID 집합 (두 탭에서 공유)
    final validScheduleIds = {for (final sc in _schedules) sc['_id'] as String};

    if (_viewMode == 0) {
      final userFloorLabel = _getUserFloorLabel(user);
      if (userFloorLabel != null) {
        items.add(
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.cyan.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.cyan.shade800),
                const SizedBox(width: 6),
                Text(
                  strs.scheduleCount(userFloorLabel, _schedules.length),
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyan.shade800),
                ),
              ],
            ),
          ),
        );
      } else if (user != null) {
        items.add(
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.cyan.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              strs.roomScheduleCount(user.roomNumber, _schedules.length),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.6, color: Colors.cyan.shade800),
            ),
          ),
        );
      }

      if (_schedules.isEmpty) {
        items.add(
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(child: Text(strs.noSchedule, style: const TextStyle(fontSize: 16, color: Colors.grey))),
          ),
        );
      } else {
        final hasPending = _requests.any((r) =>
            (r['status'] ?? '') == 'pending' &&
            validScheduleIds.contains(r['scheduleId']));
        // 내가 신청한 scheduleId 목록
        final myScheduleIds = {
          for (final r in _requests)
            if (r['scheduleId'] is String) r['scheduleId'] as String,
        };
        for (int i = 0; i < _schedules.length; i++) {
          final sid = _schedules[i]['_id'] as String;
          final isMySchedule = myScheduleIds.contains(sid);
          items.add(_buildScheduleItem(_schedules[i], user, strs, hasPending: hasPending, isMySchedule: isMySchedule));
        }
      }
    } else if (_viewMode == 1) {
      if (_schedules.isEmpty) {
        items.add(
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(child: Text(strs.noSchedule, style: const TextStyle(fontSize: 16, color: Colors.grey))),
          ),
        );
      } else {
        // 1차: scheduleId로 매칭 (같은 스케줄에 재검사로 여러 신청이 있으면 가장 최근 것 사용)
        final requestByScheduleId = <String, Map<String, dynamic>>{};
        // 2차: availableTimeSlotLabel로 매칭 (scheduleId 없는 구형 데이터 대비)
        final requestByLabel = <String, Map<String, dynamic>>{};
        // _requests는 createdAt 내림차순 정렬이므로, 먼저 채워진 값(최신)을 유지하기 위해 없을 때만 기록
        for (final r in _requests) {
          final sid = r['scheduleId'];
          if (sid is String && sid.isNotEmpty) requestByScheduleId.putIfAbsent(sid, () => r);
          final label = r['availableTimeSlotLabel'];
          if (label is String && label.isNotEmpty) requestByLabel.putIfAbsent(label, () => r);
        }
        // 현재 pending 상태인 신청 (변경 기준) - 유효한 스케줄이 존재하는 것만
        final pendingRequest = _requests.where((r) =>
            (r['status'] ?? '') == 'pending' &&
            validScheduleIds.contains(r['scheduleId'])).firstOrNull;
        // 재검사 필요 신청 (재신청 변경 기준)
        final recheckRequest = _requests.where((r) => r['needsRecheck'] == true).firstOrNull;
        // 재검사 기준 일정 날짜 (해당 scheduleId의 date)
        DateTime? recheckDate;
        if (recheckRequest != null) {
          final recheckSid = recheckRequest['scheduleId'];
          final recheckSchedule = _schedules.firstWhere(
            (s) => s['_id'] == recheckSid,
            orElse: () => <String, dynamic>{},
          );
          final dv = recheckSchedule['date'];
          if (dv is Timestamp) recheckDate = dv.toDate();
        }

        for (final schedule in _schedules) {
          final scheduleId = schedule['_id'] as String;
          final dateVal = schedule['date'];
          final date = (dateVal is Timestamp) ? dateVal.toDate() : DateTime.now();
          final startTime = (schedule['startTime'] ?? '') as String;
          final endTime = (schedule['endTime'] ?? '') as String;
          final label = '${DateFormat('MM/dd').format(date)} $startTime~$endTime';
          final request = requestByScheduleId[scheduleId] ?? requestByLabel[label];
          items.add(_buildRequestHistoryItem(schedule, request, pendingRequest, strs, recheckRequest: recheckRequest, recheckDate: recheckDate));
        }
      }
    } else {
      items.add(_buildGuideContent(strs));
    }

    items.add(const SizedBox(height: 20));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items,
      ),
    );
  }

  Widget _buildScheduleItem(Map<String, dynamic> data, dynamic user, CleaningInspectionStrings strs, {bool hasPending = false, bool isMySchedule = false}) {
    final id = data['_id'] as String;
    final dateVal = data['date'];
    final date = (dateVal is Timestamp) ? dateVal.toDate() : DateTime.now();
    final startTime = (data['startTime'] ?? '') as String;
    final endTime = (data['endTime'] ?? '') as String;
    final maxCap = (data['maxCapacity'] is num) ? (data['maxCapacity'] as num).toInt() : 1;
    final curCount = (data['currentCount'] is num) ? (data['currentCount'] as num).toInt() : 0;
    final status = (data['status'] ?? 'open') as String;
    final deadlineVal = data['applicationDeadline'];
    final deadline = (deadlineVal is Timestamp) ? deadlineVal.toDate() : null;
    final applyStartVal = data['applicationStart'];
    final applyStart = (applyStartVal is Timestamp) ? applyStartVal.toDate() : null;
    final now = DateTime.now();
    final isNotStarted = applyStart != null && now.isBefore(applyStart);
    final isDeadlinePassed = deadline != null && now.isAfter(deadline);
    final isOpen = status == 'open' && curCount < maxCap && !hasPending && !isNotStarted && !isDeadlinePassed && !isMySchedule;
    final isMoveOut = (data['inspectionType'] as String?) == 'move_out';
    final typeColor = isMoveOut ? Colors.orange : Colors.cyan;
    final typeLabel = isMoveOut ? strs.moveOutInspectionShort : strs.monthlyInspectionShort;

    final String buttonText;
    if (isMySchedule) {
      buttonText = strs.statusApplied;
    } else if (isNotStarted) {
      buttonText = strs.statusScheduled;
    } else if (isDeadlinePassed) {
      buttonText = strs.statusExpired;
    } else if (curCount >= maxCap) {
      buttonText = strs.statusFull;
    } else if (hasPending) {
      buttonText = strs.statusDuplicateBlocked;
    } else {
      buttonText = strs.statusApply;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: typeColor.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: isOpen ? () => _showApplyDialog(id, data, user) : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: typeColor.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('MM/dd').format(date),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: typeColor.shade800),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        constraints: const BoxConstraints(maxWidth: 46),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: typeColor.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            typeLabel,
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: typeColor.shade800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 점검 시간(좌) + 잔여호실·신청버튼(우)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 왼쪽: 시간 + 기한
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${DateFormat('E', strs.isEnglish ? null : 'ko').format(date)} $startTime~$endTime',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                if (applyStart != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    strs.applyStartLabel(DateFormat('MM/dd HH:mm').format(applyStart)),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                                if (deadline != null) ...[
                                  const SizedBox(height: 2),
                                  Builder(builder: (context) {
                                    final remaining = deadline.difference(DateTime.now());
                                    final isUrgent = remaining.inHours < 6 && !remaining.isNegative && !isNotStarted;
                                    return Text(
                                      isUrgent
                                          ? strs.applyEndUrgent(DateFormat('MM/dd HH:mm').format(deadline), remaining.inHours, remaining.inMinutes % 60)
                                          : strs.applyEndLabel(DateFormat('MM/dd HH:mm').format(deadline)),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isUrgent ? Colors.red : Colors.grey.shade600,
                                        fontWeight: isUrgent ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    );
                                  }),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 오른쪽: 잔여 호실 + 신청 버튼
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                strs.remainingRooms(maxCap - curCount, maxCap),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isOpen ? Colors.green : Colors.red,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isMySchedule
                                      ? typeColor.shade100
                                      : isOpen
                                          ? typeColor
                                          : Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  buttonText,
                                  style: TextStyle(
                                    color: isMySchedule
                                        ? typeColor.shade800
                                        : isOpen
                                            ? Colors.white
                                            : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if ((data['cleaningNote'] as String?)?.isNotEmpty == true) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: typeColor.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: typeColor.shade200),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 12, color: typeColor.shade700),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  data['cleaningNote'] as String,
                                  style: TextStyle(fontSize: 11, color: typeColor.shade800),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestHistoryItem(Map<String, dynamic> schedule, Map<String, dynamic>? request, Map<String, dynamic>? pendingRequest, CleaningInspectionStrings strs, {Map<String, dynamic>? recheckRequest, DateTime? recheckDate}) {
    final scheduleId = schedule['_id'] as String;
    final dateVal = schedule['date'];
    final date = (dateVal is Timestamp) ? dateVal.toDate() : DateTime.now();
    final startTime = (schedule['startTime'] ?? '') as String;
    final endTime = (schedule['endTime'] ?? '') as String;
    final scheduleStatus = (schedule['status'] ?? 'open') as String;
    final maxCap = (schedule['maxCapacity'] is num) ? (schedule['maxCapacity'] as num).toInt() : 1;
    final curCount = (schedule['currentCount'] is num) ? (schedule['currentCount'] as num).toInt() : 0;

    final deadlineVal = schedule['applicationDeadline'];
    final deadline = (deadlineVal is Timestamp) ? deadlineVal.toDate() : null;
    final applyStartVal = schedule['applicationStart'];
    final applyStart = (applyStartVal is Timestamp) ? applyStartVal.toDate() : null;
    final now = DateTime.now();
    final isNotStarted = applyStart != null && now.isBefore(applyStart);
    final isDeadlinePassed = deadline != null && now.isAfter(deadline);

    final isAvailable = scheduleStatus == 'open' && curCount < maxCap && !isNotStarted && !isDeadlinePassed;
    final isMoveOut = (schedule['inspectionType'] as String?) == 'move_out';
    final typeColor = isMoveOut ? Colors.orange : Colors.cyan;
    final typeLabel = isMoveOut ? strs.moveOutInspectionShort : strs.monthlyInspectionShort;

    // 신청 없는 경우
    if (request == null) {
      // 검사일 전일까지만 변경 가능 (검사 당일 및 이후 불가)
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final inspectionDay = DateTime(date.year, date.month, date.day);
      final isBeforeInspectionDay = inspectionDay.isAfter(today);
      final canChange = pendingRequest != null && isAvailable && isBeforeInspectionDay;
      // 재검사: 기존 검사일 이후 일정이고 신청 가능한 경우
      final canRecheck = recheckRequest != null &&
          pendingRequest == null &&
          isAvailable &&
          isBeforeInspectionDay &&
          (recheckDate == null || date.isAfter(recheckDate));
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canChange
              ? () => _confirmChangeRequest(pendingRequest, schedule)
              : canRecheck
                  ? () => _showApplyDialog(schedule['_id'] as String, schedule, user)
                  : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: canChange ? Colors.amber.shade300 : canRecheck ? Colors.red.shade200 : Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
              color: canChange ? Colors.amber.shade50 : canRecheck ? Colors.red.shade50 : Colors.grey.shade50,
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: canChange ? Colors.amber.shade100 : canRecheck ? Colors.red.shade100 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('MM/dd').format(date),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: canChange ? Colors.amber.shade800 : canRecheck ? Colors.red.shade700 : Colors.grey.shade600),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 50),
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                          color: typeColor.shade100,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            typeLabel,
                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: typeColor.shade800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${DateFormat('E', strs.isEnglish ? null : 'ko').format(date)} $startTime~$endTime',
                        style: TextStyle(fontSize: 13, color: canChange ? Colors.amber.shade900 : canRecheck ? Colors.red.shade700 : Colors.grey.shade500),
                      ),
                      if (canChange)
                        Text(strs.tapToChange, style: TextStyle(fontSize: 11, color: Colors.amber.shade700)),
                      if (canRecheck)
                        Text(strs.tapToReapply, style: TextStyle(fontSize: 11, color: Colors.red.shade600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: canChange ? Colors.amber.shade100 : canRecheck ? Colors.red.shade100 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    canChange ? strs.changeAvailable : canRecheck ? strs.changeAvailable : strs.notApplied,
                    style: TextStyle(fontSize: 12, color: canChange ? Colors.amber.shade800 : canRecheck ? Colors.red.shade700 : Colors.grey.shade500),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 신청 있는 경우
    final requestId = request['_id'] as String;
    final status = (request['status'] ?? 'pending') as String;
    final scoreAvg = (request['scoreAvg'] as num?)?.toDouble();
    final needsRecheck = request['needsRecheck'] == true;
    final comment = request['comment'] as String?;
    final createdAt = (request['createdAt'] as Timestamp?)?.toDate();

    String statusText;
    Color statusColor;
    switch (status) {
      case 'pending': statusText = strs.statusWaiting; statusColor = Colors.orange; break;
      case 'in_progress': statusText = strs.statusInspecting; statusColor = Colors.blue; break;
      case 'completed': statusText = strs.statusCompleted; statusColor = Colors.green; break;
      case 'rejected': statusText = strs.statusRejected; statusColor = Colors.red; break;
      default: statusText = status; statusColor = Colors.grey;
    }


    final canDelete = status == 'pending';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: typeColor.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: typeColor.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('MM/dd').format(date),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: typeColor.shade800),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 50),
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: typeColor.shade100,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          typeLabel,
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: typeColor.shade800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${DateFormat('E', strs.isEnglish ? null : 'ko').format(date)} $startTime~$endTime',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    if (createdAt != null)
                      Text(
                        strs.appliedAtLabel(DateFormat('MM/dd HH:mm').format(createdAt)),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(statusText, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.bold)),
              ),
              if (canDelete) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _confirmDeleteRequest(requestId, scheduleId),
                  child: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                ),
              ],
            ],
          ),
          if (scoreAvg != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  strs.scoreLabel(scoreAvg.toStringAsFixed(1)),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: scoreAvg >= 3.5 ? Colors.green : scoreAvg >= 2.5 ? Colors.blue : Colors.red,
                  ),
                ),
                if (needsRecheck) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Text(strs.recheckNeeded, style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 24,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => _submitRecheckRequest(requestId, schedule),
                      child: Text(strs.recheckApplyAction),
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (request['commonAreas'] is List && (request['commonAreas'] as List).isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strs.commonAreasLabel, style: TextStyle(fontSize: 12, color: Colors.cyan.shade700, fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text(
                    (request['commonAreas'] as List)
                        .map((a) => strs.commonArea(a as String))
                        .join(', '),
                    style: TextStyle(fontSize: 12, color: Colors.cyan.shade700),
                  ),
                ),
              ],
            ),
          ],
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(comment, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          ],
        ],
      ),
    );
  }

  void _confirmChangeRequest(Map<String, dynamic> oldRequest, Map<String, dynamic> newSchedule) {
    final strs = CleaningInspectionStrings(
        Provider.of<LocaleProvider>(context, listen: false).isEnglish);
    final dateVal = newSchedule['date'];
    final date = (dateVal is Timestamp) ? dateVal.toDate() : DateTime.now();
    final startTime = (newSchedule['startTime'] ?? '') as String;
    final endTime = (newSchedule['endTime'] ?? '') as String;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strs.scheduleChangeTitle),
        content: Text(strs.scheduleChangeConfirm(
            '${DateFormat('MM/dd(E)', strs.isEnglish ? null : 'ko').format(date)} $startTime~$endTime')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(strs.cancel)),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _changeRequest(oldRequest, newSchedule);
            },
            child: Text(strs.changeAction),
          ),
        ],
      ),
    );
  }

  Future<void> _changeRequest(Map<String, dynamic> oldRequest, Map<String, dynamic> newSchedule) async {
    final strs = CleaningInspectionStrings(
        Provider.of<LocaleProvider>(context, listen: false).isEnglish);
    try {
      final deadlineVal = newSchedule['applicationDeadline'];
      final deadline = (deadlineVal is Timestamp) ? deadlineVal.toDate() : null;
      final applyStartVal = newSchedule['applicationStart'];
      final applyStart = (applyStartVal is Timestamp) ? applyStartVal.toDate() : null;
      final now = DateTime.now();

      if (applyStart != null && now.isBefore(applyStart)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strs.outOfApplicationPeriod), backgroundColor: Colors.orange),
          );
        }
        return;
      }
      if (deadline != null && now.isAfter(deadline)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strs.applicationExpired), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      final oldRequestId = oldRequest['_id'] as String;
      final oldScheduleId = oldRequest['scheduleId'] as String?;
      final newScheduleId = newSchedule['_id'] as String;

      final dateVal = newSchedule['date'];
      final scheduleDate = (dateVal is Timestamp) ? dateVal.toDate() : DateTime.now();
      final startTime = (newSchedule['startTime'] ?? '') as String;
      final endTime = (newSchedule['endTime'] ?? '') as String;

      final batch = _firestore.batch();

      // 기존 신청 삭제 + 기존 스케줄 currentCount 감소
      batch.delete(_firestore.collection('cleaning_requests').doc(oldRequestId));
      if (oldScheduleId != null) {
        batch.update(
          _firestore.collection('cleaning_schedules').doc(oldScheduleId),
          {'currentCount': FieldValue.increment(-1), 'status': 'open'},
        );
      }

      // 새 신청 생성
      final newRequestRef = _firestore.collection('cleaning_requests').doc();
      batch.set(newRequestRef, {
        'userId': oldRequest['userId'],
        'userName': oldRequest['userName'],
        'roomNumber': oldRequest['roomNumber'],
        'building': oldRequest['building'],
        'dormBuilding': oldRequest['dormBuilding'],
        'scheduleId': newScheduleId,
        'inspectionType': (newSchedule['inspectionType'] as String?) ?? widget.inspectionType,
        'availableDates': [Timestamp.fromDate(scheduleDate)],
        'availableTimeSlot': '$startTime~$endTime',
        'availableTimeSlotLabel': '${DateFormat('MM/dd').format(scheduleDate)} $startTime~$endTime',
        'memo': oldRequest['memo'],
        'status': 'pending',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      // 새 스케줄 currentCount 증가
      batch.update(
        _firestore.collection('cleaning_schedules').doc(newScheduleId),
        {'currentCount': FieldValue.increment(1)},
      );

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strs.scheduleChanged), backgroundColor: Colors.green),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strs.changeError), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _submitRecheckRequest(String failedRequestId, Map<String, dynamic> schedule) async {
    final strs = CleaningInspectionStrings(
        Provider.of<LocaleProvider>(context, listen: false).isEnglish);
    try {
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      if (user == null) return;

      // 같은 스케줄에서 재검사: 기존 신청서/평가 결과는 그대로 두고
      // 이전 값(메모, 공동구역)을 복사한 새 신청서를 만들어 재평가를 받을 수 있게 함
      final failedRequest = _requests.firstWhere(
        (r) => r['_id'] == failedRequestId,
        orElse: () => <String, dynamic>{},
      );

      final scheduleId = schedule['_id'] as String;
      final dateVal = schedule['date'];
      final scheduleDate = (dateVal is Timestamp) ? dateVal.toDate() : DateTime.now();
      final startTime = (schedule['startTime'] ?? '') as String;
      final endTime = (schedule['endTime'] ?? '') as String;

      final batch = _firestore.batch();
      final requestRef = _firestore.collection('cleaning_requests').doc();
      batch.set(requestRef, {
        'userId': user.uid,
        'userName': user.name,
        'roomNumber': user.roomNumber,
        'building': user.building,
        'dormBuilding': user.dormBuilding,
        'scheduleId': scheduleId,
        'inspectionType': (schedule['inspectionType'] as String?) ?? widget.inspectionType,
        'availableDates': [Timestamp.fromDate(scheduleDate)],
        'availableTimeSlot': '$startTime~$endTime',
        'availableTimeSlotLabel': '${DateFormat('MM/dd').format(scheduleDate)} $startTime~$endTime',
        'memo': failedRequest['memo'],
        if (failedRequest['commonAreas'] != null) 'commonAreas': failedRequest['commonAreas'],
        'status': 'pending',
        'isRecheck': true,
        'recheckOfRequestId': failedRequestId,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      final scheduleRef = _firestore.collection('cleaning_schedules').doc(scheduleId);
      batch.update(scheduleRef, {'currentCount': FieldValue.increment(1)});
      await batch.commit();

      final updatedSchedule = await scheduleRef.get();
      final updatedData = updatedSchedule.data();
      if (updatedData != null && updatedData['currentCount'] >= updatedData['maxCapacity']) {
        await scheduleRef.update({'status': 'full'});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strs.recheckSubmitted), backgroundColor: Colors.green),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strs.requestSubmitError), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _confirmDeleteRequest(String requestId, String? scheduleId) {
    final strs = CleaningInspectionStrings(
        Provider.of<LocaleProvider>(context, listen: false).isEnglish);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strs.cancelRequestTitle),
        content: Text(strs.cancelRequestConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(strs.close)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteRequest(requestId, scheduleId);
            },
            child: Text(strs.cancelAction),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRequest(String requestId, String? scheduleId) async {
    final strs = CleaningInspectionStrings(
        Provider.of<LocaleProvider>(context, listen: false).isEnglish);
    try {
      final batch = _firestore.batch();
      batch.delete(_firestore.collection('cleaning_requests').doc(requestId));
      if (scheduleId != null) {
        final scheduleRef = _firestore.collection('cleaning_schedules').doc(scheduleId);
        batch.update(scheduleRef, {'currentCount': FieldValue.increment(-1), 'status': 'open'});
      }
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strs.requestCanceled), backgroundColor: Colors.green),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strs.cancelError), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildGuideContent(CleaningInspectionStrings strs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _guideSection(
            icon: Icons.star_outline,
            title: strs.evalCriteriaTitle,
            color: Colors.orange,
            content: strs.evalCriteriaContent,
          ),
          const SizedBox(height: 12),
          _guideSection(
            icon: Icons.checklist_outlined,
            title: strs.areasTitle,
            color: Colors.green,
            content: strs.areasContent,
          ),
          const SizedBox(height: 12),
          _guideSection(
            icon: Icons.score_outlined,
            title: strs.penaltyRewardTitle,
            color: Colors.deepOrange,
            content: strs.penaltyRewardContent,
          ),
          const SizedBox(height: 12),
          _guideSection(
            icon: Icons.warning_amber_outlined,
            title: strs.noticeTitle,
            color: Colors.red,
            content: strs.noticeContent,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⭐', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strs.warningBoxText,
                    style: TextStyle(fontSize: 13, color: Colors.red.shade800, fontWeight: FontWeight.bold),
                  ),
                ),
                const Text('⭐', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strs.contactInfo,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _guideSection({
    required IconData icon,
    required String title,
    required Color color,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 13, height: 1.6)),
        ],
      ),
    );
  }

  void _showApplyDialog(String scheduleId, Map<String, dynamic> scheduleData, dynamic user) {
    if (user == null) return;
    final strs = CleaningInspectionStrings(
        Provider.of<LocaleProvider>(context, listen: false).isEnglish);
    if (_getUserFloorLabel(user) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strs.residenceInfoRequired),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final memoController = TextEditingController();
    final dateVal = scheduleData['date'];
    final date = (dateVal is Timestamp) ? dateVal.toDate() : DateTime.now();
    final startTime = (scheduleData['startTime'] ?? '') as String;
    final endTime = (scheduleData['endTime'] ?? '') as String;
    final isMoveOut = (scheduleData['inspectionType'] as String?) == 'move_out';

    // 퇴사검사 공동구역 목록 (국제생활관은 화장실/샤워실/세면대가 개인 화장실이라 공동구역에서 제외)
    final scheduleFloor = (scheduleData['floor'] ?? '') as String;
    final isGlobalDorm = scheduleFloor.startsWith('국제생활관');
    final commonAreas = isGlobalDorm
        ? const ['현관', '바닥', '냉장고']
        : const ['현관', '화장실', '샤워실', '세면대', '바닥', '냉장고'];
    final selectedAreas = <String>{};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(strs.applyDialogTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strs.dateLabel(DateFormat('yyyy.MM.dd (E)', strs.isEnglish ? null : 'ko').format(date))),
                Text(strs.timeLabel(startTime, endTime)),
                Text(strs.nameLabel(user.name)),
                Text(strs.roomLabelWithNumber(user.roomNumber)),
                if (isMoveOut) ...[
                  const SizedBox(height: 16),
                  Text(
                    strs.commonAreaSelectTitle,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    strs.commonAreaSelectHint,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: commonAreas.map((area) {
                      final isSelected = selectedAreas.contains(area);
                      return FilterChip(
                        label: Text(strs.commonArea(area), style: const TextStyle(fontSize: 13)),
                        selected: isSelected,
                        selectedColor: Colors.cyan.shade100,
                        checkmarkColor: Colors.cyan.shade800,
                        side: BorderSide(
                          color: isSelected ? Colors.cyan.shade400 : Colors.grey.shade300,
                        ),
                        onSelected: (val) {
                          setDialogState(() {
                            if (val) {
                              selectedAreas.add(area);
                            } else {
                              selectedAreas.remove(area);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: memoController,
                  decoration: InputDecoration(
                    hintText: strs.memoHint,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(strs.cancel)),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _submitRequest(
                  scheduleId,
                  scheduleData,
                  memoController.text.trim(),
                  user,
                  commonAreas: selectedAreas.isEmpty ? null : selectedAreas.toList(),
                );
              },
              child: Text(strs.applyAction),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRequest(String scheduleId, Map<String, dynamic> scheduleData, String memo, dynamic user, {List<String>? commonAreas}) async {
    final strs = CleaningInspectionStrings(
        Provider.of<LocaleProvider>(context, listen: false).isEnglish);
    try {
      if (_getUserFloorLabel(user) == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(strs.residenceInfoRequired),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      final deadlineVal = scheduleData['applicationDeadline'];
      final deadline = (deadlineVal is Timestamp) ? deadlineVal.toDate() : null;
      final applyStartVal = scheduleData['applicationStart'];
      final applyStart = (applyStartVal is Timestamp) ? applyStartVal.toDate() : null;
      final now = DateTime.now();

      if (applyStart != null && now.isBefore(applyStart)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strs.notApplicationPeriod), backgroundColor: Colors.orange),
          );
        }
        return;
      }
      if (deadline != null && now.isAfter(deadline)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strs.applicationDeadlinePassed), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      final scheduleInspectionType =
          (scheduleData['inspectionType'] as String?) ?? widget.inspectionType;

      final existing = await _firestore
          .collection('cleaning_requests')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .where('inspectionType', isEqualTo: scheduleInspectionType)
          .get();

      if (existing.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strs.alreadyPending), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      // 월검사는 한 달에 한 번만 신청 가능 (재검사 신청은 예외)
      if (scheduleInspectionType == 'monthly') {
        final newDateVal = scheduleData['date'];
        final newDate = (newDateVal is Timestamp) ? newDateVal.toDate() : DateTime.now();
        final scheduleById = {for (final sc in _schedules) sc['_id'] as String: sc};

        final alreadyAppliedThisMonth = _requests.any((r) {
          if (r['isRecheck'] == true) return false;
          if ((r['inspectionType'] as String?) != 'monthly') return false;
          final sid = r['scheduleId'];
          if (sid is! String) return false;
          final sc = scheduleById[sid];
          if (sc == null) return false;
          final dv = sc['date'];
          final d = (dv is Timestamp) ? dv.toDate() : null;
          if (d == null) return false;
          return d.year == newDate.year && d.month == newDate.month;
        });

        if (alreadyAppliedThisMonth) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(strs.monthlyLimitReached), backgroundColor: Colors.orange),
            );
          }
          return;
        }
      }

      final dateVal = scheduleData['date'];
      final scheduleDate = (dateVal is Timestamp) ? dateVal.toDate() : DateTime.now();
      final startTime = (scheduleData['startTime'] ?? '') as String;
      final endTime = (scheduleData['endTime'] ?? '') as String;

      final batch = _firestore.batch();
      final requestRef = _firestore.collection('cleaning_requests').doc();
      batch.set(requestRef, {
        'userId': user.uid,
        'userName': user.name,
        'roomNumber': user.roomNumber,
        'building': user.building,
        'dormBuilding': user.dormBuilding,
        'scheduleId': scheduleId,
        'inspectionType': scheduleInspectionType,
        'availableDates': [Timestamp.fromDate(scheduleDate)],
        'availableTimeSlot': '$startTime~$endTime',
        'availableTimeSlotLabel': '${DateFormat('MM/dd').format(scheduleDate)} $startTime~$endTime',
        'memo': memo.isEmpty ? null : memo,
        if (commonAreas != null && commonAreas.isNotEmpty) 'commonAreas': commonAreas,
        'status': 'pending',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      final scheduleRef = _firestore.collection('cleaning_schedules').doc(scheduleId);
      batch.update(scheduleRef, {'currentCount': FieldValue.increment(1)});
      await batch.commit();

      final updatedSchedule = await scheduleRef.get();
      final updatedData = updatedSchedule.data();
      if (updatedData != null && updatedData['currentCount'] >= updatedData['maxCapacity']) {
        await scheduleRef.update({'status': 'full'});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strs.requestSubmitted), backgroundColor: Colors.green),
        );
        _loadData();
        setState(() => _viewMode = 1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strs.requestSubmitError), backgroundColor: Colors.red),
        );
      }
    }
  }
}
