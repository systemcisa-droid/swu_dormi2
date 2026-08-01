import 'package:cloud_firestore/cloud_firestore.dart';

class NoticeModel {
  final String id;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final DateTime createdAt;
  final String? pdfUrl;
  final String? pdfFileName;
  final List<String> imageUrls;
  final bool isPinned;

  NoticeModel({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    this.pdfUrl,
    this.pdfFileName,
    this.imageUrls = const [],
    this.isPinned = false,
  });

  factory NoticeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle createdAt - could be Timestamp, String, or null
    DateTime createdAtDateTime;
    final createdAtData = data['createdAt'];
    if (createdAtData is Timestamp) {
      createdAtDateTime = createdAtData.toDate();
    } else if (createdAtData is String) {
      try {
        createdAtDateTime = DateTime.parse(createdAtData);
      } catch (e) {
        createdAtDateTime = DateTime.now();
      }
    } else {
      createdAtDateTime = DateTime.now();
    }

    return NoticeModel(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      createdAt: createdAtDateTime,
      pdfUrl: data['pdfUrl'],
      pdfFileName: data['pdfFileName'],
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      isPinned: data['isPinned'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': Timestamp.fromDate(createdAt),
      'pdfUrl': pdfUrl,
      'pdfFileName': pdfFileName,
      'imageUrls': imageUrls,
      'isPinned': isPinned,
    };
  }
}
