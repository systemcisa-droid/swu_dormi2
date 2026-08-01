import 'package:cloud_firestore/cloud_firestore.dart';

class NoticeModel {
  final String id;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final DateTime createdAt;
  final bool isImportant;
  final String? imageUrl; // 하위 호환성을 위해 유지
  final List<String> imageUrls; // 여러 이미지 지원
  final String? pdfUrl;
  final String? pdfFileName;
  final int viewCount;
  final List<String> viewedUsers; // 조회한 사용자 ID 리스트

  NoticeModel({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    this.isImportant = false,
    this.imageUrl,
    this.imageUrls = const [],
    this.pdfUrl,
    this.pdfFileName,
    this.viewCount = 0,
    this.viewedUsers = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': Timestamp.fromDate(createdAt),
      'isImportant': isImportant,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'pdfUrl': pdfUrl,
      'pdfFileName': pdfFileName,
      'viewCount': viewCount,
      'viewedUsers': viewedUsers,
    };
  }

  factory NoticeModel.fromMap(Map<String, dynamic> map) {
    DateTime createdAt;

    // Firestore Timestamp 또는 String 처리
    if (map['createdAt'] is Timestamp) {
      createdAt = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      createdAt = DateTime.parse(map['createdAt']);
    } else {
      createdAt = DateTime.now();
    }

    // imageUrls 처리 (관리자 프로젝트에서 등록한 경우)
    List<String> imageUrls = [];
    if (map['imageUrls'] != null && map['imageUrls'] is List) {
      imageUrls = List<String>.from(map['imageUrls']);
    }

    List<String> viewedUsers = [];
    if (map['viewedUsers'] != null && map['viewedUsers'] is List) {
      viewedUsers = List<String>.from(map['viewedUsers']);
    }

    return NoticeModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      createdAt: createdAt,
      isImportant: map['isImportant'] ?? map['isPinned'] ?? false, // isPinned도 처리
      imageUrl: map['imageUrl'],
      imageUrls: imageUrls,
      pdfUrl: map['pdfUrl'],
      pdfFileName: map['pdfFileName'],
      viewCount: map['viewCount'] ?? 0,
      viewedUsers: viewedUsers,
    );
  }
}
