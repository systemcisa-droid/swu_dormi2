import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/reservation_strings.dart';

// 30분 단위 슬롯: 00:00 ~ 24:00 → 인덱스 0(00:00~00:30) ~ 47(23:30~24:00)
const int _kSlotStartHour = 0;
const int _kSlotEndHour = 24;
const int _kSlotsPerHour = 2;
const int _kTotalSlots = (_kSlotEndHour - _kSlotStartHour) * _kSlotsPerHour;
const int _kMaxSlotSpan = 4; // 최대 2시간(30분 x 4)

String _slotTimeLabel(int slotIndex) {
  final totalMinutes = _kSlotStartHour * 60 + slotIndex * 30;
  final hour = totalMinutes ~/ 60;
  final minute = totalMinutes % 60;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class _SeminarRoom {
  final String id;
  final String label;
  const _SeminarRoom(this.id, this.label);
}

const _kShalomRooms = [
  _SeminarRoom('shalom_123', '샬롬하우스 123호'),
  _SeminarRoom('shalom_125', '샬롬하우스 125호'),
];
const _kGlobalRooms = [
  _SeminarRoom('global_231', '국제생활관 231호'),
  _SeminarRoom('global_232', '국제생활관 232호'),
];

// 샬롬하우스 125호는 매주 월요일 21:30~22:30에 예약할 수 없다 (고정 일정 사용).
// 슬롯 43=21:30~22:00, 44=22:00~22:30 (endSlot은 기존 예약과 같이 포함 범위).
const String _kBlockedRoomId = 'shalom_125';
const int _kBlockedWeekday = DateTime.monday;
const int _kBlockedStartSlot = 43;
const int _kBlockedEndSlot = 44;

bool _isRuleBlockedSlot(String roomId, int slotIndex, DateTime date) {
  return roomId == _kBlockedRoomId &&
      date.weekday == _kBlockedWeekday &&
      slotIndex >= _kBlockedStartSlot &&
      slotIndex <= _kBlockedEndSlot;
}

class ReservationScreen extends StatefulWidget {
  const ReservationScreen({super.key});

  @override
  State<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _dateFormat = DateFormat('yyyy-MM-dd');

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
  List<_SeminarRoom> _rooms = [];
  _SeminarRoom? _selectedRoom;

  // roomId -> 예약된 슬롯 인덱스 집합 (오늘 기준)
  Map<String, Set<int>> _bookedSlotsByRoom = {};
  // 내가 오늘 예약한 문서 (없으면 null)
  Map<String, dynamic>? _myReservation;

  int? _rangeStart;
  int? _rangeEnd; // inclusive

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      final dormBuilding = user?.dormBuilding;

      if (dormBuilding == null || dormBuilding.isEmpty) {
        setState(() {
          _isLoading = false;
          _rooms = [];
        });
        return;
      }

      _rooms = dormBuilding.startsWith('국제생활관') ? _kGlobalRooms : _kShalomRooms;
      _selectedRoom ??= _rooms.first;

      final today = _dateFormat.format(DateTime.now());
      final snap = await _firestore
          .collection('seminar_room_reservations')
          .where('date', isEqualTo: today)
          .get();

      final now = DateTime.now();
      final booked = <String, Set<int>>{};
      Map<String, dynamic>? myReservation;
      for (final doc in snap.docs) {
        final data = doc.data();
        data['_id'] = doc.id;
        final roomId = data['roomId'] as String? ?? '';
        final start = (data['startSlot'] as num?)?.toInt() ?? 0;
        final end = (data['endSlot'] as num?)?.toInt() ?? start;
        booked.putIfAbsent(roomId, () => {});
        for (int i = start; i <= end; i++) {
          booked[roomId]!.add(i);
        }
        if (data['userId'] == user?.uid) {
          myReservation = data;
        }
      }
      // 요일·시간 고정 제한(예: 샬롬하우스 125호 월요일 21:30~22:30)을 이미 예약된 것처럼 병합한다.
      // 이렇게 하면 칸 색칠·탭 방지·범위 검증이 기존 예약과 동일한 로직으로 동작한다.
      for (final room in [..._kShalomRooms, ..._kGlobalRooms]) {
        for (int i = 0; i < _kTotalSlots; i++) {
          if (_isRuleBlockedSlot(room.id, i, now)) {
            booked.putIfAbsent(room.id, () => {}).add(i);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _bookedSlotsByRoom = booked;
        _myReservation = myReservation;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '$e';
      });
    }
  }

  bool _isSlotBooked(int slotIndex) {
    final room = _selectedRoom;
    if (room == null) return false;
    return _bookedSlotsByRoom[room.id]?.contains(slotIndex) ?? false;
  }

  void _onTapSlot(int slotIndex) {
    if (_isSlotBooked(slotIndex)) return;
    setState(() {
      if (_rangeStart == null || _rangeEnd != null) {
        // 새로 시작
        _rangeStart = slotIndex;
        _rangeEnd = null;
        return;
      }
      // 두 번째 탭: 범위 확정
      final start = _rangeStart!;
      final lo = slotIndex < start ? slotIndex : start;
      final hi = slotIndex < start ? start : slotIndex;
      final span = hi - lo + 1;
      if (span > _kMaxSlotSpan) {
        _rangeStart = slotIndex;
        _rangeEnd = null;
        return;
      }
      // 범위 내에 이미 예약된 슬롯이 있으면 무시
      for (int i = lo; i <= hi; i++) {
        if (_isSlotBooked(i)) {
          _rangeStart = slotIndex;
          _rangeEnd = null;
          return;
        }
      }
      _rangeStart = lo;
      _rangeEnd = hi;
    });
  }

  Future<void> _submitReservation() async {
    // 처리 중 재진입(중복 제출) 방지
    if (_isSubmitting) return;
    final s = ReservationStrings(Provider.of<LocaleProvider>(context, listen: false).isEnglish);
    final room = _selectedRoom;
    if (room == null || _rangeStart == null || _rangeEnd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.selectTimeFirst), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_myReservation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.alreadyReservedToday), backgroundColor: Colors.orange),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) return;

    // 요일·시간 고정 제한 재확인 (로드 시점과 자정을 넘겨 제출 시점의 요일이 달라지는 경우 대비).
    for (int i = _rangeStart!; i <= _rangeEnd!; i++) {
      if (_isRuleBlockedSlot(room.id, i, DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.shalom125MondayCaution), backgroundColor: Colors.red),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      final today = _dateFormat.format(DateTime.now());

      // 제출 직전 재확인: 동시성으로 인한 중복 예약 방지
      final recheckSnap = await _firestore
          .collection('seminar_room_reservations')
          .where('date', isEqualTo: today)
          .where('roomId', isEqualTo: room.id)
          .get();
      for (final doc in recheckSnap.docs) {
        final data = doc.data();
        final start = (data['startSlot'] as num?)?.toInt() ?? 0;
        final end = (data['endSlot'] as num?)?.toInt() ?? start;
        if (_rangeStart! <= end && _rangeEnd! >= start) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.slotUnavailable), backgroundColor: Colors.red),
          );
          setState(() => _isSubmitting = false);
          await _load();
          return;
        }
      }
      final myTodaySnap = await _firestore
          .collection('seminar_room_reservations')
          .where('date', isEqualTo: today)
          .where('userId', isEqualTo: user.uid)
          .get();
      if (myTodaySnap.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.alreadyReservedToday), backgroundColor: Colors.orange),
        );
        setState(() => _isSubmitting = false);
        await _load();
        return;
      }

      await _firestore.collection('seminar_room_reservations').add({
        'roomId': room.id,
        'roomLabel': room.label,
        'date': today,
        'startSlot': _rangeStart,
        'endSlot': _rangeEnd,
        'userId': user.uid,
        'userName': user.name,
        'roomNumber': user.roomNumber,
        'createdAt': Timestamp.now(),
      });

      if (!mounted) return;
      final timeRange = '${_slotTimeLabel(_rangeStart!)}~${_slotTimeLabel(_rangeEnd! + 1)}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.reserveSuccess(room.label, timeRange)), backgroundColor: Colors.green),
      );
      setState(() {
        _rangeStart = null;
        _rangeEnd = null;
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.errorLabel(e)), backgroundColor: Colors.red),
      );
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _cancelReservation() async {
    final s = ReservationStrings(Provider.of<LocaleProvider>(context, listen: false).isEnglish);
    final reservation = _myReservation;
    if (reservation == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.cancelConfirmTitle),
        content: Text(s.cancelConfirmContent),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.keep)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.confirm, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _firestore
          .collection('seminar_room_reservations')
          .doc(reservation['_id'] as String)
          .delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.cancelSuccess), backgroundColor: Colors.green),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.errorLabel(e)), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ReservationStrings(Provider.of<LocaleProvider>(context).isEnglish);
    return Scaffold(
      appBar: AppBar(title: Text(s.title)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(s.errorLabel(_error!)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _load, child: const Text('다시 시도')),
                    ],
                  ),
                )
              : _rooms.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(s.residenceInfoMissing, textAlign: TextAlign.center),
                      ),
                    )
                  : _buildContent(s),
    );
  }

  Widget _buildContent(ReservationStrings s) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 예약 안내 + 주의사항
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.indigo.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.todayOnlyNotice,
                        style: TextStyle(
                          color: Colors.indigo.shade700,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildCautionItem(s.cautionMaxHours),
                const SizedBox(height: 3),
                _buildCautionItem(s.cautionNoProxy),
                if (_rooms.any((r) => r.id == _kBlockedRoomId)) ...[
                  const SizedBox(height: 3),
                  _buildCautionItem(s.shalom125MondayCaution),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_myReservation != null) _buildMyReservationCard(s),
          if (_myReservation != null) const SizedBox(height: 20),
          Text(s.roomLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _rooms.map((room) {
              final selected = _selectedRoom?.id == room.id;
              return ChoiceChip(
                label: Text(room.label),
                selected: selected,
                onSelected: _myReservation != null
                    ? null
                    : (v) {
                        if (!v) return;
                        setState(() {
                          _selectedRoom = room;
                          _rangeStart = null;
                          _rangeEnd = null;
                        });
                      },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Text(s.timeLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Opacity(
            opacity: _myReservation != null ? 0.4 : 1.0,
            child: IgnorePointer(
              ignoring: _myReservation != null,
              child: _buildSlotGrid(),
            ),
          ),
          const SizedBox(height: 20),
          if (_myReservation == null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReservation,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(s.reserveButton),
              ),
            ),
        ],
      ),
    );
  }

  /// 주의사항 한 줄 (가운뎃점 + 본문)
  Widget _buildCautionItem(String text) {
    // 안내 박스 안에 들어가므로 배경색과 어울리는 톤으로 맞춘다.
    final color = Colors.indigo.shade700;
    return Padding(
      padding: const EdgeInsets.only(left: 26),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('· ', style: TextStyle(fontSize: 13, color: color)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: color, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyReservationCard(ReservationStrings s) {
    final reservation = _myReservation!;
    final roomLabel = reservation['roomLabel'] as String? ?? '';
    final start = (reservation['startSlot'] as num?)?.toInt() ?? 0;
    final end = (reservation['endSlot'] as num?)?.toInt() ?? start;
    final timeRange = '${_slotTimeLabel(start)} ~ ${_slotTimeLabel(end + 1)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_available, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Text(s.myReservationTitle,
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800)),
            ],
          ),
          const SizedBox(height: 8),
          Text(roomLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 2),
          Text(timeRange, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _cancelReservation,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              child: Text(s.cancelButton),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotGrid() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(_kTotalSlots, (i) {
        final booked = _isSlotBooked(i);
        final inRange = _rangeStart != null &&
            _rangeEnd != null &&
            i >= _rangeStart! &&
            i <= _rangeEnd!;
        final isRangeStartOnly = _rangeStart == i && _rangeEnd == null;

        Color bg;
        Color fg;
        Color border;
        if (booked) {
          bg = Colors.grey.shade200;
          fg = Colors.grey.shade500;
          border = Colors.grey.shade300;
        } else if (inRange || isRangeStartOnly) {
          bg = Colors.indigo;
          fg = Colors.white;
          border = Colors.indigo;
        } else {
          bg = Colors.white;
          fg = Colors.grey.shade800;
          border = Colors.grey.shade300;
        }

        return GestureDetector(
          onTap: (booked || _isSubmitting) ? null : () => _onTapSlot(i),
          child: Container(
            width: 72,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: border),
            ),
            child: Text(
              _slotTimeLabel(i),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w500),
            ),
          ),
        );
      }),
    );
  }
}
