import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/locale_provider.dart';
import '../../services/server_clock.dart';
import '../../utils/attendance_strings.dart';
import '../../widgets/user_avatar.dart';

// ──────────── 내 QR 코드 페이지 ────────────
// QR 유효시간: 5초. 만료 전 자동으로 새 QR(타임스탬프 갱신)을 생성한다.
// 인원점검 화면과 홈 사이드메뉴 양쪽에서 공용으로 사용한다.
class MyQrCodePage extends StatefulWidget {
  final String uid;
  final String studentId;
  final String? profileImageUrl;
  final String userName;
  // 층장이 스캔해 출석이 기록되면 호출된다. 목록 갱신이 필요 없는 진입점은 생략 가능.
  final VoidCallback? onCheckedIn;

  const MyQrCodePage({
    super.key,
    required this.uid,
    required this.studentId,
    required this.profileImageUrl,
    required this.userName,
    this.onCheckedIn,
  });

  @override
  State<MyQrCodePage> createState() => _MyQrCodePageState();
}

class _MyQrCodePageState extends State<MyQrCodePage> {
  static const _validSeconds = 5;

  StreamSubscription<QuerySnapshot>? _recordsSubscription;
  // 문서ID → 마지막으로 관찰한 isComplete 값. 화재대피용은 도착 확인 시 기존 문서가
  // isComplete: false → true로 갱신(update)되므로, 신규 문서 생성뿐 아니라 이 전환도 감지해야 한다.
  final Map<String, bool> _seenRecordStates = {};
  Timer? _refreshTimer;
  int _issuedAtMs = 0;
  int _remainingSeconds = _validSeconds;

  @override
  void initState() {
    super.initState();
    _regenerateQr();
    // 폰 시계가 어긋나 있어도 층장앱과 같은 기준(서버 시각)으로 발급되도록,
    // 동기화가 끝나면 QR을 한 번 다시 만든다. 실패하면 기기 시각으로 계속 발급한다.
    ServerClock.sync().then((_) {
      if (mounted) _regenerateQr();
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 1) {
        setState(() => _remainingSeconds--);
      } else {
        _regenerateQr();
      }
    });
    // 층장이 스캔해 출석 기록이 새로 생기거나(1차: 대피 시작),
    // 기존 기록이 미완료→완료로 갱신되면(2차: 대피 도착) 자동으로 화면을 닫고 목록을 갱신한다.
    bool isFirstSnapshot = true;
    _recordsSubscription = FirebaseFirestore.instance
        .collection('attendance_records')
        .where('userId', isEqualTo: widget.uid)
        .snapshots()
        .listen((snapshot) {
      if (isFirstSnapshot) {
        // 최초 스냅샷은 기존 기록 상태를 기준으로만 삼고, 이후 콜백에서만 변화 여부를 판단한다.
        isFirstSnapshot = false;
        for (final d in snapshot.docs) {
          _seenRecordStates[d.id] = d.data()['isComplete'] != false;
        }
        return;
      }
      var changed = false;
      for (final d in snapshot.docs) {
        final wasComplete = _seenRecordStates[d.id];
        final isComplete = d.data()['isComplete'] != false;
        if (wasComplete == null || (wasComplete == false && isComplete == true)) {
          changed = true;
        }
        _seenRecordStates[d.id] = isComplete;
      }
      if (changed && mounted) {
        widget.onCheckedIn?.call();
        // 출석이 기록되어 닫혔음을 호출부에 알린다(true).
        Navigator.pop(context, true);
      }
    }, onError: (e) {
      debugPrint('인원점검 기록 리스너 오류: $e');
    });
  }

  void _regenerateQr() {
    setState(() {
      _issuedAtMs = ServerClock.nowMs();
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
                      DateFormat('MM.dd HH:mm:ss').format(ServerClock.now().toSeoul()),
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
