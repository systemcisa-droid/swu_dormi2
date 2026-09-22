import 'package:cloud_firestore/cloud_firestore.dart';

class OvernightModel {
  final String id;
  final String userId;
  final String userName;
  final String studentId;
  final String roomNumber;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String destination;
  final String emergencyContact;
  final String status; // 'pending', 'approved', 'rejected'
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime? processedAt;
  final String? processedBy; // 처리한 관리자 ID
  final String? processedByName; // 처리한 관리자 이름

  OvernightModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.studentId,
    required this.roomNumber,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.destination,
    required this.emergencyContact,
    required this.status,
    this.rejectionReason,
    required this.createdAt,
    this.processedAt,
    this.processedBy,
    this.processedByName,
  });

  factory OvernightModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // createdAt과 requestedAt 둘 다 지원 (학생 프로젝트 호환)
    DateTime createdAtDate;
    if (data['createdAt'] != null) {
      createdAtDate = (data['createdAt'] as Timestamp).toDate();
    } else if (data['requestedAt'] != null) {
      createdAtDate = (data['requestedAt'] as Timestamp).toDate();
    } else {
      createdAtDate = DateTime.now();
    }

    return OvernightModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      studentId: data['studentId'] ?? '미확인',
      roomNumber: data['roomNumber'] ?? '미확인',
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reason: data['reason'] ?? '',
      destination: data['destination'] ?? '',
      emergencyContact: data['emergencyContact'] ?? '',
      status: data['status'] ?? 'pending',
      rejectionReason: data['rejectionReason'] ?? data['adminNote'],
      createdAt: createdAtDate,
      processedAt: (data['processedAt'] as Timestamp?)?.toDate(),
      processedBy: data['processedBy'],
      processedByName: data['processedByName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'studentId': studentId,
      'roomNumber': roomNumber,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'reason': reason,
      'destination': destination,
      'emergencyContact': emergencyContact,
      'status': status,
      'rejectionReason': rejectionReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'processedAt': processedAt != null ? Timestamp.fromDate(processedAt!) : null,
      'processedBy': processedBy,
      'processedByName': processedByName,
    };
  }

  String getStatusDisplayName() {
    switch (status) {
      case 'pending':
        return '대기중';
      case 'approved':
        return '승인';
      case 'rejected':
        return '거부';
      default:
        return status;
    }
  }

  int getDurationDays() {
    return endDate.difference(startDate).inDays + 1;
  }
}
