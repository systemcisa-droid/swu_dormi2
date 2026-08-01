import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'dart:typed_data';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;

  // FCM 초기화
  Future<void> initialize(String userId) async {
    // 알림 권한 요청
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('알림 권한 승인됨');
    } else {
      print('알림 권한 거부됨');
      return;
    }

    // 로컬 알림 초기화
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // 알림 클릭 시 처리
        print('알림 클릭됨: ${response.payload}');
      },
    );

    // 알림 채널 생성 (Android 8.0 이상)
    final AndroidNotificationChannel channel = AndroidNotificationChannel(
      'swu_dormi_channel',
      '샬롬하우스 알림',
      description: '샬롬하우스 앱의 중요 알림',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 200, 100, 200]),
      enableLights: true,
      ledColor: const Color.fromARGB(255, 255, 0, 0),
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // FCM 토큰 가져오기
    _fcmToken = await _messaging.getToken();
    if (_fcmToken != null) {
      print('FCM 토큰: $_fcmToken');
      // Firestore에 토큰 저장
      await _saveFcmToken(userId, _fcmToken!);
    }

    // 토큰 갱신 리스너
    _messaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      _saveFcmToken(userId, newToken);
    });

    // 포그라운드 메시지 처리
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('포그라운드 메시지 수신: ${message.notification?.title}');
      _showLocalNotification(message);
      _showToast(message);
    });

    // 백그라운드 메시지 클릭 처리
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('백그라운드 메시지 클릭: ${message.notification?.title}');
      _handleNotificationClick(message);
    });
  }

  // Firestore에 FCM 토큰 저장
  Future<void> _saveFcmToken(String userId, String token) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      print('FCM 토큰 저장 완료');
    } catch (e) {
      print('FCM 토큰 저장 실패: $e');
    }
  }

  // 로컬 알림 표시
  Future<void> _showLocalNotification(RemoteMessage message) async {
    // 진동 발생 (패턴으로 강하게)
    try {
      if (await Vibration.hasVibrator() ?? false) {
        // 진동 패턴: 대기 0ms, 진동 200ms, 대기 100ms, 진동 200ms
        await Vibration.vibrate(pattern: [0, 200, 100, 200]);
        print('포그라운드 알림 진동 발생');
      }
    } catch (e) {
      print('진동 오류: $e');
    }

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'swu_dormi_channel',
      '샬롬하우스 알림',
      channelDescription: '샬롬하우스 앱의 중요 알림',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 200, 100, 200]),
      playSound: true,
      enableLights: true,
      ledColor: const Color.fromARGB(255, 255, 0, 0),
      ledOnMs: 1000,
      ledOffMs: 500,
    );

    final NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? '새로운 알림',
      message.notification?.body ?? '',
      notificationDetails,
      payload: message.data.toString(),
    );
  }

  // 토스트 메시지 표시
  void _showToast(RemoteMessage message) {
    Fluttertoast.showToast(
      msg: '${message.notification?.title ?? '알림'}\n${message.notification?.body ?? ''}',
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.TOP,
      timeInSecForIosWeb: 3,
      backgroundColor: const Color(0xFF333333),
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  // 알림 클릭 처리
  void _handleNotificationClick(RemoteMessage message) {
    // TODO: 알림 타입에 따라 적절한 화면으로 이동
    final String? type = message.data['type'];
    print('알림 타입: $type');
  }

  // FCM 토큰 가져오기
  String? get fcmToken => _fcmToken;
}

// 백그라운드 메시지 핸들러 — Flutter 플러그인 사용 불가
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 시스템이 자동으로 알림을 표시하므로 별도 처리 불필요
}
