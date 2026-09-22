import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/server_clock.dart';
import '../../utils/attendance_strings.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _myRecords = [];
  bool _isLoading = true;
  String? _error;
  String _residentStatus = '재실중';
  bool _residenceInfoMissing = false;
  // eventId -> 이벤트 문서. 상태 기록에는 isFireDrill이 없어 이벤트 종류를 여기서 판별한다.
  Map<String, Map<String, dynamic>> _eventMap = {};

  static const _blockedStatuses = {'자퇴', '바롬인성교육관'};

  bool get _isBlocked => _blockedStatuses.contains(_residentStatus) || _residenceInfoMissing;

  bool _hasValidResidenceInfo(dynamic user) {
    if (user == null) return false;
    final hasDormBuilding = user.dormBuilding != null && (user.dormBuilding as String).isNotEmpty;
    final hasRoomNumber = (user.roomNumber as String).isNotEmpty && user.roomNumber != '000';
    final hasSeatNumber = user.seatNumber != null && (user.seatNumber as String).isNotEmpty;
    return hasDormBuilding && hasRoomNumber && hasSeatNumber;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
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

      // UserModel에 캐싱된 residentStatus 직접 사용 (Firestore 추가 읽기 불필요)
      final residentStatus = user?.residentStatus ?? '재실중';

      final recordList = <Map<String, dynamic>>[];
      if (user != null) {
        final recSnap = await _firestore
            .collection('attendance_records')
            .where('userId', isEqualTo: user.uid)
            .get();
        for (final doc in recSnap.docs) {
          final m = Map<String, dynamic>.from(doc.data());
          m['_id'] = doc.id;
          recordList.add(m);
        }
        recordList.sort((a, b) {
          final ta = (a['checkedInAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
          final tb = (b['checkedInAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
          return tb.compareTo(ta);
        });
      }

      // 기록이 속한 이벤트 문서를 읽어 종류(화재대피훈련 여부)를 알아낸다.
      // whereIn은 한 번에 10개까지만 받으므로 나눠서 조회한다.
      final eventMap = <String, Map<String, dynamic>>{};
      final eventIds = recordList
          .map((r) => r['eventId'] as String?)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      for (var i = 0; i < eventIds.length; i += 10) {
        final chunk = eventIds.sublist(i, i + 10 > eventIds.length ? eventIds.length : i + 10);
        final snap = await _firestore
            .collection('attendance_events')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          eventMap[doc.id] = doc.data();
        }
      }

      if (!mounted) return;
      setState(() {
        _residentStatus = residentStatus;
        _residenceInfoMissing = !_hasValidResidenceInfo(user);
        _eventMap = eventMap;
        _myRecords = recordList;
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

  @override
  Widget build(BuildContext context) {
    final s = AttendanceStrings(Provider.of<LocaleProvider>(context).isEnglish);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.title),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(s.errorLabel(_error!)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadData, child: Text(s.retry)),
                    ],
                  ),
                )
              : _buildContent(s),
    );
  }

  Widget _buildContent(AttendanceStrings s) {
    final items = <Widget>[];

    // 안내 메시지
    if (_isBlocked) {
      final isBarom = _residentStatus == '바롬인성교육관';
      final blockedColor = isBarom ? Colors.orange : Colors.grey;
      items.add(
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: blockedColor.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: blockedColor.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.block, size: 32, color: blockedColor.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.attendanceUnavailableTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: blockedColor.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _residenceInfoMissing
                          ? s.residenceInfoMissing
                          : s.currentStatusBlocked(s.status(_residentStatus)),
                      style: TextStyle(
                        fontSize: 13,
                        color: blockedColor.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      items.add(
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.qr_code, size: 32, color: Colors.indigo.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.qrCheckTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.indigo.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.qrCheckHint,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.indigo.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 출석 내역
    items.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Text(
          s.recordsCount(_myRecords.length),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
      ),
    );

    if (_myRecords.isEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Text(s.noRecords,
                style: const TextStyle(fontSize: 16, color: Colors.grey)),
          ),
        ),
      );
    } else {
      for (final record in _myRecords) {
        items.add(_buildRecordItem(record, s));
      }
    }

    items.add(const SizedBox(height: 80)); // FAB 공간 확보

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items,
      ),
    );
  }

  Widget _buildRecordItem(Map<String, dynamic> data, AttendanceStrings s) {
    final eventTitle = (data['eventTitle'] ?? '') as String;
    final eventLocation = (data['eventLocation'] ?? '') as String;
    final checkedInAt = (data['checkedInAt'] as Timestamp?)?.toDate();
    final arrivalCheckedAt = (data['arrivalCheckedAt'] as Timestamp?)?.toDate();
    final isComplete = data['isComplete'] != false;
    // 화재대피용(시작→도착 2단계) 레코드 판별: isFireDrill 플래그가 있거나(1차만 확인된 경우도 포함),
    // 도착 확인까지 끝나 arrivalCheckedAt 필드가 채워진 경우(플래그 도입 이전의 과거 데이터 호환).
    final hasArrivalField = data['isFireDrill'] == true || data.containsKey('arrivalCheckedAt');
    // 이벤트 종류. 상태 기록에는 isFireDrill이 없으므로 이벤트 문서에서 판별한다.
    final eventId = data['eventId'] as String?;
    final isFireDrillEvent =
        hasArrivalField || (eventId != null && _eventMap[eventId]?['isFireDrill'] == true);
    // 층장/관리자가 불참·외박 등으로 지정한 상태 기록. QR 체크 기록과 같은 컬렉션에
    // 저장되고 checkedInAt(지정 시각)도 있으므로, 구분하지 않으면 출석한 것처럼 보인다.
    final isStatusRecord = data['recordType'] == 'status';
    final adminStatus = data['adminStatus'] as String?;
    final floorStatus = data['floorStatus'] as String?;
    String? statusLabel = !isStatusRecord
        ? null
        : adminStatus == '외박'
            ? '외박신청완료'
            : (floorStatus ?? adminStatus ?? '기타');
    // '불참'은 이벤트 종료 시 자동으로 남는 값이다. 일반 인원점검(점호)에서 미출석은
    // 관리 프로그램의 상벌점 규칙과 같이 '외박미신청'으로, 화재대피훈련만 '불참'으로 본다.
    if (statusLabel == '불참' && !isFireDrillEvent) statusLabel = '외박미신청';
    final bool isAbsentStatus = statusLabel == '불참' ||
        statusLabel == '부재' ||
        statusLabel == '외박미신청' ||
        statusLabel == '무단퇴사';
    final bool isOvernightStatus =
        statusLabel != null && statusLabel.startsWith('외박') && !isAbsentStatus;
    final Color statusColor = isAbsentStatus
        ? Colors.red.shade700
        : isOvernightStatus
            ? Colors.orange.shade700
            : Colors.grey.shade700;
    final Color statusBgColor = isAbsentStatus
        ? Colors.red.shade50
        : isOvernightStatus
            ? Colors.orange.shade50
            : Colors.grey.shade200;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusLabel != null
                  ? statusBgColor
                  : isComplete
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(
              statusLabel != null
                  ? (isAbsentStatus
                      ? Icons.cancel
                      : isOvernightStatus
                          ? Icons.bedtime_outlined
                          : Icons.info_outline)
                  : isComplete
                      ? Icons.check_circle
                      : Icons.hourglass_top,
              color: statusLabel != null
                  ? statusColor
                  : isComplete
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(eventTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 6),
                    // 이벤트 종류 배지 — QR 기록·상태 기록 모두 표시
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isFireDrillEvent
                            ? Colors.red.withValues(alpha: 0.1)
                            : Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isFireDrillEvent ? '화재대피훈련' : '인원점검',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isFireDrillEvent ? Colors.red.shade700 : Colors.blue.shade700,
                        ),
                      ),
                    ),
                    // 상태 배지 — 층장/관리자가 지정한 상태 기록에만 표시
                    if (statusLabel != null) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          s.recordStatus(statusLabel),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                if (eventLocation.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 2),
                        Text(eventLocation, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                if (statusLabel != null) ...[
                  Text(
                    _captainLabel(data, s),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  if (checkedInAt != null)
                    Text(
                      DateFormat('yyyy.MM.dd HH:mm').format(checkedInAt.toSeoul()),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                ] else if (hasArrivalField) ...[
                  _buildStageRow(
                    label: '시작',
                    time: checkedInAt,
                    done: checkedInAt != null,
                  ),
                  const SizedBox(height: 2),
                  _buildStageRow(
                    label: '도착',
                    time: arrivalCheckedAt,
                    done: arrivalCheckedAt != null,
                  ),
                ] else if (checkedInAt != null)
                  Text(
                    DateFormat('yyyy.MM.dd HH:mm').format(checkedInAt.toSeoul()),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 상태 기록을 남긴 담당 층장의 구역 문구. 기록에는 층장 이메일만 있고 구역이 없으므로
  /// 기록 당시의 건물·호실에서 구역을 계산한다 (동/층 규칙은 UserModel.building/floor와 동일).
  /// 예: 샬롬하우스 412호 → "샬롬하우스 A동 4층 층장", 바롬인성교육관 1001-A호 → "바롬인성교육관 10층 층장"
  String _captainLabel(Map<String, dynamic> data, AttendanceStrings s) {
    final dorm = (data['dormBuilding'] as String? ?? '').trim();
    final room = (data['roomNumber'] as String? ?? '').trim();
    if (dorm.isEmpty || room.isEmpty || room == '000') return s.statusSetByCaptain;

    // 바롬인성교육관은 동 구분이 없고 호실이 '1001-A' 형식이다.
    if (dorm.startsWith('바롬인성교육관')) {
      final digits = int.tryParse(RegExp(r'^\d+').firstMatch(room)?.group(0) ?? '');
      if (digits == null) return s.statusSetByCaptain;
      return s.captainOf('$dorm ${digits ~/ 100}층');
    }

    final roomNum = int.tryParse(room);
    if (roomNum == null) return s.statusSetByCaptain;
    final floorNum = roomNum ~/ 100;
    String? wing;
    if (dorm.startsWith('국제생활관')) {
      if ((roomNum >= 101 && roomNum <= 132) || (roomNum >= 201 && roomNum <= 229)) {
        wing = 'A동';
      } else if ((roomNum >= 233 && roomNum <= 260) || (roomNum >= 301 && roomNum <= 329)) {
        wing = 'B동';
      }
    } else {
      final lastTwo = roomNum % 100;
      if (lastTwo >= 1 && lastTwo <= 20) {
        wing = 'A동';
      } else if (lastTwo >= 21 && lastTwo <= 35) {
        wing = 'B동';
      }
    }
    if (wing == null || floorNum < 1) return s.statusSetByCaptain;
    return s.captainOf('$dorm $wing $floorNum층');
  }

  Widget _buildStageRow({required String label, required DateTime? time, required bool done}) {
    return Row(
      children: [
        Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 13,
          color: done ? Colors.green.shade600 : Colors.grey.shade400,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: done ? Colors.grey.shade700 : Colors.grey.shade400,
          ),
        ),
        if (time != null) ...[
          const SizedBox(width: 6),
          Text(
            DateFormat('MM.dd HH:mm').format(time.toSeoul()),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text('미확인', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
          ),
      ],
    );
  }

}

