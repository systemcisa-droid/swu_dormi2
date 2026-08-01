import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import 'dart:math';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _assignedFloor;
  bool _isLoadingEvents = true;
  bool _isLoadingRecords = false;
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _roomStudents = [];
  String? _selectedEventId;
  StreamSubscription<QuerySnapshot>? _recordsSubscription;

  // 수동 상태 (로컬 즉시 반영용): userId → 상태
  final Map<String, String?> _manualStatuses = {};

  static const _statusOptions = ['외박미신청', '자퇴', '바롬', '외박미수정'];
  static const _statusColors = {
    '외박미신청': Colors.orange,
    '자퇴': Colors.red,
    '바롬': Colors.purple,
    '외박미수정': Colors.blue,
  };

  @override
  void initState() {
    super.initState();
    _loadAssignedFloorThenEvents();
  }

  Future<void> _loadAssignedFloorThenEvents() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await _firestore.collection('users').doc(uid).get();
      final floor = doc.data()?['assignedFloor'] as String?;
      if (mounted) setState(() => _assignedFloor = floor);
    }
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoadingEvents = true);
    try {
      Query query = _firestore
          .collection('attendance_events')
          .orderBy('createdAt', descending: true)
          .limit(50);

      if (_assignedFloor != null) {
        query = query.where('floor', isEqualTo: _assignedFloor);
      }

      final snapshot = await query.get();

      final events = snapshot.docs
          .map((doc) => {'id': doc.id, ...(doc.data() as Map<String, dynamic>)})
          .toList();

      // roomNumber 필드 기준 숫자 오름차순 정렬
      events.sort((a, b) {
        final ra = int.tryParse(a['roomNumber'] as String? ?? '') ?? 0;
        final rb = int.tryParse(b['roomNumber'] as String? ?? '') ?? 0;
        if (ra != rb) return ra.compareTo(rb);
        // roomNumber 없는 경우 createdAt 내림차순
        final ta = (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final tb = (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });

      setState(() {
        _events = events;
        _isLoadingEvents = false;
      });
    } catch (e) {
      debugPrint('출석 이벤트 로딩 오류: $e');
      setState(() => _isLoadingEvents = false);
    }
  }

  Future<void> _loadRecords(String eventId) async {
    // 기존 스트림 취소
    await _recordsSubscription?.cancel();
    _recordsSubscription = null;

    setState(() {
      _isLoadingRecords = true;
      _selectedEventId = eventId;
      _records = [];
      _roomStudents = [];
      _manualStatuses.clear();
    });

    final event = _events.firstWhere(
      (e) => e['id'] == eventId,
      orElse: () => {},
    );
    final roomNumber = event['roomNumber'] as String?;

    try {
      // 호실 학생 로드 (1회) — dormBuilding 필터로 같은 호실번호의 타 기숙사 학생 제외
      final dormBuilding = _assignedFloor?.split(' ').firstOrNull;
      List<Map<String, dynamic>> students = [];
      if (roomNumber != null && roomNumber.isNotEmpty) {
        Query<Map<String, dynamic>> q = _firestore
            .collection('users')
            .where('roomNumber', isEqualTo: roomNumber)
            .where('role', isEqualTo: 'student');
        if (dormBuilding != null) {
          q = q.where('dormBuilding', isEqualTo: dormBuilding);
        }
        final studentsSnap = await q.get();
        students = studentsSnap.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
        students.sort((a, b) =>
            (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));
      }

      // 수동 상태 로드 (1회)
      final eventDoc = await _firestore
          .collection('attendance_events')
          .doc(eventId)
          .get();
      final savedStatuses =
          (eventDoc.data()?['manualStatuses'] as Map<String, dynamic>?) ?? {};

      if (!mounted) return;
      setState(() {
        _roomStudents = students;
        savedStatuses.forEach((uid, st) {
          _manualStatuses[uid] = st as String?;
        });
        _isLoadingRecords = false;
      });

      // 출석 기록 실시간 스트림
      _recordsSubscription = _firestore
          .collection('attendance_records')
          .where('eventId', isEqualTo: eventId)
          .snapshots()
          .listen((snapshot) {
        if (!mounted) return;
        setState(() {
          _records = snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
        });
      });
    } catch (e) {
      debugPrint('출석 기록 로딩 오류: $e');
      if (mounted) setState(() => _isLoadingRecords = false);
    }
  }

  @override
  void dispose() {
    _recordsSubscription?.cancel();
    super.dispose();
  }

  void _selectStatus(String userId, String? status) {
    setState(() => _manualStatuses[userId] = status);
    final eventId = _selectedEventId;
    if (eventId == null) return;
    _firestore.collection('attendance_events').doc(eventId).update({
      'manualStatuses.$userId': status ?? FieldValue.delete(),
    });
  }

  String _generateToken() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadAssignedFloorThenEvents,
                  tooltip: '새로고침',
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _showCreateEventDialog,
                  tooltip: '이벤트 추가',
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoadingEvents
                ? const Center(child: CircularProgressIndicator())
                : _events.isEmpty
                    ? _buildEmptyState()
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            '등록된 출석 이벤트가 없습니다',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _showCreateEventDialog,
            icon: const Icon(Icons.add),
            label: const Text('이벤트 추가'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadAssignedFloorThenEvents,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _events.length,
        itemBuilder: (context, index) => _buildEventCard(_events[index]),
      ),
    );
  }

  static Color _buildingColor(String? dormBuilding) {
    if (dormBuilding == '샬롬하우스') return const Color(0xFF2196F3);
    if (dormBuilding == '국제생활관') return const Color(0xFF4CAF50);
    if (dormBuilding == '바롬인성교육관') return const Color(0xFFFF9800);
    return const Color(0xFF9E9E9E);
  }

  static String? _dormBuildingFromFloor(String? floor) {
    if (floor == null || floor.isEmpty) return null;
    if (floor.startsWith('샬롬하우스')) return '샬롬하우스';
    if (floor.startsWith('국제생활관')) return '국제생활관';
    if (floor.startsWith('바롬인성교육관')) return '바롬인성교육관';
    return null;
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final eventId = event['id'] as String;
    final title = event['title'] ?? '제목 없음';
    final status = event['status'] ?? 'active';
    final createdAt = (event['createdAt'] as Timestamp?)?.toDate();
    final roomNumber = event['roomNumber'] as String?;
    final floor = (event['floor'] as String?) ?? _assignedFloor ?? '';
    final isSelected = _selectedEventId == eventId;

    final isActive = status == 'active';
    final dormBuilding = _dormBuildingFromFloor(floor);
    final buildingColor = _buildingColor(dormBuilding);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Stack(
        children: [
          // 카드 본문
          Card(
            margin: EdgeInsets.zero,
            elevation: isSelected ? 4 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isSelected
                  ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
                  : BorderSide.none,
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () => _loadRecords(eventId),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(21, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isActive 
                                    ? Colors.green.withValues(alpha:0.1)
                                    : Colors.grey.withValues(alpha:0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isActive ? '진행중' : '종료',
                                style: TextStyle(
                                  color: isActive ? Colors.green : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isActive)
                            IconButton(
                              icon: const Icon(Icons.qr_code, color: Colors.blue),
                              onPressed: () => _showQrDialog(eventId, title, roomNumber: roomNumber),
                              tooltip: 'QR 코드 표시',
                            ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'toggle') {
                                _toggleEventStatus(eventId, status);
                              } else if (value == 'delete') {
                                _deleteEvent(eventId);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'toggle',
                                child: Row(
                                  children: [
                                    Icon(
                                      isActive ? Icons.stop : Icons.play_arrow,
                                      color: isActive ? Colors.orange : Colors.green,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(isActive ? '종료하기' : '재시작'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red, size: 20),
                                    SizedBox(width: 8),
                                    Text('삭제', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (dormBuilding != null)
                          Text(
                            dormBuilding,
                            style: TextStyle(fontSize: 12, color: buildingColor, fontWeight: FontWeight.w600),
                          ),
                        if (floor.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              floor,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (roomNumber != null && roomNumber.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$roomNumber호',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (createdAt != null)
                              Text(
                                DateFormat('yyyy-MM-dd HH:mm').format(createdAt),
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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
                  // 선택된 경우 출석 기록 표시
                  if (isSelected) _buildRecordsSection(),
                ],
              ),
            ),
          // 왼쪽 건물 색상 스트라이프
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 5,
              decoration: BoxDecoration(
                color: buildingColor,
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

  Widget _buildRecordsSection() {
    if (_isLoadingRecords) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // 출석한 userId 세트
    final attendedIds = _records
        .map((r) => r['userId'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    final presentCount = _roomStudents.isNotEmpty
        ? _roomStudents
            .where((s) => attendedIds.contains(s['id'] as String))
            .length
        : _records.length;
    final totalCount =
        _roomStudents.isNotEmpty ? _roomStudents.length : _records.length;

    // 호실 학생이 있으면 전체 목록, 없으면 출석 기록만
    final showStudentList = _roomStudents.isNotEmpty;

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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Text(
                  '출석 현황',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: presentCount == totalCount && totalCount > 0
                        ? Colors.green.withValues(alpha:0.1)
                        : Colors.orange.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$presentCount / $totalCount명 출석',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: presentCount == totalCount && totalCount > 0
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showStudentList)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _roomStudents.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, index) {
                final s = _roomStudents[index];
                final uid = s['id'] as String;
                final name = s['name'] as String? ?? '이름 없음';
                final studentId = s['studentId'] as String? ?? '';
                final isPresent = attendedIds.contains(uid);
                // 출석 시각 찾기
                final record = _records.firstWhere(
                  (r) => r['userId'] == uid,
                  orElse: () => {},
                );
                final checkedAt =
                    (record['checkedInAt'] as Timestamp?)?.toDate();

                final manualStatus = _manualStatuses[uid];
                final statusColor =
                    _statusColors[manualStatus] ?? Colors.grey;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          isPresent
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: isPresent
                              ? Colors.green
                              : Colors.grey.shade400,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontWeight: isPresent
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isPresent
                                    ? Colors.black87
                                    : Colors.grey.shade700,
                              ),
                            ),
                            if (studentId.isNotEmpty)
                              Text(
                                studentId,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500),
                              ),
                            if (!isPresent) ...[
                              const SizedBox(height: 6),
                              DropdownButtonHideUnderline(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: manualStatus != null
                                        ? statusColor
                                            .withValues(alpha: 0.1)
                                        : Colors.grey.shade100,
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    border: Border.all(
                                      color: manualStatus != null
                                          ? statusColor
                                              .withValues(alpha: 0.5)
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: DropdownButton<String?>(
                                    value: manualStatus,
                                    isDense: true,
                                    hint: Text(
                                      '상태 선택',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500),
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: manualStatus != null
                                          ? statusColor
                                          : Colors.grey.shade700,
                                    ),
                                    items: [
                                      DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text(
                                          '선택 안함',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  Colors.grey.shade500),
                                        ),
                                      ),
                                      ..._statusOptions.map((st) =>
                                          DropdownMenuItem<String?>(
                                            value: st,
                                            child: Text(
                                              st,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight:
                                                    FontWeight.bold,
                                                color: _statusColors[
                                                        st] ??
                                                    Colors.grey,
                                              ),
                                            ),
                                          )),
                                    ],
                                    onChanged: (val) =>
                                        _selectStatus(uid, val),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isPresent && checkedAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            DateFormat('HH:mm').format(checkedAt),
                            style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                );
              },
            )
          else if (_records.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                '출석 기록이 없습니다',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _records.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _buildRecordTile(_records[index], index + 1),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildRecordTile(Map<String, dynamic> record, int index) {
    final userName = record['userName'] ?? '이름 없음';
    final roomNumber = record['roomNumber'] ?? '';
    final dormBuilding = (record['dormBuilding'] as String?)?.isNotEmpty == true
        ? record['dormBuilding'] as String
        : (record['building'] as String? ?? '');
    final checkedAt = (record['checkedInAt'] as Timestamp?)?.toDate();

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: Theme.of(context).primaryColor,
        child: Text(
          '$index',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
      title: Row(
        children: [
          Text(userName, style: const TextStyle(fontWeight: FontWeight.w500)),
          if (dormBuilding.isNotEmpty || roomNumber.isNotEmpty)
            Text(
              ' (${[if (dormBuilding.isNotEmpty) dormBuilding, if (roomNumber.isNotEmpty) '$roomNumber호'].join(' ')})',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
        ],
      ),
      trailing: checkedAt != null
          ? Text(
              DateFormat('HH:mm:ss').format(checkedAt),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            )
          : null,
    );
  }

  void _showQrDialog(String eventId, String eventTitle, {String? roomNumber}) {
    showDialog(
      context: context,
      builder: (context) => _QrCodeDialog(eventId: eventId, eventTitle: eventTitle, roomNumber: roomNumber),
    );
  }

  Future<List<String>> _loadRoomsForFloor() async {
    if (_assignedFloor == null) return [];

    final floor = _assignedFloor!;
    final dormBuilding = floor.split(' ').firstOrNull ?? '';
    final buildingMatch = RegExp(r'([AB])동').firstMatch(floor);
    final floorMatch = RegExp(r'(\d+)층').firstMatch(floor);
    final building = buildingMatch?.group(1); // 'A' or 'B'
    final floorNum = floorMatch != null ? int.tryParse(floorMatch.group(1)!) : null;

    if (floorNum == null) return [];

    if (dormBuilding == '샬롬하우스') {
      // A동: floor×100 + 01~20 / B동: floor×100 + 21~35
      if (building == 'A') {
        return List.generate(20, (i) => '${floorNum * 100 + i + 1}');
      } else if (building == 'B') {
        return List.generate(15, (i) => '${floorNum * 100 + 21 + i}');
      }
    } else if (dormBuilding == '국제생활관') {
      // A동 1층: 101~132 / A동 2층: 201~229
      // B동 2층: 233~260 / B동 3층: 301~329
      if (building == 'A' && floorNum == 1) return List.generate(32, (i) => '${101 + i}');
      if (building == 'A' && floorNum == 2) return List.generate(29, (i) => '${201 + i}');
      if (building == 'B' && floorNum == 2) return List.generate(28, (i) => '${233 + i}');
      if (building == 'B' && floorNum == 3) return List.generate(29, (i) => '${301 + i}');
    } else if (dormBuilding == '바롬인성교육관') {
      // Firestore에서 실제 배정된 호실 조회
      final snap = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('dormBuilding', isEqualTo: dormBuilding)
          .get();
      final rooms = <String>{};
      for (final doc in snap.docs) {
        final r = doc.data()['roomNumber'] as String? ?? '';
        if (r.isEmpty || r == '000') continue;
        final n = int.tryParse(r);
        if (n != null && n ~/ 100 == floorNum) rooms.add(r);
      }
      return rooms.toList()
        ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
    }

    return [];
  }

  void _showCreateEventDialog() {
    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<List<String>>(
        future: _loadRoomsForFloor(),
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const AlertDialog(
              content: SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          return _RoomEventCreateDialog(
            assignedFloor: _assignedFloor ?? '담당 구역 미설정',
            rooms: snap.data ?? [],
            onCreate: (title, selectedRooms) async {
              Navigator.pop(ctx);
              for (final room in selectedRooms) {
                await _createEvent(title, roomNumber: room);
              }
            },
          );
        },
      ),
    );
  }

  Future<void> _createEvent(String title, {String roomNumber = ''}) async {
    try {
      await _firestore.collection('attendance_events').add({
        'title': title,
        if (roomNumber.isNotEmpty) 'roomNumber': roomNumber,
        if (_assignedFloor != null) 'floor': _assignedFloor,
        'status': 'active',
        'token': _generateToken(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      _loadEvents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이벤트가 생성되었습니다')),
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

  Future<void> _toggleEventStatus(String eventId, String currentStatus) async {
    final newStatus = currentStatus == 'active' ? 'closed' : 'active';
    try {
      await _firestore.collection('attendance_events').doc(eventId).update({
        'status': newStatus,
      });
      _loadEvents();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteEvent(String eventId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이벤트 삭제'),
        content: const Text('이 이벤트와 모든 출석 기록을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('attendance_events').doc(eventId).delete();
        if (_selectedEventId == eventId) {
          setState(() {
            _selectedEventId = null;
            _records = [];
          });
        }
        _loadEvents();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이벤트가 삭제되었습니다')),
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
}

// QR 코드 전체화면 다이얼로그
class _QrCodeDialog extends StatefulWidget {
  final String eventId;
  final String eventTitle;
  final String? roomNumber;

  const _QrCodeDialog({
    required this.eventId,
    required this.eventTitle,
    this.roomNumber,
  });

  @override
  State<_QrCodeDialog> createState() => _QrCodeDialogState();
}

class _QrCodeDialogState extends State<_QrCodeDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _refreshTimer;
  String _currentToken = '';
  int _remainingSeconds = 30;

  @override
  void initState() {
    super.initState();
    _refreshToken();
    _startTimer();
  }

  void _startTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _refreshToken();
      }
    });
  }

  Future<void> _refreshToken() async {
    final newToken = _generateToken();
    try {
      await _firestore.collection('attendance_events').doc(widget.eventId).update({
        'currentToken': newToken,
      });
      setState(() {
        _currentToken = newToken;
        _remainingSeconds = 30;
      });
    } catch (e) {
      debugPrint('토큰 갱신 오류: $e');
    }
  }

  String _generateToken() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qrData = 'attendance:${widget.eventId}:$_currentToken';
    
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.eventTitle),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha:0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 280,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _currentToken,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.timer,
                    color: _remainingSeconds <= 10 ? Colors.red : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$_remainingSeconds초 후 갱신',
                    style: TextStyle(
                      fontSize: 16,
                      color: _remainingSeconds <= 10 ? Colors.red : Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              if (widget.roomNumber != null && widget.roomNumber!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.door_front_door_outlined, color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.roomNumber}호 전용 — 타 호실 학생은 거부됩니다',
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              Text(
                '학생 앱에서 QR 코드를 스캔하거나\n위 코드를 입력하세요',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 호실별 이벤트 생성 다이얼로그 ──
class _RoomEventCreateDialog extends StatefulWidget {
  final String assignedFloor;
  final List<String> rooms;
  final Future<void> Function(String title, List<String> selectedRooms) onCreate;

  const _RoomEventCreateDialog({
    required this.assignedFloor,
    required this.rooms,
    required this.onCreate,
  });

  @override
  State<_RoomEventCreateDialog> createState() =>
      _RoomEventCreateDialogState();
}

class _RoomEventCreateDialogState extends State<_RoomEventCreateDialog> {
  final _titleController = TextEditingController();
  late Set<String> _selected;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.rooms);
    _titleController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _toggleAll(bool? value) {
    setState(() {
      if (value == true) {
        _selected = Set.from(widget.rooms);
      } else {
        _selected.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final allSelected =
        widget.rooms.isNotEmpty && _selected.length == widget.rooms.length;

    return AlertDialog(
      title: const Text('출석 이벤트 생성'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 담당 구역 표시
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.layers_outlined,
                      size: 14,
                      color: Theme.of(context).primaryColor),
                  const SizedBox(width: 6),
                  Text(
                    widget.assignedFloor,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 이벤트 제목
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '이벤트 제목',
                hintText: '예: 2026년 3월 주간 점호',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            if (widget.rooms.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  '담당 구역에 배정된 학생이 없습니다',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            else ...[
              // 전체 선택
              Row(
                children: [
                  Checkbox(
                    value: allSelected,
                    tristate: false,
                    onChanged: _toggleAll,
                  ),
                  Text(
                    '전체 선택 (${_selected.length}/${widget.rooms.length}호)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const Divider(height: 1),
              // 호실 목록
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.rooms.length,
                itemBuilder: (context, index) {
                  final room = widget.rooms[index];
                  final isSelected = _selected.contains(room);
                  return CheckboxListTile(
                    dense: true,
                    value: isSelected,
                    title: Text('$room호'),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selected.add(room);
                        } else {
                          _selected.remove(room);
                        }
                      });
                    },
                  );
                },
              ),
            ],
          ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: (_isCreating ||
                  _titleController.text.isEmpty ||
                  _selected.isEmpty)
              ? null
              : () async {
                  setState(() => _isCreating = true);
                  await widget.onCreate(
                    _titleController.text.trim(),
                    _selected.toList()
                      ..sort((a, b) =>
                          (int.tryParse(a) ?? 0)
                              .compareTo(int.tryParse(b) ?? 0)),
                  );
                },
          child: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('${_selected.length}개 생성'),
        ),
      ],
    );
  }
}
