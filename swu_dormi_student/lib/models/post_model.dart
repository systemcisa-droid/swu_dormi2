import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final String? authorNickname; // 작성자 별명
  final String? authorProfileImageUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int likeCount;
  final int commentCount;
  final int viewCount;
  final List<String> likes; // 좋아요 누른 사용자 ID 리스트
  final List<String> viewedUsers; // 조회한 사용자 ID 리스트
  final List<String> imageUrls;
  final String category; // '물품 나눔', '정보 알림', 'lost&found'

  PostModel({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    this.authorNickname,
    this.authorProfileImageUrl,
    required this.createdAt,
    this.updatedAt,
    this.likeCount = 0,
    this.commentCount = 0,
    this.viewCount = 0,
    this.likes = const [],
    this.viewedUsers = const [],
    this.imageUrls = const [],
    this.category = 'lost&found',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'authorNickname': authorNickname,
      'authorProfileImageUrl': authorProfileImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'viewCount': viewCount,
      'likes': likes,
      'viewedUsers': viewedUsers,
      'imageUrls': imageUrls,
      'category': category,
    };
  }

  factory PostModel.fromMap(Map<String, dynamic> map) {
    DateTime createdAt;
    if (map['createdAt'] is Timestamp) {
      createdAt = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      createdAt = DateTime.parse(map['createdAt']);
    } else {
      createdAt = DateTime.now();
    }

    DateTime? updatedAt;
    if (map['updatedAt'] is Timestamp) {
      updatedAt = (map['updatedAt'] as Timestamp).toDate();
    } else if (map['updatedAt'] is String) {
      updatedAt = DateTime.parse(map['updatedAt']);
    }

    List<String> likes = [];
    if (map['likes'] != null && map['likes'] is List) {
      likes = List<String>.from(map['likes']);
    }

    List<String> viewedUsers = [];
    if (map['viewedUsers'] != null && map['viewedUsers'] is List) {
      viewedUsers = List<String>.from(map['viewedUsers']);
    }

    List<String> imageUrls = [];
    if (map['imageUrls'] != null && map['imageUrls'] is List) {
      imageUrls = List<String>.from(map['imageUrls']);
    }

    return PostModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      authorNickname: map['authorNickname'],
      authorProfileImageUrl: map['authorProfileImageUrl'],
      createdAt: createdAt,
      updatedAt: updatedAt,
      likeCount: map['likeCount'] ?? 0,
      commentCount: map['commentCount'] ?? 0,
      viewCount: map['viewCount'] ?? 0,
      likes: likes,
      viewedUsers: viewedUsers,
      imageUrls: imageUrls,
      category: map['category'] ?? 'lost&found',
    );
  }

  PostModel copyWith({
    String? id,
    String? title,
    String? content,
    String? authorId,
    String? authorName,
    String? authorNickname,
    String? authorProfileImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? likeCount,
    int? commentCount,
    int? viewCount,
    List<String>? likes,
    List<String>? viewedUsers,
    List<String>? imageUrls,
    String? category,
  }) {
    return PostModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorNickname: authorNickname ?? this.authorNickname,
      authorProfileImageUrl: authorProfileImageUrl ?? this.authorProfileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      viewCount: viewCount ?? this.viewCount,
      likes: likes ?? this.likes,
      viewedUsers: viewedUsers ?? this.viewedUsers,
      imageUrls: imageUrls ?? this.imageUrls,
      category: category ?? this.category,
    );
  }
}
