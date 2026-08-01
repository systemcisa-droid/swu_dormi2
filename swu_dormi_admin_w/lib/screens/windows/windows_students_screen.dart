import 'package:flutter/material.dart' hide Colors, FilledButton, IconButton, Card, ListTile, showDialog, Divider, Checkbox, Tooltip, ButtonStyle;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:swu_dormi_admin/widgets/shimmer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:swu_dormi_admin/services/firestore_service.dart';
import 'package:swu_dormi_admin/models/user_model.dart';
import 'package:swu_dormi_admin/models/excel_student_row.dart';
import 'package:http/http.dart' as http;
import 'package:excel/excel.dart' hide Border;
import 'package:intl/intl.dart';

class WindowsStudentsScreen extends StatefulWidget {
  const WindowsStudentsScreen({super.key});

  @override
  State<WindowsStudentsScreen> createState() => _WindowsStudentsScreenState();
}

/// 가입자(UserModel)와 미가입자(ExcelStudentRow)를 하나의 리스트에서
/// 함께 다루기 위한 경량 래퍼. 둘 중 하나만 non-null이다.
class _StudentListEntry {
  final UserModel? user;
  final ExcelStudentRow? excelRow;

  const _StudentListEntry.registered(UserModel this.user) : excelRow = null;
  const _StudentListEntry.unregistered(ExcelStudentRow this.excelRow) : user = null;

  bool get isRegistered => user != null;

  String get displayName =>
      isRegistered ? user!.name : (excelRow!.name ?? '(이름 없음)');

  String get displayStudentId =>
      isRegistered ? user!.studentId : (excelRow!.studentId ?? '');

  String get displayRoomNumber =>
      isRegistered ? user!.roomNumber : (excelRow!.roomNumber ?? '');

  String? get displayDormBuilding =>
      isRegistered ? user!.dormBuilding : excelRow!.dormBuilding;
}

class _WindowsStudentsScreenState extends State<WindowsStudentsScreen> {
  final _firestoreService = FirestoreService();
  final _dateFormat = DateFormat('yyyy.MM.dd HH:mm');
  UserModel? _selectedStudent;
  ExcelStudentRow? _selectedUnregistered;
  String _searchQuery = '';
  String? _filterBuilding;
  int? _filterFloor;
  List<UserModel> _allStudents = [];
  // 엑셀에는 있으나 users 컬렉션에 이메일이 없는 학생(앱 미가입자)
  List<ExcelStudentRow> _unregisteredStudents = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String? _filterDormBuilding; // null = 전체, '샬롬하우스', '국제생활관'
  String? _filterResidentStatus; // null = 전체, '바롬인성교육관', '퇴사' (재실상태 기준)
  bool _filterOnlyUnregistered = false; // true면 미가입자만 표시

  Map<String, dynamic>? _regulationAgreement;
  Map<String, dynamic>? _moveOutAgreement;
  bool _isLoadingAgreements = false;
  List<Map<String, dynamic>> _pointHistory = [];
  bool _isLoadingPoints = false;
  String _pointHistoryError = '';

