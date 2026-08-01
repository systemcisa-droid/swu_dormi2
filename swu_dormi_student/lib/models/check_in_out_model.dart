import 'package:cloud_firestore/cloud_firestore.dart';

class CheckInOutModel {
  final String id;
  final String userId;
  final String userName;
  final String roomNumber;
  final String type; // 'check_in' or 'check_out'
  final DateTime requestDate; // 입사/퇴사 요청 날짜
  final DateTime scheduledDate; // 입사/퇴사 예정 날짜
  final String? reason; // 사유 (퇴사 시)
  final String status; // 'pending', 'approved', 'rejected', 'completed'
  final DateTime? approvedAt;
  final String? adminNote;
  final String? approvedTime; // 승인된 입퇴사 시간 (예: '09:00', '14:00')

  CheckInOutModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.roomNumber,
    required this.type,
    required this.requestDate,
    required this.scheduledDate,
    this.reason,
    this.status = 'pending',
    this.approvedAt,
    this.adminNote,
    this.approvedTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'roomNumber': roomNumber,
      'type': type,
      'requestDate': Timestamp.fromDate(requestDate),
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'reason': reason,
      'status': status,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'adminNote': adminNote,
      'approvedTime': approvedTime,
    };
  }

  factory CheckInOutModel.fromMap(Map<String, dynamic> map) {
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.parse(value);
      } else {
        return null;
      }
    }

    return CheckInOutModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      roomNumber: map['roomNumber'] ?? '',
      type: map['type'] ?? '',
      requestDate: parseDateTime(map['requestDate']) ?? DateTime.now(),
      scheduledDate: parseDateTime(map['scheduledDate']) ?? DateTime.now(),
      reason: map['reason'],
      status: map['status'] ?? 'pending',
      approvedAt: parseDateTime(map['approvedAt']),
      adminNote: map['adminNote'],
      approvedTime: map['approvedTime'],
    );
  }
}
