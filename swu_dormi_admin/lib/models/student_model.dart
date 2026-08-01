import 'package:cloud_firestore/cloud_firestore.dart';

class StudentModel {
  final String id;
  final String email;
  final String name;
  final String? nickname;
  final String studentId;
  final String phoneNumber;
  final String roomNumber;
  final String? college;
  final String? department;
  final String? seatNumber;
  final String? dormBuilding;
  final String? profileImageUrl;
  final int points;
  final DateTime createdAt;

  StudentModel({
    required this.id,
    required this.email,
    required this.name,
    this.nickname,
    required this.studentId,
    required this.phoneNumber,
    required this.roomNumber,
    this.college,
    this.department,
    this.seatNumber,
    this.dormBuilding,
    this.profileImageUrl,
    this.points = 0,
    required this.createdAt,
  });

  factory StudentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // createdAt 필드를 안전하게 파싱
    DateTime parseCreatedAt(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return DateTime.now();
        }
      }
      return DateTime.now();
    }

    return StudentModel(
      id: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      nickname: data['nickname'] as String?,
      studentId: data['studentId'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      roomNumber: data['roomNumber'] ?? '',
      college: data['college'] as String?,
      department: data['department'] as String?,
      seatNumber: data['seatNumber'] as String?,
      dormBuilding: data['dormBuilding'] as String?,
      profileImageUrl: data['profileImageUrl'],
      points: (data['points'] as num?)?.toInt() ?? 0,
      createdAt: parseCreatedAt(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      if (nickname != null) 'nickname': nickname,
      'studentId': studentId,
      'phoneNumber': phoneNumber,
      'roomNumber': roomNumber,
      if (college != null) 'college': college,
      if (department != null) 'department': department,
      if (seatNumber != null) 'seatNumber': seatNumber,
      'profileImageUrl': profileImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static const Map<int, int> _roomCapacities = {
    1: 2, 2: 4, 3: 2, 4: 2, 5: 4, 6: 2, 7: 1, 8: 2, 9: 1, 10: 2,
    11: 1, 12: 1, 13: 4, 14: 4, 15: 4, 16: 4, 17: 4, 18: 4, 19: 4, 20: 4,
    21: 2, 22: 4, 23: 2, 24: 2, 25: 4, 26: 2, 27: 2, 28: 2, 29: 1, 30: 4,
    31: 4, 32: 4, 33: 4, 34: 4, 35: 4,
  };

  String get roomCapacity {
    if (dormBuilding != null && dormBuilding != '샬롬하우스') return '';
    if (roomNumber.isEmpty || roomNumber == '000') return '';
    final roomNum = int.tryParse(roomNumber);
    if (roomNum == null) return '';
    final lastTwoDigits = roomNum % 100;
    final cap = _roomCapacities[lastTwoDigits];
    if (cap != null) return '${cap}인실';
    return '';
  }
}
