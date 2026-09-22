import 'package:cloud_firestore/cloud_firestore.dart';

class MealModel {
  final String id;
  final String title;
  final String imageUrl;
  final String imageName;
  final int year;
  final int month;
  final int weekNumber;
  final DateTime createdAt;

  MealModel({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.imageName,
    required this.year,
    required this.month,
    required this.weekNumber,
    required this.createdAt,
  });

  /// 슬롯 ID 생성 (예: 2026_1_1)
  String get slotId => '${year}_${month}_$weekNumber';

  /// 슬롯 표시명 (예: 2026.01 1번째주 식단)
  String get slotDisplayName => '$year.${month.toString().padLeft(2, '0')} $weekNumber번째주 식단';

  factory MealModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return MealModel(
      id: doc.id,
      title: data['title'] ?? '',
      imageUrl: data['imageUrl'] ?? data['pdfUrl'] ?? '',
      imageName: data['imageName'] ?? data['pdfName'] ?? '',
      year: data['year'] ?? DateTime.now().year,
      month: data['month'] ?? DateTime.now().month,
      weekNumber: data['weekNumber'] ?? 1,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'imageUrl': imageUrl,
      'imageName': imageName,
      'year': year,
      'month': month,
      'weekNumber': weekNumber,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
