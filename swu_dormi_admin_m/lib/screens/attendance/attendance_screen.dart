import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/server_clock.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:excel/excel.dart' hide Border;
import '../cleaning/cleaning_inspection_screen.dart' show kFloorOptions;
import '../../models/excel_student_row.dart';
import 'dart:async';
import 'dart:math';

// 탭 컨테이너
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
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
            Tab(icon: Icon(Icons.event, size: 18), text: '인원점검'),
            Tab(icon: Icon(Icons.history, size: 18), text: '인원점검 이력'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _AttendanceEventContent(),
          _AttendanceHistoryContent(),
        ],
      ),
    );
  }
}

// ── 출석 이벤트 탭 (기존 로직) ──
class _AttendanceEventContent extends StatefulWidget {
  const _AttendanceEventContent();

  @override
  State<_AttendanceEventContent> createState() => _AttendanceEventContentState();
}

class _AttendanceEventContentState extends State<_AttendanceEventContent> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _assignedFloor;
  bool _isLoadingEvents = true;
  // 스케줄 생성/종료 후 목록을 다시 불러와도 보고 있던 위치를 유지한다.
  final _eventScrollController = ScrollController();
  bool _isLoadingRecords = false;
  // 스케줄 종료 처리 중 여부 — 연타로 중복 실행되는 것을 막는다.
  bool _isClosingEvents = false;
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _roomStudents = [];
  // 엑셀에는 있으나 users 컬렉션에 이메일이 없는 학생(앱 미가입자) 전체 목록
  List<ExcelStudentRow> _unregisteredStudents = [];
  // 현재 선택된 이벤트의 호실(또는 구역 전체)에 해당하는 미가입자만 필터링
  List<ExcelStudentRow> _roomUnregisteredStudents = [];
  String? _selectedEventId;
  StreamSubscription<QuerySnapshot>? _recordsSubscription;

  // 이벤트별 출석 카운트 캐시: eventId → attendedCount
  Map<String, int> _eventAttendedCounts = {};
  // 호실별 학생 수 캐시: roomNumber → studentCount
  Map<String, int> _roomStudentCounts = {};
  // 구역(kFloorOptions 값) -> 재실 학생 수 (구역 전체 통합 이벤트 카드용)
  Map<String, int> _floorStudentCounts = {};
  // 화재대피용 이벤트별 QR 스캔 모드: eventId → true(대피 도착 확인)/false(대피 시작 확인, 기본값)
  final Map<String, bool> _fireDrillArrivalMode = {};

  // 층장 상태 (부재/외박미수정, 로컬 즉시 반영용): userId → 상태
  final Map<String, String?> _floorStatuses = {};
  // 층장 상태를 지정한 층장 계정 이메일: userId → email
  final Map<String, String?> _floorStatusSetBy = {};
  // 관리자 상태 (외박, Windows 관리프로그램 전용, 읽기 전용): userId → 상태
  final Map<String, String?> _adminStatuses = {};
  // 학생별 비고 (자유 텍스트): userId → 비고
  final Map<String, String?> _remarks = {};

  static const _statusOptions = ['외박미신청', '외박미수정', '바롬인성교육관', '무단퇴사'];
  static const _statusColors = {
    '외박미신청': Colors.red,
    '외박미수정': Colors.blue,
    '바롬인성교육관': Color(0xFFFF9800),
    '무단퇴사': Color(0xFF9E9E9E),
  };

  static const _blockedStatuses = {
    '퇴사',
    '만기퇴사',
    '자진퇴사',
    '강제퇴사',
    '영구퇴사',
    '바롬인성교육관',
  };
  static const _blockedStatusColors = {
    '퇴사': Color(0xFF9E9E9E),
    '만기퇴사': Color(0xFF9E9E9E),
    '자진퇴사': Color(0xFF9E9E9E),
    '강제퇴사': Color(0xFF9E9E9E),
    '영구퇴사': Color(0xFF9E9E9E),
    '바롬인성교육관': Color(0xFFFF9800),
  };

  bool _isSelectionMode = false;
  final Set<String> _selectedEventIds = {};

  @override
  void initState() {
    super.initState();
    // QR 검증은 서버 시각 기준이므로 화면 진입 시 미리 동기화해 둔다 (실패해도 스캔 시 재시도).
    ServerClock.sync();
    _loadAssignedFloorThenEvents();
    _loadUnregisteredStudents();
  }

  // 사생 기본 정보 엑셀에서 앱 미가입 학생 목록을 로드한다.
  // 부가 기능이므로 실패해도 사용자에게 에러를 표시하지 않고 조용히 무시한다.
  Future<void> _loadUnregisteredStudents() async {
    try {
      final settingsDoc = await _firestore.collection('settings').doc('home').get();
      final excelUrl = settingsDoc.data()?['studentInfoExcelUrl'] as String?;
      if (excelUrl == null || excelUrl.trim().isEmpty) return;

      final response = await http.get(Uri.parse(excelUrl));
      if (response.statusCode != 200) return;
      final excel = Excel.decodeBytes(response.bodyBytes);
      final sheet = excel.sheets.values.first;
      final rows = sheet.rows
          .map((row) => row.map((cell) => cell?.value?.toString() ?? '').toList())
          .toList();
      if (rows.isEmpty) return;

      // 첫 줄이 제목 행일 수 있으므로 실제 헤더 행을 찾는다.
      final headerIdx = ExcelStudentRow.findHeaderRowIndex(rows);
      final header = rows[headerIdx];
      final excelRows = rows
          .skip(headerIdx + 1)
          .map((row) => ExcelStudentRow.fromRow(header, row))
          .toList();

      final usersSnap = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();
      final registeredEmails = usersSnap.docs
          .map((d) => (d.data()['email'] as String? ?? '').trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toSet();

      final unregistered = excelRows.where((r) {
        if (!r.hasMatchKey) return false;
        final email = r.normalizedEmail;
        if (email != null && registeredEmails.contains(email)) return false;
        return true;
      }).toList();

      if (!mounted) return;
      setState(() {
        _unregisteredStudents = unregistered;
        if (_selectedEventId != null) {
          final event = _events.firstWhere(
            (e) => e['id'] == _selectedEventId,
            orElse: () => {},
          );
          final eventFloor = event['floor'] as String?;
          _updateRoomUnregisteredStudents(
            event['roomNumber'] as String?,
            isFloorWide: event['isFloorWide'] == true,
            floorRoomNumbers: null,
            dormBuilding: (eventFloor != null && eventFloor.isNotEmpty)
                ? _dormBuildingOf(eventFloor)
                : (_assignedFloor != null ? _dormBuildingOf(_assignedFloor!) : null),
          );
        }
      });
    } catch (_) {}
  }

  /// 구역 문자열(예: '국제생활관 A동 2층')에서 기숙사 건물명을 뽑는다.
  static String? _dormBuildingOf(String floor) =>
      floor.contains('방학') ? '샬롬하우스(방학)' : floor.split(' ').firstOrNull;

  void _updateRoomUnregisteredStudents(
    String? roomNumber, {
    bool isFloorWide = false,
    Set<String>? floorRoomNumbers,
    String? dormBuilding,
  }) {
    // 호실번호는 기숙사 간 중복되므로(예: 샬롬하우스 206호 / 국제생활관 206호)
    // 가입 학생 조회와 동일하게 건물까지 일치해야 같은 구역으로 취급한다.
    bool matchesBuilding(ExcelStudentRow s) {
      if (dormBuilding == null || dormBuilding.isEmpty) return true;
      // 엑셀에 건물이 비어 있으면 판별할 수 없으므로 제외하지 않고 남긴다.
      if (s.dormBuilding == null || s.dormBuilding!.isEmpty) return true;
      return s.dormBuilding == dormBuilding;
    }

    if (isFloorWide) {
      if (floorRoomNumbers == null || floorRoomNumbers.isEmpty) {
        _roomUnregisteredStudents = [];
        return;
      }
      _roomUnregisteredStudents = _unregisteredStudents
          .where((s) =>
              s.roomNumber != null &&
              floorRoomNumbers.contains(s.roomNumber) &&
              matchesBuilding(s))
          .toList();
      return;
    }
    if (roomNumber == null || roomNumber.isEmpty) {
      _roomUnregisteredStudents = [];
      return;
    }
    _roomUnregisteredStudents = _unregisteredStudents
        .where((s) => s.roomNumber == roomNumber && matchesBuilding(s))
        .toList();
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

  /// [showLoading]이 false면 로딩 화면으로 교체하지 않고 조용히 갱신한다.
  /// (생성/종료 후 재조회 시 목록이 사라졌다 다시 그려지며 스크롤이 초기화되는 것을 막는다)
  Future<void> _loadEvents({bool showLoading = true}) async {
    setState(() {
      if (showLoading) _isLoadingEvents = true;
    });
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

      events.sort((a, b) {
        // 1) 최근 생성된 배치가 위로 오도록 정렬 (분 단위로 묶어서 같은 배치인지 판단)
        final aCreatedAt = a['createdAt'] as Timestamp?;
        final bCreatedAt = b['createdAt'] as Timestamp?;
        if (aCreatedAt == null && bCreatedAt != null) return 1;
        if (aCreatedAt != null && bCreatedAt == null) return -1;
        if (aCreatedAt != null && bCreatedAt != null) {
          final aMinute = aCreatedAt.toDate().millisecondsSinceEpoch ~/ 60000;
          final bMinute = bCreatedAt.toDate().millisecondsSinceEpoch ~/ 60000;
          if (aMinute != bMinute) return bMinute.compareTo(aMinute);
        }
        // 2) 같은 배치 내에서는 호실 오름차순
        final aRoom = int.tryParse(a['roomNumber'] as String? ?? '') ?? 0;
        final bRoom = int.tryParse(b['roomNumber'] as String? ?? '') ?? 0;
        return aRoom.compareTo(bRoom);
      });

      // 이벤트별 출석 카운트 집계 (화재대피용 1차 스캔만 한 미완료 기록은 제외)
      final recordsSnap = await _firestore.collection('attendance_records').get();
      final counts = <String, int>{};
      for (final doc in recordsSnap.docs) {
        final data = doc.data();
        if (data['isComplete'] == false) continue;
        final eid = data['eventId'] as String?;
        if (eid != null) counts[eid] = (counts[eid] ?? 0) + 1;
      }

      // 호실별 학생 수 집계
      Query<Map<String, dynamic>> usersQuery = _firestore
          .collection('users')
          .where('role', isEqualTo: 'student');
      if (_assignedFloor != null) {
        final dormBuilding = _assignedFloor!.contains('방학')
            ? '샬롬하우스(방학)'
            : _assignedFloor!.split(' ').firstOrNull;
        if (dormBuilding != null) {
          usersQuery = usersQuery.where('dormBuilding', isEqualTo: dormBuilding);
        }
      }
      final usersSnap = await usersQuery.get();
      final roomCounts = <String, int>{};
      for (final doc in usersSnap.docs) {
        final data = doc.data();
        final room = data['roomNumber'] as String?;
        if (room == null || room.isEmpty) continue;
        final residentStatus = (data['residentStatus'] as String?) ?? '재실중';
        if (_blockedStatuses.contains(residentStatus)) continue;
        roomCounts[room] = (roomCounts[room] ?? 0) + 1;
      }

      // 담당 구역 전체 통합 이벤트 카드의 총원 표시를 위한 구역별 재실 인원 캐시
      final floorCounts = <String, int>{};
      if (_assignedFloor != null) {
        final result = await _loadStudentsForFloor(_assignedFloor!);
        floorCounts[_assignedFloor!] = result.students.length;
      }

      setState(() {
        _events = events;
        _eventAttendedCounts = counts;
        _roomStudentCounts = roomCounts;
        _floorStudentCounts = floorCounts;
        _isLoadingEvents = false;
      });
    } catch (e) {
      debugPrint('인원점검 로딩 오류: $e');
      if (mounted) {
        setState(() => _isLoadingEvents = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이벤트 로딩 오류: $e'), backgroundColor: Colors.red),
        );
      }
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
      _floorStatuses.clear();
      _floorStatusSetBy.clear();
      _adminStatuses.clear();
      _remarks.clear();
    });

    final event = _events.firstWhere(
      (e) => e['id'] == eventId,
      orElse: () => {},
    );
    final roomNumber = event['roomNumber'] as String?;
    final isFloorWide = event['isFloorWide'] == true;
    final eventFloor = event['floor'] as String?;

    try {
      // 호실 학생 로드 (1회) — dormBuilding 필터로 같은 호실번호의 타 기숙사 학생 제외
      final dormBuilding =
          _assignedFloor != null ? _dormBuildingOf(_assignedFloor!) : null;
      List<Map<String, dynamic>> students = [];
      List<String> floorAllRooms = [];
      if (isFloorWide && eventFloor != null && eventFloor.isNotEmpty) {
        final result = await _loadStudentsForFloor(eventFloor);
        students = result.students;
        floorAllRooms = result.allRoomNumbers;
      } else if (roomNumber != null && roomNumber.isNotEmpty) {
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
      final savedFloorStatuses =
          (eventDoc.data()?['floorStatuses'] as Map<String, dynamic>?) ?? {};
      final savedFloorStatusSetBy =
          (eventDoc.data()?['floorStatusSetBy'] as Map<String, dynamic>?) ?? {};
      final savedAdminStatuses =
          (eventDoc.data()?['adminStatuses'] as Map<String, dynamic>?) ?? {};
      final savedRemarks =
          (eventDoc.data()?['remarks'] as Map<String, dynamic>?) ?? {};

      if (!mounted) return;
      setState(() {
        _roomStudents = students;
        _updateRoomUnregisteredStudents(
          roomNumber,
          isFloorWide: isFloorWide,
          floorRoomNumbers: floorAllRooms.toSet(),
          // 구역 전체 이벤트는 이벤트의 구역에서, 호실별은 담당 구역에서 건물을 판별한다.
          dormBuilding: isFloorWide && eventFloor != null && eventFloor.isNotEmpty
              ? _dormBuildingOf(eventFloor)
              : dormBuilding,
        );
        savedFloorStatuses.forEach((uid, st) {
          _floorStatuses[uid] = st as String?;
        });
        savedFloorStatusSetBy.forEach((uid, email) {
          _floorStatusSetBy[uid] = email as String?;
        });
        savedAdminStatuses.forEach((uid, st) {
          _adminStatuses[uid] = st as String?;
        });
        savedRemarks.forEach((uid, remark) {
          _remarks[uid] = remark as String?;
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
      debugPrint('임원점검 기록 로딩 오류: $e');
      if (mounted) setState(() => _isLoadingRecords = false);
    }
  }

  @override
  void dispose() {
    _recordsSubscription?.cancel();
    _eventScrollController.dispose();
    super.dispose();
  }

  void _selectStatus(String userId, String? status) {
    setState(() => _floorStatuses[userId] = status);
    final eventId = _selectedEventId;
    if (eventId == null) return;
    final currentUser = FirebaseAuth.instance.currentUser;
    final email = currentUser?.email;
    final uid = currentUser?.uid;
    // 층장 이름 비동기 조회 후 저장
    Future(() async {
      String? name;
      if (uid != null) {
        try {
          final doc = await _firestore.collection('users').doc(uid).get();
          name = doc.data()?['name'] as String?;
        } catch (_) {}
      }
      await _firestore.collection('attendance_events').doc(eventId).update({
        'floorStatuses.$userId': status ?? FieldValue.delete(),
        'floorStatusSetBy.$userId': status != null ? email : FieldValue.delete(),
        'floorStatusSetByName.$userId': status != null ? (name ?? email) : FieldValue.delete(),
      });
    });
  }

  Future<void> _saveRemark(String userId, String? remark) async {
    final eventId = _selectedEventId;
    if (eventId == null) return;
    final trimmed = remark?.trim();
    setState(() => _remarks[userId] = (trimmed?.isEmpty ?? true) ? null : trimmed);
    await _firestore.collection('attendance_events').doc(eventId).update({
      'remarks.$userId':
          (trimmed?.isEmpty ?? true) ? FieldValue.delete() : trimmed,
    });
  }

  void _showRemarkDialog(String userId, String studentName) {
    final controller = TextEditingController(text: _remarks[userId] ?? '');
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$studentName 비고'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '비고를 입력하세요',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              _saveRemark(userId, controller.text);
              Navigator.pop(dialogContext);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  String _generateToken() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateEventDialog,
        icon: const Icon(Icons.add),
        label: const Text('인원점검 추가'),
      ),
      body: Column(
        children: [
          if (!_isLoadingEvents && _events.isNotEmpty) _buildSelectionBar(),
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

  Widget _buildSelectionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_isSelectionMode) ...[
                Checkbox(
                  value: _events.isNotEmpty &&
                      _selectedEventIds.length == _events.length,
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _selectedEventIds
                        ..clear()
                        ..addAll(_events.map((e) => e['id'] as String));
                    } else {
                      _selectedEventIds.clear();
                    }
                  }),
                ),
                const SizedBox(width: 4),
                Text(
                  '${_selectedEventIds.length}개 선택',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 30,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange.withValues(alpha: 0.1),
                      foregroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: _selectedEventIds.isEmpty ? null : _closeSelectedEvents,
                    child: const Text('선택 종료', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                height: 30,
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _isSelectionMode = !_isSelectionMode;
                    _selectedEventIds.clear();
                  }),
                  child: Text(
                    _isSelectionMode ? '취소' : '스케줄 종료',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _closeSelectedEvents() async {
    if (_selectedEventIds.isEmpty) return;
    // 처리 중 재진입(중복 종료) 방지
    if (_isClosingEvents) return;
    final count = _selectedEventIds.length;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('스케줄 종료'),
        content: Text('선택한 $count개 스케줄을 종료하시겠습니까?'),
        actions: [
          TextButton(child: const Text('취소'), onPressed: () => Navigator.pop(ctx, false)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('종료'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (result != true) return;
    try {
      final batch = _firestore.batch();
      for (final eventId in _selectedEventIds) {
        batch.update(_firestore.collection('attendance_events').doc(eventId), {'status': 'closed'});
      }
      await batch.commit();

      setState(() {
        _selectedEventIds.clear();
        _isSelectionMode = false;
      });
      _loadEvents(showLoading: false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count개 스케줄이 종료되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('종료 실패: $e')),
        );
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            '등록된 인원점검 스케줄이 없습니다',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _showCreateEventDialog,
            icon: const Icon(Icons.add),
            label: const Text('인원점검 추가'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadAssignedFloorThenEvents,
      child: ListView.builder(
        controller: _eventScrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _events.length,
        itemBuilder: (context, index) => _buildEventCard(_events[index]),
      ),
    );
  }


  Widget _buildEventCard(Map<String, dynamic> event) {
    final eventId = event['id'] as String;
    final title = event['title'] ?? '제목 없음';
    final status = event['status'] ?? 'active';
    final createdAt = (event['createdAt'] as Timestamp?)?.toDate();
    final roomNumber = event['roomNumber'] as String?;
    final floor = (event['floor'] as String?) ?? _assignedFloor ?? '';
    final isFloorWide = event['isFloorWide'] == true;
    final isFireDrill = event['isFireDrill'] == true;
    final isSelected = _selectedEventId == eventId;

    final isActive = status == 'active';

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
                  onTap: () {
                    if (_isSelectionMode) {
                      setState(() {
                        if (_selectedEventIds.contains(eventId)) {
                          _selectedEventIds.remove(eventId);
                        } else {
                          _selectedEventIds.add(eventId);
                        }
                      });
                      return;
                    }
                    _loadRecords(eventId);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(_isSelectionMode ? 48 : 21, 16, 16, 16),
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
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isFireDrill
                                    ? Colors.red.withValues(alpha: 0.1)
                                    : Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isFireDrill ? '화재대피훈련' : '일반 인원점검',
                                style: TextStyle(
                                  color: isFireDrill ? Colors.red : Colors.blue,
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
                              icon: const Icon(Icons.qr_code_scanner, color: Colors.blue),
                              onPressed: () => _openQrScanner(
                                eventId,
                                title,
                                roomNumber: roomNumber,
                                isFireDrill: isFireDrill,
                                isArrivalStage: _fireDrillArrivalMode[eventId] ?? false,
                              ),
                              tooltip: 'QR 코드 스캔',
                            ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'toggle') {
                                _toggleEventStatus(eventId, status);
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
                        if (floor.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.indigo.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 12, color: Colors.indigo),
                                  const SizedBox(width: 3),
                                  Text(
                                    floor,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.indigo,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  if (roomNumber != null && roomNumber.isNotEmpty) ...[
                                    Text(
                                      '$roomNumber호',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        if (isFireDrill)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildFireDrillStageButton(
                                    eventId: eventId,
                                    label: '1차',
                                    selected: !(_fireDrillArrivalMode[eventId] ?? false),
                                    onTap: () => setState(() => _fireDrillArrivalMode[eventId] = false),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _buildFireDrillStageButton(
                                    eventId: eventId,
                                    label: '2차',
                                    selected: _fireDrillArrivalMode[eventId] ?? false,
                                    onTap: () => setState(() => _fireDrillArrivalMode[eventId] = true),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            const SizedBox(width: 8),
                            if (createdAt != null)
                              Text(
                                DateFormat('yyyy-MM-dd HH:mm').format(createdAt),
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            const Spacer(),
                            Builder(builder: (_) {
                              final attended = _eventAttendedCounts[eventId] ?? 0;
                              final total = isFloorWide
                                  ? (_floorStudentCounts[floor] ?? 0)
                                  : (roomNumber != null
                                      ? (_roomStudentCounts[roomNumber] ?? 0)
                                      : 0);
                              final isComplete = total > 0 && attended >= total;
                              final color = isComplete ? Colors.green : Colors.orange;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: color.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  '$attended / $total명 인원점검 확인',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                              );
                            }),
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
          if (_isSelectionMode)
            Positioned(
              left: 4,
              top: 12,
              child: Checkbox(
                value: _selectedEventIds.contains(eventId),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selectedEventIds.add(eventId);
                  } else {
                    _selectedEventIds.remove(eventId);
                  }
                }),
              ),
            ),
        ],
      ),
    );
  }

  // 화재대피용 이벤트 카드의 "대피 시작"/"대피 도착" 모드 선택 버튼.
  // 선택된 모드는 _fireDrillArrivalMode에 저장되고, QR 스캔 버튼을 누를 때 그대로 전달된다.
  Widget _buildFireDrillStageButton({
    required String eventId,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.red.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? Colors.red : Colors.grey.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? Colors.red : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildUnregisteredStudentTile(ExcelStudentRow student) {
    final name = student.name?.trim() ?? '이름 없음';
    final studentId = student.studentId?.trim() ?? '';
    final seatNumber = student.seatNumber?.trim() ?? '';
    final roomNumber = student.roomNumber?.trim() ?? '';

    return Container(
      color: Colors.grey.withValues(alpha: 0.04),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.person_off_outlined, color: Colors.grey.shade400, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  seatNumber.isNotEmpty ? '$name (자리 $seatNumber)' : name,
                  style: TextStyle(fontWeight: FontWeight.normal, color: Colors.grey.shade700),
                ),
                if (roomNumber.isNotEmpty)
                  Text(
                    '$roomNumber호',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                if (studentId.isNotEmpty)
                  Text(
                    studentId,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '앱 미가입 (엑셀 기준)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
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

    // 이벤트가 종료되면 상태를 더 이상 변경할 수 없다.
    final selectedEvent = _events.firstWhere(
      (e) => e['id'] == _selectedEventId,
      orElse: () => {},
    );
    final isEventClosed = (selectedEvent['status'] as String?) != 'active';
    final isFireDrillEvent = selectedEvent['isFireDrill'] == true;

    // 출석한 userId 세트 (부재/외박/외박미수정 등 상태 기록은 실제 출석이 아니므로 제외.
    // 화재대피용 1차 스캔만 한(대피 시작만 확인, isComplete == false) 기록도 아직 출석 미완료로 제외한다.)
    final attendedIds = _records
        .where((r) => r['recordType'] != 'status' && r['isComplete'] != false)
        .map((r) => r['userId'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    // 호실 학생이 있으면 전체 목록, 없으면 출석 기록만
    final showStudentList =
        _roomStudents.isNotEmpty || _roomUnregisteredStudents.isNotEmpty;

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
                  '인원점검 현황',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
          if (showStudentList)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _roomStudents.length + _roomUnregisteredStudents.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, index) {
                if (index >= _roomStudents.length) {
                  final excelRow =
                      _roomUnregisteredStudents[index - _roomStudents.length];
                  return _buildUnregisteredStudentTile(excelRow);
                }
                final s = _roomStudents[index];
                final uid = s['id'] as String;
                final name = s['name'] as String? ?? '이름 없음';
                final studentId = s['studentId'] as String? ?? '';
                final seatNumber = s['seatNumber'] as String? ?? '';
                final roomNumber = s['roomNumber'] as String? ?? '';
                final residentStatus = (s['residentStatus'] as String?) ?? '재실중';
                final isBlocked = _blockedStatuses.contains(residentStatus);
                final blockedColor = _blockedStatusColors[residentStatus] ?? Colors.grey;
                final isPresent = attendedIds.contains(uid);
                final record = _records.firstWhere(
                  (r) => r['userId'] == uid && r['recordType'] != 'status',
                  orElse: () => {},
                );
                final checkedAt =
                    (record['checkedInAt'] as Timestamp?)?.toDate();
                final arrivalCheckedAt =
                    (record['arrivalCheckedAt'] as Timestamp?)?.toDate();
                // 화재대피용: 1차와 2차 중 하나만 확인된 상태(둘 다 있어야 출석 완료).
                final hasStartedOnly =
                    record.isNotEmpty && record['isComplete'] == false;

                final adminStatus = _adminStatuses[uid];
                final floorStatus = _floorStatuses[uid];
                final floorStatusSetBy = _floorStatusSetBy[uid];
                final hasAdminStatus = adminStatus != null && adminStatus.isNotEmpty;
                final adminStatusColor = _statusColors[adminStatus] ?? Colors.grey;
                final floorStatusColor = _statusColors[floorStatus] ?? Colors.grey;
                final remark = _remarks[uid];

                return Container(
                  color: isBlocked ? blockedColor.withValues(alpha: 0.05) : null,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          isBlocked
                              ? Icons.block
                              : isPresent
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                          color: isBlocked
                              ? blockedColor
                              : isPresent
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
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    seatNumber.isNotEmpty ? '$name (자리 $seatNumber)' : name,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: isPresent ? FontWeight.bold : FontWeight.normal,
                                      color: isBlocked
                                          ? blockedColor
                                          : isPresent
                                              ? Colors.black87
                                              : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                if (roomNumber.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '$roomNumber호',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500),
                                  ),
                                ],
                              ],
                            ),
                            if (studentId.isNotEmpty)
                              Text(
                                studentId,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500),
                              ),
                            if (isBlocked) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: blockedColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: blockedColor.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  residentStatus,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: blockedColor,
                                  ),
                                ),
                              ),
                            ] else ...[
                              if (hasStartedOnly) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: Colors.orange.withValues(alpha: 0.5)),
                                      ),
                                      child: Text(
                                        checkedAt != null ? '1차 확인' : '2차 확인',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      checkedAt != null
                                          ? DateFormat('HH:mm').format(checkedAt.toSeoul())
                                          : '1차 미확인',
                                      style: TextStyle(
                                          color: Colors.orange.shade800,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    if (checkedAt == null && arrivalCheckedAt != null) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        '2차 ${DateFormat('HH:mm').format(arrivalCheckedAt.toSeoul())}',
                                        style: TextStyle(
                                            color: Colors.orange.shade800,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                              if (hasAdminStatus) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: adminStatusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: adminStatusColor.withValues(alpha: 0.5)),
                                  ),
                                  child: Text(
                                    '불참인정완료',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: adminStatusColor,
                                    ),
                                  ),
                                ),
                              ],
                              if (!isPresent && !isFireDrillEvent) ...[
                                const SizedBox(height: 6),
                                DropdownButtonHideUnderline(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: floorStatus != null
                                          ? floorStatusColor.withValues(alpha: 0.1)
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: floorStatus != null
                                            ? floorStatusColor.withValues(alpha: 0.5)
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: DropdownButton<String?>(
                                      value: floorStatus,
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
                                        color: floorStatus != null
                                            ? floorStatusColor
                                            : Colors.grey.shade700,
                                      ),
                                      items: [
                                        DropdownMenuItem<String?>(
                                          value: null,
                                          child: Text(
                                            '선택 안함',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade500),
                                          ),
                                        ),
                                        ..._statusOptions.map((st) =>
                                            DropdownMenuItem<String?>(
                                              value: st,
                                              child: Text(
                                                st,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: _statusColors[st] ??
                                                      Colors.grey,
                                                ),
                                              ),
                                            )),
                                      ],
                                      onChanged: isEventClosed
                                          ? null
                                          : (val) => _selectStatus(uid, val),
                                    ),
                                  ),
                                ),
                                if (floorStatus != null && floorStatusSetBy != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '처리: $floorStatusSetBy',
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.grey.shade500),
                                  ),
                                ],
                              ],
                            ],
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: isEventClosed
                                  ? null
                                  : () => _showRemarkDialog(uid, name),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.edit_note,
                                    size: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      remark != null && remark.isNotEmpty
                                          ? remark
                                          : '비고 추가',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: remark != null && remark.isNotEmpty
                                            ? Colors.grey.shade700
                                            : Colors.grey.shade400,
                                        fontStyle: remark != null && remark.isNotEmpty
                                            ? FontStyle.normal
                                            : FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isBlocked && isPresent)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: isFireDrillEvent
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: Colors.green.withValues(alpha: 0.5)),
                                      ),
                                      child: Text(
                                        '2차',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      checkedAt != null
                                          ? '1차 ${DateFormat('HH:mm').format(checkedAt.toSeoul())}'
                                          : '1차 미확인',
                                      style: TextStyle(
                                        color: checkedAt != null
                                            ? Colors.grey.shade600
                                            : Colors.orange.shade800,
                                        fontSize: 11,
                                        fontWeight: checkedAt != null
                                            ? FontWeight.normal
                                            : FontWeight.bold,
                                      ),
                                    ),
                                    if (arrivalCheckedAt != null) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        '2차 ${DateFormat('HH:mm').format(arrivalCheckedAt.toSeoul())}',
                                        style: TextStyle(
                                            color: Colors.green.shade700,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ],
                                )
                              : (checkedAt != null
                                  ? Text(
                                      DateFormat('HH:mm').format(checkedAt.toSeoul()),
                                      style: TextStyle(
                                          color: Colors.green.shade700,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold),
                                    )
                                  : const SizedBox.shrink()),
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
                '인원점검 기록이 없습니다',
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
    final uid = record['userId'] as String? ?? '';
    final userName = record['userName'] ?? '이름 없음';
    final roomNumber = record['roomNumber'] ?? '';
    final dormBuilding = (record['dormBuilding'] as String?)?.isNotEmpty == true
        ? record['dormBuilding'] as String
        : (record['building'] as String? ?? '');
    final checkedAt = (record['checkedInAt'] as Timestamp?)?.toDate();

    final studentData = _roomStudents.firstWhere(
      (s) => s['id'] == uid,
      orElse: () => {},
    );
    final seatNumber = studentData['seatNumber'] as String? ?? '';
    final displayName = seatNumber.isNotEmpty ? '$userName (자리 $seatNumber)' : userName;

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
          Text(displayName, style: const TextStyle(fontWeight: FontWeight.w500)),
          if (dormBuilding.isNotEmpty || roomNumber.isNotEmpty)
            Text(
              ' (${[if (dormBuilding.isNotEmpty) dormBuilding, if (roomNumber.isNotEmpty) '$roomNumber호'].join(' ')})',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
        ],
      ),
      trailing: checkedAt != null
          ? Text(
              DateFormat('HH:mm:ss').format(checkedAt.toSeoul()),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            )
          : null,
    );
  }

  void _openQrScanner(
    String eventId,
    String eventTitle, {
    String? roomNumber,
    bool isFireDrill = false,
    bool isArrivalStage = false,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _QrScannerPage(
          eventTitle: eventTitle,
          isFireDrill: isFireDrill,
          isArrivalStage: isArrivalStage,
          onScanned: (String qrData) => _processScannedStudent(
            eventId,
            roomNumber,
            qrData,
            isFireDrill: isFireDrill,
            isArrivalStage: isArrivalStage,
          ),
        ),
      ),
    );
  }

  /// QR 체크가 기록되면 그 학생 호실의 층장 단톡방에 알림 메시지를 남긴다.
  /// 출석 처리와는 별개이므로 실패해도 스캔 결과에는 영향을 주지 않는다.
  Future<void> _postCheckInToRoomChat({
    required Map<String, dynamic> student,
    required String studentName,
    required String eventTitle,
    required String stageLabel,
  }) async {
    final captainUid = FirebaseAuth.instance.currentUser?.uid;
    final dorm = student['dormBuilding'] as String? ?? '';
    final wing = student['building'] as String? ?? '';
    final room = student['roomNumber'] as String? ?? '';
    if (captainUid == null || dorm.isEmpty || room.isEmpty || room == '000') return;
    // message_screen.dart의 _toRoomId와 같은 규칙 (바롬인성교육관은 동 구분이 없다).
    final roomId = wing.isEmpty ? '${dorm}_$room호' : '${dorm}_${wing}_$room호';
    final text = '[인원점검] $studentName($room호) $stageLabel · $eventTitle';
    try {
      final chat = _firestore.collection('floor_chats').doc(roomId);
      await chat.collection('messages').add({
        'text': text,
        'senderId': captainUid,
        'senderName': '층장(${_assignedFloor ?? ''})',
        'roomNumber': '층장',
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': [captainUid],
      });
      await chat.set({
        'lastMessage': text,
        'lastAt': FieldValue.serverTimestamp(),
        'roomId': roomId,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('인원점검 단톡방 알림 실패: $e');
    }
  }

  /// 학생 QR("student:{studentId}")을 스캔한 결과를 검증하고 출석 기록을 남긴다.
  /// 반환값은 스캐너 화면에 보여줄 결과 메시지(성공 시 학생 이름, 실패 시 오류 메시지)이다.
  ///
  /// isFireDrill=true(화재대피용) 이벤트는 QR을 2회 스캔해야 출석이 확정된다.
  /// isArrivalStage=false: 1차 스캔(대피 시작 확인) — 기록만 생성, 아직 미완료.
  /// isArrivalStage=true: 2차 스캔(대피 도착 확인) — 기존 기록을 완료로 확정.
  Future<_ScanResult> _processScannedStudent(
    String eventId,
    String? eventRoomNumber,
    String qrData, {
    bool isFireDrill = false,
    bool isArrivalStage = false,
  }) async {
    // QR 형식: "student:{studentId}:{issuedAtMs}"
    if (!qrData.startsWith('student:')) {
      return const _ScanResult(success: false, message: '유효하지 않은 QR 코드입니다');
    }
    final parts = qrData.split(':');
    if (parts.length != 3) {
      return const _ScanResult(success: false, message: '유효하지 않은 QR 코드입니다');
    }
    final studentId = parts[1];
    final issuedAtMs = int.tryParse(parts[2]);
    if (studentId.isEmpty || issuedAtMs == null) {
      return const _ScanResult(success: false, message: '유효하지 않은 QR 코드입니다');
    }
    // 학생앱도 서버 시각으로 발급하므로 여기서도 서버 시각으로 비교한다.
    // 화면 진입 시 동기화가 실패했으면(네트워크 지연 등) 여기서 한 번 더 시도한다.
    if (!ServerClock.isSynced) await ServerClock.sync();
    // 학생앱은 5초마다 QR을 갱신하지만, 카메라가 느린 폰의 스캔 지연과 양쪽 동기화의
    // 네트워크 왕복 오차를 흡수하도록 층장앱은 발급 후 8초, 앞선 시각은 3초까지 허용한다.
    final elapsedSeconds = (ServerClock.nowMs() - issuedAtMs) / 1000;
    if (elapsedSeconds > 8 || elapsedSeconds < -3) {
      return const _ScanResult(success: false, message: '만료된 QR 코드입니다. 학생에게 QR을 다시 열어달라고 요청하세요');
    }

    try {
      final eventDoc = await _firestore.collection('attendance_events').doc(eventId).get();
      if (!eventDoc.exists) {
        return const _ScanResult(success: false, message: '존재하지 않는 이벤트입니다');
      }
      final eventData = eventDoc.data()!;
      if ((eventData['status'] as String?) != 'active') {
        return const _ScanResult(success: false, message: '종료된 이벤트입니다');
      }

      final studentSnap = await _firestore
          .collection('users')
          .where('studentId', isEqualTo: studentId)
          .where('role', isEqualTo: 'student')
          .limit(2)
          .get();
      if (studentSnap.docs.isEmpty) {
        return const _ScanResult(success: false, message: '학생 정보를 찾을 수 없습니다');
      }
      if (studentSnap.docs.length > 1) {
        // 동일 studentId로 가입된 계정이 2개 이상 존재 — 잘못된 계정으로 출석 처리될 위험이 있어
        // 관리자가 중복 계정을 정리하기 전까지는 자동 처리하지 않고 명확히 거부한다.
        return _ScanResult(
          success: false,
          message: '학번($studentId) 계정이 중복 등록되어 있습니다. 관리자에게 문의하세요',
        );
      }
      final studentDoc = studentSnap.docs.first;
      final student = studentDoc.data();
      final uid = studentDoc.id;
      final residentStatus = (student['residentStatus'] as String?) ?? '재실중';
      if (_blockedStatuses.contains(residentStatus)) {
        return _ScanResult(success: false, message: '현재 상태($residentStatus)로는 인원점검이 불가능합니다');
      }

      // 관리자가 이 이벤트에서 이미 외박(화재대피훈련은 불참인정)으로 열외 처리한 학생은
      // QR 체크가 그 처리와 모순되므로 스캔 자체를 막는다.
      final adminStatuses = (eventData['adminStatuses'] as Map<String, dynamic>?) ?? {};
      final exemptStatus = isFireDrill ? '불참인정' : '외박';
      if (adminStatuses[uid] == exemptStatus) {
        final name = student['name'] as String? ?? '';
        return _ScanResult(
          success: false,
          message: '$name님은 이미 $exemptStatus 처리되어 인원점검을 할 수 없습니다',
        );
      }

      if (eventRoomNumber != null && eventRoomNumber.isNotEmpty) {
        final studentRoom = student['roomNumber'] as String? ?? '';
        if (studentRoom != eventRoomNumber) {
          return _ScanResult(
            success: false,
            message: '$eventRoomNumber호 인원점검 이벤트입니다. 학생 호실($studentRoom호)과 일치하지 않습니다',
          );
        }
      }

      // 구역 전체 이벤트는 층마다 별도로 만들어지므로, 다른 층 층장이 스캔하면 그 층의
      // 이벤트에 기록이 갈라져 화재대피 1차/2차가 한 기록으로 합쳐지지 않는다.
      // 학생이 이 이벤트의 구역(건물·동·층) 소속일 때만 허용한다.
      final eventFloor = eventData['floor'] as String?;
      if (eventData['isFloorWide'] == true && eventFloor != null && eventFloor.isNotEmpty) {
        final studentRoom = student['roomNumber'] as String? ?? '';
        final studentDorm = student['dormBuilding'] as String? ?? '';
        final eventDorm = _dormBuildingOf(eventFloor);
        // 호실 범위 계산은 '(방학)' 표기가 없는 건물명 기준이다.
        final floorRooms = _AttendanceHistoryContentState._roomsForFloor(
            eventFloor.replaceFirst('(방학)', ''));
        // 학생 프로필의 건물명은 방학 기간에 '샬롬하우스(방학)'처럼 남아 있을 수 있으므로
        // '(방학)' 표기는 무시하고 건물만 비교한다.
        String normDorm(String s) => s.replaceAll('(방학)', '').trim();
        final dormMismatch = eventDorm != null &&
            studentDorm.isNotEmpty &&
            normDorm(studentDorm) != normDorm(eventDorm);
        // 호실 범위를 알 수 없는 구역(바롬인성교육관 등)은 건물 일치만 확인한다.
        final roomMismatch = floorRooms.isNotEmpty && !floorRooms.contains(studentRoom);
        if (dormMismatch || roomMismatch) {
          return _ScanResult(
            success: false,
            message: '$eventFloor 인원점검 이벤트입니다. '
                '학생 구역($studentDorm $studentRoom호)과 일치하지 않습니다. '
                '담당 층장에게 QR을 보여주도록 안내하세요',
          );
        }
      }

      final existing = await _firestore
          .collection('attendance_records')
          .where('userId', isEqualTo: uid)
          .where('eventId', isEqualTo: eventId)
          .get();
      final existingDoc = existing.docs.firstOrNull;
      final existingIsComplete = existingDoc?.data()['isComplete'] != false;
      final studentName = student['name'] ?? '';

      if (!isFireDrill) {
        if (existingDoc != null) {
          return _ScanResult(success: false, message: '$studentName님은 이미 인원점검을 완료했습니다');
        }
        final batch = _firestore.batch();
        final recordRef = _firestore.collection('attendance_records').doc();
        batch.set(recordRef, {
          'eventId': eventId,
          'eventTitle': eventData['title'] ?? '',
          'userId': uid,
          'userName': studentName,
          'studentId': studentId,
          'roomNumber': student['roomNumber'] ?? '',
          'dormBuilding': student['dormBuilding'] ?? '',
          'checkedInAt': Timestamp.now(),
          'isComplete': true,
          'isFireDrill': false,
        });
        final eventRef = _firestore.collection('attendance_events').doc(eventId);
        batch.update(eventRef, {'attendeeCount': FieldValue.increment(1)});
        await batch.commit();

        _postCheckInToRoomChat(
          student: student,
          studentName: studentName,
          eventTitle: (eventData['title'] as String?) ?? '인원점검',
          stageLabel: '인원점검 완료',
        );
        _loadEvents(showLoading: false);
        if (_selectedEventId == eventId) {
          _loadRecords(eventId);
        }
        return _ScanResult(success: true, message: '$studentName님 인원점검 완료');
      }

      // 화재대피용: 2회 스캔(대피 시작 → 대피 도착)이 모두 있어야 출석 확정.
      if (!isArrivalStage) {
        // 1차: 대피 시작 확인
        if (existingDoc != null) {
          return _ScanResult(
            success: false,
            message: existingIsComplete
                ? '$studentName님은 이미 인원점검을 완료했습니다'
                : '$studentName님은 이미 1차를 확인했습니다',
          );
        }
        final recordRef = _firestore.collection('attendance_records').doc();
        await recordRef.set({
          'eventId': eventId,
          'eventTitle': eventData['title'] ?? '',
          'userId': uid,
          'userName': studentName,
          'studentId': studentId,
          'roomNumber': student['roomNumber'] ?? '',
          'dormBuilding': student['dormBuilding'] ?? '',
          'checkedInAt': Timestamp.now(),
          'isComplete': false,
          'isFireDrill': true,
        });

        _postCheckInToRoomChat(
          student: student,
          studentName: studentName,
          eventTitle: (eventData['title'] as String?) ?? '인원점검',
          stageLabel: '1차(대피 시작) 확인',
        );
        _loadEvents(showLoading: false);
        if (_selectedEventId == eventId) {
          _loadRecords(eventId);
        }
        return _ScanResult(success: true, message: '$studentName님 1차 확인');
      } else {
        // 2차: 대피 도착 확인. 1차(checkedInAt)까지 있어야 출석 완료로 인정한다.
        if (existingDoc != null) {
          if (existingIsComplete) {
            return _ScanResult(success: false, message: '$studentName님은 이미 인원점검을 완료했습니다');
          }
          // 이 시점의 existingDoc은 1차만 확인된 기록(checkedInAt 있음, isComplete=false)이므로
          // 2차까지 확인되면 정상적으로 출석 완료로 처리한다.
          final batch = _firestore.batch();
          batch.update(existingDoc.reference, {
            'arrivalCheckedAt': Timestamp.now(),
            'isComplete': true,
          });
          final eventRef = _firestore.collection('attendance_events').doc(eventId);
          batch.update(eventRef, {'attendeeCount': FieldValue.increment(1)});
          await batch.commit();

          _postCheckInToRoomChat(
            student: student,
            studentName: studentName,
            eventTitle: (eventData['title'] as String?) ?? '인원점검',
            stageLabel: '2차(대피 도착) 확인 · 인원점검 완료',
          );
          _loadEvents(showLoading: false);
          if (_selectedEventId == eventId) {
            _loadRecords(eventId);
          }
          return _ScanResult(success: true, message: '$studentName님 인원점검 완료');
        } else {
          // 1차 확인 없이 2차만 스캔한 경우: checkedInAt이 없으므로 출석 미완료로 남긴다.
          await _firestore.collection('attendance_records').add({
            'eventId': eventId,
            'eventTitle': eventData['title'] ?? '',
            'userId': uid,
            'userName': studentName,
            'studentId': studentId,
            'roomNumber': student['roomNumber'] ?? '',
            'dormBuilding': student['dormBuilding'] ?? '',
            'arrivalCheckedAt': Timestamp.now(),
            'isComplete': false,
            'isFireDrill': true,
          });

          _postCheckInToRoomChat(
            student: student,
            studentName: studentName,
            eventTitle: (eventData['title'] as String?) ?? '인원점검',
            stageLabel: '2차(대피 도착) 확인 (1차 미확인)',
          );
          _loadEvents(showLoading: false);
          if (_selectedEventId == eventId) {
            _loadRecords(eventId);
          }
          return _ScanResult(
            success: true,
            message: '$studentName님 2차 확인 (1차 미확인으로 인원점검 미완료)',
          );
        }
      }
    } catch (e) {
      return _ScanResult(success: false, message: '오류: $e');
    }
  }

  /// 구역(floor) 전체의 재실 학생을 조회한다. 퇴사 등 재실중이 아닌 학생은 제외한다.
  Future<({List<Map<String, dynamic>> students, List<String> occupiedRooms, List<String> allRoomNumbers})> _loadStudentsForFloor(
    String floor,
  ) async {
    final roomMap = await _loadRoomsForFloor(floor);
    final occupiedRooms = roomMap.entries.where((e) => e.value).map((e) => e.key).toList();
    final allRoomNumbers = roomMap.keys.toList();
    final dormBuilding = _dormBuildingOf(floor);
    final students = <Map<String, dynamic>>[];
    if (occupiedRooms.isNotEmpty && dormBuilding != null) {
      // whereIn은 최대 30개까지만 지원하므로 청크로 나눠 조회한다.
      for (var i = 0; i < occupiedRooms.length; i += 30) {
        final chunk = occupiedRooms.sublist(i, (i + 30).clamp(0, occupiedRooms.length));
        final studentsSnap = await _firestore
            .collection('users')
            .where('dormBuilding', isEqualTo: dormBuilding)
            .where('roomNumber', whereIn: chunk)
            .where('role', isEqualTo: 'student')
            .get();
        students.addAll(studentsSnap.docs.where((doc) {
          final data = doc.data();
          final residentStatus = (data['residentStatus'] as String?) ?? '재실중';
          return !_blockedStatuses.contains(residentStatus);
        }).map((doc) => {'id': doc.id, ...doc.data()}));
      }
    }
    students.sort((a, b) {
      // 바롬 '1001-A' 형식도 자연스럽게 정렬되도록 문자열 비교를 우선한다.
      final rawA = (a['roomNumber'] as String?) ?? '';
      final rawB = (b['roomNumber'] as String?) ?? '';
      final roomA = int.tryParse(rawA.split('-').first);
      final roomB = int.tryParse(rawB.split('-').first);
      if (roomA != null && roomB != null && roomA != roomB) {
        return roomA.compareTo(roomB);
      }
      if (rawA != rawB) return rawA.compareTo(rawB);
      return (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? '');
    });
    return (students: students, occupiedRooms: occupiedRooms, allRoomNumbers: allRoomNumbers);
  }

  // 반환값: 호실번호 -> 거주 학생 존재 여부 (전체 호실을 보여주되 체크 초기값 결정용)
  Future<Map<String, bool>> _loadRoomsForFloor([String? targetFloor]) async {
    final floor = targetFloor ?? _assignedFloor;
    if (floor == null) return {};
    final dormBuilding = floor.split(' ').firstOrNull ?? '';
    final buildingMatch = RegExp(r'([AB])동').firstMatch(floor);
    final floorMatch = RegExp(r'(\d+)층').firstMatch(floor);
    final building = buildingMatch?.group(1); // 'A' or 'B'
    final floorNum = floorMatch != null ? int.tryParse(floorMatch.group(1)!) : null;

    if (floorNum == null) return {};

    List<String> candidateRooms = [];

    if (dormBuilding == '샬롬하우스') {
      // A동: floor×100 + 01~20 / B동: floor×100 + 21~35
      // 단, A동 1층은 107~109호만 존재하는 예외 구역
      if (building == 'A' && floorNum == 1) {
        candidateRooms = const ['107', '108', '109'];
      } else if (building == 'A') {
        candidateRooms = List.generate(20, (i) => '${floorNum * 100 + i + 1}');
      } else if (building == 'B') {
        candidateRooms = List.generate(15, (i) => '${floorNum * 100 + 21 + i}');
      }
    } else if (dormBuilding == '국제생활관') {
      // A동 1층: 101~132 / A동 2층: 201~229
      // B동 2층: 233~260 / B동 3층: 301~329
      if (building == 'A' && floorNum == 1) {
        candidateRooms = List.generate(32, (i) => '${101 + i}');
      } else if (building == 'A' && floorNum == 2) {
        candidateRooms = List.generate(29, (i) => '${201 + i}');
      } else if (building == 'B' && floorNum == 2) {
        candidateRooms = List.generate(28, (i) => '${233 + i}');
      } else if (building == 'B' && floorNum == 3) {
        candidateRooms = List.generate(29, (i) => '${301 + i}');
      }
    }

    // Firestore에서 실제 거주 학생이 있는 호실 조회
    final snap = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'student')
        .where('dormBuilding', isEqualTo: dormBuilding)
        .get();
    final occupiedRooms = <String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final r = data['roomNumber'] as String? ?? '';
      if (r.isEmpty || r == '000') continue;
      final residentStatus = (data['residentStatus'] as String?) ?? '재실중';
      if (residentStatus != '재실중') continue;
      if (dormBuilding == '바롬인성교육관') {
        // 바롬 호실은 '1001-A' 형식 → '-' 앞 숫자로 층 판정
        final n = int.tryParse(r.split('-').first);
        if (n != null && n ~/ 100 == floorNum) occupiedRooms.add(r);
      } else {
        occupiedRooms.add(r);
      }
    }

    if (dormBuilding == '바롬인성교육관') {
      // 물리적 전체 호실 범위가 없으므로 재실 이력이 있는 호실만 후보로 사용
      candidateRooms = occupiedRooms.toList()
        ..sort((a, b) => a.compareTo(b));
    }

    return {for (final r in candidateRooms) r: occupiedRooms.contains(r)};
  }

  void _showCreateEventDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _RoomEventCreateDialog(
        initialFloor: _assignedFloor ?? kFloorOptions.first,
        loadRoomsForFloor: _loadRoomsForFloor,
        onCreateFloorWide: (title, selectedFloor, isFireDrill) async {
          Navigator.pop(ctx);
          await _createFloorWideEvent(title, floor: selectedFloor, isFireDrill: isFireDrill);
        },
      ),
    );
  }

  /// 구역(floor) 전체 재실 학생을 대상으로 하는 통합 이벤트 1개를 생성한다.
  /// (호실별로 여러 이벤트를 만드는 기존 방식과 달리 roomNumber를 두지 않는다.)
  /// isFireDrill=true(화재대피용)인 경우에만 QR 2회 스캔 및 상벌점 자동부여 로직이 적용된다.
  Future<void> _createFloorWideEvent(String title, {required String floor, bool isFireDrill = false}) async {
    try {
      await _firestore.collection('attendance_events').add({
        'title': title,
        'floor': floor,
        'isFloorWide': true,
        'isFireDrill': isFireDrill,
        'status': 'active',
        'token': _generateToken(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      _loadEvents(showLoading: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('통합 이벤트가 생성되었습니다')),
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
      if (newStatus == 'closed') {
        await _archiveManualStatuses(eventId);
      }
      _loadEvents(showLoading: false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// 이벤트 종료 시 관리자 상태(외박)와 층장 상태(부재/외박미수정)를 출석 이력에 기록으로 남긴다.
  Future<void> _archiveManualStatuses(String eventId) async {
    try {
      final eventDoc = await _firestore.collection('attendance_events').doc(eventId).get();
      final eventData = eventDoc.data();
      if (eventData == null) return;
      final adminStatuses = (eventData['adminStatuses'] as Map<String, dynamic>?) ?? {};
      final floorStatuses = (eventData['floorStatuses'] as Map<String, dynamic>?) ?? {};
      final floorStatusSetBy = (eventData['floorStatusSetBy'] as Map<String, dynamic>?) ?? {};
      final floorStatusSetByName = (eventData['floorStatusSetByName'] as Map<String, dynamic>?) ?? {};
      if (adminStatuses.isEmpty && floorStatuses.isEmpty) return;
      final eventTitle = (eventData['title'] as String?) ?? '인원점검';

      // uid -> {'admin': status?, 'floor': status?}
      final combined = <String, Map<String, String?>>{};
      adminStatuses.forEach((uid, st) {
        combined.putIfAbsent(uid, () => {})['admin'] = st as String?;
      });
      floorStatuses.forEach((uid, st) {
        combined.putIfAbsent(uid, () => {})['floor'] = st as String?;
      });

      final batch = _firestore.batch();
      for (final entry in combined.entries) {
        final uid = entry.key;
        final adminStatus = entry.value['admin'];
        final floorStatus = entry.value['floor'];
        if ((adminStatus == null || adminStatus.isEmpty) &&
            (floorStatus == null || floorStatus.isEmpty)) {
          continue;
        }

        Map<String, dynamic> userData = {};
        try {
          final userDoc = await _firestore.collection('users').doc(uid).get();
          userData = userDoc.data() ?? {};
        } catch (_) {}

        final ref = _firestore.collection('attendance_records').doc();
        batch.set(ref, {
          'eventId': eventId,
          'eventTitle': eventTitle,
          'userId': uid,
          'userName': userData['name'] ?? '',
          'studentId': userData['studentId'] ?? '',
          'roomNumber': userData['roomNumber'] ?? '',
          'dormBuilding': userData['dormBuilding'] ?? '',
          if (adminStatus != null && adminStatus.isNotEmpty) 'adminStatus': adminStatus,
          if (floorStatus != null && floorStatus.isNotEmpty) 'floorStatus': floorStatus,
          if (floorStatusSetBy[uid] != null) 'floorStatusSetBy': floorStatusSetBy[uid],
          if (floorStatusSetByName[uid] != null) 'floorStatusSetByName': floorStatusSetByName[uid],
          'recordType': 'status',
          'checkedInAt': Timestamp.now(),
        });
      }
      await batch.commit();
    } catch (_) {}
  }

}

// 학생 QR 스캔 결과
class _ScanResult {
  final bool success;
  final String message;

  const _ScanResult({required this.success, required this.message});
}

// 학생 QR 스캔 페이지
class _QrScannerPage extends StatefulWidget {
  final String eventTitle;
  final bool isFireDrill;
  // 화재대피용 전용: false=대피 시작 확인(1차), true=대피 도착 확인(2차). 이벤트 카드에서 미리 선택한 값을 그대로 받는다.
  final bool isArrivalStage;
  final Future<_ScanResult> Function(String qrData) onScanned;

  const _QrScannerPage({
    required this.eventTitle,
    this.isFireDrill = false,
    this.isArrivalStage = false,
    required this.onScanned,
  });

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  String? _resultMessage;
  bool _resultSuccess = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;
    final qrData = barcode.rawValue!;
    if (!qrData.startsWith('student:')) return;

    setState(() => _isProcessing = true);
    final result = await widget.onScanned(qrData);
    if (!mounted) return;
    setState(() {
      _resultMessage = result.message;
      _resultSuccess = result.success;
    });

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _resultMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.eventTitle} - QR 스캔'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetect,
          ),
          // 스캔 영역 가이드
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // 화재대피용: 이벤트 카드에서 미리 선택한 현재 스캔 모드 안내(고정 표시, 여기서는 변경 불가)
          if (widget.isFireDrill)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.isArrivalStage ? '2차 확인 모드' : '1차 확인 모드',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          // 결과/안내 메시지
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              color: _resultMessage == null
                  ? Colors.black54
                  : (_resultSuccess ? Colors.green : Colors.red).withValues(alpha: 0.9),
              child: Text(
                _resultMessage ?? '학생의 QR 코드를 스캔하세요',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}

// ── 호실별 이벤트 생성 다이얼로그 ──
class _RoomEventCreateDialog extends StatefulWidget {
  final String initialFloor;
  final Future<Map<String, bool>> Function(String floor) loadRoomsForFloor;
  final Future<void> Function(String title, String selectedFloor, bool isFireDrill) onCreateFloorWide;

  const _RoomEventCreateDialog({
    required this.initialFloor,
    required this.loadRoomsForFloor,
    required this.onCreateFloorWide,
  });

  @override
  State<_RoomEventCreateDialog> createState() =>
      _RoomEventCreateDialogState();
}

class _RoomEventCreateDialogState extends State<_RoomEventCreateDialog> {
  final _titleController = TextEditingController();
  late String _selectedFloor;
  // 호실번호 -> 거주 학생 존재 여부
  Map<String, bool> _rooms = {};
  bool _isLoadingRooms = false;
  bool _isCreating = false;
  // true면 화재대피용(종료 시 상벌점 자동 부여), false면 일반 인원점검
  bool _isFireDrill = false;

  int get _occupiedRoomCount => _rooms.values.where((v) => v).length;

  // 재실 학생이 있는 호실 중 가장 작은/큰 호수 (예: "201호 ~ 726호")
  String? get _occupiedRoomRangeLabel {
    final occupied = _rooms.entries.where((e) => e.value).map((e) => e.key).toList();
    if (occupied.isEmpty) return null;
    occupied.sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
    final first = occupied.first;
    final last = occupied.last;
    return first == last ? '$first호' : '$first호 ~ $last호';
  }

  @override
  void initState() {
    super.initState();
    _selectedFloor = kFloorOptions.contains(widget.initialFloor)
        ? widget.initialFloor
        : kFloorOptions.first;
    _titleController.addListener(() => setState(() {}));
    _fetchRooms(_selectedFloor);
  }

  Future<void> _fetchRooms(String floor) async {
    setState(() {
      _isLoadingRooms = true;
      _rooms = {};
    });
    final rooms = await widget.loadRoomsForFloor(floor);
    if (!mounted) return;
    setState(() {
      _rooms = rooms;
      _isLoadingRooms = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = !_isCreating &&
        _titleController.text.trim().isNotEmpty &&
        _occupiedRoomCount > 0;

    return AlertDialog(
      title: const Text('인원점검 생성'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 담당 구역 표시
              Text(
                _selectedFloor,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              // 이벤트 제목
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '이벤트 제목',
                  hintText: '예: 2026년 3월 주간 점호',
                ),
              ),
              const SizedBox(height: 12),
              // 생성 방식 선택 (둘 다 구역 전체를 1개 이벤트로 생성. 화재대피용만 종료 시 상벌점 자동 부여)
              const Text('생성 방식', style: TextStyle(fontWeight: FontWeight.w600)),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: false,
                      groupValue: _isFireDrill,
                      onChanged: (v) => setState(() => _isFireDrill = v ?? false),
                      title: const Text('일반 인원점검', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: true,
                      groupValue: _isFireDrill,
                      onChanged: (v) => setState(() => _isFireDrill = v ?? false),
                      title: const Text('"화재대피용" 인원점검', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_isLoadingRooms)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _occupiedRoomCount > 0
                              ? '$_selectedFloor 구역의 재실 학생 전원($_occupiedRoomRangeLabel, $_occupiedRoomCount개 호실)을 하나의 이벤트로 생성합니다.'
                              : '해당 구역에 재실 학생이 없습니다.',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
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
          onPressed: canCreate
              ? () async {
                  setState(() => _isCreating = true);
                  await widget.onCreateFloorWide(
                    _titleController.text.trim(),
                    _selectedFloor,
                    _isFireDrill,
                  );
                }
              : null,
          child: _isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('생성'),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 출석 이력 탭 — 학생 기준
// ══════════════════════════════════════════════════════════════
class _AttendanceHistoryContent extends StatefulWidget {
  const _AttendanceHistoryContent();

  @override
  State<_AttendanceHistoryContent> createState() => _AttendanceHistoryContentState();
}

class _AttendanceHistoryContentState extends State<_AttendanceHistoryContent> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DateFormat _dateFmt = DateFormat('yyyy.MM.dd (E) HH:mm', 'ko');

  String? _assignedFloor;
  bool _isLoading = true;

  // eventId → event data
  Map<String, Map<String, dynamic>> _eventMap = {};
  // 'room|uid' → 출석기록 목록 (최신순)
  Map<String, List<Map<String, dynamic>>> _grouped = {};
  // 'room|uid' → 학생 기본정보
  Map<String, Map<String, dynamic>> _studentInfo = {};
  List<String> _sortedKeys = [];

  String? _selectedKey;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFloorThenData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFloorThenData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final doc = await _firestore.collection('users').doc(uid).get();
        if (mounted) _assignedFloor = doc.data()?['assignedFloor'] as String?;
      } catch (_) {}
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 담당 층 호실 범위 계산 (학생/기록 필터 기준)
      final floorRooms = _assignedFloor != null
          ? _roomsForFloor(_assignedFloor!)
          : <String>{};
      final dorm = _dormFromFloor(_assignedFloor);

      // 바롬인성교육관 층 번호 (호실 prefix 필터용)
      int? baromFloorNum;
      if (dorm == '바롬인성교육관' && _assignedFloor != null) {
        final m = RegExp(r'(\d+)층').firstMatch(_assignedFloor!);
        baromFloorNum = m != null ? int.tryParse(m.group(1)!) : null;
      }

      bool isInFloor(String room) {
        if (_assignedFloor == null) return true;
        if (floorRooms.isNotEmpty) return floorRooms.contains(room);
        if (baromFloorNum != null) {
          // 바롬 호실은 '1001-A' 형식 → '-' 앞 숫자로 층 판정
          final n = int.tryParse(room.split('-').first);
          return n != null && n ~/ 100 == baromFloorNum;
        }
        return true;
      }

      // 이벤트 전체 로드 (이력 카드에 제목 표시용)
      final eventsSnap = await _firestore.collection('attendance_events').get();
      final eventMap = <String, Map<String, dynamic>>{};
      for (final doc in eventsSnap.docs) {
        eventMap[doc.id] = {'_id': doc.id, ...doc.data()};
      }

      // 출석 기록 전체 로드
      final recordsSnap = await _firestore.collection('attendance_records').get();

      // 담당 층 학생 로드
      Query usersQuery = _firestore.collection('users').where('role', isEqualTo: 'student');
      if (dorm != null) {
        usersQuery = usersQuery.where('dormBuilding', isEqualTo: dorm);
      }
      final usersSnap = await usersQuery.get();

      final studentInfo = <String, Map<String, dynamic>>{};
      for (final doc in usersSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final room = (data['roomNumber'] as String?) ?? '';
        if (room.isEmpty || room == '000') continue;
        if (!isInFloor(room)) continue;
        final key = '$room|${doc.id}';
        studentInfo[key] = {'_uid': doc.id, ...data};
      }

      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final rec in recordsSnap.docs) {
        final data = rec.data();
        final uid = (data['userId'] as String?) ?? '';
        if (uid.isEmpty) continue;
        final room = (data['roomNumber'] as String?) ?? '';
        // 담당 층 호실 범위 기준으로 기록 필터
        if (!isInFloor(room)) continue;
        // 진행중(active) 스케줄의 기록은 이력에서 제외 — 종료 후에만 표시
        final eventId = (data['eventId'] as String?) ?? '';
        if (eventId.isNotEmpty && (eventMap[eventId]?['status'] as String?) == 'active') continue;
        final key = '$room|$uid';
        grouped.putIfAbsent(key, () => []).add({'_id': rec.id, ...data});
        // 기록에만 있는 학생(퇴사 등)도 표시
        studentInfo.putIfAbsent(key, () => {
          '_uid': uid,
          'name': data['userName'] ?? '',
          'studentId': data['studentId'] ?? '',
          'roomNumber': room,
        });
      }

      // 각 학생별 기록 최신순 정렬
      for (final list in grouped.values) {
        list.sort((a, b) {
          final aTs = (a['checkedInAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final bTs = (b['checkedInAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return bTs.compareTo(aTs);
        });
      }

      // 호실 번호 오름차순 → 이름 오름차순 정렬
      final sortedKeys = studentInfo.keys.toList()
        ..sort((a, b) {
          final roomA = int.tryParse(a.split('|')[0]) ?? 0;
          final roomB = int.tryParse(b.split('|')[0]) ?? 0;
          if (roomA != roomB) return roomA.compareTo(roomB);
          final nameA = (studentInfo[a]?['name'] as String?) ?? '';
          final nameB = (studentInfo[b]?['name'] as String?) ?? '';
          return nameA.compareTo(nameB);
        });

      if (mounted) {
        setState(() {
          _eventMap = eventMap;
          _grouped = grouped;
          _studentInfo = studentInfo;
          _sortedKeys = sortedKeys;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static String? _dormFromFloor(String? floor) {
    if (floor == null) return null;
    if (floor.startsWith('샬롬하우스(방학)')) return '샬롬하우스(방학)';
    if (floor.startsWith('샬롬하우스')) return '샬롬하우스';
    if (floor.startsWith('국제생활관(방학)')) return '국제생활관(방학)';
    if (floor.startsWith('국제생활관')) return '국제생활관';
    if (floor.startsWith('바롬인성교육관')) return '바롬인성교육관';
    return null;
  }

  // 담당 층에 해당하는 호실 번호 Set 반환 (빈 Set이면 필터 없음)
  static Set<String> _roomsForFloor(String floor) {
    final dormBuilding = floor.split(' ').firstOrNull ?? '';
    final buildingMatch = RegExp(r'([AB])동').firstMatch(floor);
    final floorMatch = RegExp(r'(\d+)층').firstMatch(floor);
    final building = buildingMatch?.group(1);
    final floorNum = floorMatch != null ? int.tryParse(floorMatch.group(1)!) : null;
    if (floorNum == null) return {};

    if (dormBuilding == '샬롬하우스') {
      // A동 1층은 107~109호만 존재하는 예외 구역
      if (building == 'A' && floorNum == 1) {
        return const {'107', '108', '109'};
      } else if (building == 'A') {
        return List.generate(20, (i) => '${floorNum * 100 + i + 1}').toSet();
      } else if (building == 'B') {
        return List.generate(15, (i) => '${floorNum * 100 + 21 + i}').toSet();
      }
    } else if (dormBuilding == '국제생활관') {
      if (building == 'A' && floorNum == 1) {
        return List.generate(32, (i) => '${101 + i}').toSet();
      } else if (building == 'A' && floorNum == 2) {
        return List.generate(29, (i) => '${201 + i}').toSet();
      } else if (building == 'B' && floorNum == 2) {
        return List.generate(28, (i) => '${233 + i}').toSet();
      } else if (building == 'B' && floorNum == 3) {
        return List.generate(29, (i) => '${301 + i}').toSet();
      }
    } else if (dormBuilding == '바롬인성교육관') {
      // 바롬인성교육관은 호실 범위가 고정되지 않으므로 층 번호 prefix로 필터
      // _loadData에서 별도 처리 — 여기서는 빈 Set 반환해 Firestore 결과 전체를 받은 후 걸러냄
      return {};
    }
    return {};
  }

  static Color _buildingColor(String? dorm) {
    if (dorm == '샬롬하우스' || dorm == '샬롬하우스(방학)') return Colors.blue;
    if (dorm == '국제생활관') return Colors.green;
    if (dorm == '바롬인성교육관') return const Color(0xFFFF9800);
    return Colors.grey;
  }

  List<String> get _filteredKeys {
    if (_searchQuery.isEmpty) return _sortedKeys;
    final q = _searchQuery.trim();
    return _sortedKeys.where((key) {
      final room = key.split('|')[0];
      final name = (_studentInfo[key]?['name'] as String?) ?? '';
      return room.contains(q) || name.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        // 검색바
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '이름 또는 호실 번호 검색',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _selectedKey == null
              ? _buildStudentList()
              : _buildDetailView(),
        ),
      ],
    );
  }

  Widget _buildStudentList() {
    final keys = _filteredKeys;
    if (keys.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isEmpty ? '이력이 없습니다' : '검색 결과가 없습니다',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: keys.length,
        itemBuilder: (_, i) => _buildStudentCard(keys[i]),
      ),
    );
  }

  Widget _buildStudentCard(String key) {
    final info = _studentInfo[key] ?? {};
    final records = _grouped[key] ?? [];
    final name = (info['name'] as String?) ?? '이름 없음';
    final room = key.split('|')[0];
    final studentId = (info['studentId'] as String?) ?? '';
    final dorm = (info['dormBuilding'] as String?) ?? _dormFromFloor(_assignedFloor) ?? '';
    final latestAt = records.isNotEmpty
        ? (records.first['checkedInAt'] as Timestamp?)?.toDate()
        : null;
    final bldColor = _buildingColor(dorm);

    return GestureDetector(
      onTap: () => setState(() => _selectedKey = key),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: bldColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    bottomLeft: Radius.circular(6),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(6),
                      bottomRight: Radius.circular(6),
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              room.isNotEmpty ? '$name ($room호)' : name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            if (studentId.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(studentId,
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                            ],
                            if (latestAt != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '최근 인원점검: ${DateFormat('yyyy.MM.dd HH:mm').format(latestAt)}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (records.isEmpty ? Colors.grey : Colors.blue)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              records.isEmpty ? '기록 없음' : '${records.length}회',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: records.isEmpty ? Colors.grey : Colors.blue,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailView() {
    final key = _selectedKey!;
    final info = _studentInfo[key] ?? {};
    final records = _grouped[key] ?? [];
    final name = (info['name'] as String?) ?? '이름 없음';
    final room = key.split('|')[0];
    final dorm = (info['dormBuilding'] as String?) ?? _dormFromFloor(_assignedFloor) ?? '';

    return Column(
      children: [
        // 헤더 (뒤로가기 + 학생 정보)
        Container(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedKey = null),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.isNotEmpty ? '$name ($room호)' : name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (dorm.isNotEmpty)
                      Text(dorm,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '총 ${records.length}회',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
        // 이력 목록
        Expanded(
          child: records.isEmpty
              ? Center(
                  child: Text('인원점검 이력이 없습니다',
                      style: TextStyle(color: Colors.grey.shade500)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: records.length,
                  itemBuilder: (_, i) => _buildHistoryCard(records[i]),
                ),
        ),
      ],
    );
  }

  static const _statusColors = {
    '재실확인': Colors.green,
    '불참인정': Color(0xFFFF9800),
    '불참인정완료': Color(0xFFFF9800),
    '외박': Color(0xFFFF9800),
    '외박신청완료': Color(0xFFFF9800),
    '화재대피참석': Colors.green,
    '화재대피훈련불참': Colors.red,
    '부재': Colors.red,
    '외박미수정': Colors.blue,
    '외박미신청': Colors.red,
    '바롬인성교육관': Color(0xFFFF9800),
    '무단퇴사': Colors.grey,
  };
  static const _statusIcons = {
    '재실확인': Icons.check_circle,
    '불참인정': Icons.event_available,
    '불참인정완료': Icons.event_available,
    '외박': Icons.event_available,
    '외박신청완료': Icons.event_available,
    '화재대피참석': Icons.check_circle,
    '화재대피훈련불참': Icons.cancel,
    '부재': Icons.person_off,
    '외박미수정': Icons.warning_amber,
    '외박미신청': Icons.warning_amber,
    '바롬인성교육관': Icons.block,
    '무단퇴사': Icons.block,
  };

  Widget _buildHistoryCard(Map<String, dynamic> data) {
    final eventId = (data['eventId'] as String?) ?? '';
    final event = _eventMap[eventId];
    final eventTitle = (event?['title'] as String?) ?? (data['eventTitle'] as String?) ?? '인원점검';
    final checkedInAt = (data['checkedInAt'] as Timestamp?)?.toDate();
    final isStatusRecord = data['recordType'] == 'status';
    final adminStatus = data['adminStatus'] as String?;
    final floorStatus = data['floorStatus'] as String?;
    final floorStatusSetBy = data['floorStatusSetBy'] as String?;
    final isFireDrillEvent = event?['isFireDrill'] == true;
    final isComplete = data['isComplete'] != false;

    final String primaryStatus;
    if (isStatusRecord && adminStatus == '불참인정') {
      // 불참인정이 최우선 — 화재대피 참석 여부보다 먼저 표시한다.
      primaryStatus = '불참인정완료';
    } else if (isStatusRecord) {
      primaryStatus = floorStatus ?? adminStatus ?? '기타';
    } else if (isFireDrillEvent) {
      primaryStatus = isComplete ? '화재대피참석' : '화재대피훈련불참';
    } else {
      primaryStatus = '재실확인';
    }

    final color = _statusColors[primaryStatus] ?? Colors.grey;
    final icon = _statusIcons[primaryStatus] ?? Icons.info_outline;

    // 상태 레이블
    final labels = <String>[];
    if (isStatusRecord) {
      if (adminStatus != null && adminStatus.isNotEmpty) labels.add(adminStatus);
      if (floorStatus != null && floorStatus.isNotEmpty) labels.add(floorStatus);
    }
    final subtitle = labels.isNotEmpty ? labels.join(' · ') : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitle != null ? '$eventTitle · $subtitle' : eventTitle,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  if (checkedInAt != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      _dateFmt.format(checkedInAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                  if (floorStatusSetBy != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '처리: $floorStatusSetBy',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(
                primaryStatus,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
