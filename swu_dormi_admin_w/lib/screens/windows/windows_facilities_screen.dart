import 'package:flutter/material.dart' hide Colors, FilledButton, IconButton, Card, ListTile, showDialog, Divider, Checkbox, Tooltip, ButtonStyle, Slider, SliderThemeData;
import 'package:flutter/material.dart' as flutter_material show Colors;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:swu_dormi_admin/widgets/shimmer.dart';
import 'package:swu_dormi_admin/services/firestore_service.dart';
import 'package:swu_dormi_admin/models/facility_report_model.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:swu_dormi_admin/screens/windows/windows_cleaning_inspection_screen.dart' show kFloorOptions;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:io';
import 'dart:async';

const Map<int, int> _kShalomCapacities = {
  1: 2, 2: 4, 3: 2, 4: 2, 5: 4, 6: 2, 7: 1, 8: 2, 9: 1, 10: 2,
  11: 1, 12: 1, 13: 4, 14: 4, 15: 4, 16: 4, 17: 4, 18: 4, 19: 4, 20: 4,
  21: 2, 22: 4, 23: 2, 24: 2, 25: 4, 26: 2, 27: 2, 28: 2, 29: 1, 30: 4,
  31: 4, 32: 4, 33: 4, 34: 4, 35: 4,
};

String _roomLabel(String roomNumber, String dormBuilding) {
  final n = int.tryParse(roomNumber) ?? 0;
  if (dormBuilding == '샬롬하우스' && n > 0) {
    final cap = _kShalomCapacities[n % 100] ?? 4;
    return '$roomNumber호 ($cap인실)';
  }
  return '$roomNumber호';
}

class WindowsFacilitiesScreen extends StatefulWidget {
  const WindowsFacilitiesScreen({super.key});

  @override
  State<WindowsFacilitiesScreen> createState() => _WindowsFacilitiesScreenState();
}

class _WindowsFacilitiesScreenState extends State<WindowsFacilitiesScreen> {
  final _firestoreService = FirestoreService();
  final _dateFormat = DateFormat('yyyy.MM.dd HH:mm');
  FacilityReportModel? _selectedReport;
  String? _selectedUserDormBuilding;
  String _filterStatus = '전체';
  String? _filterFloor;
  String? _filterCategory;
  late Stream<QuerySnapshot> _reportsStream;
  Map<String, Map<String, String>> _userInfoMap = {};
  List<FacilityReportModel> _allReports = [];
  StreamSubscription<QuerySnapshot>? _allReportsSub;

