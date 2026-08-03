import 'package:fluent_ui/fluent_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:swu_dormi_admin/screens/windows/windows_cleaning_inspection_screen.dart' show kFloorOptions;
import 'dart:io';

// ──────────────────────────────────────────────────────────────
// 학생(호실)별 출석체크 이력 화면
// ──────────────────────────────────────────────────────────────
class WindowsAttendanceHistoryScreen extends StatefulWidget {
  const WindowsAttendanceHistoryScreen({super.key});

  @override
  State<WindowsAttendanceHistoryScreen> createState() =>
      _WindowsAttendanceHistoryScreenState();
}

class _WindowsAttendanceHistoryScreenState
    extends State<WindowsAttendanceHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, Map<String, dynamic>> _eventMap = {}; // eventId -> event data
  // 'dormBuilding|roomNumber|userId' -> 해당 학생의 출석 기록 목록 (checkedInAt 역순)
  Map<String, List<QueryDocumentSnapshot>> _grouped = {};
  // 'dormBuilding|roomNumber|userId' -> 학생 기본 정보 (기록이 없어도 항상 존재)
  Map<String, Map<String, dynamic>> _studentInfo = {};
  List<String> _sortedKeys = [];

  bool _isLoading = true;
  String _errorMessage = '';

  String _searchQuery = '';
  String? _selectedKey;
  String? _floorFilter;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final recordsSnap = await _firestore.collection('attendance_records').get();
      final eventsSnap = await _firestore.collection('attendance_events').get();
      final usersSnap = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();

      final eventMap = <String, Map<String, dynamic>>{};
      for (final doc in eventsSnap.docs) {
        eventMap[doc.id] = doc.data();
      }

      // 전체 학생 기준으로 key를 먼저 만든다 (기록 유무와 무관하게 항상 표시)
      final studentInfo = <String, Map<String, dynamic>>{};
      for (final doc in usersSnap.docs) {
        final data = doc.data();
        final room = (data['roomNumber'] as String?) ?? '';
        if (room.isEmpty || room == '000') continue;
        final dorm = (data['dormBuilding'] as String?) ?? '';
        final key = '$dorm|$room|${doc.id}';
        studentInfo[key] = data;
      }

      final grouped = <String, List<QueryDocumentSnapshot>>{};
      for (final rec in recordsSnap.docs) {
        final data = rec.data();
        final uid = (data['userId'] as String?) ?? '';
        if (uid.isEmpty) continue;
        final room = (data['roomNumber'] as String?) ?? '';
        final dorm = ((data['dormBuilding'] as String?)?.isNotEmpty == true
            ? data['dormBuilding'] as String
            : (data['building'] as String? ?? ''));
        final key = '$dorm|$room|$uid';
        grouped.putIfAbsent(key, () => []).add(rec);
        // 기록에만 있고 users에는 없는 학생(퇴사 등)도 표시되도록 보완
        studentInfo.putIfAbsent(key, () => {
              'name': data['userName'] ?? '',
              'studentId': data['studentId'] ?? '',
              'roomNumber': room,
              'dormBuilding': dorm,
            });
      }

      for (final list in grouped.values) {
        list.sort((a, b) {
          final aTs = (a.data() as Map<String, dynamic>)['checkedInAt'] as Timestamp?;
          final bTs = (b.data() as Map<String, dynamic>)['checkedInAt'] as Timestamp?;
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return bTs.compareTo(aTs);
        });
      }

      int buildingOrder(String key) {
        if (key.startsWith('샬롬하우스')) return 0;
        if (key.startsWith('국제생활관')) return 1;
        if (key.startsWith('바롬인성교육관')) return 2;
        return 3;
      }

      final sortedKeys = studentInfo.keys.toList()
        ..sort((a, b) {
          final bo = buildingOrder(a).compareTo(buildingOrder(b));
          if (bo != 0) return bo;
          final roomA = a.split('|').length > 1 ? a.split('|')[1] : '';
          final roomB = b.split('|').length > 1 ? b.split('|')[1] : '';
          final numA = int.tryParse(roomA) ?? 0;
          final numB = int.tryParse(roomB) ?? 0;
          if (numA != numB) return numA.compareTo(numB);
          return a.compareTo(b);
        });

      if (!mounted) return;
      setState(() {
        _eventMap = eventMap;
        _grouped = grouped;
        _studentInfo = studentInfo;
        _sortedKeys = sortedKeys;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  // 현재 로드된 출석체크 이력 전체를 엑셀로 저장한다.
  Future<void> _exportHistoryToExcel() async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ContentDialog(
        title: Text('엑셀 생성 중'),
        content: SizedBox(height: 80, child: Center(child: ProgressRing())),
      ),
    );

    try {
      final excel = Excel.createExcel();
      final sheet = excel['출석체크이력'];

      final headers = ['건물', '호실', '이름', '학번', '이벤트', '상태', '체크시각', '처리자'];
      for (int c = 0; c < headers.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).value =
            TextCellValue(headers[c]);
      }

      int rowIdx = 1;
      for (final key in _sortedKeys) {
        final info = _studentInfo[key] ?? {};
        final dorm = _keyDorm(key);
        final room = _keyRoom(key);
        final name = (info['name'] as String?) ?? '';
        final studentId = (info['studentId'] as String?) ?? '';
        final records = _grouped[key] ?? [];

        for (final rec in records) {
          final data = rec.data() as Map<String, dynamic>;
          final eventId = data['eventId'] as String?;
          final event = eventId != null ? _eventMap[eventId] : null;
          final eventTitle =
              (event?['title'] as String?) ?? (data['eventTitle'] as String?) ?? '출석체크';
          final checkedInAt = (data['checkedInAt'] as Timestamp?)?.toDate();
          final isStatusRecord = data['recordType'] == 'status';
          final adminStatus = data['adminStatus'] as String?;
          final floorStatus = data['floorStatus'] as String?;
          final floorStatusSetBy = data['floorStatusSetBy'] as String?;
          final legacyStatus = data['manualStatus'] as String?;
          final statuses = isStatusRecord
              ? [adminStatus, floorStatus, if (adminStatus == null && floorStatus == null) legacyStatus]
                  .whereType<String>()
                  .toList()
              : const ['재실확인'];

          final values = [
            dorm,
            room,
            name,
            studentId,
            eventTitle,
            statuses.join(' · '),
            checkedInAt != null ? DateFormat('yyyy.MM.dd HH:mm').format(checkedInAt) : '',
            floorStatusSetBy ?? '',
          ];
          for (int c = 0; c < values.length; c++) {
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx)).value =
                TextCellValue(values[c]);
          }
          rowIdx++;
        }
      }

      if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');

      final bytes = excel.encode();
      if (bytes == null) throw Exception('엑셀 파일 생성 실패');

      if (!mounted) return;
      Navigator.pop(context);

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: '출석체크 이력 저장',
        fileName: '출석체크이력_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (savePath == null) return;
      await File(savePath).writeAsBytes(bytes);

      if (!mounted) return;
      await displayInfoBar(
        context,
        builder: (c, close) => InfoBar(
          title: Text('저장 완료: $savePath'),
          severity: InfoBarSeverity.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      await displayInfoBar(
        context,
        builder: (c, close) => InfoBar(
          title: Text('오류: $e'),
          severity: InfoBarSeverity.error,
        ),
      );
    }
  }

  static String _keyDorm(String key) => key.split('|')[0];
  static String _keyRoom(String key) => key.split('|').length > 1 ? key.split('|')[1] : '';

  static String _floorLabelFor(String dorm, String room) {
    if (dorm.isEmpty || room.isEmpty) return '';
    final n = int.tryParse(room);
    if (n == null) return dorm;
    if (dorm == '바롬인성교육관') {
      final floor = room.length >= 4 ? room.substring(0, 2) : room.substring(0, 1);
      return '$dorm $floor층';
    }
    final lastTwo = n % 100;
    final wing = (lastTwo >= 1 && lastTwo <= 20)
        ? 'A동'
        : (lastTwo >= 21 && lastTwo <= 40)
            ? 'B동'
            : null;
    if (dorm == '국제생활관') {
      if ((n >= 101 && n <= 132) || (n >= 201 && n <= 229)) {
        final floor = n ~/ 100;
        return '$dorm A동 $floor층';
      }
      if ((n >= 233 && n <= 260) || (n >= 301 && n <= 329)) {
        final floor = n ~/ 100;
        return '$dorm B동 $floor층';
      }
      return dorm;
    }
    if (wing == null) return dorm;
    final floor = n ~/ 100;
    return '$dorm $wing $floor층';
  }

  List<String> get _filteredKeys {
    return _sortedKeys.where((key) {
      final room = _keyRoom(key);
      final records = _grouped[key] ?? [];
      final name = records.isNotEmpty
          ? ((records.first.data() as Map<String, dynamic>)['userName'] as String? ?? '')
          : '';
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.trim();
        if (!room.contains(q) && !name.contains(q)) return false;
      }
      if (_floorFilter != null) {
        final dorm = _keyDorm(key);
        final floorLabel = _floorLabelFor(dorm, room);
        if (floorLabel != _floorFilter) return false;
      }
      return true;
    }).toList();
  }

  static Color _buildingColor(String? dormBuilding) {
    if (dormBuilding == '샬롬하우스') return const Color(0xFF2196F3);
    if (dormBuilding == '국제생활관') return const Color(0xFF4CAF50);
    if (dormBuilding == '바롬인성교육관') return const Color(0xFFFF9800);
    return const Color(0xFF9E9E9E);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: ProgressRing());
    }
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FluentIcons.error, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            const Text('데이터를 불러오는 중 오류가 발생했습니다', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(_errorMessage, style: TextStyle(fontSize: 12, color: Colors.grey[100])),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadData, child: const Text('다시 시도')),
          ],
        ),
      );
    }

    return Row(
      children: [
        // 왼쪽 패널
        Expanded(
          flex: 2,
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
                _buildLeftHeader(),
                _buildSearchBox(),
                _buildFilterRow(),
                Expanded(child: _buildKeyList()),
              ],
            ),
          ),
        ),
        // 오른쪽 패널
        Expanded(flex: 3, child: _buildDetailPanel()),
      ],
    );
  }

  Widget _buildLeftHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: FluentTheme.of(context).resources.dividerStrokeColorDefault),
        ),
      ),
      child: Row(
        children: [
          const Text('출석체크 이력', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          Button(
            onPressed: _exportHistoryToExcel,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.excel_document, size: 13),
                SizedBox(width: 6),
                Text('엑셀 다운로드', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: TextBox(
        controller: _searchController,
        placeholder: '이름 또는 호실 번호 검색',
        prefix: const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Icon(FluentIcons.search, size: 14),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: ComboBox<String>(
        value: _floorFilter ?? '전체',
        isExpanded: true,
        placeholder: const Text('구역 필터'),
        items: [
          const ComboBoxItem(value: '전체', child: Text('전체 구역')),
          for (final floor in kFloorOptions)
            ComboBoxItem(value: floor, child: Text(floor)),
        ],
        onChanged: (v) => setState(() {
          _floorFilter = (v == '전체') ? null : v;
          _selectedKey = null;
        }),
      ),
    );
  }

  Widget _buildKeyList() {
    final keys = _filteredKeys;
    if (keys.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FluentIcons.history, size: 48, color: Colors.grey[60]),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isEmpty ? '이력이 없습니다' : '검색 결과가 없습니다',
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      itemCount: keys.length,
      itemBuilder: (context, index) => _buildStudentCard(keys[index]),
    );
  }

  Widget _buildStudentCard(String key) {
    final dorm = _keyDorm(key);
    final room = _keyRoom(key);
    final records = _grouped[key] ?? [];
    final info = _studentInfo[key] ?? {};
    final name = (info['name'] as String?) ?? '';
    final studentId = (info['studentId'] as String?) ?? '';
    final latestData = records.isNotEmpty ? records.first.data() as Map<String, dynamic> : <String, dynamic>{};
    final latestAt = (latestData['checkedInAt'] as Timestamp?)?.toDate();

    final isSelected = _selectedKey == key;
    final bldColor = _buildingColor(dorm);
    final floorLabel = _floorLabelFor(dorm, room);

    return GestureDetector(
      onTap: () => setState(() => _selectedKey = key),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: bldColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    bottomLeft: Radius.circular(6),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? FluentTheme.of(context).accentColor.withValues(alpha: 0.08)
                        : FluentTheme.of(context).cardColor,
                    border: Border.all(
                      color: isSelected
                          ? FluentTheme.of(context).accentColor
                          : Colors.grey.withValues(alpha: 0.2),
                      width: isSelected ? 1.5 : 1,
                    ),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(6),
                      bottomRight: Radius.circular(6),
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              room.isNotEmpty ? '$name ($room호)' : name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (records.isEmpty ? Colors.grey : Colors.blue).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              records.isEmpty ? '기록 없음' : '${records.length}회',
                              style: TextStyle(
                                fontSize: 11,
                                color: records.isEmpty ? Colors.grey : Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (studentId.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(studentId, style: TextStyle(fontSize: 11, color: Colors.grey[100])),
                      ],
                      if (floorLabel.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(floorLabel, style: TextStyle(fontSize: 12, color: Colors.grey[100])),
                      ],
                      if (latestAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '최근 출석: ${DateFormat('yyyy.MM.dd HH:mm').format(latestAt)}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[80]),
                        ),
                      ],
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

  Widget _buildDetailPanel() {
    if (_selectedKey == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FluentIcons.contact, size: 64, color: Colors.grey[60]),
            const SizedBox(height: 16),
            const Text('학생을 선택해주세요', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              '왼쪽에서 학생을 선택하면\n해당 학생의 출석 이력이 표시됩니다',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[100]),
            ),
          ],
        ),
      );
    }

    final records = _grouped[_selectedKey!] ?? [];
    final info = _studentInfo[_selectedKey!] ?? {};
    final name = (info['name'] as String?) ?? '';
    final room = _keyRoom(_selectedKey!);
    final dorm = _keyDorm(_selectedKey!);

    return Container(
      color: FluentTheme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FluentTheme.of(context).cardColor,
              border: Border(
                bottom: BorderSide(color: FluentTheme.of(context).resources.dividerStrokeColorDefault),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(FluentIcons.contact, color: Colors.purple, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.isNotEmpty ? '$name ($room호)' : name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dorm.isNotEmpty ? dorm : '기숙사 정보 없음',
                        style: TextStyle(fontSize: 13, color: Colors.grey[100]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '총 ${records.length}회 출석',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: records.isEmpty
                ? const Center(child: Text('출석 이력이 없습니다'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: records.length,
                    itemBuilder: (context, index) => _buildHistoryCard(records[index].data() as Map<String, dynamic>),
                  ),
          ),
        ],
      ),
    );
  }

  static const _statusIcons = {
    '재실확인': FluentIcons.check_mark,
    '외박': FluentIcons.airplane,
    '부재': FluentIcons.contact_card,
    '외박미수정': FluentIcons.warning,
  };
  static const _statusColors = {
    '재실확인': Color(0xFF4CAF50),
    '외박': Color(0xFFFF9800),
    '부재': Color(0xFFF44336),
    '외박미수정': Color(0xFF2196F3),
  };

  Widget _buildHistoryCard(Map<String, dynamic> data) {
    final eventId = data['eventId'] as String?;
    final event = eventId != null ? _eventMap[eventId] : null;
    final eventTitle = (event?['title'] as String?) ?? (data['eventTitle'] as String?) ?? '출석체크';
    final checkedInAt = (data['checkedInAt'] as Timestamp?)?.toDate();
    final isStatusRecord = data['recordType'] == 'status';
    final adminStatus = data['adminStatus'] as String?;
    final floorStatus = data['floorStatus'] as String?;
    final floorStatusSetBy = data['floorStatusSetBy'] as String?;
    // 구버전 데이터 호환: manualStatus만 있는 기존 기록
    final legacyStatus = data['manualStatus'] as String?;
    final statuses = isStatusRecord
        ? [adminStatus, floorStatus, if (adminStatus == null && floorStatus == null) legacyStatus]
            .whereType<String>()
            .toList()
        : const ['재실확인'];

    // 아이콘/색상은 층장이 처리한 최신 상태(floorStatus)를 우선 표시
    final primaryStatus = floorStatus ?? (statuses.isNotEmpty ? statuses.first : null);
    final icon = _statusIcons[primaryStatus] ?? FluentIcons.info;
    final color = _statusColors[primaryStatus] ?? Colors.grey;
    final title = statuses.isNotEmpty ? '$eventTitle · ${statuses.join(' · ')}' : eventTitle;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  if (checkedInAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('yyyy.MM.dd (E) HH:mm', 'ko').format(checkedInAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[100]),
                    ),
                  ],
                  if (floorStatusSetBy != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '처리: $floorStatusSetBy',
                      style: TextStyle(fontSize: 11, color: Colors.grey[90]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
