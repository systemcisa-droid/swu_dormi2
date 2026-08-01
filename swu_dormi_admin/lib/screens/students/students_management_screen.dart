import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../models/student_model.dart';
import 'student_detail_screen.dart';

class StudentsManagementScreen extends StatefulWidget {
  const StudentsManagementScreen({super.key});

  @override
  State<StudentsManagementScreen> createState() => _StudentsManagementScreenState();
}

class _StudentsManagementScreenState extends State<StudentsManagementScreen> {
  final _firestoreService = FirestoreService();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _filterDormBuilding; // null=전체, 'NONE'=미배정, '샬롬하우스', '국제생활관', '바롬인성교육관'
  String? _filterWing;         // null=전체, 'A', 'B'
  int? _filterFloor;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 샬롬하우스: 마지막 두 자리 01~20 = A동, 21~35 = B동
  String _getBuilding(String roomNumber) {
    final n = int.tryParse(roomNumber);
    if (n == null || roomNumber == '000') return '';
    final lastTwo = n % 100;
    if (lastTwo >= 1 && lastTwo <= 20) return 'A';
    if (lastTwo >= 21 && lastTwo <= 35) return 'B';
    return '';
  }

  int _getFloor(String roomNumber) {
    final n = int.tryParse(roomNumber);
    if (n == null || roomNumber == '000') return 0;
    return n ~/ 100;
  }

  // 국제생활관: A동 1층 101~132, A동 2층 201~229, B동 2층 233~260, B동 3층 301~329
  String _getIntlWing(String roomNumber) {
    final n = int.tryParse(roomNumber);
    if (n == null) return '';
    if ((n >= 101 && n <= 132) || (n >= 201 && n <= 229)) return 'A';
    if ((n >= 233 && n <= 260) || (n >= 301 && n <= 329)) return 'B';
    return '';
  }