  @override
  void initState() {
    super.initState();
    _loadReports();
    _loadUserInfo();
    _allReportsSub = FirebaseFirestore.instance
        .collection('facility_reports')
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() {
          _allReports = snap.docs.map((d) => FacilityReportModel.fromFirestore(d)).toList();
        });
      }
    });
  }

  @override
  void dispose() {
    _allReportsSub?.cancel();
    super.dispose();
  }

  // 시설신고 내역을 엑셀로 저장한다. 사진/영상 등 미디어 자료는 포함하지 않는다.
  Future<void> _exportReportsToExcel() async {
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
      final sheet = excel['시설신고내역'];

      final headers = [
        '이름',
        '학번',
        '기숙사 건물',
        '호실',
        '자리번호',
        '분류',
        '내용',
        '상태',
        '신고일시',
        '처리일시',
        '처리자',
        '처리 메모',
      ];
      for (int c = 0; c < headers.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).value =
            TextCellValue(headers[c]);
      }

      final reports = List<FacilityReportModel>.from(_allReports)
        ..sort((a, b) => b.reportedAt.compareTo(a.reportedAt));

      for (int r = 0; r < reports.length; r++) {
        final report = reports[r];
        final info = _userInfoMap[report.userId];
        final rowIdx = r + 1;

        final values = [
          report.userName,
          info?['studentId'] ?? '',
          info?['dormBuilding'] ?? (report.building ?? ''),
          report.roomNumber,
          report.seatNumber ?? '',
          report.getCategoryDisplayName(),
          report.description,
          report.getStatusDisplayName(),
          _dateFormat.format(report.reportedAt),
          report.processedAt != null ? _dateFormat.format(report.processedAt!) : '',
          report.processedByName ?? '',
          report.technicianNote ?? '',
        ];
        for (int c = 0; c < values.length; c++) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx)).value =
              TextCellValue(values[c]);
        }
      }

      if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');

      final bytes = excel.encode();
      if (bytes == null) throw Exception('엑셀 파일 생성 실패');

      if (!mounted) return;
      Navigator.pop(context);

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: '시설신고 내역 저장',
        fileName: '시설신고내역_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx',
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

  Future<void> _loadUserInfo() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('users').get();
      if (!mounted) return;
      final map = <String, Map<String, String>>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        map[doc.id] = {
          'dormBuilding': (data['dormBuilding'] as String?) ?? '',
          'studentId': (data['studentId'] as String?) ?? '',
          'building': (data['building'] as String?) ?? '',
          'floor': (data['floor'] as String?) ?? '',
        };
      }
      setState(() => _userInfoMap = map);
    } catch (_) {}
  }

  Future<void> _fetchUserDormBuilding(String userId) async {
    if (userId.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (mounted) {
        setState(() {
          _selectedUserDormBuilding = doc.data()?['dormBuilding'] as String?;
        });
      }
    } catch (_) {}
  }

  void _loadReports() {
    setState(() {
      _reportsStream = _filterStatus == '전체'
          ? _firestoreService.getFacilityReports()
          : _firestoreService.getFacilityReports(status: _filterStatus);
    });
  }

  static String _floorArea(String dormBuilding, String roomNumber, String building) {
    final roomNum = int.tryParse(roomNumber);

    if (dormBuilding == '국제생활관' && roomNum != null) {
      if (roomNum >= 101 && roomNum <= 132) return '국제생활관 A동 1층';
      if (roomNum >= 201 && roomNum <= 229) return '국제생활관 A동 2층';
      if (roomNum >= 233 && roomNum <= 260) return '국제생활관 B동 2층';
      if (roomNum >= 301 && roomNum <= 329) return '국제생활관 B동 3층';
      return '';
    }

    if (dormBuilding == '바롬인성교육관') return '바롬인성교육관 10층';

    // 샬롬하우스: 저장된 building(A동/B동) + 방 번호에서 층 계산
    if (dormBuilding == '샬롬하우스' && roomNum != null && building.isNotEmpty) {
      final floor = roomNum ~/ 100;
      if (floor >= 2 && floor <= 7) return '샬롬하우스 $building ${floor}층';
    }

    if (dormBuilding == '샬롬하우스(여름방학)' && roomNum != null) {
      final floor = roomNum ~/ 100;
      if (floor >= 2 && floor <= 4) return '샬롬하우스(여름방학) A동 ${floor}층';
    }

    return '';
  }

  Widget _buildFloorFilterRow() {
    int countForArea(String? area) {
      return _allReports.where((r) {
        final info = _userInfoMap[r.userId];
        final dormBuilding = info?['dormBuilding'] ?? '';
        final building = info?['building'] ?? '';
        final a = _floorArea(dormBuilding, r.roomNumber, building);
        return area == null ? true : a.startsWith(area);
      }).length;
    }

    Widget chip(String label, String? area) {
      final isSelected = _filterFloor == area;
      final count = countForArea(area);
      return GestureDetector(
        onTap: () => setState(() {
          _filterFloor = isSelected ? null : area;
          _selectedReport = null;
        }),
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
                '$count건',
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

    List<Widget> withSep(List<Widget> items) {
      final result = <Widget>[];
      for (int i = 0; i < items.length; i++) {
        if (i > 0) result.add(const SizedBox(width: 6));
        result.add(items[i]);
      }
      return result;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(
            color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 전체
          scrollRow(withSep([chip('전체', null)])),
          const SizedBox(height: 8),
          // 샬롬하우스 A동
          scrollRow(withSep([
            chip('샬롬하우스 A동', '샬롬하우스 A동'),
            for (final f in kFloorOptions.where((f) => f.startsWith('샬롬하우스 A동')))
              chip(f.replaceFirst('샬롬하우스 A동 ', ''), f),
          ])),
          const SizedBox(height: 8),
          // 샬롬하우스 B동
          scrollRow(withSep([
            chip('샬롬하우스 B동', '샬롬하우스 B동'),
            for (final f in kFloorOptions.where((f) => f.startsWith('샬롬하우스 B동')))
              chip(f.replaceFirst('샬롬하우스 B동 ', ''), f),
          ])),
          const SizedBox(height: 8),
          // 국제생활관 A동
          scrollRow(withSep([
            chip('국제생활관 A동', '국제생활관 A동'),
            for (final f in kFloorOptions.where((f) => f.startsWith('국제생활관 A동')))
              chip(f.replaceFirst('국제생활관 A동 ', ''), f),
          ])),
          const SizedBox(height: 8),
          // 국제생활관 B동
          scrollRow(withSep([
            chip('국제생활관 B동', '국제생활관 B동'),
            for (final f in kFloorOptions.where((f) => f.startsWith('국제생활관 B동')))
              chip(f.replaceFirst('국제생활관 B동 ', ''), f),
          ])),
          const SizedBox(height: 8),
          // 바롬인성교육관
          scrollRow(withSep([
            for (final f in kFloorOptions.where((f) => f.startsWith('바롬인성교육관')))
              chip(f, f),
          ])),
          const SizedBox(height: 8),
          // 샬롬하우스(여름방학)
          scrollRow(withSep([
            for (final f in kFloorOptions.where((f) => f.startsWith('샬롬하우스(여름방학)')))
              chip(f, f),
          ])),
        ],
      ),
    );
  }

  Color _buildingColor(String dormBuilding) {
    if (dormBuilding.startsWith('샬롬하우스')) return const Color(0xFF2196F3);
    if (dormBuilding == '국제생활관') return const Color(0xFF4CAF50);
    if (dormBuilding == '바롬인성교육관') return const Color(0xFFFF9800);
    return const Color(0xFF9E9E9E);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return FluentIcons.clock;
      case 'in_progress':
        return FluentIcons.progress_ring_dots;
      case 'completed':
        return FluentIcons.completed;
      default:
        return FluentIcons.status_circle_question_mark;
    }
  }

  void _showStatusChangeDialog(FacilityReportModel report) {
    String selectedStatus = report.status;
    final noteController = TextEditingController(text: report.technicianNote ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: const Text('상태 변경'),
        content: Container(
          width: 500,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상태 선택
              const Text('상태', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ComboBox<String>(
                value: selectedStatus,
                items: const [
                  ComboBoxItem(value: 'pending', child: Text('대기중')),
                  ComboBoxItem(value: 'in_progress', child: Text('처리중')),
                  ComboBoxItem(value: 'completed', child: Text('완료됨')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    selectedStatus = value;
                  }
                },
              ),
              const SizedBox(height: 24),
              // 관리자 메모
              const Text('관리자 메모', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextBox(
                controller: noteController,
                placeholder: '처리 내용을 입력하세요',
                maxLines: 5,
              ),
            ],
          ),
        ),
        actions: [
          Button(
            child: const Text('취소'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          FilledButton(
            child: const Text('저장'),
            onPressed: () async {
              Navigator.pop(dialogContext);

              // 프로그레스 다이얼로그 표시
              showDialog(
                context: this.context,
                barrierDismissible: false,
                builder: (progressContext) => const ContentDialog(
                  title: Text('처리 중'),
                  content: SizedBox(
                    height: 100,
                    child: Center(
                      child: ProgressRing(),
                    ),
                  ),
                ),
              );

              try {
                await _firestoreService.updateFacilityReportStatus(
                  report.id,
                  selectedStatus,
                  noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                );

                if (!mounted) return;
                Navigator.pop(this.context);

                // 성공 메시지
                await showDialog(
                  context: this.context,
                  builder: (successContext) => ContentDialog(
                    title: const Text('완료'),
                    content: const Text('상태가 변경되었습니다.'),
                    actions: [
                      FilledButton(
                        child: const Text('확인'),
                        onPressed: () => Navigator.pop(successContext),
                      ),
                    ],
                  ),
                );

                // 선택된 리포트 초기화 후 목록 새로고침
                setState(() {
                  _selectedReport = null;
                });
                _loadReports();
              } catch (e) {
                if (!mounted) return;
                Navigator.pop(this.context);

                await showDialog(
                  context: this.context,
                  builder: (errorContext) => ContentDialog(
                    title: const Text('오류'),
                    content: Text('상태 변경 중 오류가 발생했습니다:\n$e'),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Row(
        children: [
          // 왼쪽: 시설 신고 목록
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
                    child: Row(
                      children: [
                        const Text(
                          '수리 보수 목록',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Button(
                          onPressed: _exportReportsToExcel,
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(FluentIcons.excel_document, size: 13),
                              SizedBox(width: 6),
                              Text('엑셀 다운로드', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(FluentIcons.refresh),
                          onPressed: _loadReports,
                        ),
                      ],
                    ),
                  ),
                  // 서브필터
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ComboBox<String>(
                                value: _filterFloor ?? '전체',
                                isExpanded: true,
                                items: [
                                  const ComboBoxItem(value: '전체', child: Text('전체 구역')),
                                  ...kFloorOptions.map((f) => ComboBoxItem(value: f, child: Text(f))),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _filterFloor = (value == '전체') ? null : value;
                                    _selectedReport = null;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ComboBox<String>(
                                value: _filterStatus,
                                isExpanded: true,
                                items: const [
                                  ComboBoxItem(value: '전체', child: Text('전체 상태')),
                                  ComboBoxItem(value: 'pending', child: Text('대기중')),
                                  ComboBoxItem(value: 'in_progress', child: Text('처리중')),
                                  ComboBoxItem(value: 'completed', child: Text('완료됨')),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _filterStatus = value ?? '전체';
                                    _selectedReport = null;
                                  });
                                  _loadReports();
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // 카테고리 칩 필터
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final entry in [
                                (null, '전체'),
                                ('plumbing', '수도/냉난방'),
                                ('maintenance', '가구/도어'),
                                ('electrical', '전기'),
                                ('common_area', '공동구역'),
                                ('other', '기타'),
                              ])
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: _buildCategoryChip(entry.$1, entry.$2),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 목록
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _reportsStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text('오류: ${snapshot.error}'),
                          );
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return ShimmerList(itemBuilder: () => const FacilityCardShimmer(), count: 6);
                        }

                        var reports = snapshot.data!.docs
                            .map((doc) => FacilityReportModel.fromFirestore(doc))
                            .toList();

                        // 점검구역 필터 적용
                        if (_filterFloor != null) {
                          reports = reports.where((r) {
                            final info = _userInfoMap[r.userId];
                            final dormBuilding = info?['dormBuilding'] ?? '';
                            final building = info?['building'] ?? '';
                            final area = _floorArea(dormBuilding, r.roomNumber, building);
                            return area.startsWith(_filterFloor!);
                          }).toList();
                        }

                        // 카테고리 필터 적용
                        if (_filterCategory != null) {
                          reports = reports.where((r) => r.category == _filterCategory).toList();
                        }

                        // 날짜순 정렬 (최신순)
                        reports.sort((a, b) => b.reportedAt.compareTo(a.reportedAt));

                        if (reports.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  FluentIcons.repair,
                                  size: 64,
                                  color: Colors.grey[60],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  '수리 보수 신고가 없습니다',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: reports.length,
                          itemBuilder: (context, index) {
                            final report = reports[index];
                            final isSelected = _selectedReport?.id == report.id;

                            final dormBuilding = _userInfoMap[report.userId]?['dormBuilding'] ?? '';
                            final buildingColor = _buildingColor(dormBuilding);

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
                                    _selectedReport = report;
                                    _selectedUserDormBuilding = null;
                                  });
                                  _fetchUserDormBuilding(report.userId);
                                },
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(report.status).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _getStatusIcon(report.status),
                                    color: _getStatusColor(report.status),
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  report.getCategoryDisplayName(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Builder(builder: (_) {
                                  final info = _userInfoMap[report.userId];
                                  final dormBuilding = info?['dormBuilding'] ?? '';
                                  final studentId = info?['studentId'] ?? '';
                                  final parts = <String>[
                                    _roomLabel(report.roomNumber, dormBuilding),
                                    if (dormBuilding.isNotEmpty) dormBuilding,
                                    report.userName,
                                    if (studentId.isNotEmpty) studentId,
                                  ];
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          parts.join(' | '),
                                          style: TextStyle(fontSize: 12, color: Colors.grey[100]),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _dateFormat.format(report.reportedAt),
                                          style: TextStyle(fontSize: 11, color: Colors.grey[90]),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(report.status).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    report.getStatusDisplayName(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _getStatusColor(report.status),
                                    ),
                                  ),
                                ),
                              ),
                            ));
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 오른쪽: 필터 + 상세 정보
          Expanded(
            flex: 3,
            child: Column(
              children: [
                _buildFloorFilterRow(),
                Expanded(
                  child: _selectedReport == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FluentIcons.repair,
                          size: 64,
                          color: Colors.grey[60],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '시설 신고를 선택해주세요',
                          style: TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 헤더
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedReport!.getCategoryDisplayName(),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(_selectedReport!.status).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          _selectedReport!.getStatusDisplayName(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _getStatusColor(_selectedReport!.status),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          _selectedReport!.getCategoryDisplayName(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[120],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            FilledButton(
                              onPressed: () => _showStatusChangeDialog(_selectedReport!),
                              child: const Text('상태 변경'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        // 신고자 정보
                        _buildInfoSection(
                          '신고자 정보',
                          [
                            _buildInfoRow('이름', _selectedReport!.userName),
                            _buildInfoRow('호실', _roomLabel(_selectedReport!.roomNumber, _selectedUserDormBuilding ?? '')),
                            if (_selectedReport!.seatNumber != null && _selectedReport!.seatNumber!.isNotEmpty)
                              _buildInfoRow('자리번호', _selectedReport!.seatNumber!),
                            if (_selectedUserDormBuilding != null)
                              _buildInfoRow('기숙사 건물', _selectedUserDormBuilding!),
                            _buildInfoRow('신고 일시', _dateFormat.format(_selectedReport!.reportedAt)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // 신고 내용
                        _buildInfoSection(
                          '신고 내용',
                          [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _selectedReport!.description,
                                style: const TextStyle(fontSize: 14, height: 1.6),
                              ),
                            ),
                          ],
                        ),
                        // 첨부 파일
                        if (_selectedReport!.mediaUrls != null && _selectedReport!.mediaUrls!.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _buildInfoSection(
                            '첨부 파일 (${_selectedReport!.mediaUrls!.length}개)',
                            _selectedReport!.mediaUrls!.map((url) {
                              final isVideo = _isVideoUrl(url);
                              if (isVideo) {
                                return _AdminVideoPlayer(key: ValueKey(url), url: url);
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: GestureDetector(
                                  onTap: () => launchUrl(url),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      url,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        height: 200,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: Icon(FluentIcons.photo_error, size: 48, color: Colors.grey[60]),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        // 처리 정보
                        if (_selectedReport!.processedByName != null) ...[
                          const SizedBox(height: 24),
                          _buildInfoSection(
                            '처리 정보',
                            [
                              _buildInfoRow('처리자', _selectedReport!.processedByName!),
                              if (_selectedReport!.processedAt != null)
                                _buildInfoRow('처리 일시', _dateFormat.format(_selectedReport!.processedAt!)),
                              if (_selectedReport!.completedAt != null)
                                _buildInfoRow('완료 일시', _dateFormat.format(_selectedReport!.completedAt!)),
                            ],
                          ),
                        ],
                        // 관리자 메모
                        if (_selectedReport!.technicianNote != null) ...[
                          const SizedBox(height: 24),
                          _buildInfoSection(
                            '관리자 메모',
                            [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.blue.withOpacity(0.2),
                                  ),
                                ),
                                child: Text(
                                  _selectedReport!.technicianNote!,
                                  style: const TextStyle(fontSize: 14, height: 1.6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),   // Expanded (상세 정보)
              ],
            ),       // Column
          ),         // Expanded(flex: 3)
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildCategoryChip(String? value, String label) {
    final isSelected = _filterCategory == value;
    return GestureDetector(
      onTap: () => setState(() {
        _filterCategory = isSelected ? null : value;
        _selectedReport = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isSelected ? FluentTheme.of(context).accentColor : Colors.grey[100],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[100],
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

  bool _isVideoUrl(String url) {
    // Firebase Storage URL에서 실제 파일명 추출 (%2F 디코딩, 쿼리 파라미터 제거)
    try {
      final uri = Uri.parse(url);
      final path = Uri.decodeComponent(uri.path).toLowerCase();
      const videoExts = ['mp4', 'mov', 'avi', '3gp', 'mkv', 'webm'];
      return videoExts.any((ext) => path.endsWith('.$ext'));
    } catch (_) {
      return false;
    }
  }

  void launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await url_launcher.canLaunchUrl(uri)) {
      await url_launcher.launchUrl(uri);
    }
  }
}

// 인라인 영상 플레이어 (다운로드 후 로컬 재생)
class _AdminVideoPlayer extends StatefulWidget {
  final String url;
  const _AdminVideoPlayer({super.key, required this.url});

  @override
  State<_AdminVideoPlayer> createState() => _AdminVideoPlayerState();
}

enum _VideoState { idle, downloading, ready, error }

class _AdminVideoPlayerState extends State<_AdminVideoPlayer> {
  late final Player _player;
  late final VideoController _controller;

  _VideoState _state = _VideoState.idle;
  double _downloadProgress = 0.0;
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
  }

  @override
  void dispose() {
    _player.dispose();
    if (_localPath != null) {
      File(_localPath!).exists().then((exists) {
        if (exists) File(_localPath!).delete();
      });
    }
    super.dispose();
  }

  Future<void> _downloadAndPlay() async {
    if (mounted) setState(() { _state = _VideoState.downloading; _downloadProgress = 0; });

    try {
      final uri = Uri.parse(widget.url);
      final pathDecoded = Uri.decodeComponent(uri.path);
      final ext = pathDecoded.split('.').last.split('?').first;

      final tmpDir = Directory.systemTemp;
      final fileName = 'swu_repair_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final tmpFile = File('${tmpDir.path}\\$fileName');

      final response = await http.Client().send(http.Request('GET', Uri.parse(widget.url)));
      final total = response.contentLength ?? 0;
      int received = 0;
      final sink = tmpFile.openWrite();

      await response.stream.forEach((chunk) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && mounted) {
          setState(() => _downloadProgress = received / total);
        }
      });
      await sink.close();

      if (!mounted) return;
      _localPath = tmpFile.path;

      await _player.open(Media('file:///${tmpFile.path.replaceAll('\\', '/')}'), play: true);
      if (mounted) setState(() => _state = _VideoState.ready);
    } catch (e) {
      if (mounted) setState(() => _state = _VideoState.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          color: flutter_material.Colors.black,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: switch (_state) {
                  _VideoState.idle => Center(
                      child: IconButton(
                        icon: const Icon(FluentIcons.play, color: flutter_material.Colors.white, size: 48),
                        onPressed: _downloadAndPlay,
                      ),
                    ),
                  _VideoState.downloading => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(FluentIcons.download, color: flutter_material.Colors.white, size: 32),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: ProgressBar(value: _downloadProgress * 100),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '다운로드 중... ${(_downloadProgress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(color: flutter_material.Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  _VideoState.ready => Video(controller: _controller),
                  _VideoState.error => const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(FluentIcons.error, color: flutter_material.Colors.red, size: 32),
                          SizedBox(height: 8),
                          Text('재생 오류', style: TextStyle(color: flutter_material.Colors.white)),
                        ],
                      ),
                    ),
                },
              ),
              if (_state == _VideoState.ready)
                Container(
                  color: flutter_material.Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: StreamBuilder<bool>(
                    stream: _player.stream.playing,
                    builder: (context, snapshot) {
                      final isPlaying = snapshot.data ?? false;
                      return Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              isPlaying ? FluentIcons.pause : FluentIcons.play,
                              color: flutter_material.Colors.white,
                              size: 20,
                            ),
                            onPressed: () => _player.playOrPause(),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: StreamBuilder<Duration>(
                              stream: _player.stream.position,
                              builder: (context, posSnap) {
                                return StreamBuilder<Duration>(
                                  stream: _player.stream.duration,
                                  builder: (context, durSnap) {
                                    final position = posSnap.data ?? Duration.zero;
                                    final duration = durSnap.data ?? Duration.zero;
                                    final progress = duration.inMilliseconds > 0
                                        ? position.inMilliseconds / duration.inMilliseconds
                                        : 0.0;
                                    return Slider(
                                      value: progress.clamp(0.0, 1.0),
                                      onChanged: (v) {
                                        _player.seek(Duration(
                                          milliseconds: (v * duration.inMilliseconds).round(),
                                        ));
                                      },
                                      style: SliderThemeData(
                                        activeColor: ButtonState.all(flutter_material.Colors.white),
                                        inactiveColor: ButtonState.all(flutter_material.Colors.white24),
                                        thumbColor: ButtonState.all(flutter_material.Colors.white),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          StreamBuilder<Duration>(
                            stream: _player.stream.position,
                            builder: (context, posSnap) {
                              final pos = posSnap.data ?? Duration.zero;
                              final mm = pos.inMinutes.toString().padLeft(2, '0');
                              final ss = (pos.inSeconds % 60).toString().padLeft(2, '0');
                              return Text('$mm:$ss',
                                  style: const TextStyle(color: flutter_material.Colors.white, fontSize: 12));
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
