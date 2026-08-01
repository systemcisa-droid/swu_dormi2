import 'package:cloud_firestore/cloud_firestore.dart';

class RegulationAgreementModel {
  final String id;
  final String userId;
  final String userName;
  final String roomNumber;
  final String? dormBuilding;
  final String signatureUrl; // 서명 이미지 URL
  final DateTime agreedAt; // 동의한 날짜 및 시간

  RegulationAgreementModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.roomNumber,
    this.dormBuilding,
    required this.signatureUrl,
    required this.agreedAt,
  });

  factory RegulationAgreementModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RegulationAgreementModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      roomNumber: data['roomNumber'] ?? '',
      dormBuilding: data['dormBuilding'] as String?,
      signatureUrl: data['signatureUrl'] ?? '',
      agreedAt: (data['agreedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'roomNumber': roomNumber,
      'dormBuilding': dormBuilding,
      'signatureUrl': signatureUrl,
      'agreedAt': Timestamp.fromDate(agreedAt),
    };
  }
}