  int _getIntlFloor(String roomNumber) {
    final n = int.tryParse(roomNumber);
    if (n == null) return 0;
    if (n >= 101 && n <= 132) return 1;
    if (n >= 201 && n <= 229) return 2;
    if (n >= 233 && n <= 260) return 2;
    if (n >= 301 && n <= 329) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 검색 바
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '이름 또는 학번으로 검색',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // 학생 목록
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestoreService.getStudents(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('오류가 발생했습니다: ${snapshot.error}'),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          '등록된 학생이 없습니다',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                final students = snapshot.data!.docs
                    .map((doc) => StudentModel.fromFirestore(doc))
                    .toList();

                // 검색 + 필터링
                final filteredStudents = students.where((student) {
                  if (_searchQuery.isNotEmpty) {
                    final match =
                        student.name.toLowerCase().contains(_searchQuery) ||
                        student.studentId.toLowerCase().contains(_searchQuery) ||
                        student.roomNumber.contains(_searchQuery);
                    if (!match) return false;
                  }
                  if (_filterDormBuilding != null) {
                    if (_filterDormBuilding == 'NONE') {
                      if (student.roomNumber.isNotEmpty && student.roomNumber != '000') return false;
                    } else {
                      if (student.dormBuilding != _filterDormBuilding) return false;
                    }
                  }
                  if (_filterWing != null) {
                    final isIntl = student.dormBuilding == '국제생활관';
                    final wing = isIntl ? _getIntlWing(student.roomNumber) : _getBuilding(student.roomNumber);
                    if (wing != _filterWing) return false;
                  }
                  if (_filterFloor != null) {
                    final isIntl = student.dormBuilding == '국제생활관';
                    final floor = isIntl ? _getIntlFloor(student.roomNumber) : _getFloor(student.roomNumber);
                    if (floor != _filterFloor) return false;
                  }
                  return true;
                }).toList();

                // 건물 순서 → 호수 순 정렬
                const buildingOrder = ['샬롬하우스', '국제생활관', '바롬인성교육관'];
                filteredStudents.sort((a, b) {
                  final ai = buildingOrder.indexOf(a.dormBuilding ?? '');
                  final bi = buildingOrder.indexOf(b.dormBuilding ?? '');
                  final aIdx = ai == -1 ? buildingOrder.length : ai;
                  final bIdx = bi == -1 ? buildingOrder.length : bi;
                  if (aIdx != bIdx) return aIdx.compareTo(bIdx);
                  final ra = int.tryParse(a.roomNumber) ?? 0;
                  final rb = int.tryParse(b.roomNumber) ?? 0;
                  return ra.compareTo(rb);
                });

                if (filteredStudents.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          '검색 결과가 없습니다',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // 필터 칩 (다중 행)
                    _buildFilterChips(students),

                    // 학생 수 표시
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      color: Colors.grey.shade100,
                      child: Text(
                        '전체 ${students.length}명'
                        '${filteredStudents.length != students.length ? ' / 표시 ${filteredStudents.length}명' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    // 학생 리스트
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredStudents.length,
                        itemBuilder: (context, index) {
                          return _buildStudentCard(context, filteredStudents[index]);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static Color _dormBuildingColor(String? dorm) {
    switch (dorm) {
      case '샬롬하우스':    return Colors.indigo;
      case '국제생활관':    return Colors.teal;
      case '바롬인성교육관': return Colors.orange;
      default:            return Colors.blueGrey;
    }
  }

  Widget _buildFilterChips(List<StudentModel> all) {
    int countBy(String? dorm, String? wing, int? floor) => all.where((s) {
      if (dorm == 'NONE') {
        return s.roomNumber.isEmpty || s.roomNumber == '000';
      }
      if (dorm != null && s.dormBuilding != dorm) return false;
      if (wing != null || floor != null) {
        final isIntl = s.dormBuilding == '국제생활관';
        final w = isIntl ? _getIntlWing(s.roomNumber) : _getBuilding(s.roomNumber);
        final f = isIntl ? _getIntlFloor(s.roomNumber) : _getFloor(s.roomNumber);
        if (wing != null && w != wing) return false;
        if (floor != null && f != floor) return false;
      }
      return true;
    }).length;

    void setFilter(String? dorm, String? wing, int? floor) {
      setState(() {
        if (_filterDormBuilding == dorm && _filterWing == wing && _filterFloor == floor) {
          _filterDormBuilding = null;
          _filterWing = null;
          _filterFloor = null;
        } else {
          _filterDormBuilding = dorm;
          _filterWing = wing;
          _filterFloor = floor;
        }
      });
    }

    bool isActive(String? dorm, String? wing, int? floor) =>
        _filterDormBuilding == dorm && _filterWing == wing && _filterFloor == floor;

    Widget chip(String label, int count, String? dorm, String? wing, int? floor) {
      final active = isActive(dorm, wing, floor);
      final color = dorm == null || dorm == 'NONE'
          ? Colors.blueGrey
          : _dormBuildingColor(dorm);
      return GestureDetector(
        onTap: () => setFilter(dorm, wing, floor),
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.15) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? color : Colors.grey.shade300,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: active ? color : Colors.grey.shade600,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              Text(
                '$count명',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: active ? color : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget scrollRow(List<Widget> chips) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: chips),
    );

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 전체 + 미배정
          scrollRow([
            chip('전체', all.length, null, null, null),
            chip('미배정', countBy('NONE', null, null), 'NONE', null, null),
          ]),
          const SizedBox(height: 6),
          // 샬롬하우스 A동
          scrollRow([
            chip('샬롬하우스 A동', countBy('샬롬하우스', 'A', null), '샬롬하우스', 'A', null),
            for (int f = 2; f <= 7; f++)
              chip('A동 $f층', countBy('샬롬하우스', 'A', f), '샬롬하우스', 'A', f),
          ]),
          const SizedBox(height: 6),
          // 샬롬하우스 B동
          scrollRow([
            chip('샬롬하우스 B동', countBy('샬롬하우스', 'B', null), '샬롬하우스', 'B', null),
            for (int f = 2; f <= 7; f++)
              chip('B동 $f층', countBy('샬롬하우스', 'B', f), '샬롬하우스', 'B', f),
          ]),
          const SizedBox(height: 6),
          // 국제생활관
          scrollRow([
            chip('국제생활관', countBy('국제생활관', null, null), '국제생활관', null, null),
            chip('A동 1층', countBy('국제생활관', 'A', 1), '국제생활관', 'A', 1),
            chip('A동 2층', countBy('국제생활관', 'A', 2), '국제생활관', 'A', 2),
            chip('B동 2층', countBy('국제생활관', 'B', 2), '국제생활관', 'B', 2),
            chip('B동 3층', countBy('국제생활관', 'B', 3), '국제생활관', 'B', 3),
          ]),
          const SizedBox(height: 6),
          // 바롬인성교육관
          scrollRow([
            chip('바롬인성교육관 10층', countBy('바롬인성교육관', null, null), '바롬인성교육관', null, null),
          ]),
        ],
      ),
    );
  }

  Widget _buildStudentCard(BuildContext context, StudentModel student) {
    final color = _dormBuildingColor(student.dormBuilding);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudentDetailScreen(student: student),
            ),
          );
        },
        child: IntrinsicHeight(
          child: Row(
            children: [
              // 건물 색상 사이드바
              Container(width: 6, color: color),

              // 카드 내용
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // 프로필 아바타
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: color.withValues(alpha: 0.12),
                        backgroundImage: student.profileImageUrl != null
                            ? NetworkImage(student.profileImageUrl!)
                            : null,
                        child: student.profileImageUrl == null
                            ? Icon(Icons.person, size: 30, color: color)
                            : null,
                      ),
                      const SizedBox(width: 14),

                      // 학생 정보
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Text(
                                  student.studentId,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                                Text('  ·  ', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                                Text(
                                  '${student.roomNumber}호',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                ),
                                Text('  ·  ', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                                if (student.dormBuilding != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      student.dormBuilding!,
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      Icon(Icons.chevron_right, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
