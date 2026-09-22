import 'package:cloud_firestore/cloud_firestore.dart';

class CheckInOutModel {
  final String id;
  final String userId;
  final String userName;
  final String studentId;
  final String type; // 'check_in' or 'check_out'
  final String roomNumber;
  final DateTime requestDate;
  final String status; // 'pending', 'approved', 'rejected'
  final String? rejectionReason;
  final String? approvedTime; // 승인된 입퇴사 시간 (예: '09:00', '14:00')
  final DateTime createdAt;
  final DateTime? processedAt;
  final String? processedBy; // 처리한 관리자 ID
  final String? processedByName; // 처리한 관리자 이름

  CheckInOutModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.studentId,
    required this.type,
    required this.roomNumber,
    required this.requestDate,
    required this.status,
    this.rejectionReason,
    this.approvedTime,
    required this.createdAt,
    this.processedAt,
    this.processedBy,
    this.processedByName,
  });

  factory CheckInOutModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Timestamp 또는 String 처리 함수
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    // createdAt/requestDate 처리 (학생 프로젝트 호환)
    DateTime createdAtDate;
    if (data['createdAt'] != null) {
      createdAtDate = parseDateTime(data['createdAt']) ?? DateTime.now();
    } else if (data['requestDate'] != null) {
      createdAtDate = parseDateTime(data['requestDate']) ?? DateTime.now();
    } else {
      createdAtDate = DateTime.now();
    }

    // requestDate 처리
    DateTime requestDateValue;
    if (data['requestDate'] != null) {
      requestDateValue = parseDateTime(data['requestDate']) ?? DateTime.now();
    } else if (data['scheduledDate'] != null) {
      requestDateValue = parseDateTime(data['scheduledDate']) ?? DateTime.now();
    } else {
      requestDateValue = DateTime.now();
    }

    return CheckInOutModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      studentId: data['studentId'] ?? '미확인',
      type: data['type'] ?? 'check_in',
      roomNumber: data['roomNumber'] ?? '미확인',
      requestDate: requestDateValue,
      status: data['status'] ?? 'pending',
      rejectionReason: data['rejectionReason'] ?? data['adminNote'],
      approvedTime: data['approvedTime'],
      createdAt: createdAtDate,
      processedAt: parseDateTime(data['processedAt']) ?? parseDateTime(data['approvedAt']),
      processedBy: data['processedBy'],
      processedByName: data['processedByName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'studentId': studentId,
      'type': type,
      'roomNumber': roomNumber,
      'requestDate': Timestamp.fromDate(requestDate),
      'status': status,
      'rejectionReason': rejectionReason,
      'approvedTime': approvedTime,
      'createdAt': Timestamp.fromDate(createdAt),
      'processedAt': processedAt != null ? Timestamp.fromDate(processedAt!) : null,
      'processedBy': processedBy,
      'processedByName': processedByName,
    };
  }

  String getTypeDisplayName() {
    return type == 'check_in' ? '입사' : '퇴사';
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
}
