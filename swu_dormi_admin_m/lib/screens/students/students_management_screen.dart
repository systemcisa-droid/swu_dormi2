import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:excel/excel.dart' hide Border;
import '../../services/firestore_service.dart';
import '../../models/student_model.dart';
import '../../models/excel_student_row.dart';
import 'student_detail_screen.dart';

/// 가입자(StudentModel)와 미가입자(ExcelStudentRow)를 하나의 리스트에서
/// 함께 다루기 위한 경량 래퍼. 둘 중 하나만 non-null이다.
class _StudentListEntry {
  final StudentModel? student;
  final ExcelStudentRow? excelRow;

  const _StudentListEntry.registered(StudentModel this.student) : excelRow = null;
  const _StudentListEntry.unregistered(ExcelStudentRow this.excelRow) : student = null;

  bool get isRegistered => student != null;

  String get displayName =>
      isRegistered ? student!.name : (excelRow!.name ?? '(이름 없음)');

  String get displayRoomNumber =>
      isRegistered ? student!.roomNumber : (excelRow!.roomNumber ?? '');

  String? get displayDormBuilding =>
      isRegistered ? student!.dormBuilding : excelRow!.dormBuilding;
}

class StudentsManagementScreen extends StatefulWidget {
  const StudentsManagementScreen({super.key});

  @override
  State<StudentsManagementScreen> createState() => _StudentsManagementScreenState();
}

class _StudentsManagementScreenState extends State<StudentsManagementScreen> {
  final _firestoreService = FirestoreService();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _assignedFloor;
  List<ExcelStudentRow> _excelStudentRows = [];
  bool _showOnlyUnregistered = false;

  @override
  void initState() {
    super.initState();
    _loadAssignedFloor();
    _loadExcelStudentRows();
  }

  // 사생 기본 정보 엑셀에서 전체 명단을 로드한다.
  // 부가 기능이므로 실패해도 에러를 표시하지 않고 조용히 빈 리스트로 처리한다.
  Future<void> _loadExcelStudentRows() async {
    try {
      final settingsDoc =
          await FirebaseFirestore.instance.collection('settings').doc('home').get();
      final excelUrl = settingsDoc.data()?['studentInfoExcelUrl'] as String?;
      if (excelUrl == null || excelUrl.trim().isEmpty) {
        if (mounted) setState(() => _excelStudentRows = []);
        return;
      }

      final response = await http.get(Uri.parse(excelUrl));
      if (response.statusCode != 200) {
        if (mounted) setState(() => _excelStudentRows = []);
        return;
      }
      final excel = Excel.decodeBytes(response.bodyBytes);
      final sheet = excel.sheets.values.first;
      final rows = sheet.rows
          .map((row) => row.map((cell) => cell?.value?.toString() ?? '').toList())
          .toList();
      if (rows.isEmpty) {
        if (mounted) setState(() => _excelStudentRows = []);
        return;
      }

      final header = rows.first;
      final excelRows =
          rows.skip(1).map((row) => ExcelStudentRow.fromRow(header, row)).toList();

      if (mounted) setState(() => _excelStudentRows = excelRows);
    } catch (_) {
      // 조용히 무시 (가입자 목록 표시는 계속 정상 동작해야 함)
      if (mounted) setState(() => _excelStudentRows = []);
    }
  }

  // 엑셀 row가 담당 구역(zone) 필터를 통과하는지 판단.
  // roomNumber를 정수로 변환할 수 없는 등 판단 불가능한 경우는 제외 처리한다.
  bool _isExcelRowInAssignedZone(ExcelStudentRow row) {
    final zone = _assignedZone;
    if (zone == null) return true;

    if (row.dormBuilding != zone.dorm) return false;

    final room = int.tryParse(row.roomNumber ?? '');
    if (room == null) return false;

    if (zone.floor != null) {
      if (room ~/ 100 != zone.floor) return false;
    }

    if (zone.wing != null) {
      final last = room % 100;
      final rowWing = (zone.dorm == '국제생활관')
          ? ((room >= 101 && room <= 132) || (room >= 201 && room <= 229) ? 'A' : 'B')
          : (last >= 1 && last <= 20 ? 'A' : 'B');
      if (rowWing != zone.wing) return false;
    }

    return true;
  }

