import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String type; // 'notice', 'chat', 'check_in_out', 'meal'
  final String title;
  final String content;
  final DateTime createdAt;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    DateTime createdAt;

    // Firestore Timestamp 또는 String 처리
    if (map['createdAt'] is Timestamp) {
      createdAt = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      createdAt = DateTime.parse(map['createdAt']);
    } else {
      createdAt = DateTime.now();
    }

    return NotificationModel(
      id: map['id'] ?? '',
      type: map['type'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      createdAt: createdAt,
      isRead: map['isRead'] ?? false,
    );
  }

  String getTypeDisplayName() {
    switch (type) {
      case 'notice':
        return '공지사항';
      case 'chat':
        return '채팅';
      case 'check_in_out':
        return '입퇴사';
      case 'meal':
        return '식단표';
      case 'facility_report':
        return '시설신고';
      case 'message':
        return '층장단톡방';
      case 'admin_message':
        return '행정실';
      default:
        return '알림';
    }
  }
}
