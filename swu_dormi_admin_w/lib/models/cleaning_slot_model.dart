import 'package:cloud_firestore/cloud_firestore.dart';

class CleaningSlotModel {
  final String id;
  final DateTime date;
  final String startTime; // "10:00"
  final String endTime;   // "12:00"
  final int maxCapacity;
  final int currentCount;
  final String status; // open, closed, full
  final String createdBy;
  final DateTime createdAt;
  final DateTime? applicationStart;
  final DateTime? applicationDeadline;

  CleaningSlotModel({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.maxCapacity,
    required this.currentCount,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    this.applicationStart,
    this.applicationDeadline,
  });

  factory CleaningSlotModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CleaningSlotModel(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      maxCapacity: data['maxCapacity'] ?? 1,
      currentCount: data['currentCount'] ?? 0,
      status: data['status'] ?? 'open',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      applicationStart: (data['applicationStart'] as Timestamp?)?.toDate(),
      applicationDeadline: (data['applicationDeadline'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'startTime': startTime,
      'endTime': endTime,
      'maxCapacity': maxCapacity,
      'currentCount': currentCount,
      'status': status,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      if (applicationStart != null) 'applicationStart': Timestamp.fromDate(applicationStart!),
      if (applicationDeadline != null) 'applicationDeadline': Timestamp.fromDate(applicationDeadline!),
    };
  }

  int get remainingCapacity => maxCapacity - currentCount;

  bool get isFull => currentCount >= maxCapacity;

  String get statusText {
    switch (status) {
      case 'open':
        return '신청가능';
      case 'closed':
        return '마감';
      case 'full':
        return '정원초과';
      default:
        return '알 수 없음';
    }
  }
}
