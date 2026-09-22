import 'package:cloud_firestore/cloud_firestore.dart';

class CleaningRequestModel {
  final String id;
  final String userId;
  final String userName;
  final String roomNumber;
  final String? building;
  final String? memo; // 신청 메모
  final String? imageUrl; // 첨부 이미지
  final List<DateTime> availableDates; // 학생이 선택한 점검 가능 날짜
  final String? availableTimeSlot; // 방문 가능 시간대 코드
  final String? availableTimeSlotLabel; // 방문 가능 시간대 레이블
  final String? slotId; // 연결된 청소 슬롯 ID
  final String status; // pending, in_progress, completed, rejected
  final DateTime createdAt;
  final DateTime? updatedAt;

  // 평가 관련 필드
  final String? grade; // 등급 (excellent, good, poor)
  final String? comment; // 평가 코멘트
  final String? evaluatedBy; // 평가자 ID
  final String? evaluatedByName; // 평가자 이름
  final DateTime? evaluatedAt; // 평가 일시

  CleaningRequestModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.roomNumber,
    this.building,
    this.memo,
    this.imageUrl,
    this.availableDates = const [],
    this.availableTimeSlot,
    this.availableTimeSlotLabel,
    this.slotId,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.grade,
    this.comment,
    this.evaluatedBy,
    this.evaluatedByName,
    this.evaluatedAt,
  });

  factory CleaningRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // availableDates 변환
    List<DateTime> dates = [];
    if (data['availableDates'] != null) {
      dates = (data['availableDates'] as List)
          .map((e) => (e as Timestamp).toDate())
          .toList();
    }

    return CleaningRequestModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      roomNumber: data['roomNumber'] ?? '',
      building: data['building'],
      memo: data['memo'],
      imageUrl: data['imageUrl'],
      availableDates: dates,
      availableTimeSlot: data['availableTimeSlot'],
      availableTimeSlotLabel: data['availableTimeSlotLabel'],
      slotId: data['slotId'],
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      grade: data['grade'],
      comment: data['comment'],
      evaluatedBy: data['evaluatedBy'],
      evaluatedByName: data['evaluatedByName'],
      evaluatedAt: data['evaluatedAt'] != null
          ? (data['evaluatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'roomNumber': roomNumber,
      'building': building,
      'memo': memo,
      'imageUrl': imageUrl,
      'availableDates': availableDates.map((e) => Timestamp.fromDate(e)).toList(),
      'availableTimeSlot': availableTimeSlot,
      'availableTimeSlotLabel': availableTimeSlotLabel,
      'slotId': slotId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'grade': grade,
      'comment': comment,
      'evaluatedBy': evaluatedBy,
      'evaluatedByName': evaluatedByName,
      'evaluatedAt': evaluatedAt != null ? Timestamp.fromDate(evaluatedAt!) : null,
    };
  }

  String get statusText {
    switch (status) {
      case 'pending':
        return '대기중';
      case 'in_progress':
        return '점검중';
      case 'completed':
        return '완료';
      case 'rejected':
        return '반려됨';
      default:
        return '알 수 없음';
    }
  }

  String get gradeText {
    switch (grade) {
      case 'excellent':
        return '매우양호';
      case 'good':
        return '양호';
      case 'poor':
        return '미흡';
      default:
        return '미평가';
    }
  }
}

