import 'package:cloud_firestore/cloud_firestore.dart';

class CleaningInspectionModel {
  final String id;
  final String roomNumber;
  final int score;
  final String status; // 양호, 보통, 미흡
  final String comment;
  final DateTime inspectionDate;
  final String inspectorId;
  final String inspectorName;
  final DateTime createdAt;

  CleaningInspectionModel({
    required this.id,
    required this.roomNumber,
    required this.score,
    required this.status,
    required this.comment,
    required this.inspectionDate,
    required this.inspectorId,
    required this.inspectorName,
    required this.createdAt,
  });

  factory CleaningInspectionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return CleaningInspectionModel(
      id: doc.id,
      roomNumber: data['roomNumber'] ?? '',
      score: data['score'] ?? 0,
      status: data['status'] ?? '미확인',
      comment: data['comment'] ?? '',
      inspectionDate: (data['inspectionDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      inspectorId: data['inspectorId'] ?? '',
      inspectorName: data['inspectorName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomNumber': roomNumber,
      'score': score,
      'status': status,
      'comment': comment,
      'inspectionDate': Timestamp.fromDate(inspectionDate),
      'inspectorId': inspectorId,
      'inspectorName': inspectorName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// 점수에 따른 상태 자동 결정
  static String getStatusFromScore(int score) {
    if (score >= 90) {
      return '양호';
    } else if (score >= 70) {
      return '보통';
    } else {
      return '미흡';
    }
  }
}
