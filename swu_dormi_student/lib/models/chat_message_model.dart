import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessageModel {
  final String id;
  final String facilityReportId;
  final String senderId;
  final String senderName;
  final bool isAdmin; // true: 관리자, false: 학생
  final String message;
  final DateTime sentAt;

  ChatMessageModel({
    required this.id,
    required this.facilityReportId,
    required this.senderId,
    required this.senderName,
    required this.isAdmin,
    required this.message,
    required this.sentAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'facilityReportId': facilityReportId,
      'senderId': senderId,
      'senderName': senderName,
      'isAdmin': isAdmin,
      'message': message,
      'sentAt': Timestamp.fromDate(sentAt),
    };
  }

  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.parse(value);
      } else {
        return DateTime.now();
      }
    }

    return ChatMessageModel(
      id: map['id'] ?? '',
      facilityReportId: map['facilityReportId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      isAdmin: map['isAdmin'] ?? false,
      message: map['message'] ?? '',
      sentAt: parseDateTime(map['sentAt']),
    );
  }
}
