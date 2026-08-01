import 'package:flutter/material.dart' hide Colors, FilledButton, IconButton, Card, ListTile, showDialog, Divider, Checkbox, Tooltip, ButtonStyle;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:swu_dormi_admin/widgets/shimmer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:swu_dormi_admin/screens/windows/windows_cleaning_inspection_screen.dart' show kFloorOptions, roomCapacityLabel;
import 'package:swu_dormi_admin/screens/windows/windows_attendance_history_screen.dart';
import 'package:swu_dormi_admin/models/excel_student_row.dart';
import 'package:swu_dormi_admin/data/point_codes.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';

/// 출석체크(현재)와 출석체크 이력을 "현재 / 이력" 2탭으로 보여주는 화면.
/// 단위실 청소점검(WindowsInspectionTabScreen)과 동일한 구조로 사이드바 메뉴를 통합할 때 사용한다.
class WindowsAttendanceTabScreen extends StatefulWidget {
  const WindowsAttendanceTabScreen({super.key});

  @override
  State<WindowsAttendanceTabScreen> createState() =>
      _WindowsAttendanceTabScreenState();
}

class _WindowsAttendanceTabScreenState
    extends State<WindowsAttendanceTabScreen> {
  // 0: 현재, 1: 이력
  int _tabIndex = 0;

  final _accentColor = Colors.purple;

  @override
  Widget build(BuildContext context) {
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
                _buildTab(0, '출석체크', FluentIcons.check_list),
                const SizedBox(width: 8),
                _buildTab(1, '출석체크이력', FluentIcons.history),
              ],
            ),
          ),
          // 탭 콘텐츠
          Expanded(
            child: _tabIndex == 1
                ? const WindowsAttendanceHistoryScreen()
                : const WindowsAttendanceScreen(),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label, IconData icon) {
    final isSelected = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? _accentColor.withValues(alpha: 0.12)
              : Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? _accentColor : Colors.grey.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? _accentColor : Colors.grey),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? _accentColor : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WindowsAttendanceScreen extends StatefulWidget {
  const WindowsAttendanceScreen({super.key});

  @override
  State<WindowsAttendanceScreen> createState() => _WindowsAttendanceScreenState();
}

