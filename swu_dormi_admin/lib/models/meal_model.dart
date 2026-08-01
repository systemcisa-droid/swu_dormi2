import 'package:cloud_firestore/cloud_firestore.dart';

class MealModel {
  final String id;
  final DateTime date;
  final Map<String, List<String>> meals; // 'breakfast', 'lunch', 'dinner'
  final DateTime createdAt;

  MealModel({
    required this.id,
    required this.date,
    required this.meals,
    required this.createdAt,
  });

  factory MealModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final mealsData = data['meals'] as Map<String, dynamic>? ?? {};
    final meals = <String, List<String>>{};

    mealsData.forEach((key, value) {
      meals[key] = List<String>.from(value ?? []);
    });

    return MealModel(
      id: doc.id,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      meals: meals,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'meals': meals,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  List<String>? getBreakfast() => meals['breakfast'];
  List<String>? getLunch() => meals['lunch'];
  List<String>? getDinner() => meals['dinner'];
}
