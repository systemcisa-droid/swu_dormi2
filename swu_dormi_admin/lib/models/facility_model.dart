import 'package:cloud_firestore/cloud_firestore.dart';

class FacilityModel {
  final String id;
  final String userId;
  final String userName;
  final String category;
  final String location;
  final String description;
  final List<String> imageUrls;
  final String status; // 'pending', 'in_progress', 'completed'
  final String? adminNote;
  final DateTime createdAt;
  final DateTime? processedAt;

  FacilityModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.category,
    required this.location,
    required this.description,
    this.imageUrls = const [],
    required this.status,
    this.adminNote,
    required this.createdAt,
    this.processedAt,
  });

  factory FacilityModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FacilityModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      category: data['category'] ?? '',
      location: data['location'] ?? '',
      description: data['description'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      status: data['status'] ?? 'pending',
      adminNote: data['adminNote'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      processedAt: (data['processedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'category': category,
      'location': location,
      'description': description,
      'imageUrls': imageUrls,
      'status': status,
      'adminNote': adminNote,
      'createdAt': Timestamp.fromDate(createdAt),
      'processedAt': processedAt != null ? Timestamp.fromDate(processedAt!) : null,
    };
  }

  String getStatusDisplayName() {
    switch (status) {
      case 'pending':
        return '대기중';
      case 'in_progress':
        return '처리중';
      case 'completed':
        return '완료';
      default:
        return status;
    }
  }
}