class _WindowsAttendanceScreenState extends State<WindowsAttendanceScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _dateFormat = DateFormat('yyyy.MM.dd HH:mm');

  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _roomStudents = [];
  // 엑셀에는 있으나 users 컬렉션에 이메일이 없는 학생(앱 미가입자) 전체 목록
  List<ExcelStudentRow> _unregisteredStudents = [];
  // 현재 선택된 이벤트의 호실에 해당하는 미가입자만 필터링
  List<ExcelStudentRow> _roomUnregisteredStudents = [];
  final Map<String, String?> _adminStatuses = {};
  final Map<String, String?> _floorStatuses = {};
  Map<String, dynamic>? _selectedEvent;
  bool _isLoadingEvents = true;
  bool _isLoadingRecords = false;
  String? _eventsError;
  String? _recordsError;
  String? _filterFloor;
  Map<String, int> _roomStudentCounts = {};
  // 구역(kFloorOptions 값) -> 재실 학생 수 (구역 전체 통합 이벤트 카드용)
  Map<String, int> _floorStudentCounts = {};
  final Set<String> _selectedEventIds = {};
  bool _isSelectionMode = false;

  // 출석체크 불가 상태. '퇴사'는 세분화 전 레거시 데이터 호환을 위해 함께 둔다.
  static const _blockedStatuses = {
    '퇴사', '만기퇴사', '자진퇴사', '강제퇴사', '영구퇴사', '바롬인성교육관',
  };
  static const _blockedStatusColors = {
    '퇴사': Color(0xFF9E9E9E),
    '만기퇴사': Color(0xFF9E9E9E),
    '자진퇴사': Color(0xFF9E9E9E),
    '강제퇴사': Color(0xFF9E9E9E),
    '영구퇴사': Color(0xFF9E9E9E),
    '바롬인성교육관': Color(0xFFFF9800),
  };

  // 층장이 지정한 상태(부재/외박미수정) 표시 색상 — 읽기 전용
  static const _floorStatusColors = {
    '부재': Color(0xFFF44336),
    '외박미수정': Color(0xFF2196F3),
  };

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _loadRoomStudentCounts();
    _loadUnregisteredStudents();
  }

  Future<void> _loadRoomStudentCounts() async {
    try {
      final snap = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();
      final counts = <String, int>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final room = (data['roomNumber'] as String?) ?? '';
        if (room.isEmpty || room == '000') continue;
        final residentStatus = (data['residentStatus'] as String?) ?? '재실중';
        if (residentStatus != '재실중') continue;
        counts[room] = (counts[room] ?? 0) + 1;
      }
      if (!mounted) return;
      setState(() => _roomStudentCounts = counts);
    } catch (_) {}

    // 구역(floor) 전체 통합 이벤트 카드의 총원 표시를 위한 구역별 재실 인원 캐시
    try {
      final floorCounts = <String, int>{};
      for (final floor in kFloorOptions) {
        final result = await _loadStudentsForFloor(floor);
        floorCounts[floor] = result.students.length;
      }
      if (!mounted) return;
      setState(() => _floorStudentCounts = floorCounts);
    } catch (_) {}
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

      final header = rows.first;
      final excelRows =
          rows.skip(1).map((row) => ExcelStudentRow.fromRow(header, row)).toList();

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
        if (_selectedEvent != null) {
          _updateRoomUnregisteredStudents(_selectedEvent!['roomNumber'] as String?);
        }
      });
    } catch (_) {}
  }

  void _updateRoomUnregisteredStudents(
    String? roomNumber, {
    bool isFloorWide = false,
    Set<String>? floorRoomNumbers,
  }) {
    if (isFloorWide) {
      if (floorRoomNumbers == null || floorRoomNumbers.isEmpty) {
        _roomUnregisteredStudents = [];
        return;
      }
      _roomUnregisteredStudents = _unregisteredStudents
          .where((s) => s.roomNumber != null && floorRoomNumbers.contains(s.roomNumber))
          .toList();
      return;
    }
    if (roomNumber == null || roomNumber.isEmpty) {
      _roomUnregisteredStudents = [];
      return;
    }
    _roomUnregisteredStudents =
        _unregisteredStudents.where((s) => s.roomNumber == roomNumber).toList();
  }

  Future<void> _loadEvents() async {
    setState(() { _isLoadingEvents = true; _eventsError = null; });
    try {
      final snap = await _firestore.collection('attendance_events').get();
      final list = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final m = Map<String, dynamic>.from(doc.data());
        m['_id'] = doc.id;
        list.add(m);
      }
      list.sort((a, b) {
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
        final aRoom = int.tryParse((a['roomNumber'] as String?) ?? '') ?? 0;
        final bRoom = int.tryParse((b['roomNumber'] as String?) ?? '') ?? 0;
        return aRoom.compareTo(bRoom);
      });
      if (!mounted) return;
      setState(() {
        _events = list;
        _isLoadingEvents = false;
      });
      if (_selectedEvent != null) {
        _loadRecords(_selectedEvent!['_id']);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoadingEvents = false; _eventsError = e.toString(); });
    }
  }

  Future<void> _loadRecords(String eventId) async {
    setState(() { _isLoadingRecords = true; _recordsError = null; _roomStudents = []; _adminStatuses.clear(); _floorStatuses.clear(); });

    final event = _events.firstWhere((e) => e['_id'] == eventId, orElse: () => {});
    final roomNumber = event['roomNumber'] as String?;
    final isFloorWide = event['isFloorWide'] == true;
    final floor = event['floor'] as String?;

    try {
      final snap = await _firestore
          .collection('attendance_records')
          .where('eventId', isEqualTo: eventId)
          .get();
      final list = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final m = Map<String, dynamic>.from(doc.data());
        m['_id'] = doc.id;
        list.add(m);
      }
      list.sort((a, b) {
        final aT = (a['checkedInAt'] is Timestamp) ? (a['checkedInAt'] as Timestamp).toDate() : DateTime(2000);
        final bT = (b['checkedInAt'] is Timestamp) ? (b['checkedInAt'] as Timestamp).toDate() : DateTime(2000);
        return bT.compareTo(aT);
      });

      List<Map<String, dynamic>> students = [];
      List<String> floorOccupiedRooms = [];
      if (isFloorWide && floor != null && floor.isNotEmpty) {
        try {
          final result = await _loadStudentsForFloor(floor);
          students = result.students;
          floorOccupiedRooms = result.occupiedRooms;
        } catch (_) {}
      } else if (roomNumber != null && roomNumber.isNotEmpty) {
        try {
          final studentsSnap = await _firestore
              .collection('users')
              .where('roomNumber', isEqualTo: roomNumber)
              .get();
          students = studentsSnap.docs
              .where((doc) => (doc.data()['role'] as String?) == 'student')
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
          students.sort((a, b) =>
              (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));
        } catch (_) {}
      }

      final Map<String, String?> savedAdminStatuses = {};
      final Map<String, String?> savedFloorStatuses = {};
      try {
        final eventDoc = await _firestore.collection('attendance_events').doc(eventId).get();
        final rawAdmin = (eventDoc.data()?['adminStatuses'] as Map<String, dynamic>?) ?? {};
        rawAdmin.forEach((uid, st) => savedAdminStatuses[uid] = st as String?);
        final rawFloor = (eventDoc.data()?['floorStatuses'] as Map<String, dynamic>?) ?? {};
        rawFloor.forEach((uid, st) => savedFloorStatuses[uid] = st as String?);
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _records = list;
        _roomStudents = students;
        _updateRoomUnregisteredStudents(
          roomNumber,
          isFloorWide: isFloorWide,
          floorRoomNumbers: floorOccupiedRooms.toSet(),
        );
        _adminStatuses.clear();
        savedAdminStatuses.forEach((uid, st) => _adminStatuses[uid] = st);
        _floorStatuses.clear();
        savedFloorStatuses.forEach((uid, st) => _floorStatuses[uid] = st);
        _isLoadingRecords = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _records = [];
        _isLoadingRecords = false;
        _recordsError = e.toString();
      });
    }
  }

  void _saveAdminStatus(String userId, String? status) {
    setState(() => _adminStatuses[userId] = status);
    final eventId = _selectedEvent?['_id'] as String?;
    if (eventId == null) return;
    final currentUser = FirebaseAuth.instance.currentUser;
    Future(() async {
      String? adminName;
      if (currentUser != null) {
        try {
          final doc = await _firestore.collection('users').doc(currentUser.uid).get();
          adminName = doc.data()?['name'] as String?;
        } catch (_) {}
      }
      await _firestore.collection('attendance_events').doc(eventId).update({
        'adminStatuses.$userId': status ?? FieldValue.delete(),
        'adminStatusSetBy.$userId': status != null ? currentUser?.email : FieldValue.delete(),
        'adminStatusSetByName.$userId': status != null ? (adminName ?? currentUser?.email) : FieldValue.delete(),
      });
    });
  }

  /// 랜덤 토큰 생성 (6자리 영숫자)
  String _generateToken() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  List<Map<String, dynamic>> get _filteredEvents {
    if (_filterFloor == null) return _events;
    return _events.where((e) => (e['floor'] as String? ?? '') == _filterFloor).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: const Text('출석체크 관리'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.add),
              label: const Text('이벤트 생성'),
              onPressed: _showCreateEventDialog,
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.refresh),
              label: const Text('새로고침'),
              onPressed: _loadEvents,
            ),
          ],
        ),
      ),
      content: Row(
        children: [
          // 좌측: 이벤트 목록
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 헤더
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.05),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(FluentIcons.event, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '출석체크 이벤트 (${_filteredEvents.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (_isSelectionMode) ...[
                          Checkbox(
                            checked: _filteredEvents.isNotEmpty &&
                                _selectedEventIds.length == _filteredEvents.length,
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selectedEventIds
                                  ..clear()
                                  ..addAll(_filteredEvents.map((e) => e['_id'] as String));
                              } else {
                                _selectedEventIds.clear();
                              }
                            }),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_selectedEventIds.length}개 선택',
                            style: TextStyle(fontSize: 12, color: Colors.grey[100]),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 26,
                            child: Button(
                              style: ButtonStyle(
                                backgroundColor: WidgetStateProperty.all(Colors.red.withOpacity(0.1)),
                              ),
                              onPressed: _selectedEventIds.isEmpty ? null : _deleteSelectedEvents,
                              child: const Text('선택 삭제', style: TextStyle(fontSize: 11)),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        SizedBox(
                          height: 26,
                          child: Button(
                            onPressed: () => setState(() {
                              _isSelectionMode = !_isSelectionMode;
                              _selectedEventIds.clear();
                            }),
                            child: Text(
                              _isSelectionMode ? '취소' : '스케줄 선택 삭제',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 서브필터 — 점검 구역
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
                        ),
                      ),
                    ),
                    child: ComboBox<String>(
                      value: _filterFloor ?? '전체',
                      isExpanded: true,
                      items: [
                        const ComboBoxItem(value: '전체', child: Text('전체 구역')),
                        for (final floor in kFloorOptions)
                          ComboBoxItem(value: floor, child: Text(floor)),
                      ],
                      onChanged: (v) => setState(() {
                        _filterFloor = (v == '전체') ? null : v;
                        _selectedEvent = null;
                      }),
                    ),
                  ),
                  Expanded(
                    child: _isLoadingEvents
                        ? ShimmerList(itemBuilder: () => const AttendanceEventShimmer(), count: 5, padding: const EdgeInsets.all(12))
                        : _eventsError != null
                            ? Center(child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text('오류: $_eventsError', style: TextStyle(color: Colors.red, fontSize: 12)),
                              ))
                        : _filteredEvents.isEmpty
                            ? const Center(child: Text('등록된 이벤트가 없습니다'))
                            : ListView.builder(
                                itemCount: _filteredEvents.length,
                                itemBuilder: (context, index) {
                                  return _buildEventCard(_filteredEvents[index]);
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
          // 우측: 출석 기록
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _selectedEvent == null
                  ? const Center(
                      child: Text('이벤트를 선택하면 출석 기록이 표시됩니다',
                          style: TextStyle(color: Color(0xFF999999))))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildRecordHeader(),
                        const Divider(),
                        Expanded(
                          child: _isLoadingRecords
                              ? ShimmerList(itemBuilder: () => const AttendanceRowShimmer(), count: 8, padding: EdgeInsets.zero)
                              : _recordsError != null
                                  ? Center(child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text('오류: $_recordsError', style: TextStyle(color: Colors.red, fontSize: 12)),
                                    ))
                                  : _buildStudentList(),
                        ),
                      ],
                    ),
            ),
          ),
        ],
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
    final eventId = event['_id'] as String;
    final title = (event['title'] ?? '') as String;
    final location = (event['location'] ?? '') as String;
    final floor = (event['floor'] as String?) ?? '';
    final status = (event['status'] ?? 'active') as String;
    final eventDateVal = event['eventDate'];
    final eventDate = (eventDateVal is Timestamp) ? eventDateVal.toDate() : DateTime.now();
    final attendeeCount = (event['attendeeCount'] is num) ? (event['attendeeCount'] as num).toInt() : 0;
    final isSelected = _selectedEvent?['_id'] == eventId;
    final isActive = status == 'active';

    final roomNumber = (event['roomNumber'] as String?) ?? '';
    final isFloorWide = event['isFloorWide'] == true;
    final dormBuilding = _dormBuildingFromFloor(floor);
    final buildingColor = _buildingColor(dormBuilding);
    final displayBuilding = dormBuilding ?? '';
    final displayArea = floor.isNotEmpty ? floor : location;
    final capacityLabel = dormBuilding == '샬롬하우스' ? roomCapacityLabel(roomNumber) : '';

    final isChecked = _selectedEventIds.contains(eventId);
    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          setState(() {
            if (isChecked) {
              _selectedEventIds.remove(eventId);
            } else {
              _selectedEventIds.add(eventId);
            }
          });
          return;
        }
        setState(() => _selectedEvent = event);
        _loadRecords(eventId);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isChecked
                ? Colors.red
                : isSelected
                    ? Colors.blue
                    : Colors.grey.withOpacity(0.2),
            width: (isChecked || isSelected) ? 1.5 : 1,
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 왼쪽 건물 색상 스트라이프
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: buildingColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    bottomLeft: Radius.circular(6),
                  ),
                ),
              ),
              if (_isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Checkbox(
                    checked: isChecked,
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _selectedEventIds.add(eventId);
                      } else {
                        _selectedEventIds.remove(eventId);
                      }
                    }),
                  ),
                ),
              // 카드 내용
              Expanded(
                child: Container(
                  color: isSelected ? Colors.blue.withOpacity(0.06) : null,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.green.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isActive ? '진행중' : '종료',
                              style: TextStyle(
                                fontSize: 11,
                                color: isActive ? Colors.green.dark : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      
                      if (roomNumber.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            capacityLabel.isNotEmpty
                                ? '$roomNumber호 ($capacityLabel)'
                                : '$roomNumber호',
                            style: TextStyle(fontSize: 12, color: Colors.grey[100]),
                          ),
                        ),
                      if (displayArea.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            displayArea,
                            style: TextStyle(fontSize: 12, color: Colors.grey[100]),
                          ),
                        ),
                      Text(
                        DateFormat('yyyy.MM.dd HH:mm').format(eventDate),
                        style: TextStyle(fontSize: 11, color: Colors.grey[90]),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(FluentIcons.people, size: 12, color: Colors.blue),
                          const SizedBox(width: 4),
                          Builder(builder: (_) {
                            final totalCount = isFloorWide
                                ? (_floorStudentCounts[floor] ?? 0)
                                : (_roomStudentCounts[roomNumber] ?? 0);
                            final isComplete = totalCount > 0 && attendeeCount >= totalCount;
                            return Text(
                              totalCount > 0
                                  ? '$attendeeCount / $totalCount명 출석'
                                  : '출석: $attendeeCount명',
                              style: TextStyle(
                                fontSize: 12,
                                color: isComplete ? Colors.green : null,
                                fontWeight: isComplete ? FontWeight.bold : FontWeight.normal,
                              ),
                            );
                          }),
                          const Spacer(),
                          // QR 표시 버튼
                          if (isActive)
                            SizedBox(
                              height: 24,
                              child: FilledButton(
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(FluentIcons.q_r_code, size: 12),
                                    SizedBox(width: 4),
                                    Text('QR', style: TextStyle(fontSize: 11)),
                                  ],
                                ),
                                onPressed: () => _showQrDialog(eventId, title),
                              ),
                            ),
                          if (isActive) const SizedBox(width: 4),
                          // 상태 토글 버튼
                          SizedBox(
                            height: 24,
                            child: Button(
                              child: Text(isActive ? '종료' : '재개', style: const TextStyle(fontSize: 11)),
                              onPressed: () => _toggleEventStatus(eventId, status),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // 삭제 버튼
                          SizedBox(
                            height: 24,
                            child: Button(
                              child: const Text('삭제', style: TextStyle(fontSize: 11)),
                              onPressed: () => _deleteEvent(eventId),
                            ),
                          ),
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

  Widget _buildStudentList() {
    if (_roomStudents.isEmpty && _roomUnregisteredStudents.isEmpty) {
      if (_records.isEmpty) return const Center(child: Text('출석 기록이 없습니다'));
      return ListView.builder(
        itemCount: _records.length,
        itemBuilder: (context, index) => _buildRecordCard(_records[index], index),
      );
    }

    // 부재/외박/외박미수정 등 상태 기록(recordType == 'status')은 실제 출석(QR 체크인)이 아니므로 제외
    final attendedIds = _records
        .where((r) => r['recordType'] != 'status')
        .map((r) => r['userId'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();

    // 이벤트가 종료되면 상태를 더 이상 변경할 수 없다.
    final isEventClosed = (_selectedEvent?['status'] as String?) != 'active';

    return ListView.separated(
      itemCount: _roomStudents.length + _roomUnregisteredStudents.length,
      separatorBuilder: (context, i) => const Divider(),
      itemBuilder: (context, index) {
        if (index >= _roomStudents.length) {
          final excelRow = _roomUnregisteredStudents[index - _roomStudents.length];
          return _buildUnregisteredStudentTile(excelRow);
        }
        final student = _roomStudents[index];
        final uid = student['id'] as String;
        final name = (student['name'] as String?) ?? '이름 없음';
        final studentId = (student['studentId'] as String?) ?? '';
        final seatNumber = (student['seatNumber'] as String?) ?? '';
        final residentStatus = (student['residentStatus'] as String?) ?? '재실중';
        final isBlocked = _blockedStatuses.contains(residentStatus);
        final isPresent = attendedIds.contains(uid);

        final record = _records.firstWhere(
          (r) => r['userId'] == uid && r['recordType'] != 'status',
          orElse: () => {},
        );
        final checkedAt = (record['checkedInAt'] as Timestamp?)?.toDate();

        final adminStatus = _adminStatuses[uid];
        final floorStatus = _floorStatuses[uid];
        final blockedColor = _blockedStatusColors[residentStatus] ?? const Color(0xFF9E9E9E);
        final floorStatusColor = _floorStatusColors[floorStatus] ?? const Color(0xFF9E9E9E);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: isBlocked ? blockedColor.withValues(alpha: 0.04) : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                isBlocked
                    ? FluentIcons.blocked
                    : isPresent
                        ? FluentIcons.check_mark
                        : FluentIcons.radio_bullet,
                color: isBlocked
                    ? blockedColor
                    : isPresent
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFF9E9E9E),
                size: 20,
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 130, // Expanded from 80 to fit name + seat number
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seatNumber.isNotEmpty ? '$name (자리 $seatNumber)' : name,
                      style: TextStyle(
                        fontWeight: isPresent ? FontWeight.bold : FontWeight.normal,
                        color: isBlocked
                            ? blockedColor
                            : isPresent
                                ? null
                                : const Color(0xFF888888),
                      ),
                    ),
                    if (studentId.isNotEmpty)
                      Text(studentId, style: const TextStyle(fontSize: 11, color: Color(0xFF999999))),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (isBlocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: blockedColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: blockedColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    residentStatus,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: blockedColor,
                    ),
                  ),
                )
              else if (isPresent)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.5)),
                      ),
                      child: const Text(
                        '재실확인',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50)),
                      ),
                    ),
                    if (checkedAt != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('HH:mm').format(checkedAt),
                        style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ],
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (floorStatus != null && floorStatus.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: floorStatusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: floorStatusColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          '층장: $floorStatus',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: floorStatusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Button(
                      onPressed: isEventClosed
                          ? null
                          : () => _saveAdminStatus(uid, adminStatus == '외박' ? null : '외박'),
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(
                          adminStatus == '외박'
                              ? const Color(0xFFFF9800).withValues(alpha: 0.15)
                              : null,
                        ),
                      ),
                      child: Text(
                        adminStatus == '외박' ? '외박 신청 완료' : '외박',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: adminStatus == '외박' ? const Color(0xFFFF9800) : null,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUnregisteredStudentTile(ExcelStudentRow student) {
    final name = student.name?.trim() ?? '이름 없음';
    final studentId = student.studentId?.trim() ?? '';
    final seatNumber = student.seatNumber?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.grey.withValues(alpha: 0.04),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            FluentIcons.contact,
            color: Color(0xFF9E9E9E),
            size: 20,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 130,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  seatNumber.isNotEmpty ? '$name (자리 $seatNumber)' : name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                if (studentId.isNotEmpty)
                  Text(
                    studentId,
                    style: TextStyle(fontSize: 11, color: Colors.grey[100]),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '미가입',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[130],
              ),
            ),
          ),
          const Spacer(),
          Text(
            '앱 미가입 (엑셀 기준)',
            style: TextStyle(fontSize: 11, color: Colors.grey[100]),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordHeader() {
    if (_selectedEvent == null) return const SizedBox.shrink();
    final title = (_selectedEvent!['title'] ?? '') as String;
    final attendeeCount = (_selectedEvent!['attendeeCount'] is num)
        ? (_selectedEvent!['attendeeCount'] as num).toInt()
        : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          const Icon(FluentIcons.people, size: 16),
          const SizedBox(width: 8),
          Builder(builder: (_) {
            final roomNumber = (_selectedEvent!['roomNumber'] as String?) ?? '';
            final isFloorWide = _selectedEvent!['isFloorWide'] == true;
            final floor = (_selectedEvent!['floor'] as String?) ?? '';
            final totalCount = isFloorWide
                ? (_floorStudentCounts[floor] ?? 0)
                : (_roomStudentCounts[roomNumber] ?? 0);
            final label = totalCount > 0
                ? '$title - 출석 기록 ($attendeeCount / $totalCount명)'
                : '$title - 출석 기록 ($attendeeCount명)';
            return Text(label, style: const TextStyle(fontWeight: FontWeight.bold));
          }),
          const Spacer(),
          Button(
            child: const Text('엑셀 출력'),
            onPressed: _exportRecordsToExcel,
          ),
          const SizedBox(width: 8),
          Button(
            child: const Text('새로고침'),
            onPressed: () {
              if (_selectedEvent != null) {
                _loadRecords(_selectedEvent!['_id']);
                _loadEvents();
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _exportRecordsToExcel() async {
    if (_selectedEvent == null || !mounted) return;
    final eventId = _selectedEvent!['_id'] as String;
    final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ContentDialog(
        title: Text('엑셀 생성 중'),
        content: SizedBox(height: 80, child: Center(child: ProgressRing())),
      ),
    );

    try {
      final attendedIds = _records
          .where((r) => r['eventId'] == eventId)
          .map((r) => r['userId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      final excel = Excel.createExcel();
      final sheet = excel['출석부과내역'];
      final headers = ['학번', '성명', '부과일자', '상벌구분', '상벌점내용', '상점', '비고'];
      for (int c = 0; c < headers.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).value =
            TextCellValue(headers[c]);
      }

      int rowIdx = 1;
      void writeRow(String studentId, String name, bool attended) {
        final code = attended ? kPointCodeByCode['0006'] : kPointCodeByCode['0134'];
        final values = [
          studentId,
          name,
          dateStr,
          (code?['division'] as String?) ?? '',
          (code?['code'] as String?) ?? '',
          code != null ? '${code['points']}' : '',
          '',
        ];
        for (int c = 0; c < values.length; c++) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx)).value =
              TextCellValue(values[c]);
        }
        rowIdx++;
      }

      for (final s in _roomStudents) {
        final uid = s['id'] as String? ?? '';
        final name = (s['name'] as String?) ?? '';
        final studentId = (s['studentId'] as String?) ?? '';
        writeRow(studentId, name, attendedIds.contains(uid));
      }
      for (final s in _roomUnregisteredStudents) {
        writeRow(s.studentId ?? '', s.name ?? '', false);
      }

      if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');

      final bytes = excel.encode();
      if (bytes == null) throw Exception('엑셀 파일 생성 실패');

      if (!mounted) return;
      Navigator.pop(context);

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: '출석 부과 내역 저장',
        fileName: '출석부과내역_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (savePath == null) return;
      await File(savePath).writeAsBytes(bytes);

      if (!mounted) return;
      await displayInfoBar(
        context,
        builder: (c, close) => InfoBar(
          title: Text('저장 완료: $savePath'),
          severity: InfoBarSeverity.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      await displayInfoBar(
        context,
        builder: (c, close) => InfoBar(
          title: Text('오류: $e'),
          severity: InfoBarSeverity.error,
        ),
      );
    }
  }

  Widget _buildRecordCard(Map<String, dynamic> record, int index) {
    final uid = record['userId'] as String? ?? '';
    final userName = (record['userName'] ?? '') as String;
    final studentId = (record['studentId'] ?? '') as String;
    final roomNumber = (record['roomNumber'] ?? '') as String;
    final dormBuilding = ((record['dormBuilding'] as String?)?.isNotEmpty == true
        ? record['dormBuilding'] as String
        : (record['building'] as String? ?? ''));
    final checkedInAt = (record['checkedInAt'] as Timestamp?)?.toDate();
    final recordId = record['_id'] as String;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(0.15)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text('${index + 1}', style: TextStyle(fontSize: 13, color: Colors.grey[100])),
          ),
          SizedBox(
            width: 130, // Expanded from 80 to fit name + seat number
            child: uid.isNotEmpty
                ? FutureBuilder<DocumentSnapshot>(
                    future: _firestore.collection('users').doc(uid).get(),
                    builder: (context, snapshot) {
                      String displaySeat = '';
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final udata = snapshot.data!.data() as Map<String, dynamic>?;
                        final seat = udata?['seatNumber'] as String? ?? '';
                        if (seat.isNotEmpty) {
                          displaySeat = ' (자리 $seat)';
                        }
                      }
                      return Text(
                        '$userName$displaySeat',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      );
                    },
                  )
                : Text(userName, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            width: 100,
            child: Text(studentId, style: const TextStyle(fontSize: 13)),
          ),
          SizedBox(
            width: 140,
            child: Text(
              [if (dormBuilding.isNotEmpty) dormBuilding, if (roomNumber.isNotEmpty) '$roomNumber호'].join(' '),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              checkedInAt != null ? _dateFormat.format(checkedInAt) : '',
              style: TextStyle(fontSize: 13, color: Colors.grey[100]),
            ),
          ),
          SizedBox(
            height: 24,
            child: Button(
              child: const Icon(FluentIcons.delete, size: 12),
              onPressed: () => _deleteRecord(recordId),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────── QR 코드 다이얼로그 ────────────
  void _showQrDialog(String eventId, String eventTitle) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _QrCodeDialog(
        eventId: eventId,
        eventTitle: eventTitle,
        firestore: _firestore,
        generateToken: _generateToken,
      ),
    );
  }

  /// 구역(floor) 전체의 재실 학생을 조회한다. 퇴사 등 재실중이 아닌 학생은 제외한다.
  Future<({List<Map<String, dynamic>> students, List<String> occupiedRooms})> _loadStudentsForFloor(
    String floor,
  ) async {
    final roomMap = await _loadRoomsForFloor(floor);
    final occupiedRooms = roomMap.entries.where((e) => e.value).map((e) => e.key).toList();
    final dormBuilding = _dormBuildingFromFloor(floor);
    final students = <Map<String, dynamic>>[];
    if (occupiedRooms.isNotEmpty && dormBuilding != null) {
      // whereIn은 최대 30개까지만 지원하므로 청크로 나눠 조회한다.
      for (var i = 0; i < occupiedRooms.length; i += 30) {
        final chunk = occupiedRooms.sublist(i, (i + 30).clamp(0, occupiedRooms.length));
        final studentsSnap = await _firestore
            .collection('users')
            .where('dormBuilding', isEqualTo: dormBuilding)
            .where('roomNumber', whereIn: chunk)
            .get();
        students.addAll(studentsSnap.docs.where((doc) {
          final data = doc.data();
          if ((data['role'] as String?) != 'student') return false;
          final residentStatus = (data['residentStatus'] as String?) ?? '재실중';
          return !_blockedStatuses.contains(residentStatus);
        }).map((doc) => {'id': doc.id, ...doc.data()}));
      }
    }
    students.sort((a, b) {
      final roomA = int.tryParse((a['roomNumber'] as String?) ?? '') ?? 0;
      final roomB = int.tryParse((b['roomNumber'] as String?) ?? '') ?? 0;
      if (roomA != roomB) return roomA.compareTo(roomB);
      return (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? '');
    });
    return (students: students, occupiedRooms: occupiedRooms);
  }

  // ──────────── 관리구역 → 호실 목록 로드 ────────────
  // 반환값: 호실번호 -> 거주 학생 존재 여부 (전체 호실을 보여주되 체크 초기값 결정용)
  Future<Map<String, bool>> _loadRoomsForFloor(String floor) async {
    final dormBuilding = floor.split(' ').firstOrNull ?? '';
    final buildingMatch = RegExp(r'([AB])동').firstMatch(floor);
    final floorMatch = RegExp(r'(\d+)층').firstMatch(floor);
    final building = buildingMatch?.group(1);
    final floorNum = floorMatch != null ? int.tryParse(floorMatch.group(1)!) : null;

    if (floorNum == null) return {};

    List<String> candidateRooms = [];

    if (dormBuilding == '샬롬하우스') {
      // A동: floor×100 + 01~20 / B동: floor×100 + 21~40
      if (building == 'A') {
        candidateRooms = List.generate(20, (i) => '${floorNum * 100 + i + 1}');
      } else if (building == 'B') {
        candidateRooms = List.generate(15, (i) => '${floorNum * 100 + 21 + i}');
      }
    } else if (dormBuilding == '국제생활관') {
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

    final snap = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'student')
        .where('dormBuilding', isEqualTo: dormBuilding)
        .get();
    final occupiedRooms = <String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final r = (data['roomNumber'] as String?) ?? '';
      if (r.isEmpty || r == '000') continue;
      final residentStatus = (data['residentStatus'] as String?) ?? '재실중';
      if (residentStatus != '재실중') continue;
      if (dormBuilding == '바롬인성교육관') {
        final n = int.tryParse(r);
        if (n != null && n ~/ 100 == floorNum) occupiedRooms.add(r);
      } else {
        occupiedRooms.add(r);
      }
    }

    if (dormBuilding == '바롬인성교육관') {
      // 물리적 전체 호실 범위가 없으므로 재실 이력이 있는 호실만 후보로 사용
      candidateRooms = occupiedRooms.toList()
        ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
    }

    return {for (final r in candidateRooms) r: occupiedRooms.contains(r)};
  }

  // ──────────── 이벤트 생성 ────────────
  void _showCreateEventDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => _AttendanceEventCreateDialog(
        firestore: _firestore,
        loadRoomsForFloor: _loadRoomsForFloor,
        onCreate: (title, floor, selectedRooms) async {
          Navigator.pop(dialogContext);
          for (final room in selectedRooms) {
            await _createEvent(title, floor: floor, roomNumber: room);
          }
        },
        onCreateFloorWide: (title, floor) async {
          Navigator.pop(dialogContext);
          await _createFloorWideEvent(title, floor: floor);
        },
      ),
    );
  }

  Future<void> _createEvent(String title, {required String floor, required String roomNumber}) async {
    try {
      await _firestore.collection('attendance_events').add({
        'title': title,
        'floor': floor,
        'roomNumber': roomNumber,
        'createdAt': Timestamp.now(),
        'status': 'active',
        'attendeeCount': 0,
        'currentToken': '',
      });
      _loadEvents();
    } catch (e) {
      if (mounted) {
        await displayInfoBar(context, builder: (context, close) {
          return InfoBar(title: const Text('오류'), content: Text('이벤트 생성 실패: $e'), severity: InfoBarSeverity.error);
        });
      }
    }
  }

  /// 구역(floor) 전체 재실 학생을 대상으로 하는 통합 이벤트 1개를 생성한다.
  /// (호실별로 여러 이벤트를 만드는 기존 방식과 달리 roomNumber를 두지 않는다.)
  Future<void> _createFloorWideEvent(String title, {required String floor}) async {
    try {
      await _firestore.collection('attendance_events').add({
        'title': title,
        'floor': floor,
        'roomNumber': '',
        'isFloorWide': true,
        'createdAt': Timestamp.now(),
        'status': 'active',
        'attendeeCount': 0,
        'currentToken': '',
      });
      _loadEvents();
    } catch (e) {
      if (mounted) {
        await displayInfoBar(context, builder: (context, close) {
          return InfoBar(title: const Text('오류'), content: Text('이벤트 생성 실패: $e'), severity: InfoBarSeverity.error);
        });
      }
    }
  }

  Future<void> _toggleEventStatus(String eventId, String currentStatus) async {
    final newStatus = currentStatus == 'active' ? 'closed' : 'active';
    // ignore: avoid_print
    print('[토글] eventId=$eventId currentStatus=$currentStatus newStatus=$newStatus');
    try {
      await _firestore.collection('attendance_events').doc(eventId).update({
        'status': newStatus,
        if (newStatus == 'closed') 'currentToken': '',
      });
      if (newStatus == 'closed') {
        // ignore: avoid_print
        print('[토글] _archiveManualStatuses 호출 시작');
        await _archiveManualStatuses(eventId);
        await _applyAttendancePoints(eventId);
      }
      _loadEvents();
    } catch (e) {
      if (mounted) {
        await displayInfoBar(context, builder: (context, close) {
          return InfoBar(title: const Text('오류'), content: Text('상태 변경 실패: $e'), severity: InfoBarSeverity.error);
        });
      }
    }
  }

  /// 이벤트 종료 시 관리자 상태(외박)와 층장 상태(부재/외박미수정)를 출석 이력에 기록으로 남긴다.
  Future<void> _archiveManualStatuses(String eventId) async {
    try {
      final eventDoc = await _firestore.collection('attendance_events').doc(eventId).get();
      final eventData = eventDoc.data();
      // ignore: avoid_print
      print('[아카이브] eventId=$eventId eventData keys=${eventData?.keys.toList()}');
      if (eventData == null) return;
      final adminStatuses = (eventData['adminStatuses'] as Map<String, dynamic>?) ?? {};
      final floorStatuses = (eventData['floorStatuses'] as Map<String, dynamic>?) ?? {};
      final adminStatusSetBy = (eventData['adminStatusSetBy'] as Map<String, dynamic>?) ?? {};
      final adminStatusSetByName = (eventData['adminStatusSetByName'] as Map<String, dynamic>?) ?? {};
      final floorStatusSetBy = (eventData['floorStatusSetBy'] as Map<String, dynamic>?) ?? {};
      final floorStatusSetByName = (eventData['floorStatusSetByName'] as Map<String, dynamic>?) ?? {};
      // ignore: avoid_print
      print('[아카이브] adminStatuses=$adminStatuses floorStatuses=$floorStatuses');
      if (adminStatuses.isEmpty && floorStatuses.isEmpty) return;
      final eventTitle = (eventData['title'] as String?) ?? '출석체크';

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
          if (adminStatusSetBy[uid] != null) 'adminStatusSetBy': adminStatusSetBy[uid],
          if (adminStatusSetByName[uid] != null) 'adminStatusSetByName': adminStatusSetByName[uid],
          if (floorStatus != null && floorStatus.isNotEmpty) 'floorStatus': floorStatus,
          if (floorStatusSetBy[uid] != null) 'floorStatusSetBy': floorStatusSetBy[uid],
          if (floorStatusSetByName[uid] != null) 'floorStatusSetByName': floorStatusSetByName[uid],
          'recordType': 'status',
          'checkedInAt': Timestamp.now(),
        });
        // ignore: avoid_print
        print('[아카이브] 기록 추가: uid=$uid admin=$adminStatus floor=$floorStatus');
      }
      await batch.commit();
      // ignore: avoid_print
      print('[아카이브] batch.commit 완료');
    } catch (e, st) {
      // ignore: avoid_print
      print('[아카이브] 에러: $e\n$st');
    }
  }

  /// 이벤트 종료 시 재실 학생 전체에게 출석 여부에 따라 상벌점을 자동 적용한다.
  /// 출석=0006(상점), 미출석=0134(벌점). 이벤트당 1회만 적용되도록 pointsApplied 플래그로 막는다.
  Future<void> _applyAttendancePoints(String eventId) async {
    try {
      final eventDoc = await _firestore.collection('attendance_events').doc(eventId).get();
      final eventData = eventDoc.data();
      if (eventData == null) return;
      if (eventData['pointsApplied'] == true) return;

      final roomNumber = eventData['roomNumber'] as String?;
      final isFloorWide = eventData['isFloorWide'] == true;
      final floor = eventData['floor'] as String?;
      final eventTitle = (eventData['title'] as String?) ?? '출석체크';

      List<Map<String, dynamic>> students = [];
      if (isFloorWide && floor != null && floor.isNotEmpty) {
        final result = await _loadStudentsForFloor(floor);
        students = result.students;
      } else if (roomNumber != null && roomNumber.isNotEmpty) {
        final studentsSnap = await _firestore
            .collection('users')
            .where('roomNumber', isEqualTo: roomNumber)
            .where('role', isEqualTo: 'student')
            .get();
        students = studentsSnap.docs
            .where((doc) {
              final residentStatus = (doc.data()['residentStatus'] as String?) ?? '재실중';
              return !_blockedStatuses.contains(residentStatus);
            })
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
      }
      if (students.isEmpty) return;

      final recordsSnap = await _firestore
          .collection('attendance_records')
          .where('eventId', isEqualTo: eventId)
          .get();
      final attendedIds = recordsSnap.docs
          .where((d) => d.data()['recordType'] != 'status')
          .map((d) => d.data()['userId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      final rewardCode = kPointCodeByCode['0006'];
      final penaltyCode = kPointCodeByCode['0134'];
      if (rewardCode == null || penaltyCode == null) return;

      final batch = _firestore.batch();
      for (final s in students) {
        final uid = s['id'] as String;
        final attended = attendedIds.contains(uid);
        final code = attended ? rewardCode : penaltyCode;
        final type = code['type'] as String;
        final points = code['points'] as int;
        final reason = '$eventTitle - ${code['name']} (${code['code']})';

        final historyRef = _firestore.collection('users').doc(uid).collection('point_history').doc();
        batch.set(historyRef, {
          'userId': uid,
          'type': type,
          'points': points,
          'reason': reason,
          'createdAt': Timestamp.now(),
        });
        final userRef = _firestore.collection('users').doc(uid);
        batch.update(userRef, {
          'points': FieldValue.increment(type == 'reward' ? points : -points),
        });
      }
      batch.set(
        _firestore.collection('attendance_events').doc(eventId),
        {'pointsApplied': true},
        SetOptions(merge: true),
      );
      await batch.commit();
    } catch (e) {
      // ignore: avoid_print
      print('[상벌점 자동적용] 에러: $e');
    }
  }

  Future<void> _deleteEvent(String eventId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('이벤트 삭제'),
        content: const Text('이벤트를 삭제하시겠습니까? 출석 이력 기록은 삭제되지 않고 유지됩니다.'),
        actions: [
          Button(child: const Text('취소'), onPressed: () => Navigator.pop(ctx, false)),
          FilledButton(
            style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Colors.red)),
            child: const Text('삭제'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (result != true) return;
    try {
      // 이벤트 문서만 삭제하고, attendance_records(QR 체크인·상태 기록)는 이력 보존을 위해 남겨둔다.
      await _firestore.collection('attendance_events').doc(eventId).delete();
      if (_selectedEvent?['_id'] == eventId) {
        setState(() { _selectedEvent = null; _records = []; });
      }
      _loadEvents();
    } catch (e) {
      if (mounted) {
        await displayInfoBar(context, builder: (context, close) {
          return InfoBar(title: const Text('오류'), content: Text('삭제 실패: $e'), severity: InfoBarSeverity.error);
        });
      }
    }
  }

  Future<void> _deleteSelectedEvents() async {
    if (_selectedEventIds.isEmpty) return;
    final count = _selectedEventIds.length;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('선택 이벤트 삭제'),
        content: Text('선택한 $count개 이벤트를 삭제하시겠습니까? 출석 이력 기록은 삭제되지 않고 유지됩니다.'),
        actions: [
          Button(child: const Text('취소'), onPressed: () => Navigator.pop(ctx, false)),
          FilledButton(
            style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Colors.red)),
            child: const Text('삭제'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (result != true) return;
    try {
      // 이벤트 문서만 삭제하고, attendance_records(QR 체크인·상태 기록)는 이력 보존을 위해 남겨둔다.
      final batch = _firestore.batch();
      for (final eventId in _selectedEventIds) {
        batch.delete(_firestore.collection('attendance_events').doc(eventId));
      }
      await batch.commit();

      if (_selectedEvent != null && _selectedEventIds.contains(_selectedEvent!['_id'])) {
        setState(() { _selectedEvent = null; _records = []; });
      }
      setState(() {
        _selectedEventIds.clear();
        _isSelectionMode = false;
      });
      _loadEvents();

      if (mounted) {
        await displayInfoBar(context, builder: (context, close) {
          return InfoBar(title: Text('$count개 이벤트가 삭제되었습니다.'), severity: InfoBarSeverity.success);
        });
      }
    } catch (e) {
      if (mounted) {
        await displayInfoBar(context, builder: (context, close) {
          return InfoBar(title: const Text('오류'), content: Text('삭제 실패: $e'), severity: InfoBarSeverity.error);
        });
      }
    }
  }

  Future<void> _deleteRecord(String recordId) async {
    try {
      await _firestore.collection('attendance_records').doc(recordId).delete();
      if (_selectedEvent != null) {
        final eventId = _selectedEvent!['_id'] as String;
        await _firestore.collection('attendance_events').doc(eventId).update({
          'attendeeCount': FieldValue.increment(-1),
        });
        _loadEvents();
        _loadRecords(eventId);
      }
    } catch (e) {
      if (mounted) {
        await displayInfoBar(context, builder: (context, close) {
          return InfoBar(title: const Text('오류'), content: Text('삭제 실패: $e'), severity: InfoBarSeverity.error);
        });
      }
    }
  }
}

// ──────────── 이벤트 생성 다이얼로그 ────────────
class _AttendanceEventCreateDialog extends StatefulWidget {
  final FirebaseFirestore firestore;
  final Future<Map<String, bool>> Function(String floor) loadRoomsForFloor;
  final Future<void> Function(String title, String floor, List<String> selectedRooms) onCreate;
  final Future<void> Function(String title, String floor) onCreateFloorWide;

  const _AttendanceEventCreateDialog({
    required this.firestore,
    required this.loadRoomsForFloor,
    required this.onCreate,
    required this.onCreateFloorWide,
  });

  @override
  State<_AttendanceEventCreateDialog> createState() => _AttendanceEventCreateDialogState();
}

class _AttendanceEventCreateDialogState extends State<_AttendanceEventCreateDialog> {
  final _titleController = TextEditingController();
  String? _selectedFloor;
  // 호실번호 -> 거주 학생 존재 여부
  Map<String, bool> _rooms = {};
  Set<String> _selectedRooms = {};
  bool _isLoadingRooms = false;
  bool _isCreating = false;
  // true면 구역 전체 재실 학생을 1개 통합 이벤트로 생성 (호실별 개별 생성이 아님)
  bool _isFloorWideMode = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _onFloorChanged(String floor) async {
    setState(() { _selectedFloor = floor; _isLoadingRooms = true; _rooms = {}; _selectedRooms = {}; });
    final rooms = await widget.loadRoomsForFloor(floor);
    if (!mounted) return;
    setState(() {
      _rooms = rooms;
      // 거주 학생이 있는 호실만 기본 체크
      _selectedRooms = rooms.entries.where((e) => e.value).map((e) => e.key).toSet();
      _isLoadingRooms = false;
    });
  }

  int get _occupiedRoomCount => _rooms.values.where((v) => v).length;

  @override
  Widget build(BuildContext context) {
    final allSelected = _occupiedRoomCount > 0 && _selectedRooms.length == _occupiedRoomCount;
    final canCreate = !_isCreating &&
        _titleController.text.trim().isNotEmpty &&
        _selectedFloor != null &&
        (_isFloorWideMode ? _occupiedRoomCount > 0 : _selectedRooms.isNotEmpty);

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 520, maxHeight: 700),
      title: const Text('출석체크 이벤트 생성'),
      content: SingleChildScrollView(
        child: StatefulBuilder(
          builder: (context, setSt) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 이벤트명
              const Text('이벤트명 *', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextBox(
                controller: _titleController,
                placeholder: '예: 2026년 3월 주간 점호',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              // 관리구역
              const Text('관리구역 *', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ComboBox<String>(
                value: _selectedFloor,
                isExpanded: true,
                placeholder: const Text('구역 선택'),
                items: kFloorOptions.map((f) => ComboBoxItem(value: f, child: Text(f))).toList(),
                onChanged: (v) { if (v != null) _onFloorChanged(v); },
              ),
              const SizedBox(height: 16),
              // 생성 방식 선택
              const Text('생성 방식', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioButton(
                      checked: !_isFloorWideMode,
                      onChanged: (v) {
                        if (v) setState(() => _isFloorWideMode = false);
                      },
                      content: const Text('호실별로 개별 생성', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  Expanded(
                    child: RadioButton(
                      checked: _isFloorWideMode,
                      onChanged: (v) {
                        if (v) setState(() => _isFloorWideMode = true);
                      },
                      content: const Text('구역 전체 통합 생성', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 호실 목록 / 구역 전체 안내
              if (_selectedFloor != null) ...[
                const Divider(),
                const SizedBox(height: 8),
                if (_isLoadingRooms)
                  Column(children: List.generate(4, (_) => const Padding(padding: EdgeInsets.only(bottom: 6), child: AttendanceRowShimmer())))
                else if (_isFloorWideMode)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: FluentTheme.of(context).accentColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(FluentIcons.info, size: 16, color: FluentTheme.of(context).accentColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _occupiedRoomCount > 0
                                ? '$_selectedFloor 구역의 재실 학생 전원(${_occupiedRoomCount}개 호실)을 하나의 이벤트로 생성합니다.'
                                : '해당 구역에 재실 학생이 없습니다.',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_rooms.isEmpty)
                  Text('해당 구역에 배정된 학생이 없습니다', style: TextStyle(color: Colors.grey[100]))
                else ...[
                  // 전체 선택
                  Row(
                    children: [
                      Checkbox(
                        checked: allSelected,
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selectedRooms = _rooms.entries.where((e) => e.value).map((e) => e.key).toSet();
                          } else {
                            _selectedRooms.clear();
                          }
                        }),
                      ),
                      const SizedBox(width: 8),
                      Text('전체 선택 (${_selectedRooms.length}/${_occupiedRoomCount}호)', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('거주 학생이 없는 호실은 선택할 수 없습니다', style: TextStyle(fontSize: 11, color: Colors.grey[100])),
                  const SizedBox(height: 4),
                  // 호실 체크박스 격자
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: _rooms.entries.map((entry) {
                      final room = entry.key;
                      final isOccupied = entry.value;
                      final isChecked = _selectedRooms.contains(room);
                      return GestureDetector(
                        onTap: !isOccupied
                            ? null
                            : () => setState(() {
                                  if (isChecked) _selectedRooms.remove(room);
                                  else _selectedRooms.add(room);
                                }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: !isOccupied
                                ? FluentTheme.of(context).cardColor.withOpacity(0.4)
                                : isChecked
                                    ? FluentTheme.of(context).accentColor.withOpacity(0.15)
                                    : FluentTheme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: !isOccupied
                                  ? Colors.grey.withOpacity(0.15)
                                  : isChecked
                                      ? FluentTheme.of(context).accentColor
                                      : Colors.grey.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            '$room호',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                              color: !isOccupied
                                  ? Colors.grey.withOpacity(0.5)
                                  : isChecked
                                      ? FluentTheme.of(context).accentColor
                                      : null,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        Button(
          child: const Text('취소'),
          onPressed: _isCreating ? null : () => Navigator.pop(context),
        ),
        FilledButton(
          onPressed: canCreate
              ? () async {
                  setState(() => _isCreating = true);
                  if (_isFloorWideMode) {
                    await widget.onCreateFloorWide(
                      _titleController.text.trim(),
                      _selectedFloor!,
                    );
                  } else {
                    await widget.onCreate(
                      _titleController.text.trim(),
                      _selectedFloor!,
                      _selectedRooms.toList()..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0)),
                    );
                  }
                }
              : null,
          child: _isCreating
              ? const SizedBox(width: 16, height: 16, child: ProgressRing(strokeWidth: 2))
              : Text(_isFloorWideMode
                  ? '통합 생성'
                  : (_selectedRooms.isEmpty ? '생성' : '${_selectedRooms.length}개 생성')),
        ),
      ],
    );
  }
}

// ──────────── QR 코드 전체화면 다이얼로그 ────────────
class _QrCodeDialog extends StatefulWidget {
  final String eventId;
  final String eventTitle;
  final FirebaseFirestore firestore;
  final String Function() generateToken;

  const _QrCodeDialog({
    required this.eventId,
    required this.eventTitle,
    required this.firestore,
    required this.generateToken,
  });

  @override
  State<_QrCodeDialog> createState() => _QrCodeDialogState();
}

class _QrCodeDialogState extends State<_QrCodeDialog> {
  Timer? _timer;
  String _currentToken = '';
  int _secondsLeft = 7;
  static const int _intervalSeconds = 7;

  @override
  void initState() {
    super.initState();
    _refreshToken();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          _refreshToken();
        }
      });
    });
  }

  Future<void> _refreshToken() async {
    final token = widget.generateToken();
    _currentToken = token;
    _secondsLeft = _intervalSeconds;

    try {
      await widget.firestore.collection('attendance_events').doc(widget.eventId).update({
        'currentToken': token,
      });
    } catch (_) {}

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    // QR 다이얼로그 닫을 때 토큰 초기화
    widget.firestore.collection('attendance_events').doc(widget.eventId).update({
      'currentToken': '',
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qrData = 'attendance:${widget.eventId}:$_currentToken';

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 620),
      title: Row(
        children: [
          const Icon(FluentIcons.q_r_code, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.eventTitle)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          const Text(
            '학생 앱에서 이 QR 코드를 스캔하세요',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          // QR 코드
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 280,
              backgroundColor: const Color(0xFFFFFFFF),
            ),
          ),
          const SizedBox(height: 16),
          // 타이머 표시
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 프로그레스 바
              SizedBox(
                width: 200,
                child: ProgressBar(value: (_secondsLeft / _intervalSeconds) * 100),
              ),
              const SizedBox(width: 12),
              Text(
                '${_secondsLeft}초 후 갱신',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
      actions: [
        FilledButton(
          child: const Text('닫기'),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
