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
