import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/attendance_strings.dart';
import '../../widgets/user_avatar.dart';

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

  bool _autoOpened = false;

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

      // 사이드 메뉴에서 진입하면 바로 내 QR 코드를 보여준다 (최초 1회만).
      if (!_autoOpened && !_isBlocked) {
        _autoOpened = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showMyQrCode();
        });
      }
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

  // ──────────── 내 QR 코드 표시 ────────────
  void _showMyQrCode() {
    if (_isBlocked) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _MyQrCodePage(
          uid: user.uid,
          studentId: user.studentId,
          profileImageUrl: user.profileImageUrl,
          userName: user.name,
          onCheckedIn: _loadData,
        ),
      ),
    );
  }
}

// ──────────── 내 QR 코드 페이지 ────────────
// QR 유효시간: 5초. 만료 전 자동으로 새 QR(타임스탬프 갱신)을 생성한다.
class _MyQrCodePage extends StatefulWidget {
  final String uid;
  final String studentId;
  final String? profileImageUrl;
  final String userName;
  final VoidCallback onCheckedIn;

  const _MyQrCodePage({
    required this.uid,
    required this.studentId,
    required this.profileImageUrl,
    required this.userName,
    required this.onCheckedIn,
  });

  @override
  State<_MyQrCodePage> createState() => _MyQrCodePageState();
}

class _MyQrCodePageState extends State<_MyQrCodePage> {
  static const _validSeconds = 5;

  StreamSubscription<QuerySnapshot>? _recordsSubscription;
  final Set<String> _seenRecordIds = {};
  Timer? _refreshTimer;
  int _issuedAtMs = 0;
  int _remainingSeconds = _validSeconds;

  @override
  void initState() {
    super.initState();
    _regenerateQr();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 1) {
        setState(() => _remainingSeconds--);
      } else {
        _regenerateQr();
      }
    });
    // 층장이 스캔해 출석 기록이 새로 생기면 자동으로 화면을 닫고 목록을 갱신한다.
    bool isFirstSnapshot = true;
    _recordsSubscription = FirebaseFirestore.instance
        .collection('attendance_records')
        .where('userId', isEqualTo: widget.uid)
        .snapshots()
        .listen((snapshot) {
      if (isFirstSnapshot) {
        // 최초 스냅샷은 기존 기록 개수(0건 포함)를 기준으로만 삼고, 이후 콜백에서만 신규 여부를 판단한다.
        isFirstSnapshot = false;
        _seenRecordIds.addAll(snapshot.docs.map((d) => d.id));
        return;
      }
      final hasNew = snapshot.docs.any((d) => !_seenRecordIds.contains(d.id));
      if (hasNew && mounted) {
        widget.onCheckedIn();
        Navigator.pop(context);
      }
    }, onError: (e) {
      debugPrint('출석 기록 리스너 오류: $e');
    });
  }

  void _regenerateQr() {
    setState(() {
      _issuedAtMs = DateTime.now().millisecondsSinceEpoch;
      _remainingSeconds = _validSeconds;
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _recordsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AttendanceStrings(Provider.of<LocaleProvider>(context).isEnglish);
    final qrData = 'student:${widget.studentId}:$_issuedAtMs';
    return Scaffold(
      appBar: AppBar(
        title: Text(s.myQrCodeTitle),
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
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 4),
                ],
              ),
              child: UserAvatar(
                imageUrl: widget.profileImageUrl,
                fallbackName: widget.userName,
                radius: 84,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 240,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.H,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      DateFormat('MM.dd HH:mm:ss').format(DateTime.now()),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.userName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              widget.studentId,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.timer,
                  size: 18,
                  color: _remainingSeconds <= 2 ? Colors.red : Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  s.qrValidFor(_remainingSeconds),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _remainingSeconds <= 2 ? Colors.red : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                s.myQrCodeHint,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