  int get _totalPoints {
    int total = 0;
    for (final item in _pointHistory) {
      final pts = (item['points'] as num?)?.toInt() ?? 0;
      final type = (item['type'] ?? 'penalty') as String;
      total += type == 'reward' ? pts : -pts;
    }
    return total;
  }

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadPointHistory(String uid) async {
    setState(() { _isLoadingPoints = true; _pointHistory = []; _pointHistoryError = ''; });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('point_history')
          .get();
      if (!mounted) return;
      final docs = snap.docs.map((d) => d.data()).toList();
      docs.sort((a, b) {
        final at = a['createdAt'];
        final bt = b['createdAt'];
        if (at is Timestamp && bt is Timestamp) return bt.compareTo(at);
        return 0;
      });
      setState(() {
        _pointHistory = docs;
        _isLoadingPoints = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoadingPoints = false; _pointHistoryError = e.toString(); });
    }
  }

  Future<void> _loadAgreements(String uid) async {
    setState(() {
      _isLoadingAgreements = true;
      _regulationAgreement = null;
      _moveOutAgreement = null;
    });
    try {
      final firestore = FirebaseFirestore.instance;
      final regDoc = await firestore.collection('regulation_agreements').doc(uid).get();
      final moveDoc = await firestore.collection('move_out_agreements').doc(uid).get();
      if (!mounted) return;
      setState(() {
        _regulationAgreement = regDoc.exists ? regDoc.data() : null;
        _moveOutAgreement = moveDoc.exists ? moveDoc.data() : null;
        _isLoadingAgreements = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingAgreements = false);
    }
  }

  Future<void> _loadStudents() async {
    setState(() { _isLoading = true; _errorMessage = ''; });
    try {
      final snapshot = await _firestoreService.getStudentsOnce();
      if (!mounted) return;
      setState(() {
        _allStudents = snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
        _isLoading = false;
      });
      // 미가입자 목록은 부가 기능이므로 await 하지 않고 별도로 로드한다.
      _loadUnregisteredStudents();
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; _errorMessage = e.toString(); });
    }
  }

  // 엑셀을 읽을 수 없을 때 미가입자 목록과 선택 상태를 비운다.
  // (엑셀이 삭제/교체된 뒤에도 유령 항목이 남지 않도록)
  void _clearUnregisteredStudents() {
    if (!mounted) return;
    if (_unregisteredStudents.isEmpty && _selectedUnregistered == null) return;
    setState(() {
      _unregisteredStudents = [];
      _selectedUnregistered = null;
    });
  }

  // 사생 기본 정보 엑셀에서 앱 미가입 학생 목록을 로드한다.
  // 부가 기능이므로 실패해도 사용자에게 에러를 표시하지 않고 조용히 무시한다.
  Future<void> _loadUnregisteredStudents() async {
    try {
      final firestore = FirebaseFirestore.instance;

      // 1. settings/home 에서 엑셀 URL 조회
      final settingsDoc =
          await firestore.collection('settings').doc('home').get();
      final excelUrl = settingsDoc.data()?['studentInfoExcelUrl'] as String?;
      if (excelUrl == null || excelUrl.trim().isEmpty) {
        _clearUnregisteredStudents();
        return;
      }

      // 2. 엑셀 다운로드 및 파싱
      final response = await http.get(Uri.parse(excelUrl));
      if (response.statusCode != 200) {
        _clearUnregisteredStudents();
        return;
      }
      final excel = Excel.decodeBytes(response.bodyBytes);
      final sheet = excel.sheets.values.first;
      final rows = sheet.rows
          .map((row) => row.map((cell) => cell?.value?.toString() ?? '').toList())
          .toList();
      if (rows.isEmpty) {
        _clearUnregisteredStudents();
        return;
      }

      final header = rows.first;
      final excelRows = rows
          .skip(1)
          .map((row) => ExcelStudentRow.fromRow(header, row))
          .toList();

      // 3. 가입자 이메일 대조 후 미가입자만 추출
      final registeredEmails = _allStudents
          .map((u) => u.email.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toSet();
      final unregistered = excelRows.where((r) {
        if (!r.hasMatchKey) return false;
        final email = r.normalizedEmail;
        if (email != null && registeredEmails.contains(email)) return false;
        return true;
      }).toList();

      if (!mounted) return;
      setState(() {
        _unregisteredStudents = unregistered;
        // 새로고침 시 선택 항목은 새 객체로 교체된다. 같은 학생을 다시 찾아
        // 선택 상태를 유지하되, 목록에서 사라졌으면 선택을 해제한다.
        final prev = _selectedUnregistered;
        if (prev != null) {
          // 이메일이 없는 행(학번만 있는 행)도 hasMatchKey를 통과하므로
          // 이메일 → 학번 순으로 재매칭한다. 둘 다 없으면 선택을 해제한다.
          final prevEmail = prev.normalizedEmail;
          final prevStudentId = prev.studentId?.trim();
          ExcelStudentRow? rematched;
          for (final r in unregistered) {
            if (prevEmail != null && r.normalizedEmail == prevEmail) {
              rematched = r;
              break;
            }
            if (prevEmail == null &&
                prevStudentId != null &&
                prevStudentId.isNotEmpty &&
                r.studentId?.trim() == prevStudentId) {
              rematched = r;
              break;
            }
          }
          _selectedUnregistered = rematched;
        }
      });
    } catch (_) {
      // 조용히 무시 (가입자 목록 표시는 계속 정상 동작해야 함)
    }
  }

  static const _penaltyReasons = [
    {'reason': '지각 (24시~24시15분)', 'points': 3},
    {'reason': '지각 (24시15분~01시)', 'points': 7},
    {'reason': '인원확인 지각', 'points': 1},
    {'reason': '비사생과 출입', 'points': 13},
    {'reason': '외부인 출입 묵인', 'points': 5},
    {'reason': '출입카드 무단사용', 'points': 3},
    {'reason': '출입카드 미소지 3회', 'points': 1},
    {'reason': '출입카드 미소지 4회', 'points': 2},
    {'reason': '출입카드 미소지 5회 이상', 'points': 3},
    {'reason': '직원지시 불응', 'points': 5},
    {'reason': '화재대피훈련 불참', 'points': 1},
    {'reason': '반입불가물품 소지', 'points': 10},
    {'reason': '청소점검 미실시', 'points': 4},
    {'reason': '기간외 청소신청', 'points': 2},
    {'reason': '기타', 'points': 1},
  ];

  static const _rewardReasons = [
    {'reason': '안전교육 참석', 'points': 3},
    {'reason': '응급상황 사생동행', 'points': 2},
    {'reason': '심폐소생술 교육이수증', 'points': 5},
    {'reason': '안전보안 실천', 'points': 3},
    {'reason': '위급상황 협조', 'points': 1},
    {'reason': '엔젤호실 지정엔젤', 'points': 2},
    {'reason': '입퇴사 도우미', 'points': 2},
    {'reason': '택배정리 지원', 'points': 1},
    {'reason': '행정실 업무 지원', 'points': 1},
    {'reason': '청소 우수 호실', 'points': 2},
    {'reason': '시설물 운영 개선', 'points': 2},
    {'reason': '에너지 절약', 'points': 2},
    {'reason': '시설물 보전관리 지원', 'points': 2},
    {'reason': '주요행사 참여', 'points': 1},
    {'reason': '책임교수 판단 협조', 'points': 1},
    {'reason': '기타', 'points': 1},
  ];

  void _showAddPointDialog(UserModel student) {
    String selectedType = 'penalty';
    String? selectedReason;
    final pointsController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final reasons = selectedType == 'reward' ? _rewardReasons : _penaltyReasons;
          return ContentDialog(
            title: const Text('상벌점 입력'),
            content: Container(
              width: 420,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('유형', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildPointTypeChip(setDialogState, selectedType, 'reward', '상점', Colors.blue, (v) {
                        selectedType = v;
                        selectedReason = null;
                        pointsController.text = '1';
                      }),
                      const SizedBox(width: 8),
                      _buildPointTypeChip(setDialogState, selectedType, 'penalty', '벌점', Colors.red, (v) {
                        selectedType = v;
                        selectedReason = null;
                        pointsController.text = '1';
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('사유', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ComboBox<String>(
                    value: selectedReason,
                    placeholder: const Text('사유를 선택하세요'),
                    isExpanded: true,
                    items: reasons.map((item) => ComboBoxItem<String>(
                      value: item['reason'] as String,
                      child: Text('${item['reason']}  (${item['points']}점)'),
                    )).toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      final matched = reasons.firstWhere((r) => r['reason'] == val, orElse: () => {'points': 1});
                      setDialogState(() {
                        selectedReason = val;
                        pointsController.text = '${matched['points']}';
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('점수', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: TextBox(
                          controller: pointsController,
                          placeholder: '점수',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('점'),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              Button(child: const Text('취소'), onPressed: () => Navigator.pop(dialogContext)),
              FilledButton(
                child: const Text('저장'),
                onPressed: () async {
                  final pts = int.tryParse(pointsController.text.trim()) ?? 0;
                  if (pts <= 0) return;
                  if (selectedReason == null) return;
                  Navigator.pop(dialogContext);
                  await _addPoint(student, selectedType, pts, selectedReason!);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPointTypeChip(StateSetter setDialogState, String current, String value, String label, Color color, Function(String) onSelect) {
    final isSelected = current == value;
    return GestureDetector(
      onTap: () => setDialogState(() => onSelect(value)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? color : null,
          ),
        ),
      ),
    );
  }

  Future<void> _addPoint(UserModel student, String type, int pts, String reason) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final userRef = firestore.collection('users').doc(student.uid);
      await userRef.collection('point_history').add({
        'userId': student.uid,
        'type': type,
        'points': pts,
        'reason': reason,
        'createdAt': Timestamp.now(),
      });
      final delta = type == 'reward' ? pts : -pts;
      await userRef.update({'points': FieldValue.increment(delta)});

      if (!mounted) return;
      await _loadStudents();
      // _allStudents 갱신 후 _selectedStudent도 새 객체로 업데이트
      if (mounted) {
        setState(() {
          _selectedStudent = _allStudents.firstWhere(
            (s) => s.uid == student.uid,
            orElse: () => student,
          );
        });
      }
      await _loadPointHistory(student.uid);
      if (!mounted) return;
      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: Text('${type == 'reward' ? '상점' : '벌점'} $pts점 입력 완료'),
          severity: InfoBarSeverity.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(title: Text('오류: $e'), severity: InfoBarSeverity.error),
      );
    }
  }


  bool _isProfileIncomplete(UserModel student) {
    return student.studentId.isEmpty ||
        student.phoneNumber.isEmpty ||
        student.roomNumber == '000' ||
        student.dormBuilding == null ||
        student.department == null ||
        student.seatNumber == null;
  }

  String? _fillingProfileUid;

  Future<void> _fillProfileFromExcel(UserModel student) async {
    setState(() => _fillingProfileUid = student.uid);
    try {
      final firestore = FirebaseFirestore.instance;
      final settingsDoc = await firestore.collection('settings').doc('home').get();
      final excelUrl = settingsDoc.data()?['studentInfoExcelUrl'] as String?;
      if (excelUrl == null || excelUrl.trim().isEmpty) {
        if (!mounted) return;
        await displayInfoBar(context, builder: (context, close) => const InfoBar(
          title: Text('업로드된 엑셀이 없습니다'), severity: InfoBarSeverity.warning));
        return;
      }
      final response = await http.get(Uri.parse(excelUrl));
      if (response.statusCode != 200) {
        throw Exception('엑셀 파일 다운로드 실패 (${response.statusCode})');
      }
      final excel = Excel.decodeBytes(response.bodyBytes);
      final sheet = excel.sheets.values.first;
      final rows = sheet.rows.map((row) => row.map((cell) => cell?.value?.toString() ?? '').toList()).toList();
      if (rows.isEmpty) throw Exception('엑셀 파일에 데이터가 없습니다.');
      final header = rows.first;
      final excelRows = rows.skip(1).map((row) => ExcelStudentRow.fromRow(header, row)).toList();

      final targetEmail = student.email.trim().toLowerCase();
      ExcelStudentRow? matched;
      for (final row in excelRows) {
        if (row.normalizedEmail == targetEmail) { matched = row; break; }
      }
      if (matched == null) {
        if (!mounted) return;
        await displayInfoBar(context, builder: (context, close) => const InfoBar(
          title: Text('엑셀에서 해당 학생을 찾을 수 없습니다'), severity: InfoBarSeverity.warning));
        return;
      }

      final updateMap = <String, dynamic>{};
      if (student.studentId.isEmpty && matched.studentId != null && matched.studentId!.isNotEmpty) {
        updateMap['studentId'] = matched.studentId;
      }
      if (student.phoneNumber.isEmpty && matched.phoneNumber != null && matched.phoneNumber!.isNotEmpty) {
        updateMap['phoneNumber'] = matched.phoneNumber;
      }
      if (student.dormBuilding == null && matched.dormBuilding != null && matched.dormBuilding!.isNotEmpty) {
        updateMap['dormBuilding'] = matched.dormBuilding;
      }
      if (student.roomNumber == '000' && matched.roomNumber != null && matched.roomNumber!.isNotEmpty) {
        updateMap['roomNumber'] = matched.roomNumber;
      }
      if (student.department == null && matched.department != null && matched.department!.isNotEmpty) {
        updateMap['department'] = matched.department;
      }
      if (student.seatNumber == null && matched.seatNumber != null && matched.seatNumber!.isNotEmpty) {
        updateMap['seatNumber'] = matched.seatNumber;
      }

      if (updateMap.isEmpty) {
        if (!mounted) return;
        await displayInfoBar(context, builder: (context, close) => const InfoBar(
          title: Text('채울 정보가 없습니다'), severity: InfoBarSeverity.info));
        return;
      }

      await _firestoreService.updateStudent(student.uid, updateMap);

      if (!mounted) return;
      await _loadStudents();
      if (mounted) {
        setState(() {
          _selectedStudent = _allStudents.firstWhere((s) => s.uid == student.uid, orElse: () => student);
        });
      }
      if (!mounted) return;
      await displayInfoBar(context, builder: (context, close) => const InfoBar(
        title: Text('프로필 정보를 업데이트했습니다'), severity: InfoBarSeverity.success));
    } catch (e) {
      if (!mounted) return;
      await displayInfoBar(context, builder: (context, close) =>
        InfoBar(title: Text('오류: $e'), severity: InfoBarSeverity.error));
    } finally {
      if (mounted) setState(() => _fillingProfileUid = null);
    }
  }

  // 퇴사 세부 유형. 통계칩/필터에서는 '퇴사' 하나로 묶어서 취급한다.
  static const _moveOutStatusOptions = ['만기퇴사', '자진퇴사', '강제퇴사', '영구퇴사'];

  // '퇴사'는 세분화 전 레거시 데이터에 남아있을 수 있어 퇴사 계열로 함께 인식한다.
  // 단, 선택 옵션(_residentStatusOptions)에는 포함하지 않는다.
  static bool _isMoveOutStatus(String status) =>
      status == '퇴사' || _moveOutStatusOptions.contains(status);

  static const _residentStatusOptions = [
    '재실중',
    '바롬인성교육관',
    ..._moveOutStatusOptions,
  ];

  static Color _residentStatusColor(String status) {
    switch (status) {
      case '재실중': return const Color(0xFF4CAF50);
      case '바롬인성교육관': return const Color(0xFFFF9800);
      default:
        return _isMoveOutStatus(status)
            ? const Color(0xFF9E9E9E)
            : const Color(0xFF4CAF50);
    }
  }

  void _showDeleteStudentDialog(UserModel student) {
    showDialog(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: const Text('회원탈퇴'),
        content: Text(
          '${student.name}(${student.studentId}) 학생을 탈퇴 처리하시겠습니까?\n'
          '시설신고, 월청소검사, 퇴사청소검사, 출석체크 이력은 삭제되지 않고 보존됩니다.',
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.red),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await _firestoreService.deleteStudent(student.uid);
                if (!mounted) return;
                setState(() {
                  if (_selectedStudent?.uid == student.uid) {
                    _selectedStudent = null;
                  }
                });
                await _loadStudents();
                if (!mounted) return;
                await displayInfoBar(
                  context,
                  builder: (c, close) => InfoBar(
                    title: const Text('회원탈퇴 완료'),
                    content: Text('${student.name} 학생이 탈퇴 처리되었습니다.'),
                    severity: InfoBarSeverity.success,
                    action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                await displayInfoBar(
                  context,
                  builder: (c, close) => InfoBar(
                    title: const Text('오류'),
                    content: Text('회원탈퇴 처리 중 오류: $e'),
                    severity: InfoBarSeverity.error,
                    action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
                  ),
                );
              }
            },
            child: const Text('탈퇴 처리'),
          ),
        ],
      ),
    );
  }

  void _showEditStudentDialog(UserModel student) {
    final nameController = TextEditingController(text: student.name);
    final nicknameController = TextEditingController(text: student.nickname ?? '');
    final studentIdController = TextEditingController(text: student.studentId);
    final phoneController = TextEditingController(text: student.phoneNumber);
    final roomController = TextEditingController(text: student.roomNumber);
    final seatNumberController = TextEditingController(text: student.seatNumber ?? '');
    final departmentController = TextEditingController(text: student.department ?? '');
    String? selectedDormBuilding = student.dormBuilding;
    String selectedResidentStatus = student.residentStatus;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => ContentDialog(
          title: Row(
            children: [
              const Expanded(child: Text('학생 정보 수정')),
              Button(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(
                    Colors.red.withValues(alpha: 0.1),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _showDeleteStudentDialog(student);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.blocked, size: 14, color: Colors.red),
                    const SizedBox(width: 6),
                    Text('회원탈퇴', style: TextStyle(color: Colors.red, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, 16, 12, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('이름', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextBox(controller: nameController, placeholder: '이름을 입력하세요'),
                  const SizedBox(height: 16),
                  const Text('별명', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextBox(controller: nicknameController, placeholder: '별명을 입력하세요 (선택)'),
                  const SizedBox(height: 16),
                  const Text('학번', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextBox(controller: studentIdController, placeholder: '학번을 입력하세요'),
                  const SizedBox(height: 16),
                  const Text('전화번호', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextBox(controller: phoneController, placeholder: '010-0000-0000'),
                  const SizedBox(height: 16),
                  const Text('기숙사 건물', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ComboBox<String>(
                    value: selectedDormBuilding,
                    isExpanded: true,
                    placeholder: const Text('건물 선택 (선택)'),
                    items: const [
                      ComboBoxItem(value: '샬롬하우스', child: Text('샬롬하우스')),
                      ComboBoxItem(value: '국제생활관', child: Text('국제생활관')),
                      ComboBoxItem(value: '바롬인성교육관', child: Text('바롬인성교육관')),
                      ComboBoxItem(value: '샬롬하우스(여름방학)', child: Text('샬롬하우스(여름방학)')),
                    ],
                    onChanged: (v) => setDialogState(() => selectedDormBuilding = v),
                  ),
                  const SizedBox(height: 16),
                  const Text('호실', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextBox(controller: roomController, placeholder: '호실을 입력하세요'),
                  const SizedBox(height: 16),
                  const Text('자리번호', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextBox(controller: seatNumberController, placeholder: '자리번호를 입력하세요 (선택)'),
                  const SizedBox(height: 16),
                  const Text('학과', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextBox(controller: departmentController, placeholder: '학과를 입력하세요 (선택)'),
                  const SizedBox(height: 16),
                  const Text('현재 상태', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _residentStatusOptions.map((status) {
                      final isSelected = selectedResidentStatus == status;
                      final color = _residentStatusColor(status);
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedResidentStatus = status),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? color.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? color : null,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            Button(
              child: const Text('취소'),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            FilledButton(
              child: const Text('수정'),
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  await showDialog(
                    context: context,
                    builder: (alertContext) => ContentDialog(
                      title: const Text('알림'),
                      content: const Text('이름을 입력해주세요.'),
                      actions: [
                        FilledButton(
                          child: const Text('확인'),
                          onPressed: () => Navigator.pop(alertContext),
                        ),
                      ],
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext);

                try {
                  await _firestoreService.updateStudent(student.uid, {
                    'name': nameController.text.trim(),
                    'nickname': nicknameController.text.trim().isEmpty
                        ? null
                        : nicknameController.text.trim(),
                    'studentId': studentIdController.text.trim(),
                    'phoneNumber': phoneController.text.trim(),
                    'roomNumber': roomController.text.trim(),
                    'seatNumber': seatNumberController.text.trim().isEmpty
                        ? null
                        : seatNumberController.text.trim(),
                    'department': departmentController.text.trim().isEmpty
                        ? null
                        : departmentController.text.trim(),
                    'dormBuilding': selectedDormBuilding,
                    'residentStatus': selectedResidentStatus,
                  });

                  if (!mounted) return;

                  await _loadStudents();
                  if (!mounted) return;
                  setState(() {
                    _selectedStudent = _allStudents.firstWhere(
                      (s) => s.uid == student.uid,
                      orElse: () => student,
                    );
                  });

                  await showDialog(
                    context: context,
                    builder: (successContext) => ContentDialog(
                      title: const Text('완료'),
                      content: const Text('학생 정보가 수정되었습니다.'),
                      actions: [
                        FilledButton(
                          child: const Text('확인'),
                          onPressed: () => Navigator.pop(successContext),
                        ),
                      ],
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;

                  await showDialog(
                    context: context,
                    builder: (errorContext) => ContentDialog(
                      title: const Text('오류'),
                      content: Text('학생 정보 수정 중 오류가 발생했습니다:\n$e'),
                      actions: [
                        FilledButton(
                          child: const Text('확인'),
                          onPressed: () => Navigator.pop(errorContext),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getBuilding(String roomNumber) {
    final roomNum = int.tryParse(roomNumber);
    if (roomNum == null || roomNumber == '000') return '';
    final lastTwo = roomNum % 100;
    if (lastTwo >= 1 && lastTwo <= 20) return 'A';
    if (lastTwo >= 21 && lastTwo <= 35) return 'B';
    return '';
  }

  int _getFloor(String roomNumber) {
    final roomNum = int.tryParse(roomNumber);
    if (roomNum == null || roomNumber == '000') return 0;
    return roomNum ~/ 100;
  }

  // 국제생활관 전용 동/층 판별
  // A동 1층: 101~132, A동 2층: 201~229
  // B동 2층: 233~260, B동 3층: 301~329
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

  Widget _buildStatChip(BuildContext context, String label, int count, {bool isSelected = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? FluentTheme.of(context).accentColor.withOpacity(0.15)
              : FluentTheme.of(context).cardColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? FluentTheme.of(context).accentColor
                : FluentTheme.of(context).resources.dividerStrokeColorDefault,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: isSelected ? FluentTheme.of(context).accentColor : Colors.grey[100],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count명',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isSelected ? FluentTheme.of(context).accentColor : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _buildingColor(String? dormBuilding) {
    if (dormBuilding == '샬롬하우스' || dormBuilding == '샬롬하우스(여름방학)') {
      return const Color(0xFF2196F3);
    }
    if (dormBuilding == '국제생활관') return const Color(0xFF4CAF50);
    if (dormBuilding == '바롬인성교육관') return const Color(0xFFFF9800);
    return const Color(0xFF9E9E9E);
  }

  Widget _buildStatsRow(BuildContext context, List<UserModel> all, List<_StudentListEntry> allEntries) {
    // 구역별 칩은 가입자만 대상으로 한다. 미가입자는 재실상태 개념 자체가
    // 없으므로(재실중으로 간주하지 않음) 별도의 '미가입' 칩으로만 카운트한다.
    int countBy(String? dorm, String? wing, int? floor) => all.where((s) {
          if (_isMoveOutStatus(s.residentStatus)) return false;
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

    final unassignedCount = all.where((s) =>
        !_isMoveOutStatus(s.residentStatus) &&
        (s.roomNumber.isEmpty || s.roomNumber == '000')).length;

    final unregisteredCount = allEntries.where((entry) => !entry.isRegistered).length;

    void setFilter(String? dorm, String? wing, int? floor) {
      setState(() {
        if (!_filterOnlyUnregistered &&
            _filterResidentStatus == null &&
            _filterDormBuilding == dorm &&
            _filterBuilding == wing &&
            _filterFloor == floor) {
          _filterDormBuilding = null;
          _filterBuilding = null;
          _filterFloor = null;
        } else {
          _filterOnlyUnregistered = false;
          _filterResidentStatus = null;
          _filterDormBuilding = dorm;
          _filterBuilding = wing;
          _filterFloor = floor;
        }
      });
    }

    bool isActive(String? dorm, String? wing, int? floor) =>
        !_filterOnlyUnregistered &&
        _filterResidentStatus == null &&
        _filterDormBuilding == dorm &&
        _filterBuilding == wing &&
        _filterFloor == floor;

    void setOnlyUnregisteredFilter() {
      setState(() {
        if (_filterOnlyUnregistered) {
          _filterOnlyUnregistered = false;
        } else {
          _filterOnlyUnregistered = true;
          _filterResidentStatus = null;
          _filterDormBuilding = null;
          _filterBuilding = null;
          _filterFloor = null;
        }
      });
    }

    // '퇴사' 칩은 4가지 세부 퇴사 유형을 모두 합산한다.
    int countByStatus(String status) => all
        .where((s) => status == '퇴사'
            ? _isMoveOutStatus(s.residentStatus)
            : s.residentStatus == status)
        .length;

    void setStatusFilter(String status) {
      setState(() {
        if (_filterResidentStatus == status) {
          _filterResidentStatus = null;
        } else {
          _filterOnlyUnregistered = false;
          _filterResidentStatus = status;
          _filterDormBuilding = null;
          _filterBuilding = null;
          _filterFloor = null;
        }
      });
    }

    bool isStatusActive(String status) => _filterResidentStatus == status;

    Widget scrollRow(List<Widget> chips) => LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: chips,
              ),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 전체 + 미배정 + 미가입
          scrollRow([
            _buildStatChip(context, '전체', all.length,
                isSelected: isActive(null, null, null),
                onTap: () => setFilter(null, null, null)),
            const SizedBox(width: 6),
            _buildStatChip(context, '호수 미배정', unassignedCount,
                isSelected: isActive('NONE', null, null),
                onTap: () => setFilter('NONE', null, null)),
            const SizedBox(width: 6),
            _buildStatChip(context, '바롬인성교육관', countByStatus('바롬인성교육관'),
                isSelected: isStatusActive('바롬인성교육관'),
                onTap: () => setStatusFilter('바롬인성교육관')),
            const SizedBox(width: 6),
            _buildStatChip(context, '퇴사', countByStatus('퇴사'),
                isSelected: isStatusActive('퇴사'),
                onTap: () => setStatusFilter('퇴사')),
            const SizedBox(width: 6),
            _buildStatChip(context, '미가입', unregisteredCount,
                isSelected: _filterOnlyUnregistered,
                onTap: setOnlyUnregisteredFilter),
          ]),
          const SizedBox(height: 8),
          // 샬롬하우스 A동
          scrollRow([
            _buildStatChip(context, '샬롬하우스 A동', countBy('샬롬하우스', 'A', null),
                isSelected: isActive('샬롬하우스', 'A', null),
                onTap: () => setFilter('샬롬하우스', 'A', null)),
            const SizedBox(width: 6),
            for (int f = 2; f <= 7; f++) ...[
              _buildStatChip(context, 'A동 $f층', countBy('샬롬하우스', 'A', f),
                  isSelected: isActive('샬롬하우스', 'A', f),
                  onTap: () => setFilter('샬롬하우스', 'A', f)),
              if (f < 7) const SizedBox(width: 6),
            ],
          ]),
          const SizedBox(height: 8),
          // 샬롬하우스 B동
          scrollRow([
            _buildStatChip(context, '샬롬하우스 B동', countBy('샬롬하우스', 'B', null),
                isSelected: isActive('샬롬하우스', 'B', null),
                onTap: () => setFilter('샬롬하우스', 'B', null)),
            const SizedBox(width: 6),
            for (int f = 2; f <= 7; f++) ...[
              _buildStatChip(context, 'B동 $f층', countBy('샬롬하우스', 'B', f),
                  isSelected: isActive('샬롬하우스', 'B', f),
                  onTap: () => setFilter('샬롬하우스', 'B', f)),
              if (f < 7) const SizedBox(width: 6),
            ],
          ]),
          const SizedBox(height: 8),
          // 국제생활관
          scrollRow([
            _buildStatChip(context, '국제생활관', countBy('국제생활관', null, null),
                isSelected: isActive('국제생활관', null, null),
                onTap: () => setFilter('국제생활관', null, null)),
            const SizedBox(width: 6),
            _buildStatChip(context, 'A동 1층', countBy('국제생활관', 'A', 1),
                isSelected: isActive('국제생활관', 'A', 1),
                onTap: () => setFilter('국제생활관', 'A', 1)),
            const SizedBox(width: 6),
            _buildStatChip(context, 'A동 2층', countBy('국제생활관', 'A', 2),
                isSelected: isActive('국제생활관', 'A', 2),
                onTap: () => setFilter('국제생활관', 'A', 2)),
            const SizedBox(width: 6),
            _buildStatChip(context, 'B동 2층', countBy('국제생활관', 'B', 2),
                isSelected: isActive('국제생활관', 'B', 2),
                onTap: () => setFilter('국제생활관', 'B', 2)),
            const SizedBox(width: 6),
            _buildStatChip(context, 'B동 3층', countBy('국제생활관', 'B', 3),
                isSelected: isActive('국제생활관', 'B', 3),
                onTap: () => setFilter('국제생활관', 'B', 3)),
          ]),
          const SizedBox(height: 8),
          // 바롬인성교육관
          scrollRow([
            _buildStatChip(context, '바롬인성교육관 10층', countBy('바롬인성교육관', null, null),
                isSelected: isActive('바롬인성교육관', null, null),
                onTap: () => setFilter('바롬인성교육관', null, null)),
          ]),
          const SizedBox(height: 8),
          // 샬롬하우스(여름방학)
          scrollRow([
            for (int f = 2; f <= 4; f++) ...[
              _buildStatChip(
                  context, '샬롬하우스 A동 $f층(여름방학)',
                  countBy('샬롬하우스(여름방학)', 'A', f),
                  isSelected: isActive('샬롬하우스(여름방학)', 'A', f),
                  onTap: () => setFilter('샬롬하우스(여름방학)', 'A', f)),
              if (f < 4) const SizedBox(width: 6),
            ],
          ]),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[120],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgreementCard(String title, Map<String, dynamic>? data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.teal,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (data == null)
            Text(
              '미동의',
              style: TextStyle(fontSize: 13, color: Colors.grey[100]),
            )
          else ...[
            _buildInfoRow('이름', data['userName'] ?? '-'),
            const Divider(),
            _buildInfoRow(
              '동의일시',
              data['agreedAt'] != null
                  ? _dateFormat.format((data['agreedAt'] as Timestamp).toDate())
                  : '-',
            ),
            const SizedBox(height: 12),
            const Text(
              '서명',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            if (data['signatureUrl'] != null)
              Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    data['signatureUrl'],
                    height: 120,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Text(
                        '이미지 로드 실패',
                        style: TextStyle(fontSize: 12, color: Colors.grey[100]),
                      ),
                    ),
                  ),
                ),
              )
            else
              Text(
                '서명 없음',
                style: TextStyle(fontSize: 13, color: Colors.grey[100]),
              ),
          ],
        ],
      ),
    );
  }

  // 앱 미가입 학생의 좌측 목록 카드. 주황 아바타 + '미가입' 배지로 구분한다.
  Widget _buildUnregisteredListItem(_StudentListEntry entry) {
    final row = entry.excelRow!;
    final isSelected = identical(_selectedUnregistered, row);
    final buildingColor = _buildingColor(entry.displayDormBuilding);
    final room = entry.displayRoomNumber;
    final dorm = entry.displayDormBuilding;
    // 비어있는 조각은 제외해 구분자가 잔존하지 않도록 한다.
    final subtitleParts = <String>[
      if (entry.displayStudentId.isNotEmpty) entry.displayStudentId,
      if (room.isNotEmpty) '$room호',
      if (dorm != null && dorm.isNotEmpty) dorm,
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: buildingColor, width: 4)),
      ),
      child: Card(
        backgroundColor: isSelected
            ? FluentTheme.of(context).accentColor.withValues(alpha: 0.1)
            : null,
        margin: EdgeInsets.zero,
        child: ListTile(
          onPressed: () {
            setState(() {
              _selectedUnregistered = row;
              _selectedStudent = null;
            });
          },
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(FluentIcons.contact, color: Colors.orange, size: 20),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  entry.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.6)),
                ),
                child: Text(
                  '미가입',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          // 조각이 모두 비면 '-'로 대체해 카드 높이를 일정하게 유지한다.
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              subtitleParts.isEmpty ? '-' : subtitleParts.join('  ·  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey[100]),
            ),
          ),
        ),
      ),
    );
  }

  // 앱 미가입 학생(엑셀 전용 데이터) 상세 패널.
  // uid가 없어 상벌점/서명 조회가 불가하므로 기본 정보만 표시한다.
  Widget _buildUnregisteredDetail(ExcelStudentRow student) {
    final room = student.roomNumber;
    final capacity = student.roomCapacity;
    return Container(
      padding: const EdgeInsets.all(32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Icon(FluentIcons.contact, color: Colors.orange, size: 40),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    student.name ?? '(이름 없음)',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '미가입',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const InfoBar(
              title: Text('앱 미가입 학생'),
              content: Text('엑셀 업로드 정보만 표시됩니다.'),
              severity: InfoBarSeverity.warning,
              isLong: true,
            ),
            const SizedBox(height: 20),
            // 기본 정보
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: FluentTheme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '기본 정보',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('이메일', student.email ?? '-'),
                  const Divider(),
                  _buildInfoRow('학번', student.studentId ?? '-'),
                  const Divider(),
                  _buildInfoRow('휴대폰', student.phoneNumber ?? '-'),
                  if (student.dormBuilding != null) ...[
                    const Divider(),
                    _buildInfoRow('기숙사 건물', student.dormBuilding!),
                  ],
                  const Divider(),
                  _buildInfoRow(
                    '호실',
                    room == null
                        ? '-'
                        : (capacity != null ? '$room호 ($capacity)' : '$room호'),
                  ),
                  if (student.seatNumber != null) ...[
                    const Divider(),
                    _buildInfoRow('자리번호', student.seatNumber!),
                  ],
                  if (student.department != null) ...[
                    const Divider(),
                    _buildInfoRow('학과', student.department!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 가입자 + 미가입자 전체(필터 미적용) - 통계뱃지 카운트는 항상 이 기준으로 계산한다.
    final allEntriesUnfiltered = <_StudentListEntry>[
      ..._allStudents.map((u) => _StudentListEntry.registered(u)),
      ..._unregisteredStudents.map((r) => _StudentListEntry.unregistered(r)),
    ];

    // 가입자 + 미가입자를 하나의 리스트로 합쳐 검색/필터/정렬을 적용한다.
    // 재실상태(_filterResidentStatus)는 가입자만 가지는 개념이므로,
    // 해당 필터가 활성화된 동안에는 미가입자를 목록에서 제외한다.
    final allEntries = <_StudentListEntry>[
      if (!_filterOnlyUnregistered) ..._allStudents.map((u) => _StudentListEntry.registered(u)),
      if (_filterResidentStatus == null)
        ..._unregisteredStudents.map((r) => _StudentListEntry.unregistered(r)),
    ];

    final students = allEntries
        .where((student) {
          final room = student.displayRoomNumber;
          final dorm = student.displayDormBuilding;
          if (_searchQuery.isNotEmpty) {
            final matchSearch = student.displayName.toLowerCase().contains(_searchQuery) ||
                student.displayStudentId.toLowerCase().contains(_searchQuery) ||
                room.toLowerCase().contains(_searchQuery);
            if (!matchSearch) return false;
          }
          if (_filterOnlyUnregistered) return true;
          if (_filterDormBuilding != null) {
            if (_filterDormBuilding == 'NONE') {
              if (room.isNotEmpty && room != '000') return false;
            } else {
              if (dorm != _filterDormBuilding) return false;
            }
          }
          if (_filterBuilding != null) {
            final isIntl = dorm == '국제생활관';
            final wing = isIntl ? _getIntlWing(room) : _getBuilding(room);
            if (wing != _filterBuilding) return false;
          }
          if (_filterFloor != null) {
            final isIntl = dorm == '국제생활관';
            final floor = isIntl ? _getIntlFloor(room) : _getFloor(room);
            if (floor != _filterFloor) return false;
          }
          // 재실상태는 가입자 전용 개념. 필터 활성화 시 미가입자는 이미
          // allEntries 단계에서 제외되므로 여기서는 가입자만 검사한다.
          if (_filterResidentStatus != null) {
            if (!student.isRegistered) return false;
            final rs = student.user!.residentStatus;
            final matches = _filterResidentStatus == '퇴사'
                ? _isMoveOutStatus(rs)
                : rs == _filterResidentStatus;
            if (!matches) return false;
          }
          return true;
        })
        .toList()
      ..sort((a, b) {
        // 가입자를 먼저, 그 다음 미가입자
        if (a.isRegistered != b.isRegistered) return a.isRegistered ? -1 : 1;
        const buildingOrder = ['샬롬하우스', '국제생활관', '바롬인성교육관', '샬롬하우스(여름방학)'];
        final aIdx = buildingOrder.indexOf(a.displayDormBuilding ?? '');
        final bIdx = buildingOrder.indexOf(b.displayDormBuilding ?? '');
        final aBuildingIdx = aIdx == -1 ? buildingOrder.length : aIdx;
        final bBuildingIdx = bIdx == -1 ? buildingOrder.length : bIdx;
        if (aBuildingIdx != bBuildingIdx) return aBuildingIdx.compareTo(bBuildingIdx);
        final aRoom = int.tryParse(a.displayRoomNumber) ?? 0;
        final bRoom = int.tryParse(b.displayRoomNumber) ?? 0;
        return aRoom.compareTo(bRoom);
      });

    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Row(
            children: [
              // 왼쪽: 학생 목록
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: FluentTheme.of(context).micaBackgroundColor,
                    border: Border(
                      right: BorderSide(
                        color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      // 헤더
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: FluentTheme.of(context).cardColor,
                          border: Border(
                            bottom: BorderSide(
                              color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Text(
                                  '학생 목록',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Tooltip(
                                  message: '새로고침',
                                  child: IconButton(
                                    icon: _isLoading
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: ProgressRing(strokeWidth: 2),
                                          )
                                        : const Icon(FluentIcons.refresh, size: 16),
                                    onPressed: _isLoading ? null : _loadStudents,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextBox(
                              placeholder: '이름, 학번, 호실로 검색',
                              prefix: Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: Icon(FluentIcons.search, size: 16),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value.toLowerCase();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      // 목록
                      Expanded(
                        child: _isLoading
                            ? ShimmerList(itemBuilder: () => const StudentCardShimmer(), count: 8)
                            : _errorMessage.isNotEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(FluentIcons.error, size: 48, color: Colors.red),
                                        const SizedBox(height: 12),
                                        const Text('데이터 로드 실패', style: TextStyle(fontSize: 16)),
                                        const SizedBox(height: 8),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          child: Text(_errorMessage, style: TextStyle(fontSize: 11, color: Colors.grey[100]), textAlign: TextAlign.center),
                                        ),
                                        const SizedBox(height: 12),
                                        FilledButton(onPressed: _loadStudents, child: const Text('다시 시도')),
                                      ],
                                    ),
                                  )
                                : students.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(FluentIcons.people, size: 64, color: Colors.grey[60]),
                                            const SizedBox(height: 16),
                                            Text(
                                              _searchQuery.isEmpty ? '등록된 학생이 없습니다' : '검색 결과가 없습니다',
                                              style: const TextStyle(fontSize: 16),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        padding: const EdgeInsets.all(16),
                                        itemCount: students.length,
                                        itemBuilder: (context, index) {
                                          final entry = students[index];
                                          if (!entry.isRegistered) {
                                            return _buildUnregisteredListItem(entry);
                                          }
                                          final student = entry.user!;
                                          final isSelected = _selectedStudent?.uid == student.uid;
                                          final buildingColor = _buildingColor(student.dormBuilding);
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border(
                                                left: BorderSide(color: buildingColor, width: 4),
                                              ),
                                            ),
                                            child: Card(
                                            backgroundColor: isSelected
                                                ? FluentTheme.of(context).accentColor.withOpacity(0.1)
                                                : null,
                                            margin: EdgeInsets.zero,
                                            child: ListTile(
                                              onPressed: () {
                                                setState(() {
                                                  _selectedStudent = student;
                                                  _selectedUnregistered = null;
                                                });
                                                _loadAgreements(student.uid);
                                                _loadPointHistory(student.uid);
                                              },
                                              leading: Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  color: buildingColor.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: student.profileImageUrl != null
                                                    ? ClipRRect(
                                                        borderRadius: BorderRadius.circular(20),
                                                        child: Image.network(
                                                          student.profileImageUrl!,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (context, error, stackTrace) {
                                                            return Icon(FluentIcons.contact, color: buildingColor, size: 20);
                                                          },
                                                        ),
                                                      )
                                                    : Icon(FluentIcons.contact, color: buildingColor, size: 20),
                                              ),
                                              title: Row(
                                                children: [
                                                  Text(
                                                    student.name,
                                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  if (student.nickname != null && student.nickname!.isNotEmpty) ...[
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      '(${student.nickname})',
                                                      style: TextStyle(fontSize: 12, color: Colors.grey[100]),
                                                    ),
                                                  ],
                                                  if (student.residentStatus.isNotEmpty &&
                                                      student.residentStatus != '재실중') ...[
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: _residentStatusColor(student.residentStatus).withValues(alpha: 0.12),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        student.residentStatus,
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: _residentStatusColor(student.residentStatus),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              subtitle: Padding(
                                                padding: const EdgeInsets.only(top: 3),
                                                child: Row(
                                                  children: [
                                                    Text(
                                                      student.studentId,
                                                      style: TextStyle(fontSize: 11, color: Colors.grey[100]),
                                                    ),
                                                    Text(
                                                      '  ·  ',
                                                      style: TextStyle(fontSize: 11, color: Colors.grey[80]),
                                                    ),
                                                    Text(
                                                      '${student.roomNumber}호',
                                                      style: TextStyle(fontSize: 11, color: Colors.grey[80], fontWeight: FontWeight.w500),
                                                    ),
                                                    if (student.seatNumber != null && student.seatNumber!.isNotEmpty) ...[
                                                      Text(
                                                        '  ·  ',
                                                        style: TextStyle(fontSize: 11, color: Colors.grey[80]),
                                                      ),
                                                      Text(
                                                        '자리 ${student.seatNumber}',
                                                        style: TextStyle(fontSize: 11, color: Colors.grey[80]),
                                                      ),
                                                    ],
                                                    Text(
                                                      '  ·  ',
                                                      style: TextStyle(fontSize: 11, color: Colors.grey[80]),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: buildingColor.withValues(alpha: 0.12),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        student.dormBuilding ?? student.building,
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: buildingColor,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            ));
                                        },
                                      ),
                      ),
                    ],
                  ),
                ),
              ),
              // 오른쪽: 통계 + 상세 정보
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 통계 (상단)
                    Container(
                      decoration: BoxDecoration(
                        color: FluentTheme.of(context).cardColor,
                        border: Border(
                          bottom: BorderSide(
                            color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
                          ),
                        ),
                      ),
                      child: _buildStatsRow(context, _allStudents, allEntriesUnfiltered),
                    ),
                    // 학생 상세 정보
                    Expanded(
                      child: _selectedUnregistered != null
                          ? _buildUnregisteredDetail(_selectedUnregistered!)
                          : _selectedStudent == null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(FluentIcons.people, size: 64, color: Colors.grey[60]),
                                  const SizedBox(height: 16),
                                  const Text('학생을 선택해주세요', style: TextStyle(fontSize: 18)),
                                ],
                              ),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(32, 32, 44, 32),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 헤더
                                    Row(
                                      children: [
                                        Container(
                                          width: 80,
                                          height: 80,
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(40),
                                          ),
                                          child: _selectedStudent!.profileImageUrl != null
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(40),
                                                  child: Image.network(
                                                    _selectedStudent!.profileImageUrl!,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) {
                                                      return Icon(FluentIcons.contact, color: Colors.green, size: 40);
                                                    },
                                                  ),
                                                )
                                              : Icon(FluentIcons.contact, color: Colors.green, size: 40),
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _selectedStudent!.name,
                                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                              ),
                                              const SizedBox(height: 4),
                                              if (_selectedStudent!.nickname != null)
                                                Text(
                                                  '별명: ${_selectedStudent!.nickname}',
                                                  style: TextStyle(fontSize: 14, color: Colors.grey[100]),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: (_totalPoints >= 0 ? Colors.blue : Colors.red).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: (_totalPoints >= 0 ? Colors.blue : Colors.red).withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: Text(
                                            '${_totalPoints > 0 ? '+' : ''}$_totalPoints점',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: _totalPoints >= 0 ? Colors.blue : Colors.red,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        FilledButton(
                                          onPressed: () => _showEditStudentDialog(_selectedStudent!),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(FluentIcons.edit, size: 16),
                                              SizedBox(width: 8),
                                              Text('수정'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 32),
                                    if (_isProfileIncomplete(_selectedStudent!)) ...[
                                      InfoBar(
                                        title: const Text('프로필 정보가 완성되지 않았습니다.'),
                                        content: const Text('엑셀에서 정보를 채울 수 있습니다.'),
                                        severity: InfoBarSeverity.warning,
                                        isLong: true,
                                        action: Builder(
                                          builder: (context) {
                                            final isFilling = _fillingProfileUid == _selectedStudent!.uid;
                                            return FilledButton(
                                              onPressed: isFilling ? null : () => _fillProfileFromExcel(_selectedStudent!),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (isFilling)
                                                    const SizedBox(width: 16, height: 16, child: ProgressRing(strokeWidth: 2))
                                                  else
                                                    const Icon(FluentIcons.excel_logo, size: 16),
                                                  const SizedBox(width: 8),
                                                  const Text('엑셀에서 정보 채우기'),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                    ],
                                    // 기본 정보
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: FluentTheme.of(context).cardColor,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            '기본 정보',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 16),
                                          _buildInfoRow('이메일', _selectedStudent!.email),
                                          const Divider(),
                                          _buildInfoRow('학번', _selectedStudent!.studentId),
                                          const Divider(),
                                          _buildInfoRow('전화번호', _selectedStudent!.phoneNumber),
                                          const Divider(),
                                          if (_selectedStudent!.dormBuilding != null) ...[
                                            const Divider(),
                                            _buildInfoRow('기숙사 건물', _selectedStudent!.dormBuilding!),
                                          ],
                                            const Divider(),
                                          Row(
                                            children: [
                                              Expanded(child: _buildInfoRow('호실', _selectedStudent!.roomCapacity.isNotEmpty ? '${_selectedStudent!.roomNumber}호 (${_selectedStudent!.roomCapacity})' : '${_selectedStudent!.roomNumber}호')),
                                              if (_selectedStudent!.seatNumber != null) ...[
                                                const SizedBox(width: 8),
                                                Expanded(child: _buildInfoRow('자리번호', _selectedStudent!.seatNumber!)),
                                              ],
                                            ],
                                          ),

                                          if (_selectedStudent!.department != null) ...[
                                            const Divider(),
                                            _buildInfoRow('학과', _selectedStudent!.department!),
                                          ],
                                          const Divider(),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                SizedBox(
                                                  width: 100,
                                                  child: Text(
                                                    '현재 상태',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey[120],
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: _residentStatusColor(_selectedStudent!.residentStatus).withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(
                                                      color: _residentStatusColor(_selectedStudent!.residentStatus).withValues(alpha: 0.5),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    _selectedStudent!.residentStatus,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                      color: _residentStatusColor(_selectedStudent!.residentStatus),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Divider(),
                                          _buildInfoRow('가입일', _dateFormat.format(_selectedStudent!.createdAt)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    // 상벌점 섹션
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: FluentTheme.of(context).cardColor,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: FluentTheme.of(context).resources.dividerStrokeColorDefault),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(width: 4, height: 16, decoration: BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.circular(2))),
                                              const SizedBox(width: 8),
                                              const Text('상벌점', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                              const Spacer(),
                                              FilledButton(
                                                onPressed: () => _showAddPointDialog(_selectedStudent!),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(FluentIcons.add, size: 14),
                                                    SizedBox(width: 6),
                                                    Text('입력'),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          if (_isLoadingPoints)
                                            Column(children: List.generate(3, (_) => Padding(padding: const EdgeInsets.only(bottom: 8), child: ShimmerBox(width: double.infinity, height: 56))))
                                          else if (_pointHistoryError.isNotEmpty)
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('이력 로드 실패', style: TextStyle(fontSize: 13, color: Colors.red)),
                                                const SizedBox(height: 4),
                                                Text(_pointHistoryError, style: TextStyle(fontSize: 11, color: Colors.grey[100])),
                                                const SizedBox(height: 8),
                                                Button(
                                                  onPressed: () => _loadPointHistory(_selectedStudent!.uid),
                                                  child: const Text('다시 시도'),
                                                ),
                                              ],
                                            )
                                          else if (_pointHistory.isEmpty)
                                            Text('이력이 없습니다', style: TextStyle(fontSize: 13, color: Colors.grey[100]))
                                          else
                                            ...(_pointHistory.map((item) {
                                              final type = (item['type'] ?? 'penalty') as String;
                                              final pts = (item['points'] as num?)?.toInt() ?? 0;
                                              final reason = (item['reason'] ?? '') as String;
                                              final isReward = type == 'reward';
                                              final color = isReward ? Colors.blue : Colors.red;
                                              DateTime? date;
                                              final raw = item['createdAt'];
                                              if (raw is Timestamp) {
                                                date = raw.toDate();
                                              } else if (raw is String) {
                                                try { date = DateTime.parse(raw); } catch (_) {}
                                              }
                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 8),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: color.withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(color: color.withValues(alpha: 0.4)),
                                                      ),
                                                      child: Text(
                                                        '${isReward ? '+' : '-'}$pts점',
                                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Text(reason, style: const TextStyle(fontSize: 13)),
                                                    ),
                                                    if (date != null)
                                                      Text(
                                                        DateFormat('yyyy.MM.dd').format(date),
                                                        style: TextStyle(fontSize: 11, color: Colors.grey[90]),
                                                      ),
                                                  ],
                                                ),
                                              );
                                            }).toList()),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    // 서명 섹션
                                    if (_isLoadingAgreements)
                                      Column(children: List.generate(2, (_) => Padding(padding: const EdgeInsets.only(bottom: 16), child: ShimmerBox(width: double.infinity, height: 80))))
                                    else ...[
                                      _buildAgreementCard('사행수칙 동의 서명', _regulationAgreement),
                                      const SizedBox(height: 16),
                                      _buildAgreementCard('퇴사확인 서명', _moveOutAgreement),
                                    ],
                                  ],
                                ),
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }
}
