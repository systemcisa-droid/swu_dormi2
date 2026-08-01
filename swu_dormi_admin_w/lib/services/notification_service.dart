import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 모든 학생에게 알림 전송 (공지사항 작성 시)
  Future<void> sendNoticeNotification({
    required String noticeId,
    required String title,
    required String content,
  }) async {
    try {
      print('=== 공지사항 알림 생성 시작 ===');
      print('noticeId: $noticeId');
      print('title: $title');
      print('content: $content');

      // 모든 학생의 userId 가져오기
      final students = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();

      print('학생 수: ${students.docs.length}');

      if (students.docs.isEmpty) {
        print('경고: 학생이 없습니다!');
        return;
      }

      // 각 학생에게 user_notifications 생성
      final batch = _firestore.batch();
      int count = 0;
      for (var student in students.docs) {
        print('학생 ${++count}: ${student.id} - ${student.data()['name']}');

        final notificationRef = _firestore.collection('user_notifications').doc();
        batch.set(notificationRef, {
          'userId': student.id,
          'type': 'notice',
          'title': '새로운 공지사항',
          'content': title,
          'data': {
            'noticeId': noticeId,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

      print('배치 커밋 시작...');
      await batch.commit();
      print('배치 커밋 완료: ${students.docs.length}개 알림 생성');

      // notification_requests 컬렉션에도 알림 요청 추가 (Cloud Function 사용 시)
      await _firestore.collection('notification_requests').add({
        'type': 'notice',
        'noticeId': noticeId,
        'title': '새로운 공지사항',
        'body': title,
        'data': {
          'type': 'notice',
          'noticeId': noticeId,
        },
        'target': 'all_students',
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      print('알림 요청 생성 완료: 공지사항');
      print('=== 공지사항 알림 생성 완료 ===');
    } catch (e) {
      print('알림 요청 생성 실패: $e');
      print('에러 스택: ${StackTrace.current}');
    }
  }

  // 특정 학생에게 알림 전송 (외박/입퇴사 승인/거부 시)
  Future<void> sendRequestStatusNotification({
    required String userId,
    required String type, // 'overnight', 'check_in_out'
    required String status, // 'approved', 'rejected'
    required String requestId,
  }) async {
    try {
      String title = '';
      String body = '';

      if (type == 'overnight') {
        if (status == 'approved') {
          title = '외박 신청 승인';
          body = '외박 신청이 승인되었습니다.';
        } else {
          title = '외박 신청 거부';
          body = '외박 신청이 거부되었습니다.';
        }
      } else if (type == 'check_in_out') {
        if (status == 'approved') {
          title = '입퇴사 신청 승인';
          body = '입퇴사 신청이 승인되었습니다.';
        } else {
          title = '입퇴사 신청 거부';
          body = '입퇴사 신청이 거부되었습니다.';
        }
      }

      // user_notifications 컬렉션에 직접 알림 추가 (Cloud Function 없이 작동)
      await _firestore.collection('user_notifications').add({
        'userId': userId,
        'type': type,
        'title': title,
        'content': body,
        'data': {
          'requestId': requestId,
          'status': status,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // notification_requests 컬렉션에도 알림 요청 추가 (Cloud Function 사용 시)
      await _firestore.collection('notification_requests').add({
        'type': type,
        'requestId': requestId,
        'title': title,
        'body': body,
        'data': {
          'type': type,
          'requestId': requestId,
          'status': status,
        },
        'target': 'user',
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      print('알림 요청 생성 완료: $type - $status');
    } catch (e) {
      print('알림 요청 생성 실패: $e');
    }
  }

  // 시설 신고 상태 변경 알림 전송
  Future<void> sendFacilityReportStatusNotification({
    required String userId,
    required String reportId,
    required String status, // 'in_progress', 'completed'
    required String title,
  }) async {
    try {
      print('=== 시설 신고 알림 생성 시작 ===');
      print('userId: $userId');
      print('reportId: $reportId');
      print('status: $status');
      print('title: $title');

      String notificationTitle = '';
      String body = '';

      if (status == 'in_progress') {
        notificationTitle = '시설 신고 처리중';
        body = '\'$title\' 신고가 처리 중입니다.';
      } else if (status == 'completed') {
        notificationTitle = '시설 신고 완료';
        body = '\'$title\' 신고가 완료되었습니다.';
      }

      print('notificationTitle: $notificationTitle');
      print('body: $body');

      // user_notifications 컬렉션에 직접 알림 추가 (Cloud Function 없이 작동)
      final docRef = await _firestore.collection('user_notifications').add({
        'userId': userId,
        'type': 'facility_report',
        'title': notificationTitle,
        'content': body,
        'data': {
          'reportId': reportId,
          'status': status,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      print('user_notifications 생성 완료: ${docRef.id}');

      // notification_requests 컬렉션에도 알림 요청 추가 (Cloud Function 사용 시)
      await _firestore.collection('notification_requests').add({
        'type': 'facility_report',
        'reportId': reportId,
        'title': notificationTitle,
        'body': body,
        'data': {
          'type': 'facility_report',
          'reportId': reportId,
          'status': status,
        },
        'target': 'user',
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      print('알림 요청 생성 완료: 시설 신고 - $status');
      print('=== 시설 신고 알림 생성 완료 ===');
    } catch (e) {
      print('알림 요청 생성 실패: $e');
      print('에러 스택: ${StackTrace.current}');
    }
  }

  // 모든 FCM 토큰 가져오기 (Cloud Function 대신 직접 전송 시)
  Future<List<String>> getAllStudentFcmTokens() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('fcmToken', isNull: false)
          .get();

      return querySnapshot.docs
          .map((doc) => doc.data()['fcmToken'] as String)
          .where((token) => token.isNotEmpty)
          .toList();
    } catch (e) {
      print('FCM 토큰 조회 실패: $e');
      return [];
    }
  }

  // 특정 사용자의 FCM 토큰 가져오기
  Future<String?> getUserFcmToken(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['fcmToken'] as String?;
    } catch (e) {
      print('FCM 토큰 조회 실패: $e');
      return null;
    }
  }
}
