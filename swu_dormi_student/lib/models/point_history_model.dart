import 'package:cloud_firestore/cloud_firestore.dart';

class PointHistoryModel {
  final String id;
  final String userId;
  final String type; // 'reward' | 'penalty'
  final int points;
  final String reason;
  final DateTime createdAt;

  PointHistoryModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.points,
    required this.reason,
    required this.createdAt,
  });

  bool get isReward => type == 'reward';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'points': points,
      'reason': reason,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PointHistoryModel.fromMap(Map<String, dynamic> map) {
    return PointHistoryModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      type: map['type'] ?? 'penalty',
      points: map['points'] ?? 0,
      reason: map['reason'] ?? '',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is Timestamp
              ? (map['createdAt'] as Timestamp).toDate()
              : DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}
