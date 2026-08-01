/// 사생 기본 정보 엑셀의 한 행을 나타내는 경량 모델.
///
/// 헤더 텍스트 기반으로 컬럼을 자동 매핑한다. Firestore `users` 조인 없이
/// 엑셀 데이터만 다루는 화면(미가입자 목록)에서 사용한다.
class ExcelStudentRow {
  final String? name;
  final String? email;
  final String? studentId;
  final String? dormBuilding;
  final String? roomNumber;
  final String? roomCapacity;
  final String? seatNumber;
  final String? department;
  final String? phoneNumber;

  const ExcelStudentRow({
    this.name,
    this.email,
    this.studentId,
    this.dormBuilding,
    this.roomNumber,
    this.roomCapacity,
    this.seatNumber,
    this.department,
    this.phoneNumber,
  });

  /// 헤더 텍스트 기반 자동 컬럼 매핑.
  ///
  /// 헤더를 공백 제거·소문자화한 뒤 키워드 포함 여부로 컬럼 인덱스를 판단한다.
  factory ExcelStudentRow.fromRow(List<String> header, List<String> row) {
    // 헤더를 정규화(공백 제거 + 소문자화)
    final normalizedHeader =
        header.map((h) => h.replaceAll(RegExp(r'\s+'), '').toLowerCase()).toList();

    /// keywords 중 하나라도 포함하는 첫 헤더의 인덱스를 반환. 없으면 -1.
    /// exclude 키워드가 포함된 헤더는 건너뛴다.
    int findIndex(List<String> keywords, {List<String> exclude = const []}) {
      for (int i = 0; i < normalizedHeader.length; i++) {
        final h = normalizedHeader[i];
        if (exclude.any((e) => h.contains(e))) continue;
        if (keywords.any((k) => h.contains(k))) return i;
      }
      return -1;
    }

    /// 인덱스의 셀 값을 trim 후 반환. 범위 밖이거나 비었으면 null.
    String? cellAt(int index) {
      if (index < 0 || index >= row.length) return null;
      final v = row[index].trim();
      return v.isEmpty ? null : v;
    }

    return ExcelStudentRow(
      email: cellAt(findIndex(['이메일', 'email'])),
      name: cellAt(findIndex(['성명', '이름'])),
      studentId: cellAt(findIndex(['학번'])),
      dormBuilding: cellAt(findIndex(['기숙사', '건물'])),
      roomNumber: cellAt(findIndex(['호실'], exclude: ['인실'])),
      roomCapacity: cellAt(findIndex(['인실'])),
      seatNumber: cellAt(findIndex(['자리번호', '자리'])),
      department: cellAt(findIndex(['학부', '학과', '전공'])),
      phoneNumber: cellAt(findIndex(['휴대폰', '전화'])),
    );
  }

  /// email 또는 studentId 중 하나라도 비어있지 않으면 true.
  bool get hasMatchKey =>
      (email != null && email!.trim().isNotEmpty) ||
      (studentId != null && studentId!.trim().isNotEmpty);

  /// email을 trim+toLowerCase. 비어있으면 null.
  String? get normalizedEmail {
    if (email == null) return null;
    final e = email!.trim().toLowerCase();
    return e.isEmpty ? null : e;
  }
}
