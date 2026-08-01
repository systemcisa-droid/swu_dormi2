import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String postId;
  final String content;
  final String authorId;
  final String authorName;
  final String? authorProfileImageUrl;
  final DateTime createdAt;
  final int likeCount;
  final List<String> likes; // 좋아요 누른 사용자 ID 리스트

  CommentModel({
    required this.id,
    required this.postId,
    required this.content,
    required this.authorId,
    required this.authorName,
    this.authorProfileImageUrl,
    required this.createdAt,
    this.likeCount = 0,
    this.likes = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'postId': postId,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'authorProfileImageUrl': authorProfileImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'likeCount': likeCount,
      'likes': likes,
    };
  }

  factory CommentModel.fromMap(Map<String, dynamic> map) {
    DateTime createdAt;
    if (map['createdAt'] is Timestamp) {
      createdAt = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      createdAt = DateTime.parse(map['createdAt']);
    } else {
      createdAt = DateTime.now();
    }

    List<String> likes = [];
    if (map['likes'] != null && map['likes'] is List) {
      likes = List<String>.from(map['likes']);
    }

    return CommentModel(
      id: map['id'] ?? '',
      postId: map['postId'] ?? '',
      content: map['content'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      authorProfileImageUrl: map['authorProfileImageUrl'],
      createdAt: createdAt,
      likeCount: map['likeCount'] ?? 0,
      likes: likes,
    );
  }

  CommentModel copyWith({
    String? id,
    String? postId,
    String? content,
    String? authorId,
    String? authorName,
    String? authorProfileImageUrl,
    DateTime? createdAt,
    int? likeCount,
    List<String>? likes,
  }) {
    return CommentModel(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      content: content ?? this.content,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorProfileImageUrl: authorProfileImageUrl ?? this.authorProfileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      likeCount: likeCount ?? this.likeCount,
      likes: likes ?? this.likes,
    );
  }
}
