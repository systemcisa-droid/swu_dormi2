import 'package:flutter/material.dart' hide Colors, FilledButton, IconButton, Card, ListTile, showDialog, Divider, Checkbox, Tooltip, ButtonStyle;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
      final snap = await _firestore
          .collection('seminar_room_reservations')
          .where('date', isEqualTo: dateKey)
          .get();
      final list = snap.docs.map((d) {
        final data = d.data();
        data['_id'] = d.id;
        return data;
      }).toList();
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
            _detailRow('예약자', '$userName ($roomNumber호)'),
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
