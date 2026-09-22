import 'package:flutter/material.dart' hide Colors, FilledButton, IconButton, Card, ListTile, showDialog, Divider, Checkbox, Tooltip, ButtonStyle;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// 샬롬하우스 125호는 매주 월요일 21:30~22:30을 정기적으로 막아둔다(관리자 지정).
// 학생앱(swu_dormi_student/lib/screens/reservation/reservation_screen.dart)의 같은 규칙과 짝을 이루되,
// 여기서는 실제 예약 문서로 만들어 이 캘린더에 예약된 것처럼 보이고, 특정 주만 예약 취소 버튼으로
// 해제할 수도 있게 한다(예: 그 주에 세미나실을 실제로 열어줘야 하는 경우).
const String _kRecurringBlockRoomLabel = '샬롬하우스 125호';
const int _kRecurringBlockWeekday = DateTime.monday;
const int _kRecurringBlockStartSlot = 43; // 21:30
const int _kRecurringBlockEndSlot = 44; // ~22:30
const String _kRecurringBlockUserName = '정기예약(관리자 지정)';

const int _kSlotStartHour = 0;
const int _kSlotEndHour = 24;
const int _kSlotsPerHour = 2;
const int _kTotalSlots = (_kSlotEndHour - _kSlotStartHour) * _kSlotsPerHour;

