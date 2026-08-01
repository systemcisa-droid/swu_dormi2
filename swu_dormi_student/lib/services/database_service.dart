import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notice_model.dart';
import '../models/room_assignment_model.dart';
import '../models/facility_report_model.dart';
import '../models/meal_model.dart';
import '../models/chat_message_model.dart';
import '../models/user_model.dart';
import '../models/check_in_out_model.dart';
import '../models/point_history_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ===== Notice Methods =====

  Stream<List<NoticeModel>> getNotices() {
    return _firestore
        .collection('notices')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return NoticeModel.fromMap(data);
            })
            .toList());
  }

  Future<void> addNotice(NoticeModel notice) async {
    await _firestore.collection('notices').doc(notice.id).set(notice.toMap());
  }

  Future<void> createNotice(NoticeModel notice) async {
    await addNotice(notice);
  }

  Future<void> _incrementViewCount(String collection, String docId, String userId) async {
    final doc = await _firestore.collection(collection).doc(docId).get();
    if (!doc.exists) return;
    final viewed = (doc.data()?['viewedUsers'] as List<dynamic>?) ?? [];
    if (!viewed.contains(userId)) {
      await _firestore.collection(collection).doc(docId).update({
        'viewCount': FieldValue.increment(1),
        'viewedUsers': FieldValue.arrayUnion([userId]),
      });
    }
  }

  Future<void> incrementNoticeViewCount(String noticeId, String userId) async {
    try {
      await _incrementViewCount('notices', noticeId, userId);
    } catch (e) {
      debugPrint('공지사항 조회수 증가 실패: $e');
    }
  }

  Future<void> incrementPostViewCount(String postId, String userId) async {
    try {
      await _incrementViewCount('board_posts', postId, userId);
    } catch (e) {
      debugPrint('게시글 조회수 증가 실패: $e');
    }
  }

  // ===== Room Assignment Methods =====

  Future<RoomAssignmentModel?> getUserRoomAssignment(String userId) async {
    QuerySnapshot snapshot = await _firestore
        .collection('room_assignments')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return RoomAssignmentModel.fromMap(
          snapshot.docs.first.data() as Map<String, dynamic>);
    }
    return null;
  }

  // ===== Facility Report Methods (facility_reports 컬렉션으로 통합) =====

  Stream<List<FacilityReportModel>> getUserFacilityReports(String userId) {
    return _firestore
        .collection('facility_reports')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => FacilityReportModel.fromMap(doc.data()))
              .toList();
          list.sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
          return list;
        });
  }

  Future<void> submitFacilityReport(FacilityReportModel report) async {
    await _firestore
        .collection('facility_reports')
        .doc(report.id)
        .set(report.toMap());
  }

  Stream<List<FacilityReportModel>> getAllFacilityReports() {
    return _firestore
        .collection('facility_reports')
        .orderBy('reportedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FacilityReportModel.fromMap(doc.data()))
            .toList());
  }

  // ===== Meal Methods =====

  Stream<List<MealModel>> getMeals(DateTime startDate, DateTime endDate) {
    return _firestore
        .collection('meals')
        .where('date', isGreaterThanOrEqualTo: startDate.toIso8601String())
        .where('date', isLessThanOrEqualTo: endDate.toIso8601String())
        .orderBy('date')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MealModel.fromFirestore(doc))
            .toList());
  }

  Stream<List<MealModel>> getTodaysMeals() {
    DateTime now = DateTime.now();
    DateTime startOfDay = DateTime(now.year, now.month, now.day);
    DateTime endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return getMeals(startOfDay, endOfDay);
  }

  // ===== Chat Methods =====

  Stream<List<ChatMessageModel>> getChatMessages(String facilityReportId) {
    return _firestore
        .collection('chat_messages')
        .where('facilityReportId', isEqualTo: facilityReportId)
        .orderBy('sentAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessageModel.fromMap(doc.data()))
            .toList());
  }

  Future<void> sendChatMessage(ChatMessageModel message) async {
    await _firestore
        .collection('chat_messages')
        .doc(message.id)
        .set(message.toMap());
  }

  // ===== User Profile Methods =====

  Future<void> updateUserProfile(UserModel user) async {
    await _firestore
        .collection('users')
        .doc(user.uid)
        .update(user.toMap());
  }

  Future<void> updateProfileImageUrl(String uid, String profileImageUrl) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .update({'profileImageUrl': profileImageUrl});
  }

  Future<UserModel?> getUserProfile(String userId) async {
    DocumentSnapshot doc = await _firestore
        .collection('users')
        .doc(userId)
        .get();

    if (doc.exists) {
      return UserModel.fromMap(doc.data() as Map<String, dynamic>);
    }
    return null;
  }

  // ===== Check In/Out Methods =====

  Future<void> submitCheckInOutRequest(CheckInOutModel request) async {
    await _firestore
        .collection('check_in_out_requests')
        .doc(request.id)
        .set(request.toMap());
  }

  Stream<List<CheckInOutModel>> getUserCheckInOutRequests(String userId) {
    return _firestore
        .collection('check_in_out_requests')
        .where('userId', isEqualTo: userId)
        .orderBy('requestDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CheckInOutModel.fromMap(doc.data()))
            .toList());
  }

  Stream<List<CheckInOutModel>> getAllCheckInOutRequests() {
    return _firestore
        .collection('check_in_out_requests')
        .orderBy('requestDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CheckInOutModel.fromMap(doc.data()))
            .toList());
  }

  // ===== Point History Methods =====

  Stream<List<PointHistoryModel>> getPointHistory(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('point_history')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return PointHistoryModel.fromMap(data);
            }).toList());
  }
}
