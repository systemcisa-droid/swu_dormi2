import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  
  bool _isLoadingEvents = true;
  bool _isLoadingRecords = false;
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _roomStudents = [];
  String? _selectedEventId;

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
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoadingEvents = true);
    try {
      final snapshot = await _firestore
          .collection('attendance_events')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final events = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
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
      // 출석 기록 로드
      final snapshot = await _firestore
          .collection('attendance_records')
          .where('eventId', isEqualTo: eventId)
          .get();

      // 해당 호실 학생 로드
      List<Map<String, dynamic>> students = [];
      if (roomNumber != null && roomNumber.isNotEmpty) {
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
        } catch (e) {
          debugPrint('학생 로딩 오류: $e');
        }
      }

      // 기존 수동 상태 로드 (이벤트 문서의 manualStatuses 맵)
      final eventDoc = await _firestore
          .collection('attendance_events')
          .doc(eventId)
          .get();
      final savedStatuses =
          (eventDoc.data()?['manualStatuses'] as Map<String, dynamic>?) ?? {};

      setState(() {
        _records = snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
        _roomStudents = students;
        _manualStatuses.clear();
        savedStatuses.forEach((uid, st) {
          _manualStatuses[uid] = st as String?;
        });
        _isLoadingRecords = false;
      });
    } catch (e) {
      debugPrint('출석 기록 로딩 오류: $e');
      setState(() => _isLoadingRecords = false);
    }
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
                  onPressed: _loadEvents,
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
      onRefresh: _loadEvents,
      child: ListView.builder(
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
    final isSelected = _selectedEventId == eventId;

    final isActive = status == 'active';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
              padding: const EdgeInsets.all(16),
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
                    child: Row(
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
                  ),
                ],
              ),
            ),
          ),
          // 선택된 경우 출석 기록 표시
          if (isSelected) _buildRecordsSection(),
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

  void _showCreateEventDialog() {
    final titleController = TextEditingController();
    final roomController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('출석 이벤트 생성'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: roomController,
              decoration: const InputDecoration(
                labelText: '호실 번호',
                hintText: '예: 401',
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: '이벤트 제목',
                hintText: '예: 2026년 3월 주간 점호',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                _createEvent(
                  titleController.text,
                  roomNumber: roomController.text.trim(),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('생성'),
          ),
        ],
      ),
    );
  }

  Future<void> _createEvent(String title, {String roomNumber = ''}) async {
    try {
      await _firestore.collection('attendance_events').add({
        'title': title,
        if (roomNumber.isNotEmpty) 'roomNumber': roomNumber,
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
