import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 컬렉션 참조 가져오기
  CollectionReference get notices => _firestore.collection('notices');
  CollectionReference get checkInOutRequests => _firestore.collection('check_in_out_requests');
  CollectionReference get overnightRequests => _firestore.collection('overnight_requests');
  CollectionReference get facilities => _firestore.collection('facilities');
  CollectionReference get meals => _firestore.collection('meals');
  CollectionReference get users => _firestore.collection('users');
  CollectionReference get chats => _firestore.collection('chats');

  // 공지사항 관리
  Future<void> addNotice(Map<String, dynamic> noticeData) async {
    try {
      await notices.add({
        ...noticeData,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('공지사항 추가 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> updateNotice(String noticeId, Map<String, dynamic> noticeData) async {
    try {
      await notices.doc(noticeId).update({
        ...noticeData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('공지사항 수정 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> deleteNotice(String noticeId) async {
    try {
      await notices.doc(noticeId).delete();
    } catch (e) {
      throw Exception('공지사항 삭제 중 오류가 발생했습니다: $e');
    }
  }

  Stream<QuerySnapshot> getNotices() {
    return notices.orderBy('createdAt', descending: true).snapshots();
  }

  // 입퇴사 신청 관리
  Future<void> updateCheckInOutStatus(
    String requestId,
    String status,
    String? reason,
    {String? approvedTime}
  ) async {
    try {
      // 현재 로그인한 관리자 정보 가져오기
      final currentUser = _auth.currentUser;
      print('===== 입퇴사 처리 시작 =====');
      print('현재 로그인 사용자 UID: ${currentUser?.uid}');
      print('현재 로그인 사용자 Email: ${currentUser?.email}');

      String? adminName;

      if (currentUser != null) {
        // 관리자 이름 가져오기
        print('관리자 정보 조회 중...');
        final adminDoc = await users.doc(currentUser.uid).get();
        print('관리자 문서 존재 여부: ${adminDoc.exists}');

        if (adminDoc.exists) {
          final adminData = adminDoc.data() as Map<String, dynamic>;
          adminName = adminData['name'] ?? adminData['email'];
          print('조회된 관리자 이름: $adminName');
          print('관리자 전체 데이터: $adminData');
        } else {
          print('⚠️ 관리자 문서를 찾을 수 없음!');
        }
      } else {
        print('⚠️ 현재 로그인한 사용자가 없음!');
      }

      final Map<String, dynamic> updateData = {
        'status': status,
        'rejectionReason': reason,
        'processedAt': FieldValue.serverTimestamp(),
        'processedBy': currentUser?.uid,
        'processedByName': adminName ?? '관리자',
      };

      print('저장할 데이터: $updateData');
      print('===== 입퇴사 처리 완료 =====');

      // 승인 시 승인 시간 추가
      if (status == 'approved' && approvedTime != null) {
        updateData['approvedTime'] = approvedTime;
      }

      await checkInOutRequests.doc(requestId).update(updateData);
    } catch (e) {
      throw Exception('입퇴사 신청 상태 변경 중 오류가 발생했습니다: $e');
    }
  }

  Stream<QuerySnapshot> getCheckInOutRequests({String? status}) {
    Query query = checkInOutRequests;
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    return query.snapshots();
  }

  // 외박 신청 관리
  Future<void> updateOvernightStatus(String requestId, String status, String? reason) async {
    try {
      // 현재 로그인한 관리자 정보 가져오기
      final currentUser = _auth.currentUser;
      print('===== 외박 처리 시작 =====');
      print('현재 로그인 사용자 UID: ${currentUser?.uid}');
      print('현재 로그인 사용자 Email: ${currentUser?.email}');

      String? adminName;

      if (currentUser != null) {
        // 관리자 이름 가져오기
        print('관리자 정보 조회 중...');
        final adminDoc = await users.doc(currentUser.uid).get();
        print('관리자 문서 존재 여부: ${adminDoc.exists}');

        if (adminDoc.exists) {
          final adminData = adminDoc.data() as Map<String, dynamic>;
          adminName = adminData['name'] ?? adminData['email'];
          print('조회된 관리자 이름: $adminName');
        } else {
          print('⚠️ 관리자 문서를 찾을 수 없음!');
        }
      } else {
        print('⚠️ 현재 로그인한 사용자가 없음!');
      }

      final updateData = {
        'status': status,
        'rejectionReason': reason,
        'processedAt': FieldValue.serverTimestamp(),
        'processedBy': currentUser?.uid,
        'processedByName': adminName ?? '관리자',
      };

      print('저장할 데이터: $updateData');
      await overnightRequests.doc(requestId).update(updateData);
      print('===== 외박 처리 완료 =====');
    } catch (e) {
      throw Exception('외박 신청 상태 변경 중 오류가 발생했습니다: $e');
    }
  }

  Stream<QuerySnapshot> getOvernightRequests({String? status}) {
    Query query = overnightRequests;
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    return query.snapshots();
  }

  // 시설 신고 관리
  Future<void> updateFacilityStatus(String facilityId, String status, String? note) async {
    try {
      await facilities.doc(facilityId).update({
        'status': status,
        'adminNote': note,
        'processedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('시설 신고 상태 변경 중 오류가 발생했습니다: $e');
    }
  }

  Stream<QuerySnapshot> getFacilities({String? status}) {
    Query query = facilities;
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    return query.snapshots();
  }

  // 시설 신고
  Stream<QuerySnapshot> getFacilityReports({String? status}) {
    Query query = _firestore.collection('facility_reports');
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    return query.snapshots();
  }

  Future<void> updateFacilityReportStatus(
    String reportId,
    String status,
    String? technicianNote,
  ) async {
    try {
      // 현재 로그인한 관리자 정보 가져오기
      final currentUser = _auth.currentUser;
      print('===== 시설 신고 처리 시작 (facility_reports) =====');
      print('현재 로그인 사용자 UID: ${currentUser?.uid}');
      print('현재 로그인 사용자 Email: ${currentUser?.email}');

      String? adminEmail = currentUser?.email;

      if (currentUser != null) {
        // 관리자 이메일 가져오기
        print('관리자 정보 조회 중...');
        final adminDoc = await users.doc(currentUser.uid).get();
        print('관리자 문서 존재 여부: ${adminDoc.exists}');

        if (adminDoc.exists) {
          final adminData = adminDoc.data() as Map<String, dynamic>;
          adminEmail = adminData['email'] ?? currentUser.email;
          print('조회된 관리자 이메일: $adminEmail');
        } else {
          print('⚠️ 관리자 문서를 찾을 수 없음!');
        }
      } else {
        print('⚠️ 현재 로그인한 사용자가 없음!');
      }

      final data = <String, dynamic>{
        'status': status,
        'technicianNote': technicianNote,
        'processedAt': FieldValue.serverTimestamp(),
        'processedBy': currentUser?.uid,
        'processedByName': adminEmail ?? '관리자',
      };

      if (status == 'completed') {
        data['completedAt'] = FieldValue.serverTimestamp();
      }

      print('저장할 데이터: $data');
      await _firestore.collection('facility_reports').doc(reportId).update(data);
      print('===== 시설 신고 처리 완료 =====');
    } catch (e) {
      throw Exception('시설 신고 상태 변경 중 오류가 발생했습니다: $e');
    }
  }

  // 식단표 관리
  Future<void> addMeal(Map<String, dynamic> mealData) async {
    try {
      await meals.add({
        ...mealData,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('식단표 추가 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> updateMeal(String mealId, Map<String, dynamic> mealData) async {
    try {
      await meals.doc(mealId).update({
        ...mealData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('식단표 수정 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> deleteMeal(String mealId) async {
    try {
      await meals.doc(mealId).delete();
    } catch (e) {
      throw Exception('식단표 삭제 중 오류가 발생했습니다: $e');
    }
  }

  Stream<QuerySnapshot> getMeals() {
    return meals.orderBy('createdAt', descending: true).snapshots();
  }

  // 학생 관리 (orderBy 없이 조회 후 클라이언트 정렬 — 복합 인덱스 불필요)
  Future<QuerySnapshot> getStudentsOnce() {
    return users.where('role', isEqualTo: 'student').get();
  }

  Future<void> updateStudent(String userId, Map<String, dynamic> userData) async {
    try {
      // roomNumber가 변경되면 building, floor 계산 필드도 함께 업데이트
      if (userData.containsKey('roomNumber')) {
        final roomNumber = userData['roomNumber'] as String;
        final roomNum = int.tryParse(roomNumber);
        if (roomNum != null && roomNumber != '000') {
          final lastTwo = roomNum % 100;
          final floor = roomNum ~/ 100;
          userData['building'] = (lastTwo >= 1 && lastTwo <= 20)
              ? 'A동'
              : (lastTwo >= 21 && lastTwo <= 35)
                  ? 'B동'
                  : '미배정';
          userData['floor'] = (floor >= 1 && floor <= 7) ? '${floor}층' : '미배정';
        } else {
          userData['building'] = '미배정';
          userData['floor'] = '미배정';
        }
      }
      await users.doc(userId).update(userData);
    } catch (e) {
      throw Exception('학생 정보 수정 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> deleteStudent(String userId) async {
    try {
      await users.doc(userId).delete();
    } catch (e) {
      throw Exception('회원탈퇴 처리 중 오류가 발생했습니다: $e');
    }
  }

  // 통계 (실시간) - 3초마다 Firestore에서 최신 데이터 가져오기
  Stream<Map<String, int>> getStatisticsStream() async* {
    // 초기 데이터 즉시 제공
    try {
      yield await getStatistics();
    } catch (e) {
      yield {
        'pendingCheckInOut': 0,
        'pendingOvernight': 0,
        'pendingFacilities': 0,
        'totalStudents': 0,
      };
    }

    // 3초마다 업데이트
    await for (var _ in Stream.periodic(const Duration(seconds: 3))) {
      try {
        final stats = await getStatistics();
        yield stats;
      } catch (e) {
        // 에러가 발생해도 이전 데이터 유지 (yield 안 함)
      }
    }
  }

  Future<Map<String, int>> getStatistics() async {
    int checkInOutCount = 0;
    int overnightCount = 0;
    int facilitiesCount = 0;
    int cleaningCount = 0;
    int studentsCount = 0;

    // 각 쿼리를 개별적으로 try-catch 처리
    try {
      final pendingCheckInOut = await checkInOutRequests
          .where('status', isEqualTo: 'pending')
          .get();
      checkInOutCount = pendingCheckInOut.docs.length;
      print('입퇴사 대기: $checkInOutCount');
    } catch (e) {
      print('입퇴사 대기 조회 오류: $e');
    }

    try {
      final pendingOvernight = await overnightRequests
          .where('status', isEqualTo: 'pending')
          .get();
      overnightCount = pendingOvernight.docs.length;
      print('외박 대기: $overnightCount');
      for (var doc in pendingOvernight.docs) {
        print('외박 문서 ID: ${doc.id}');
      }
    } catch (e) {
      print('외박 대기 조회 오류: $e');
    }

    try {
      // facility_reports 컬렉션에서 pending 상태 조회
      final pendingRepairReports = await _firestore
          .collection('facility_reports')
          .where('status', isEqualTo: 'pending')
          .get();
      facilitiesCount = pendingRepairReports.docs.length;
      print('시설 신고 (facility_reports): $facilitiesCount');
    } catch (e) {
      print('시설 신고 조회 오류: $e');
    }

    int inProgressFacilities = 0;
    int completedFacilities = 0;
    try {
      final inProgressRepairReports = await _firestore
          .collection('facility_reports')
          .where('status', isEqualTo: 'in_progress')
          .get();
      inProgressFacilities = inProgressRepairReports.docs.length;

      final completedRepairReports = await _firestore
          .collection('facility_reports')
          .where('status', isEqualTo: 'completed')
          .get();
      completedFacilities = completedRepairReports.docs.length;
    } catch (e) {
      print('시설 신고 상태별 조회 오류: $e');
    }

    try {
      // cleaning_requests 컬렉션에서 pending 상태 조회
      final pendingCleaningRequests = await _firestore
          .collection('cleaning_requests')
          .where('status', isEqualTo: 'pending')
          .get();
      cleaningCount = pendingCleaningRequests.docs.length;
      print('청소점검 (cleaning_requests): $cleaningCount');
    } catch (e) {
      print('청소점검 조회 오류: $e');
    }

    int inProgressCleaning = 0;
    int completedCleaning = 0;
    try {
      final inProgressCleaningRequests = await _firestore
          .collection('cleaning_requests')
          .where('status', isEqualTo: 'in_progress')
          .get();
      inProgressCleaning = inProgressCleaningRequests.docs.length;

      final completedCleaningRequests = await _firestore
          .collection('cleaning_requests')
          .where('status', isEqualTo: 'completed')
          .get();
      completedCleaning = completedCleaningRequests.docs.length;
    } catch (e) {
      print('청소점검 상태별 조회 오류: $e');
    }

    try {
      final totalStudents = await users
          .where('role', isEqualTo: 'student')
          .get();
      studentsCount = totalStudents.docs.length;
      print('총 학생 수: $studentsCount');
    } catch (e) {
      print('총 학생 수 조회 오류: $e');
    }

    final stats = {
      'pendingCheckInOut': checkInOutCount,
      'pendingOvernight': overnightCount,
      'pendingFacilities': facilitiesCount,
      'inProgressFacilities': inProgressFacilities,
      'completedFacilities': completedFacilities,
      'pendingCleaning': cleaningCount,
      'inProgressCleaning': inProgressCleaning,
      'completedCleaning': completedCleaning,
      'totalStudents': studentsCount,
    };
    print('통계 결과: $stats');

    return stats;
  }

  // 알림 전송
  Future<void> sendNotification({
    required List<String> userIds,
    required String type,
    required String title,
    required String content,
    String? targetLabel,
    List<Map<String, String>>? recipients,
  }) async {
    try {
      print('===== 알림 전송 시작 =====');
      print('수신자 수: ${userIds.length}');
      print('제목: $title');

      final batch = _firestore.batch();
      final now = FieldValue.serverTimestamp();

      for (final userId in userIds) {
        // user_notifications 컬렉션에 알림 추가 (학생앱과 동일한 구조)
        final notificationRef = _firestore
            .collection('user_notifications')
            .doc();

        batch.set(notificationRef, {
          'userId': userId,
          'type': type,
          'title': title,
          'content': content,
          'createdAt': now,
          'isRead': false,
        });
      }

      // 보낸 메시지 이력 저장
      if (type == 'message' || type == 'admin_message') {
        final sentRef = _firestore.collection('admin_sent_messages').doc();
        batch.set(sentRef, {
          'title': title,
          'content': content,
          'recipientCount': userIds.length,
          'targetLabel': targetLabel ?? '개별 선택',
          'sentAt': now,
          if (recipients != null) 'recipients': recipients,
        });
      }

      await batch.commit();
      print('===== 알림 전송 완료 =====');
    } catch (e) {
      print('===== 알림 전송 오류 =====');
      print('오류 상세: $e');
      throw Exception('알림 전송 중 오류가 발생했습니다: $e');
    }
  }

  // 보낸 메시지 목록 조회
  Stream<QuerySnapshot> getSentMessages() {
    return _firestore
        .collection('admin_sent_messages')
        .orderBy('sentAt', descending: true)
        .snapshots();
  }
}
