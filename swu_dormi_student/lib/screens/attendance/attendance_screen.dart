import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:vibration/vibration.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
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

      if (!mounted) return;
      setState(() {
        _residentStatus = residentStatus;
        _residenceInfoMissing = !_hasValidResidenceInfo(user);
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
                      Text(s.errorLabel(_error!)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadData, child: Text(s.retry)),
                    ],
                  ),
                )
              : _buildContent(s),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isBlocked ? null : _openQrScanner,
        icon: Icon(_isBlocked ? Icons.block : Icons.qr_code_scanner),
        label: Text(_isBlocked ? s.attendanceBlocked : s.qrScan),
        backgroundColor: _isBlocked ? Colors.grey.shade400 : Colors.indigo,
        foregroundColor: Colors.white,
      ),
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
              Icon(Icons.qr_code_scanner, size: 32, color: Colors.indigo.shade700),
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
        items.add(_buildRecordItem(record));
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

  Widget _buildRecordItem(Map<String, dynamic> data) {
    final eventTitle = (data['eventTitle'] ?? '') as String;
    final eventLocation = (data['eventLocation'] ?? '') as String;
    final checkedInAt = (data['checkedInAt'] as Timestamp?)?.toDate();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.check_circle, color: Colors.green.shade700, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(eventTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (eventLocation.isNotEmpty) ...[
                      Icon(Icons.location_on, size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 2),
                      Text(eventLocation, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      const SizedBox(width: 8),
                    ],
                    if (checkedInAt != null)
                      Text(
                        DateFormat('yyyy.MM.dd HH:mm').format(checkedInAt),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────── QR 스캐너 ────────────
  void _openQrScanner() {
    if (_isBlocked) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _QrScannerPage(
          onScanned: (String qrData) => _processQrCode(qrData),
        ),
      ),
    );
  }

  Future<void> _processQrCode(String qrData) async {
    final s = AttendanceStrings(
        Provider.of<LocaleProvider>(context, listen: false).isEnglish);
    // 상태 재확인 (QR 스캔 후 돌아왔을 때 방어)
    if (_isBlocked) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.currentStatusBlockedShort(s.status(_residentStatus))),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // QR 형식: "attendance:{eventId}:{token}"
    final parts = qrData.split(':');
    if (parts.length != 3 || parts[0] != 'attendance') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.invalidQrCode), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final eventId = parts[1];
    final token = parts[2];

    if (token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.expiredQrCode), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) return;

    try {
      // 이벤트 존재 여부 및 토큰 검증
      final eventDoc = await _firestore.collection('attendance_events').doc(eventId).get();
      if (!eventDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.eventNotFound), backgroundColor: Colors.red),
          );
        }
        return;
      }

      final eventData = eventDoc.data()!;
      final eventStatus = eventData['status'] as String?;
      final currentToken = eventData['currentToken'] as String?;

      if (eventStatus != 'active') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.eventEnded), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      if (currentToken == null || currentToken.isEmpty || currentToken != token) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.expiredQrCode), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      // 호실 검증
      final eventRoomNumber = eventData['roomNumber'] as String?;
      if (eventRoomNumber != null && eventRoomNumber.isNotEmpty) {
        final studentRoom = user.roomNumber;
        if (studentRoom.isEmpty || studentRoom == '000' || studentRoom != eventRoomNumber) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(s.roomMismatch(eventRoomNumber, studentRoom)),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return;
        }
      }

      // 중복 체크
      final existing = await _firestore
          .collection('attendance_records')
          .where('userId', isEqualTo: user.uid)
          .where('eventId', isEqualTo: eventId)
          .get();

      if (existing.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.alreadyCheckedIn), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      // 출석 기록 저장
      final batch = _firestore.batch();
      final recordRef = _firestore.collection('attendance_records').doc();
      batch.set(recordRef, {
        'eventId': eventId,
        'eventTitle': eventData['title'] ?? '',
        'eventLocation': eventData['location'] ?? '',
        'userId': user.uid,
        'userName': user.name,
        'studentId': user.studentId,
        'roomNumber': user.roomNumber,
        'building': user.building,
        'dormBuilding': user.dormBuilding ?? '',
        'checkedInAt': Timestamp.now(),
      });

      final eventRef = _firestore.collection('attendance_events').doc(eventId);
      batch.update(eventRef, {'attendeeCount': FieldValue.increment(1)});
      await batch.commit();

      if (mounted) {
        // 진동
        if (await Vibration.hasVibrator() ?? false) {
          await Vibration.vibrate(duration: 300);
        }
        // 토스트 메시지
        Fluttertoast.showToast(
          msg: s.checkInCompleted(eventData['title'] ?? ''),
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.CENTER,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.checkInFailed(e)), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ──────────── QR 스캐너 페이지 ────────────
class _QrScannerPage extends StatefulWidget {
  final Future<void> Function(String) onScanned;

  const _QrScannerPage({required this.onScanned});

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AttendanceStrings(Provider.of<LocaleProvider>(context).isEnglish);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.qrScanTitle),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (BarcodeCapture capture) async {
              if (_isProcessing) return;
              final barcode = capture.barcodes.firstOrNull;
              if (barcode == null || barcode.rawValue == null) return;

              final qrData = barcode.rawValue!;
              if (!qrData.startsWith('attendance:')) return;

              _isProcessing = true;
              Navigator.pop(context);
              await widget.onScanned(qrData);
            },
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
          // 안내 텍스트
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              color: Colors.black54,
              child: Text(
                s.qrScanHint,
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