  Future<void> _loadAssignedFloor() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final floor = doc.data()?['assignedFloor'] as String?;
      if (mounted) setState(() => _assignedFloor = floor);
    } catch (_) {}
  }

  ({String dorm, String? wing, int? floor})? get _assignedZone {
    final zone = _assignedFloor;
    if (zone == null) return null;

    String dorm;
    if (zone.startsWith('샬롬하우스(겨울방학)')) {
      dorm = '샬롬하우스(겨울방학)';
    } else if (zone.startsWith('샬롬하우스')) {
      dorm = '샬롬하우스';
    } else if (zone.startsWith('국제생활관')) {
      dorm = '국제생활관';
    } else if (zone.startsWith('바롬인성교육관')) {
      dorm = '바롬인성교육관';
    } else {
      return null;
    }

    final wingMatch = RegExp(r'([AB])동').firstMatch(zone);
    final floorMatch = RegExp(r'(\d+)층').firstMatch(zone);
    return (
      dorm: dorm,
      wing: wingMatch?.group(1),
      floor: floorMatch != null ? int.tryParse(floorMatch.group(1)!) : null,
    );
  }

  bool _isInAssignedZone(StudentModel student) {
    final zone = _assignedZone;
    if (zone == null) return true;

    if (student.dormBuilding != zone.dorm) return false;

    final room = int.tryParse(student.roomNumber);
    if (room == null) return false;

    if (zone.floor != null) {
      if (room ~/ 100 != zone.floor) return false;
    }

    if (zone.wing != null) {
      final last = room % 100;
      final studentWing = (zone.dorm == '국제생활관')
          ? ((room >= 101 && room <= 132) || (room >= 201 && room <= 229) ? 'A' : 'B')
          : (last >= 1 && last <= 20 ? 'A' : 'B');
      if (studentWing != zone.wing) return false;
    }

    return true;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static Color _dormBuildingColor(String? dorm) {
    if (dorm != null && dorm.startsWith('샬롬하우스')) return Colors.indigo;
    switch (dorm) {
      case '국제생활관':    return Colors.teal;
      case '바롬인성교육관': return Colors.orange;
      default:            return Colors.blueGrey;
    }
  }

  static const _moveOutStatusOptions = ['만기퇴사', '자진퇴사', '강제퇴사', '영구퇴사'];
  static bool _isMoveOutStatus(String status) => status == '퇴사' || _moveOutStatusOptions.contains(status);

  static String _residentStatusText(String? status) {
    if (status != null && _isMoveOutStatus(status)) return status;
    if (status == '바롬인성교육관') return '바롬인성교육관';
    return '재실중';
  }

  static Color _residentStatusColor(String? status) {
    final text = _residentStatusText(status);
    if (text == '바롬인성교육관') return Colors.orange.shade800;
    if (_isMoveOutStatus(text)) return Colors.red.shade700;
    return Colors.green.shade700;
  }

  // 담당 구역 요약 바: "A동 4층  정원: 35명  [미가입 N명]"
  Widget _buildZoneSummary(int zoneCount, int unregisteredCount) {
    final zone = _assignedZone;
    final zoneLabel = _assignedFloor ?? '전체';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, size: 16, color: Colors.indigo.shade400),
          const SizedBox(width: 6),
          Text(
            zoneLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: zone != null ? Colors.indigo.shade700 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '정원: $zoneCount명',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const Spacer(),
          if (unregisteredCount > 0)
            GestureDetector(
              onTap: () {
                setState(() => _showOnlyUnregistered = !_showOnlyUnregistered);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _showOnlyUnregistered
                      ? Colors.orange
                      : Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange, width: 1),
                ),
                child: Text(
                  '미가입 $unregisteredCount명',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _showOnlyUnregistered ? Colors.white : Colors.orange.shade800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
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

                final students = (snapshot.data?.docs ?? [])
                    .map((doc) => StudentModel.fromFirestore(doc))
                    .toList();

                // 가입자 이메일 Set (이메일 기준으로만 미가입자 판단)
                final registeredEmails = students
                    .map((s) => s.email.trim().toLowerCase())
                    .where((e) => e.isNotEmpty)
                    .toSet();

                // 엑셀 명단에서 미가입자만 추출
                final unregisteredRows = _excelStudentRows.where((r) {
                  if (!r.hasMatchKey) return false;
                  final email = r.normalizedEmail;
                  if (email != null && registeredEmails.contains(email)) return false;
                  return true;
                }).toList();

                // 담당 구역 필터 적용 후 하나의 리스트로 병합
                final entries = <_StudentListEntry>[
                  ...students.where(_isInAssignedZone).map(_StudentListEntry.registered),
                  ...unregisteredRows
                      .where(_isExcelRowInAssignedZone)
                      .map(_StudentListEntry.unregistered),
                ];

                final unregisteredCount = entries.where((e) => !e.isRegistered).length;

                // 검색 + 미가입 필터링
                final filteredEntries = entries.where((entry) {
                  if (_showOnlyUnregistered && entry.isRegistered) return false;
                  if (_searchQuery.isEmpty) return true;
                  final studentId = entry.isRegistered
                      ? entry.student!.studentId
                      : (entry.excelRow!.studentId ?? '');
                  return entry.displayName.toLowerCase().contains(_searchQuery) ||
                      studentId.toLowerCase().contains(_searchQuery) ||
                      entry.displayRoomNumber.contains(_searchQuery);
                }).toList();

                // 호실 번호 순 정렬
                filteredEntries.sort((a, b) {
                  final ra = int.tryParse(a.displayRoomNumber) ?? 0;
                  final rb = int.tryParse(b.displayRoomNumber) ?? 0;
                  return ra.compareTo(rb);
                });

                if (filteredEntries.isEmpty) {
                  final noResultAtAll = entries.isEmpty;
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          noResultAtAll ? Icons.people_outline : Icons.search_off,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          noResultAtAll ? '등록된 학생이 없습니다' : '검색 결과가 없습니다',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    _buildZoneSummary(entries.length, unregisteredCount),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredEntries.length,
                        itemBuilder: (context, index) {
                          final entry = filteredEntries[index];
                          return entry.isRegistered
                              ? _buildStudentCard(context, entry.student!)
                              : _buildUnregisteredCard(context, entry.excelRow!);
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
              Container(width: 6, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  student.name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (student.residentStatus.isNotEmpty && student.residentStatus != '재실중') ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: _residentStatusColor(student.residentStatus).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      student.residentStatus,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _residentStatusColor(student.residentStatus),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  student.studentId,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                                Text('  ·  ', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                                Text(
                                  student.roomCapacity.isNotEmpty
                                      ? '${student.roomNumber}호 (${student.roomCapacity})'
                                      : '${student.roomNumber}호',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                ),
                                if (student.seatNumber != null && student.seatNumber!.isNotEmpty) ...[
                                  Text('  ·  ', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                                  Text(
                                    student.seatNumber!,
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                  ),
                                ],
                                if (student.dormBuilding != null && student.dormBuilding!.isNotEmpty) ...[
                                  Text('  ·  ', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                                  Text(
                                    student.dormBuilding!,
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                  ),
                                ],
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

  // 미가입 학생(엑셀 명단에만 있는 학생) 카드. 가입자 카드와 유사하지만
  // 주황색 아바타/배지로 구분하고, 탭 시 간단한 정보 바텀시트를 띄운다.
  Widget _buildUnregisteredCard(BuildContext context, ExcelStudentRow row) {
    const color = Colors.orange;
    final name = row.name ?? '(이름 없음)';
    final roomNumber = row.roomNumber ?? '';
    final roomCapacity = row.roomCapacity;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showUnregisteredDetail(context, row),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 6, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: color.withValues(alpha: 0.12),
                        child: const Icon(Icons.person_outline, size: 30, color: color),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: const Text(
                                    '미가입',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (row.dormBuilding != null) ...[
                                  Text(
                                    row.dormBuilding!,
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                  ),
                                  Text('  ·  ', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                                ],
                                Text(
                                  roomCapacity != null
                                      ? '$roomNumber호 ($roomCapacity)'
                                      : '$roomNumber호',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                                ),
                                if (row.seatNumber != null && row.seatNumber!.isNotEmpty) ...[
                                  Text('  ·  ', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                                  Text(
                                    row.seatNumber!,
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                  ),
                                ],
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

  // 미가입 학생 탭 시 표시할 간단한 정보 바텀시트.
  // StudentDetailScreen은 StudentModel(non-nullable 필드)을 요구하므로
  // 엑셀 기본 정보만 보여주는 별도 바텀시트로 대체한다.
  void _showUnregisteredDetail(BuildContext context, ExcelStudentRow row) {
    Widget infoRow(IconData icon, String label, String? value) {
      if (value == null || value.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 10),
            SizedBox(
              width: 70,
              child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    row.name ?? '(이름 없음)',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Text(
                      '미가입',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              infoRow(Icons.email_outlined, '이메일', row.email),
              infoRow(Icons.badge_outlined, '학번', row.studentId),
              infoRow(Icons.phone_outlined, '휴대폰', row.phoneNumber),
              infoRow(Icons.apartment_outlined, '기숙사', row.dormBuilding),
              infoRow(
                Icons.meeting_room_outlined,
                '호실',
                row.roomCapacity != null && row.roomNumber != null
                    ? '${row.roomNumber}호 (${row.roomCapacity})'
                    : row.roomNumber,
              ),
              infoRow(Icons.event_seat_outlined, '자리번호', row.seatNumber),
              infoRow(Icons.school_outlined, '학과', row.department),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
