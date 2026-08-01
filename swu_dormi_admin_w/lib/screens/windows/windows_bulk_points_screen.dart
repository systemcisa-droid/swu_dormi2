import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:intl/intl.dart';
import 'package:swu_dormi_admin/data/point_codes.dart';
import 'package:swu_dormi_admin/services/firestore_service.dart';
import 'package:swu_dormi_admin/screens/windows/windows_points_statistics_screen.dart';

/// 상벌 일괄 입력과 상벌 통계를 "입력 / 통계" 2탭으로 보여주는 화면.
/// 단위실 청소점검(WindowsInspectionTabScreen)과 동일한 구조로 사이드바 메뉴를 통합할 때 사용한다.
class WindowsPointsManagementTabScreen extends StatefulWidget {
  const WindowsPointsManagementTabScreen({super.key});

  @override
  State<WindowsPointsManagementTabScreen> createState() =>
      _WindowsPointsManagementTabScreenState();
}

class _WindowsPointsManagementTabScreenState
    extends State<WindowsPointsManagementTabScreen> {
  // 0: 입력, 1: 통계
  int _tabIndex = 0;

  final _accentColor = Colors.purple;

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Column(
        children: [
          // 탭 헤더
          Container(
            color: FluentTheme.of(context).cardColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _buildTab(0, '상벌 일괄 입력', FluentIcons.certificate),
                const SizedBox(width: 8),
                _buildTab(1, '상벌 통계', FluentIcons.b_i_dashboard),
              ],
            ),
          ),
          // 탭 콘텐츠
          Expanded(
            child: _tabIndex == 1
                ? const WindowsPointsStatisticsScreen()
                : const WindowsBulkPointsScreen(),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label, IconData icon) {
    final isSelected = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? _accentColor.withValues(alpha: 0.12)
              : Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? _accentColor : Colors.grey.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? _accentColor : Colors.grey),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? _accentColor : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 상벌점 입력 그리드의 한 행. 학생별로 상벌구분/코드/점수/비고를 개별 지정한다.
class _GridRow {
  final String uid;
  final String studentId;
  final String name;
  final String roomNumber;
  final DateTime chargeDate;
  final int seq;
  String? division; // '00'|'01'|'02'
  String? code; // 상벌점코드
  final _noteController = TextEditingController();

  _GridRow({
    required this.uid,
    required this.studentId,
    required this.name,
    required this.roomNumber,
    required this.chargeDate,
    required this.seq,
  });

  Map<String, dynamic>? get pointCode =>
      code != null ? kPointCodeByCode[code!] : null;

  void dispose() => _noteController.dispose();
}

class WindowsBulkPointsScreen extends StatefulWidget {
  const WindowsBulkPointsScreen({super.key});

  @override
  State<WindowsBulkPointsScreen> createState() => _WindowsBulkPointsScreenState();
}

class _WindowsBulkPointsScreenState extends State<WindowsBulkPointsScreen> {
  final _firestoreService = FirestoreService();

  bool _isApplyingPoints = false;
  bool _isSearchingStudent = false;
  bool _isExcelUploadMode = false;
  bool _isUploadingExcel = false;
  final _studentIdController = TextEditingController();

  // 학번 자동완성용 전체 학생 캐시 (최초 입력 시 1회 로드)
  List<QueryDocumentSnapshot>? _allStudentsCache;
  bool _isLoadingStudentCache = false;
  List<QueryDocumentSnapshot> _studentSuggestions = [];

  // 상벌점 입력 그리드 상태 (uid -> 행)
  final Map<String, _GridRow> _gridRows = {};
  int _seqCounter = 1;

  @override
  void dispose() {
    _studentIdController.dispose();
    for (final row in _gridRows.values) {
      row.dispose();
    }
    super.dispose();
  }

  Future<List<QueryDocumentSnapshot>> _loadStudentCache() async {
    if (_allStudentsCache != null) return _allStudentsCache!;
    if (mounted) setState(() => _isLoadingStudentCache = true);
    try {
      final snapshot =
          await _firestoreService.users.where('role', isEqualTo: 'student').get();
      _allStudentsCache = snapshot.docs;
      return _allStudentsCache!;
    } finally {
      if (mounted) setState(() => _isLoadingStudentCache = false);
    }
  }

  /// 입력값이 학번 또는 이름에 부분 포함되는 학생 목록을 반환한다 (최대 20건).
  Future<List<QueryDocumentSnapshot>> _searchStudents(String query) async {
    if (query.trim().isEmpty) return [];
    final students = await _loadStudentCache();
    final q = query.trim().toLowerCase();
    return students.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final studentId = (data['studentId'] ?? '').toString().toLowerCase();
      final name = (data['name'] ?? '').toString().toLowerCase();
      return studentId.contains(q) || name.contains(q);
    }).take(20).toList();
  }

  void _addStudentRow(QueryDocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final studentId = (data['studentId'] ?? '').toString();
    if (_gridRows.values.any((r) => r.studentId == studentId)) {
      displayInfoBar(context,
          builder: (ctx, close) => InfoBar(
                title: const Text('알림'),
                content: const Text('이미 추가된 학번입니다.'),
                severity: InfoBarSeverity.warning,
                action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
              ));
      return;
    }
    setState(() {
      _gridRows[doc.id] = _GridRow(
        uid: doc.id,
        studentId: studentId,
        name: (data['name'] ?? '').toString(),
        roomNumber: (data['roomNumber'] ?? '').toString(),
        chargeDate: DateTime.now(),
        seq: _seqCounter++,
      );
      _studentIdController.clear();
    });
  }

  /// 학번으로 학생을 조회해 그리드에 행으로 추가한다. 이미 추가된 학생이면 안내만 하고 중복 추가하지 않는다.
  Future<void> _addStudentByStudentId() async {
    final studentId = _studentIdController.text.trim();
    if (studentId.isEmpty) return;

    final alreadyAdded = _gridRows.values.any((r) => r.studentId == studentId);
    if (alreadyAdded) {
      displayInfoBar(context,
          builder: (ctx, close) => InfoBar(
                title: const Text('알림'),
                content: const Text('이미 추가된 학번입니다.'),
                severity: InfoBarSeverity.warning,
                action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
              ));
      return;
    }

    setState(() => _isSearchingStudent = true);
    try {
      final snapshot = await _firestoreService.users
          .where('role', isEqualTo: 'student')
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();
      if (!mounted) return;
      if (snapshot.docs.isEmpty) {
        setState(() => _isSearchingStudent = false);
        displayInfoBar(context,
            builder: (ctx, close) => InfoBar(
                  title: const Text('알림'),
                  content: Text('학번 $studentId 학생을 찾을 수 없습니다.'),
                  severity: InfoBarSeverity.warning,
                  action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
                ));
        return;
      }

      final doc = snapshot.docs.first;
      final data = (doc.data() as Map<String, dynamic>?) ?? {};
      setState(() {
        _gridRows[doc.id] = _GridRow(
          uid: doc.id,
          studentId: (data['studentId'] ?? '').toString(),
          name: (data['name'] ?? '').toString(),
          roomNumber: (data['roomNumber'] ?? '').toString(),
          chargeDate: DateTime.now(),
          seq: _seqCounter++,
        );
        _isSearchingStudent = false;
        _studentIdController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearchingStudent = false);
      displayInfoBar(context,
          builder: (ctx, close) => InfoBar(
                title: const Text('오류'),
                content: Text('학생 조회 실패: $e'),
                severity: InfoBarSeverity.error,
                action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
              ));
    }
  }

  void _removeRow(String uid) {
    setState(() => _gridRows.remove(uid)?.dispose());
  }

  /// 엑셀 파일을 업로드해 그리드에 행을 일괄 추가한다.
  /// 헤더: 학번, 성명(선택, 검증용), 부과일자(선택), 상벌구분, 상벌점내용, 상벌점(선택), 비고(선택)
  /// "상벌점내용" 셀은 "이름 [코드]" 또는 코드 단독 표기를 모두 허용한다.
  Future<void> _uploadExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (result == null || result.files.single.path == null) return;

    setState(() => _isUploadingExcel = true);
    try {
      final bytes = await File(result.files.single.path!).readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null || sheet.maxRows < 2) {
        throw Exception('엑셀에 데이터가 없습니다.');
      }

      final header = sheet.row(0)
          .map((c) => (c?.value?.toString() ?? '').trim())
          .toList();
      int findCol(List<String> keywords) {
        for (int i = 0; i < header.length; i++) {
          if (keywords.any((k) => header[i].contains(k))) return i;
        }
        return -1;
      }

      final studentIdCol = findCol(['학번']);
      final noteCol = findCol(['비고']);
      final contentCol = findCol(['상벌점내용', '내용']);
      final divisionCol = findCol(['상벌구분', '구분']);
      if (studentIdCol == -1) {
        throw Exception('엑셀에 "학번" 컬럼이 없습니다.');
      }
      if (contentCol == -1) {
        throw Exception('엑셀에 "상벌점내용" 컬럼이 없습니다.');
      }

      final notFoundIds = <String>[];
      final unmatchedContents = <String>[];
      int addedCount = 0;
      int skippedCount = 0;

      for (int r = 1; r < sheet.maxRows; r++) {
        final row = sheet.row(r);
        String cellText(int col) {
          if (col < 0 || col >= row.length) return '';
          return (row[col]?.value?.toString() ?? '').trim();
        }

        final studentId = cellText(studentIdCol);
        if (studentId.isEmpty) continue;

        final contentText = cellText(contentCol);
        final divisionText = cellText(divisionCol);
        final note = cellText(noteCol);

        // "이름 [코드]" 또는 "이름 (코드)"에서 코드 추출, 없으면 코드 단독 표기로 간주
        final codeMatch = RegExp(r'[\[(]([^\])]+)[\])]').firstMatch(contentText);
        String? code = codeMatch?.group(1) ?? (kPointCodeByCode.containsKey(contentText) ? contentText : null);
        if (code == null && divisionText.isNotEmpty) {
          // 상벌구분 + 내용 텍스트로 이름 매칭 시도
          final divisionCode = RegExp(r'\d{2}').firstMatch(divisionText)?.group(0);
          final match = kPointCodes.firstWhere(
            (c) => (divisionCode == null || c['division'] == divisionCode) &&
                contentText.contains(c['name'] as String),
            orElse: () => const {},
          );
          if (match.isNotEmpty) code = match['code'] as String;
        }

        if (code == null || !kPointCodeByCode.containsKey(code)) {
          unmatchedContents.add('${r + 1}행: $contentText');
          skippedCount++;
          continue;
        }

        if (_gridRows.values.any((r) => r.studentId == studentId)) {
          skippedCount++;
          continue;
        }

        final snapshot = await _firestoreService.users
            .where('role', isEqualTo: 'student')
            .where('studentId', isEqualTo: studentId)
            .limit(1)
            .get();
        if (snapshot.docs.isEmpty) {
          notFoundIds.add(studentId);
          skippedCount++;
          continue;
        }

        final doc = snapshot.docs.first;
        final data = (doc.data() as Map<String, dynamic>?) ?? {};
        final matchedCode = kPointCodeByCode[code]!;
        final newRow = _GridRow(
          uid: doc.id,
          studentId: (data['studentId'] ?? '').toString(),
          name: (data['name'] ?? '').toString(),
          roomNumber: (data['roomNumber'] ?? '').toString(),
          chargeDate: DateTime.now(),
          seq: _seqCounter++,
        );
        newRow.division = matchedCode['division'] as String;
        newRow.code = code;
        if (note.isNotEmpty) newRow._noteController.text = note;

        if (!mounted) return;
        setState(() => _gridRows[doc.id] = newRow);
        addedCount++;
      }

      if (!mounted) return;
      setState(() => _isUploadingExcel = false);

      final messages = <String>['$addedCount명 추가됨'];
      if (skippedCount > 0) messages.add('$skippedCount건 제외됨');
      if (notFoundIds.isNotEmpty) {
        messages.add('학생 미발견: ${notFoundIds.join(', ')}');
      }
      if (unmatchedContents.isNotEmpty) {
        messages.add('코드 미매칭: ${unmatchedContents.join(', ')}');
      }

      displayInfoBar(context,
          builder: (ctx, close) => InfoBar(
                title: const Text('엑셀 업로드 완료'),
                content: Text(messages.join(' / ')),
                severity: notFoundIds.isEmpty && unmatchedContents.isEmpty
                    ? InfoBarSeverity.success
                    : InfoBarSeverity.warning,
                action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
              ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingExcel = false);
      displayInfoBar(context,
          builder: (ctx, close) => InfoBar(
                title: const Text('오류'),
                content: Text('엑셀 업로드 실패: $e'),
                severity: InfoBarSeverity.error,
                action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
              ));
    }
  }

  void _showPointCodeSelector(_GridRow row) {
    String searchQuery = '';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final filtered = kPointCodes.where((c) {
            if (row.division != null && c['division'] != row.division) return false;
            if (searchQuery.isEmpty) return true;
            final q = searchQuery.toLowerCase();
            return (c['name'] as String).toLowerCase().contains(q) ||
                (c['detail'] as String).toLowerCase().contains(q);
          }).toList();

          // 코드구분별 그룹핑
          final grouped = <String, List<Map<String, dynamic>>>{};
          for (final c in filtered) {
            final cat = c['division'] as String;
            grouped.putIfAbsent(cat, () => []).add(c);
          }

          return ContentDialog(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
            title: Text(row.division != null
                ? '상벌점 기준표 - ${kDivisionLabels[row.division!] ?? row.division!}'
                : '상벌점 기준표'),
            content: Column(
              children: [
                TextBox(
                  placeholder: '항목명, 세부내용 검색',
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(FluentIcons.search, size: 16),
                  ),
                  onChanged: (v) => setDialogState(() => searchQuery = v),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: grouped.entries.map((entry) {
                      final catLabel = kDivisionLabels[entry.key] ?? entry.key;
                      final isRewardCat = entry.key == '00';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            color: (isRewardCat ? Colors.green : Colors.red)
                                .withValues(alpha: 0.1),
                            child: Text(
                              catLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isRewardCat ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                          ...entry.value.map((code) {
                            final pts = code['points'] as int;
                            final isReward = code['type'] == 'reward';
                            return Button(
                              style: ButtonStyle(
                                padding: WidgetStateProperty.all(
                                  const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  row.division = code['division'] as String;
                                  row.code = code['code'] as String;
                                });
                                Navigator.of(ctx).pop();
                              },
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.grey
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                code['code'] as String,
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    color: Colors.grey
                                                        .withValues(
                                                            alpha: 0.9)),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                code['name'] as String,
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if ((code['detail'] as String)
                                            .isNotEmpty)
                                          Text(
                                            code['detail'] as String,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey
                                                    .withValues(alpha: 0.7)),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: (isReward
                                              ? Colors.green
                                              : Colors.red)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${isReward ? '+' : '-'}$pts점',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isReward
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            actions: [
              Button(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('취소'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _validateAndShowConfirmDialog() {
    if (_gridRows.isEmpty) {
      displayInfoBar(context,
          builder: (ctx, close) => InfoBar(
                title: const Text('알림'),
                content: const Text('학생을 선택하세요.'),
                severity: InfoBarSeverity.warning,
                action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
              ));
      return;
    }
    final rows = _gridRows.values.toList()..sort((a, b) => a.seq.compareTo(b.seq));
    final incomplete = rows.where((r) => r.pointCode == null).toList();
    if (incomplete.isNotEmpty) {
      displayInfoBar(context,
          builder: (ctx, close) => InfoBar(
                title: const Text('알림'),
                content: Text('${incomplete.map((r) => r.name).join(', ')} 학생의 상벌점내용을 선택하세요.'),
                severity: InfoBarSeverity.warning,
                action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
              ));
      return;
    }

    bool isProcessing = false;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return ContentDialog(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
            title: Text('상벌점 일괄 적용 확인 (${rows.length}명)'),
            content: SizedBox(
              width: 520,
              height: 440,
              child: ListView.builder(
                itemCount: rows.length,
                itemBuilder: (ctx, i) {
                  final row = rows[i];
                  final code = row.pointCode!;
                  final isReward = code['type'] == 'reward';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: FluentTheme.of(ctx).resources.dividerStrokeColorDefault),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${row.name} (${row.studentId}) - ${code['name']}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(
                          '${isReward ? '+' : '-'}${code['points']}점',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isReward ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            actions: [
              Button(
                onPressed: isProcessing ? null : () => Navigator.pop(dialogContext),
                child: const Text('취소'),
              ),
              Button(
                onPressed: isProcessing ? null : () => _exportAppliedEntriesToExcel(rows),
                child: const Text('엑셀생성'),
              ),
              FilledButton(
                onPressed: isProcessing
                    ? null
                    : () async {
                        setDialogState(() => isProcessing = true);
                        Navigator.pop(dialogContext);
                        await _applyPoints(rows);
                      },
                child: const Text('일괄 적용'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _applyPoints(List<_GridRow> rows) async {
    setState(() => _isApplyingPoints = true);
    final firestore = FirebaseFirestore.instance;
    int successCount = 0;

    try {
      for (final row in rows) {
        final code = row.pointCode!;
        final type = code['type'] as String;
        final points = code['points'] as int;
        final reason = '${code['name']} (${code['code']})'
            '${row._noteController.text.trim().isNotEmpty ? ' - ${row._noteController.text.trim()}' : ''}';
        final userRef = firestore.collection('users').doc(row.uid);
        await userRef.collection('point_history').add({
          'userId': row.uid,
          'type': type,
          'points': points,
          'reason': reason,
          'createdAt': Timestamp.now(),
        });
        await userRef.update({'points': FieldValue.increment(type == 'reward' ? points : -points)});
        successCount++;
      }

      if (!mounted) return;
      setState(() {
        _isApplyingPoints = false;
        for (final row in _gridRows.values) {
          row.dispose();
        }
        _gridRows.clear();
      });

      displayInfoBar(context,
          builder: (ctx, close) => InfoBar(
                title: const Text('완료'),
                content: Text('$successCount명에게 상벌점이 적용되었습니다.'),
                severity: InfoBarSeverity.success,
                action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
              ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isApplyingPoints = false);
      displayInfoBar(context,
          builder: (ctx, close) => InfoBar(
                title: const Text('오류'),
                content: Text('처리 중 오류: $e'),
                severity: InfoBarSeverity.error,
                action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
              ));
    }
  }

  // 엑셀 헤더: 학번, 호실, 성명, 부과일자, 순번, 상벌구분, 상벌점내용, 상벌점, 비고
  Future<void> _exportAppliedEntriesToExcel(List<_GridRow> rows) async {
    if (rows.isEmpty) return;
    try {
      final excel = Excel.createExcel();
      final sheet = excel['상벌점'];

      final headers = ['학번', '호실', '성명', '부과일자', '순번', '상벌구분', '상벌점내용', '상벌점', '비고'];
      for (int c = 0; c < headers.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).value =
            TextCellValue(headers[c]);
      }

      for (int r = 0; r < rows.length; r++) {
        final row = rows[r];
        final code = row.pointCode!;
        final rowIdx = r + 1;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx)).value =
            TextCellValue(row.studentId);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIdx)).value =
            TextCellValue(row.roomNumber);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIdx)).value =
            TextCellValue(row.name);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIdx)).value =
            TextCellValue(DateFormat('yyyyMMdd').format(row.chargeDate));
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIdx)).value =
            IntCellValue(row.seq);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIdx)).value =
            TextCellValue(row.division ?? '');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIdx)).value =
            TextCellValue('${code['name']} [${code['code']}]');
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIdx)).value =
            IntCellValue(code['points'] as int);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIdx)).value =
            TextCellValue(row._noteController.text.trim());
      }

      if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');
      final bytes = excel.encode();
      if (bytes == null) throw Exception('엑셀 파일 생성 실패');

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: '상벌점 적용 내역 저장',
        fileName: '상벌점_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (savePath == null) return;
      await File(savePath).writeAsBytes(bytes);

      if (!mounted) return;
      displayInfoBar(context,
          builder: (ctx, close) => InfoBar(
                title: const Text('저장 완료'),
                content: Text(savePath),
                severity: InfoBarSeverity.success,
                action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
              ));
    } catch (e) {
      if (!mounted) return;
      displayInfoBar(context,
          builder: (ctx, close) => InfoBar(
                title: const Text('오류'),
                content: Text('엑셀 저장 실패: $e'),
                severity: InfoBarSeverity.error,
                action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
              ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: const PageHeader(
        title: Text('상벌 일괄 입력'),
      ),
      content: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('상벌점 입력',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('엑셀 업로드', style: TextStyle(fontSize: 12, color: Colors.grey[110])),
                    const SizedBox(width: 6),
                    ToggleSwitch(
                      checked: _isExcelUploadMode,
                      onChanged: (v) => setState(() => _isExcelUploadMode = v),
                    ),
                    const SizedBox(width: 12),
                    Text('${_gridRows.length}명',
                        style: TextStyle(fontSize: 12, color: Colors.grey[100])),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isExcelUploadMode)
                  Row(
                    children: [
                      Button(
                        onPressed: _isUploadingExcel ? null : _uploadExcel,
                        child: _isUploadingExcel
                            ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                      width: 14, height: 14, child: ProgressRing(strokeWidth: 2)),
                                  SizedBox(width: 8),
                                  Text('업로드 중...'),
                                ],
                              )
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(FluentIcons.excel_document, size: 14),
                                  SizedBox(width: 6),
                                  Text('엑셀 파일 선택'),
                                ],
                              ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '헤더: 학번, 상벌구분, 상벌점내용, 비고(선택)',
                        style: TextStyle(fontSize: 11, color: Colors.grey[100]),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      SizedBox(
                        width: 320,
                        child: AutoSuggestBox<QueryDocumentSnapshot>(
                          controller: _studentIdController,
                          placeholder: '학번 또는 이름 일부 입력',
                          leadingIcon: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _isLoadingStudentCache
                                ? const SizedBox(
                                    width: 12, height: 12, child: ProgressRing(strokeWidth: 2))
                                : const Icon(FluentIcons.contact, size: 16),
                          ),
                          items: _studentSuggestions.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final studentId = (data['studentId'] ?? '').toString();
                            final name = (data['name'] ?? '').toString();
                            final room = (data['roomNumber'] ?? '').toString();
                            return AutoSuggestBoxItem<QueryDocumentSnapshot>(
                              value: doc,
                              label: '$studentId $name',
                              child: Text(
                                room.isNotEmpty ? '$studentId  $name ($room호)' : '$studentId  $name',
                              ),
                              onSelected: () => _addStudentRow(doc),
                            );
                          }).toList(),
                          onChanged: (text, reason) async {
                            if (reason != TextChangedReason.userInput) return;
                            final results = await _searchStudents(text);
                            if (!mounted) return;
                            setState(() => _studentSuggestions = results);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Button(
                        onPressed: _isSearchingStudent ? null : _addStudentByStudentId,
                        child: _isSearchingStudent
                            ? const SizedBox(
                                width: 14, height: 14, child: ProgressRing(strokeWidth: 2))
                            : const Text('신규'),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                Expanded(
                  child: _gridRows.isEmpty
                      ? Center(
                          child: Text('학번을 입력해 학생을 추가하세요',
                              style: TextStyle(fontSize: 14, color: Colors.grey[120])))
                      : _buildPointGrid(),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Button(
                      onPressed: _isApplyingPoints
                          ? null
                          : () => setState(() {
                                for (final row in _gridRows.values) {
                                  row.dispose();
                                }
                                _gridRows.clear();
                              }),
                      child: const Text('초기화'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _isApplyingPoints ? null : _validateAndShowConfirmDialog,
                      child: _isApplyingPoints
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: ProgressRing(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text('처리 중...'),
                              ],
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(FluentIcons.certificate, size: 16),
                                SizedBox(width: 8),
                                Text('상벌점 일괄 적용'),
                              ],
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPointGrid() {
    final rows = _gridRows.values.toList()..sort((a, b) => a.seq.compareTo(b.seq));
    final headerStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[140]);
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[60]),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: Colors.grey.withValues(alpha: 0.1),
            child: Row(
              children: [
                SizedBox(width: 90, child: Text('학번', style: headerStyle)),
                SizedBox(width: 50, child: Text('호실', style: headerStyle)),
                SizedBox(width: 70, child: Text('성명', style: headerStyle)),
                SizedBox(width: 90, child: Text('부과일자', style: headerStyle)),
                SizedBox(width: 40, child: Text('순번', style: headerStyle)),
                SizedBox(width: 90, child: Text('상벌구분', style: headerStyle)),
                const Expanded(flex: 3, child: SizedBox()),
                SizedBox(width: 60, child: Text('상벌점', style: headerStyle)),
                const Expanded(flex: 2, child: SizedBox()),
                const SizedBox(width: 32),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (ctx, i) {
                final row = rows[i];
                final code = row.pointCode;
                final isReward = code?['type'] == 'reward';
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(row.studentId, style: const TextStyle(fontSize: 13)),
                      ),
                      SizedBox(
                        width: 50,
                        child: Text('${row.roomNumber}호', style: const TextStyle(fontSize: 13)),
                      ),
                      SizedBox(
                        width: 70,
                        child: Text(row.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      SizedBox(
                        width: 90,
                        child: Text(dateFormat.format(row.chargeDate), style: const TextStyle(fontSize: 13)),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text('${row.seq}', style: const TextStyle(fontSize: 13)),
                      ),
                      SizedBox(
                        width: 90,
                        child: ComboBox<String>(
                          value: row.division,
                          placeholder: const Text('선택', style: TextStyle(fontSize: 12)),
                          isExpanded: true,
                          items: kDivisionLabels.entries
                              .map((e) => ComboBoxItem(
                                    value: e.key,
                                    child: Text('${e.value} [${e.key}]',
                                        style: const TextStyle(fontSize: 12)),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() {
                            if (v == row.division) return;
                            row.division = v;
                            // 구분이 바뀌면 기존 코드가 새 구분과 맞지 않을 수 있으므로 초기화한다.
                            if (row.code != null &&
                                kPointCodeByCode[row.code!]?['division'] != v) {
                              row.code = null;
                            }
                          }),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Button(
                          style: ButtonStyle(
                            padding: WidgetStateProperty.all(
                                const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                          ),
                          onPressed: () => _showPointCodeSelector(row),
                          child: Text(
                            code != null ? '${code['name']} [${code['code']}]' : '선택',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: code != null
                            ? Text(
                                '${isReward ? '+' : '-'}${code['points']}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isReward ? Colors.green : Colors.red,
                                ),
                              )
                            : const SizedBox(),
                      ),
                      Expanded(
                        flex: 2,
                        child: TextBox(
                          controller: row._noteController,
                          placeholder: '비고',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        child: IconButton(
                          icon: const Icon(FluentIcons.delete, size: 14),
                          onPressed: () => _removeRow(row.uid),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
