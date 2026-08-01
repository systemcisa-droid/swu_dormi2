import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String? nickname; // 별명
  final String studentId;
  final String phoneNumber;
  final String roomNumber; // 호실
  final String role; // 'student' 또는 'admin'
  final String? college; // 학부
  final String? department; // 학과
  final String? profileImageUrl;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.nickname,
    required this.studentId,
    required this.phoneNumber,
    this.roomNumber = '000', // 기본값 "000"
    this.role = 'student', // 기본값 "student"
    this.college,
    this.department,
    this.profileImageUrl,
    required this.createdAt,
  });

  // 호실번호로부터 동 계산 (201~220: A동, 221~235: B동)
  String get building {
    if (roomNumber.isEmpty || roomNumber == '000') return '미배정';

    final roomNum = int.tryParse(roomNumber);
    if (roomNum == null) return '미배정';

    final lastTwoDigits = roomNum % 100;
    if (lastTwoDigits >= 1 && lastTwoDigits <= 20) {
      return 'A동';
    } else if (lastTwoDigits >= 21 && lastTwoDigits <= 35) {
      return 'B동';
    }
    return '미배정';
  }

  // 호실번호로부터 층 계산 (200번대: 2층, 300번대: 3층, ...)
  String get floor {
    if (roomNumber.isEmpty || roomNumber == '000') return '미배정';

    final roomNum = int.tryParse(roomNumber);
    if (roomNum == null) return '미배정';

    final floorNum = roomNum ~/ 100;
    if (floorNum >= 2 && floorNum <= 7) {
      return '${floorNum}층';
    }
    return '미배정';
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'nickname': nickname,
      'studentId': studentId,
      'phoneNumber': phoneNumber,
      'roomNumber': roomNumber,
      'building': building, // 동 정보
      'floor': floor, // 층 정보
      'role': role,
      'college': college,
      'department': department,
      'profileImageUrl': profileImageUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      nickname: map['nickname'],
      studentId: map['studentId'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      roomNumber: map['roomNumber'] ?? '000',
      role: map['role'] ?? 'student',
      college: map['college'],
      department: map['department'],
      profileImageUrl: map['profileImageUrl'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

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

    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      nickname: data['nickname'],
      studentId: data['studentId'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      roomNumber: data['roomNumber'] ?? '000',
      role: data['role'] ?? 'student',
      college: data['college'],
      department: data['department'],
      profileImageUrl: data['profileImageUrl'],
      createdAt: parseCreatedAt(data['createdAt']),
    );
  }
}
