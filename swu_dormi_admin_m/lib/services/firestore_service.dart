import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 컬렉션 참조 가져오기
  CollectionReference get notices => _firestore.collection('notices');
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

  // 시설 신고 (facilities 또는 facility_reports 모두 지원)
  Stream<QuerySnapshot> getRepairReports({String? status}) {
    // facility_reports 컬렉션 사용
    CollectionReference reports = _firestore.collection('facility_reports');
    Query query = reports;
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    // 인덱스가 필요하므로 orderBy 제거
    return query.snapshots();
  }

  Future<void> updateRepairReportStatus(
    String reportId,
    String status,
    String? technicianNote,
  ) async {
    try {
      // 현재 로그인한 관리자 정보 가져오기
      final currentUser = _auth.currentUser;
      print('===== 시설 신고 처리 시작 =====');
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
        'processedByEmail': currentUser?.email,
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

  Stream<QuerySnapshot> getStudents() {
    return users.where('role', isEqualTo: 'student').snapshots();
  }

  Future<void> updateStudent(String userId, Map<String, dynamic> userData) async {
    try {
      await users.doc(userId).update(userData);
    } catch (e) {
      throw Exception('학생 정보 수정 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> deleteStudent(String userId) async {
    try {
      final userDoc = await users.doc(userId).get();
      final userData = userDoc.data() as Map<String, dynamic>?;
      final studentId = userData?['studentId'] as String?;

      final batch = _firestore.batch();
      batch.delete(users.doc(userId));
      if (studentId != null && studentId.isNotEmpty) {
        batch.delete(_firestore.collection('student_ids').doc(studentId));
      }
      await batch.commit();
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
    int facilitiesCount = 0;
    int studentsCount = 0;
    int cleaningCount = 0;
    int attendanceCount = 0;

    // 각 쿼리를 개별적으로 try-catch 처리
    try {
      // facility_reports 컬렉션에서 pending 상태 조회
      final pendingRepairReports = await _firestore
          .collection('facility_reports')
          .where('status', isEqualTo: 'pending')
          .get();
      facilitiesCount = pendingRepairReports.docs.length;
    } catch (e) {
      print('시설 신고 조회 오류: $e');
    }

    try {
      final totalStudents = await users
          .where('role', isEqualTo: 'student')
          .get();
      studentsCount = totalStudents.docs.length;
    } catch (e) {
      print('총 학생 수 조회 오류: $e');
    }

    try {
      // 청소 점검 대기 중인 요청 수
      final pendingCleaning = await _firestore
          .collection('cleaning_requests')
          .where('status', isEqualTo: 'pending')
          .get();
      cleaningCount = pendingCleaning.docs.length;
    } catch (e) {
      print('청소 점검 조회 오류: $e');
    }

    try {
      // 활성 출석 이벤트 수
      final activeAttendance = await _firestore
          .collection('attendance_events')
          .where('status', isEqualTo: 'active')
          .get();
      attendanceCount = activeAttendance.docs.length;
    } catch (e) {
      print('출석 이벤트 조회 오류: $e');
    }

    final stats = {
      'pendingFacilities': facilitiesCount,
      'totalStudents': studentsCount,
      'pendingCleaning': cleaningCount,
      'activeAttendance': attendanceCount,
    };

    return stats;
  }
}