String _slotTimeLabel(int slotIndex) {
  final totalMinutes = _kSlotStartHour * 60 + slotIndex * 30;
  final hour = totalMinutes ~/ 60;
  final minute = totalMinutes % 60;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

const _kRooms = [
  '샬롬하우스 123호',
  '샬롬하우스 125호',
  '국제생활관 231호',
  '국제생활관 232호',
];

final _kRoomColors = {
  '샬롬하우스 123호': Colors.blue,
  '샬롬하우스 125호': Colors.teal,
  '국제생활관 231호': Colors.purple,
  '국제생활관 232호': Colors.orange,
};

/// 학생앱 세미나실 예약(seminar_room_reservations)을 시간표 형태로 모니터링하는 화면.
/// 방(열) x 30분 시간대(행)로 배치해 예약/공실 여부를 한눈에 볼 수 있게 한다.
class WindowsReservationsScreen extends StatefulWidget {
  const WindowsReservationsScreen({super.key});

  @override
  State<WindowsReservationsScreen> createState() => _WindowsReservationsScreenState();
}

class _WindowsReservationsScreenState extends State<WindowsReservationsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _dateFormat = DateFormat('yyyy-MM-dd');
  final _displayDateFormat = DateFormat('yyyy.MM.dd (E)', 'ko_KR');

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  String _errorMessage = '';
  List<Map<String, dynamic>> _reservations = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final dateKey = _dateFormat.format(_selectedDate);
      var list = await _fetchReservations(dateKey);

      // 이 날짜가 월요일이고, 아직 정기 예약 문서가 없으면(과거 날짜는 건드리지 않는다) 만들어 둔다.
      final today = DateTime.now();
      final isPastDate = _selectedDate
          .isBefore(DateTime(today.year, today.month, today.day));
      if (!isPastDate && _selectedDate.weekday == _kRecurringBlockWeekday) {
        final hasBlock = list.any((r) => _overlapsRecurringBlock(r));
        if (!hasBlock) {
          final created = await _ensureRecurringBlock(dateKey);
          if (created) list = await _fetchReservations(dateKey);
        }
      }

      if (!mounted) return;
      setState(() {
        _reservations = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchReservations(String dateKey) async {
    final snap = await _firestore
        .collection('seminar_room_reservations')
        .where('date', isEqualTo: dateKey)
        .get();
    return snap.docs.map((d) {
      final data = d.data();
      data['_id'] = d.id;
      return data;
    }).toList();
  }

  bool _overlapsRecurringBlock(Map<String, dynamic> r) {
    if (r['roomLabel'] != _kRecurringBlockRoomLabel) return false;
    final start = (r['startSlot'] as num?)?.toInt() ?? 0;
    final end = (r['endSlot'] as num?)?.toInt() ?? start;
    return start <= _kRecurringBlockEndSlot && end >= _kRecurringBlockStartSlot;
  }

  /// 정기 예약 문서를 생성한다. 관리자 계정 UID로 만들어야 보안 규칙(생성자 본인 uid)을 통과한다.
  /// 로그인 정보를 못 가져오는 등 실패해도 화면 로딩 자체는 막지 않는다.
  Future<bool> _ensureRecurringBlock(String dateKey) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    try {
      await _firestore.collection('seminar_room_reservations').add({
        'roomId': 'shalom_125',
        'roomLabel': _kRecurringBlockRoomLabel,
        'date': dateKey,
        'startSlot': _kRecurringBlockStartSlot,
        'endSlot': _kRecurringBlockEndSlot,
        'userId': uid,
        'userName': _kRecurringBlockUserName,
        'roomNumber': '-',
        'isRecurringBlock': true,
        'createdAt': Timestamp.now(),
      });
      return true;
    } catch (e) {
      debugPrint('정기 예약 생성 실패: $e');
      return false;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      await _load();
    }
  }

  // roomLabel -> 해당 방의 예약 목록 (슬롯 순 정렬)
  Map<String, List<Map<String, dynamic>>> get _reservationsByRoom {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final room in _kRooms) {
      map[room] = _reservations.where((r) => r['roomLabel'] == room).toList()
        ..sort((a, b) {
          final aStart = (a['startSlot'] as num?)?.toInt() ?? 0;
          final bStart = (b['startSlot'] as num?)?.toInt() ?? 0;
          return aStart.compareTo(bStart);
        });
    }
    return map;
  }

  // 특정 방의 특정 슬롯에 해당하는 예약을 찾는다 (있으면 반환, 없으면 null)
  Map<String, dynamic>? _reservationAt(
      Map<String, List<Map<String, dynamic>>> byRoom, String room, int slot) {
    for (final r in byRoom[room] ?? const []) {
      final start = (r['startSlot'] as num?)?.toInt() ?? 0;
      final end = (r['endSlot'] as num?)?.toInt() ?? start;
      if (slot >= start && slot <= end) return r;
    }
    return null;
  }

  Future<void> _showReservationDetail(Map<String, dynamic> r) async {
    final roomLabel = r['roomLabel'] as String? ?? '';
    final userName = r['userName'] as String? ?? '';
    final roomNumber = r['roomNumber'] as String? ?? '';
    final isRecurringBlock = r['isRecurringBlock'] == true;
    final start = (r['startSlot'] as num?)?.toInt() ?? 0;
    final end = (r['endSlot'] as num?)?.toInt() ?? start;
    final createdAt = (r['createdAt'] as Timestamp?)?.toDate();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('예약 상세'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _detailRow('세미나실', roomLabel),
            _detailRow('시간', '${_slotTimeLabel(start)} ~ ${_slotTimeLabel(end + 1)}'),
            _detailRow('예약자', isRecurringBlock ? userName : '$userName ($roomNumber호)'),
            if (isRecurringBlock)
              _detailRow('안내', '매주 월요일 자동 생성. 이 주만 취소하려면 아래 예약 취소를 누르세요.'),
            if (createdAt != null)
              _detailRow('신청 시각', DateFormat('yyyy.MM.dd HH:mm').format(createdAt)),
          ],
        ),
        actions: [
          Button(child: const Text('닫기'), onPressed: () => Navigator.pop(ctx, false)),
          FilledButton(
            style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Colors.red)),
            child: const Text('예약 취소'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed == true) await _cancelReservation(r);
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: TextStyle(color: Colors.grey[100], fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Future<void> _cancelReservation(Map<String, dynamic> reservation) async {
    try {
      await _firestore.collection('seminar_room_reservations').doc(reservation['_id'] as String).delete();
      if (!mounted) return;
      await displayInfoBar(
        context,
        builder: (c, close) => const InfoBar(
          title: Text('예약이 취소되었습니다'),
          severity: InfoBarSeverity.success,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      await displayInfoBar(
        context,
        builder: (c, close) => InfoBar(
          title: Text('오류: $e'),
          severity: InfoBarSeverity.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: const Text('세미나실 예약'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.calendar),
              label: Text(_displayDateFormat.format(_selectedDate)),
              onPressed: _pickDate,
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.refresh),
              label: const Text('오늘'),
              onPressed: () {
                setState(() => _selectedDate = DateTime.now());
                _load();
              },
            ),
          ],
        ),
      ),
      content: _isLoading
          ? const Center(child: ProgressRing())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(FluentIcons.error, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text('데이터 로드 실패: $_errorMessage'),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('다시 시도')),
                    ],
                  ),
                )
              : _buildTimetable(),
    );
  }

  Widget _buildTimetable() {
    final byRoom = _reservationsByRoom;
    const timeColWidth = 64.0;
    const rowHeight = 16.0;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 범례
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 16,
              runSpacing: 6,
              children: _kRooms.map((room) {
                final color = _kRoomColors[room] ?? Colors.grey;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(room, style: TextStyle(fontSize: 12, color: Colors.grey[110])),
                  ],
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 시간 라벨 열
                  Column(
                    children: [
                      const SizedBox(height: 40), // 헤더 높이 맞춤
                      ...List.generate(_kTotalSlots, (slot) {
                        final isHourMark = slot % _kSlotsPerHour == 0;
                        return SizedBox(
                          width: timeColWidth,
                          height: rowHeight,
                          child: isHourMark
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    _slotTimeLabel(slot),
                                    style: TextStyle(fontSize: 11, color: Colors.grey[110]),
                                  ),
                                )
                              : null,
                        );
                      }),
                    ],
                  ),
                  // 방별 열
                  ..._kRooms.map((room) {
                    final color = _kRoomColors[room] ?? Colors.grey;
                    return Column(
                      children: [
                        // 방 이름 헤더
                        Container(
                          width: 150,
                          height: 40,
                          alignment: Alignment.center,
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            room,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        _buildRoomColumn(room, byRoom, color, timeColWidth, rowHeight),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 한 방에 대해 전체 슬롯을 순회하며, 예약 블록은 병합된 하나의 셀로, 빈 슬롯은 개별 셀로 그린다.
  Widget _buildRoomColumn(
    String room,
    Map<String, List<Map<String, dynamic>>> byRoom,
    Color color,
    double timeColWidth,
    double rowHeight,
  ) {
    final children = <Widget>[];
    int slot = 0;
    while (slot < _kTotalSlots) {
      final reservation = _reservationAt(byRoom, room, slot);
      if (reservation == null) {
        children.add(_buildEmptySlotCell(rowHeight));
        slot++;
        continue;
      }
      final start = (reservation['startSlot'] as num?)?.toInt() ?? slot;
      final end = (reservation['endSlot'] as num?)?.toInt() ?? start;
      final span = end - start + 1;
      children.add(_buildBookedCell(reservation, color, rowHeight * span));
      slot = end + 1;
    }
    return Container(
      margin: const EdgeInsets.only(left: 4),
      width: 150,
      child: Column(children: children),
    );
  }

  Widget _buildEmptySlotCell(double rowHeight) {
    return Container(
      height: rowHeight,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        color: Colors.grey.withValues(alpha: 0.02),
      ),
    );
  }

  Widget _buildBookedCell(Map<String, dynamic> reservation, Color color, double height) {
    final userName = reservation['userName'] as String? ?? '';
    final roomNumber = reservation['roomNumber'] as String? ?? '';
    final start = (reservation['startSlot'] as num?)?.toInt() ?? 0;
    final end = (reservation['endSlot'] as num?)?.toInt() ?? start;

    return GestureDetector(
      onTap: () => _showReservationDetail(reservation),
      child: Tooltip(
        message: '${_slotTimeLabel(start)}~${_slotTimeLabel(end + 1)}  $userName ($roomNumber호)\n클릭하여 상세/취소',
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.75),
            border: Border.all(color: color),
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            height >= 32 ? '$userName ($roomNumber호)' : userName,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}
