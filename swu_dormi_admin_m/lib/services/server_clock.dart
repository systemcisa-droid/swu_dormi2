import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Firestore 서버 시각을 기준으로 하는 시계.
///
/// QR 인원점검은 학생 폰이 QR에 넣은 발급 시각과 층장 폰의 현재 시각을 비교하는데,
/// 두 폰의 시계가 몇 초만 어긋나도 정상 QR이 만료로 처리된다(특히 통신사 시간 동기화를
/// 받지 못하는 해외 폰). 그래서 양쪽 앱 모두 기기 시각 대신 서버 시각을 기준으로 삼는다.
/// (학생앱의 lib/services/server_clock.dart와 같은 구현이다.)
class ServerClock {
  static int _offsetMs = 0;
  static bool _synced = false;

  /// 한국은 서머타임이 없어 항상 UTC+9다.
  static const seoulOffset = Duration(hours: 9);

  static bool get isSynced => _synced;

  /// 서버 시각 기준 현재 epoch ms. 동기화 전이거나 실패했으면 기기 시각을 그대로 쓴다.
  static int nowMs() => DateTime.now().millisecondsSinceEpoch + _offsetMs;

  static DateTime now() => DateTime.fromMillisecondsSinceEpoch(nowMs());

  /// 본인 users 문서에 serverTimestamp를 기록한 뒤 서버에서 다시 읽어
  /// 서버 시각과 기기 시각의 차이를 구한다. 네트워크 왕복만큼(보통 1초 미만) 오차가 있다.
  static Future<bool> sync() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(uid);
      final t0 = DateTime.now().millisecondsSinceEpoch;
      await ref.set({'clockSyncAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      final tAck = DateTime.now().millisecondsSinceEpoch;
      final snap = await ref.get(const GetOptions(source: Source.server));
      final serverTs = snap.data()?['clockSyncAt'] as Timestamp?;
      if (serverTs == null) return false;
      // 서버가 시각을 찍은 순간은 요청 전송(t0)과 응답 수신(tAck) 사이이므로 그 중간으로 본다.
      // 이렇게 해야 느린 네트워크에서 읽기 지연만큼 시계가 뒤처지는 편향이 생기지 않는다.
      _offsetMs = serverTs.millisecondsSinceEpoch - ((t0 + tAck) ~/ 2);
      _synced = true;
      return true;
    } catch (e) {
      debugPrint('서버 시각 동기화 실패: $e');
      return false;
    }
  }
}

/// 기기의 시간대 설정과 무관하게 한국(서울) 시각으로 바꾼다. 표시 전용.
extension SeoulTime on DateTime {
  DateTime toSeoul() => toUtc().add(ServerClock.seoulOffset);
}
