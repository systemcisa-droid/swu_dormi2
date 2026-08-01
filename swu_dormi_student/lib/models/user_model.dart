class UserModel {
  final String uid;
  final String email;
  final String name;
  final String? nickname; // 별명
  final String studentId;
  final String phoneNumber;
  final String roomNumber; // 호실
  final String? seatNumber; // 자리번호
  final String role; // 'student' 또는 'admin'
  final String? college; // 학부
  final String? department; // 학과
  final String? dormBuilding; // 기숙사 건물 (샬롬하우스, 국제생활관)
  final String? profileImageUrl;
  final DateTime createdAt;
  final int points; // 상벌점 (마이너스 가능)
  final String residentStatus; // 재실중, 바롬인성교육관, 자퇴
  final List<String> blockedUsers; // 차단한 유저 uid 목록

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.nickname,
    this.studentId = '',
    this.phoneNumber = '',
    this.roomNumber = '000', // 기본값 "000"
    this.seatNumber,
    this.role = 'student', // 기본값 "student"
    this.college,
    this.department,
    this.dormBuilding,
    this.profileImageUrl,
    required this.createdAt,
    this.points = 0, // 기본값 0점
    this.residentStatus = '재실중',
    this.blockedUsers = const [],
  });

  // 호실번호로부터 동 계산
  // 샬롬하우스: 마지막 두자리 01~20=A동, 21~40=B동
  // 국제생활관: 101~132, 201~229=A동 / 233~260, 301~329=B동
  String get building {
    if (roomNumber.isEmpty || roomNumber == '000') return '미배정';

    final roomNum = int.tryParse(roomNumber);
    if (roomNum == null) return '미배정';

    if (dormBuilding == '국제생활관') {
      if ((roomNum >= 101 && roomNum <= 132) || (roomNum >= 201 && roomNum <= 229)) return 'A동';
      if ((roomNum >= 233 && roomNum <= 260) || (roomNum >= 301 && roomNum <= 329)) return 'B동';
      return '미배정';
    }

    // 샬롬하우스 (기존 로직)
    final lastTwoDigits = roomNum % 100;
    if (lastTwoDigits >= 1 && lastTwoDigits <= 20) return 'A동';
    if (lastTwoDigits >= 21 && lastTwoDigits <= 35) return 'B동';
    return '미배정';
  }

  // 호실번호로부터 층 계산
  // 샬롬하우스: 200번대=2층, 300번대=3층, ...
  // 국제생활관: 100번대=1층, 200번대=2층, 300번대=3층
  String get floor {
    if (roomNumber.isEmpty || roomNumber == '000') return '미배정';

    final roomNum = int.tryParse(roomNumber);
    if (roomNum == null) return '미배정';

    if (dormBuilding == '국제생활관') {
      final floorNum = roomNum ~/ 100;
      if (floorNum >= 1 && floorNum <= 9) return '${floorNum}층';
      return '미배정';
    }

    // 샬롬하우스 (기존 로직)
    final floorNum = roomNum ~/ 100;
    if (floorNum >= 2 && floorNum <= 7) return '${floorNum}층';
    return '미배정';
  }

  static const Map<int, int> _roomCapacities = {
    1: 2, 2: 4, 3: 2, 4: 2, 5: 4, 6: 2, 7: 1, 8: 2, 9: 1, 10: 2,
    11: 1, 12: 1, 13: 4, 14: 4, 15: 4, 16: 4, 17: 4, 18: 4, 19: 4, 20: 4,
    21: 2, 22: 4, 23: 2, 24: 2, 25: 4, 26: 2, 27: 2, 28: 2, 29: 1, 30: 4,
    31: 4, 32: 4, 33: 4, 34: 4, 35: 4,
  };

  String get roomCapacity {
    if (dormBuilding != null && !dormBuilding!.startsWith('샬롬하우스')) return '';
    if (roomNumber.isEmpty || roomNumber == '000') return '';
    final roomNum = int.tryParse(roomNumber);
    if (roomNum == null) return '';
    final lastTwoDigits = roomNum % 100;
    final cap = _roomCapacities[lastTwoDigits];
    if (cap != null) return '${cap}인실';
    return '';
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
      'seatNumber': seatNumber,
      'building': building, // 동 정보
      'floor': floor, // 층 정보
      'role': role,
      'college': college,
      'department': department,
      'dormBuilding': dormBuilding,
      'profileImageUrl': profileImageUrl,
      'createdAt': createdAt.toIso8601String(),
      'points': points,
      'residentStatus': residentStatus,
      'blockedUsers': blockedUsers,
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
      seatNumber: map['seatNumber'],
      role: map['role'] ?? 'student',
      college: map['college'],
      department: map['department'],
      dormBuilding: map['dormBuilding'],
      profileImageUrl: map['profileImageUrl'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      points: map['points'] ?? 0,
      residentStatus: (map['residentStatus'] as String?) ?? '재실중',
      blockedUsers: List<String>.from(map['blockedUsers'] ?? []),
    );
  }
}
