import 'dart:io';
import 'package:flutter/material.dart'
    hide
        Colors,
        FilledButton,
        IconButton,
        Card,
        ListTile,
        showDialog,
        Divider,
        Checkbox,
        Tooltip,
        ButtonStyle;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:window_manager/window_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:excel/excel.dart' hide Border;
import 'package:swu_dormi_admin/services/auth_service.dart';
import 'package:swu_dormi_admin/services/storage_service.dart';
import 'package:swu_dormi_admin/models/user_model.dart';
import 'package:swu_dormi_admin/models/excel_student_row.dart';
import 'package:swu_dormi_admin/utils/xlsx_repair.dart';
import 'package:swu_dormi_admin/screens/windows/windows_dashboard.dart';
import 'package:swu_dormi_admin/screens/windows/windows_notices_screen.dart';
import 'package:swu_dormi_admin/screens/windows/windows_student_council_screen.dart';
import 'package:swu_dormi_admin/screens/windows/windows_meals_screen.dart';
import 'package:swu_dormi_admin/screens/windows/windows_facilities_screen.dart';
import 'package:swu_dormi_admin/screens/windows/windows_students_screen.dart';
import 'package:swu_dormi_admin/screens/windows/windows_message_screen.dart';
import 'package:swu_dormi_admin/screens/windows/windows_bulk_points_screen.dart';
import 'package:swu_dormi_admin/screens/windows/windows_login_screen.dart';
import 'package:swu_dormi_admin/screens/windows/windows_cleaning_inspection_screen.dart'
    show WindowsInspectionTabScreen;
import 'package:swu_dormi_admin/screens/windows/windows_attendance_screen.dart';
import 'package:swu_dormi_admin/screens/windows/windows_work_schedule_screen.dart';
import 'package:swu_dormi_admin/screens/windows/windows_board_screen.dart';
import 'package:swu_dormi_admin/screens/windows/windows_interns_screen.dart';
import 'package:swu_dormi_admin/screens/windows/windows_reports_screen.dart';
import 'package:swu_dormi_admin/screens/windows/windows_reservations_screen.dart';

class WindowsNavigationShell extends StatefulWidget {
  const WindowsNavigationShell({super.key});

  @override
  State<WindowsNavigationShell> createState() => _WindowsNavigationShellState();
}

class _WindowsNavigationShellState extends State<WindowsNavigationShell> with WindowListener {
  final _authService = AuthService();
  int _currentIndex = 0;
  bool _isCompact = false;

  final List<NavigationPaneItem> _navigationItems = [];

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initNavigationItems();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  void _initNavigationItems() {
    _navigationItems.addAll([
      PaneItem(
        icon: const Icon(FluentIcons.home),
        title: const Text('대시보드'),
        body: WindowsDashboard(
          onNavigate: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
        selectedTileColor: WidgetStateProperty.all(Colors.blue.withValues(alpha: 0.1)),
      ),
      PaneItemSeparator(),
      PaneItem(
        icon: const Icon(FluentIcons.megaphone),
        title: const Text('공지사항/월간계획'),
        body: const WindowsNoticesTabScreen(),
        selectedTileColor: WidgetStateProperty.all(Colors.blue.withValues(alpha: 0.1)),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.search),
        title: const Text('게시판'),
        body: const WindowsBoardScreen(),
        selectedTileColor: WidgetStateProperty.all(Colors.orange.withValues(alpha: 0.1)),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.cafe),
        title: const Text('식단표'),
        body: const WindowsMealsScreen(),
        selectedTileColor: WidgetStateProperty.all(Colors.teal.withValues(alpha: 0.1)),
      ),
      PaneItemSeparator(),
      PaneItem(
        icon: const Icon(FluentIcons.repair),
        title: const Text('수리 보수'),
        body: const WindowsFacilitiesScreen(),
        selectedTileColor: WidgetStateProperty.all(Colors.red.withValues(alpha: 0.1)),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.calendar_agenda),
        title: const Text('단위실 월검사'),
        body: const WindowsInspectionTabScreen(inspectionType: 'monthly'),
        selectedTileColor: WidgetStateProperty.all(Colors.teal.withValues(alpha: 0.1)),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.move_to_folder),
        title: const Text('단위실 퇴사검사'),
        body: const WindowsInspectionTabScreen(inspectionType: 'move_out'),
        selectedTileColor: WidgetStateProperty.all(Colors.orange.withValues(alpha: 0.1)),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.check_list),
        title: const Text('인원점검(화재대피)'),
        body: const WindowsAttendanceTabScreen(),
        selectedTileColor: WidgetStateProperty.all(Colors.purple.withValues(alpha: 0.1)),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.event_date),
        title: const Text('세미나실 예약'),
        body: const WindowsReservationsScreen(),
        selectedTileColor: WidgetStateProperty.all(Colors.blue.withValues(alpha: 0.1)),
      ),
      PaneItemSeparator(),
      PaneItem(
        icon: const Icon(FluentIcons.people),
        title: const Text('학생 관리'),
        body: const WindowsStudentsScreen(),
        selectedTileColor: WidgetStateProperty.all(Colors.green.withValues(alpha: 0.1)),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.message),
        title: const Text('메시지 전송'),
        body: const WindowsMessageScreen(),
        selectedTileColor: WidgetStateProperty.all(Colors.orange.withValues(alpha: 0.1)),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.certificate),
        title: const Text('상벌 관리'),
        body: const WindowsPointsManagementTabScreen(),
        selectedTileColor: WidgetStateProperty.all(Colors.purple.withValues(alpha: 0.1)),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.people_add),
        title: const Text('행정실 근무자 현황'),
        body: const WindowsWorkScheduleScreen(),
        selectedTileColor: WidgetStateProperty.all(Colors.orange.withValues(alpha: 0.1)),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.education),
        title: const Text('인턴 관리'),
        body: const WindowsInternManagementTabScreen(),
        selectedTileColor: WidgetStateProperty.all(Colors.teal.withValues(alpha: 0.1)),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.group),
        title: const Text('사생회'),
        body: const WindowsStudentCouncilTabScreen(),
        selectedTileColor: WidgetStateProperty.all(Colors.purple.withValues(alpha: 0.1)),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.flag),
        title: const Text('게시판 신고 관리'),
        body: const WindowsReportsScreen(),
        selectedTileColor: WidgetStateProperty.all(Colors.red.withValues(alpha: 0.1)),
        infoBadge: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('reports')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, snapshot) {
            final count = snapshot.data?.docs.length ?? 0;
            if (count == 0) return const SizedBox.shrink();
            return InfoBadge(source: Text('$count'));
          },
        ),
      ),
    ]);
  }

  Future<void> _handleLogout() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => ContentDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          Button(
            child: const Text('취소'),
            onPressed: () {
              Navigator.pop(context, false);
            },
          ),
          FilledButton(
            child: const Text('로그아웃'),
            onPressed: () {
              Navigator.pop(context, true);
            },
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacement(FluentPageRoute(builder: (context) => const WindowsLoginScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;
    final brightness = FluentTheme.of(context).brightness;

    return NavigationView(
      appBar: NavigationAppBar(
        automaticallyImplyLeading: false,
        title: DragToMoveArea(
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(
                  child: Text(
                    'SWU',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text('샬롬하우스 관리 시스템(2학기)'),
              const Spacer(),
            ],
          ),
        ),
        actions: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 사용자 정보
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(FluentIcons.contact, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currentUser?.email?.split('@').first ?? '',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            // 로그아웃 버튼
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: IconButton(
                icon: const Icon(FluentIcons.sign_out, size: 16),
                onPressed: _handleLogout,
              ),
            ),
            // 창 컨트롤 버튼들
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(FluentIcons.chrome_minimize, size: 12),
              onPressed: () => windowManager.minimize(),
            ),
            IconButton(
              icon: const Icon(FluentIcons.chrome_restore, size: 12),
              onPressed: () async {
                if (await windowManager.isMaximized()) {
                  windowManager.restore();
                } else {
                  windowManager.maximize();
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(FluentIcons.chrome_close, size: 12),
                onPressed: () => windowManager.close(),
              ),
            ),
          ],
        ),
      ),
      pane: NavigationPane(
        selected: _currentIndex,
        onChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        displayMode: _isCompact ? PaneDisplayMode.compact : PaneDisplayMode.open,
        toggleable: true,
        size: const NavigationPaneSize(openMaxWidth: 250, openMinWidth: 200, compactWidth: 48),
        items: _navigationItems,
        footerItems: [
          PaneItemSeparator(),
          PaneItem(
            icon: const Icon(FluentIcons.settings),
            title: const Text('설정'),
            body: const _SettingsPage(),
            selectedTileColor: WidgetStateProperty.all(Colors.grey.withValues(alpha: 0.1)),
          ),
        ],
      ),
      paneBodyBuilder: (item, body) {
        return body ?? const SizedBox.shrink();
      },
    );
  }

  @override
  void onWindowResize() {
    setState(() {
      // 창 크기에 따라 네비게이션 모드 변경
      windowManager.getSize().then((size) {
        if (size.width < 900) {
          _isCompact = true;
        } else {
          _isCompact = false;
        }
      });
    });
  }
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage();

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  final _storageService = StorageService();
  String? _currentBannerUrl;
  bool _isLoading = true;
  bool _isUploading = false;

  String? _studentInfoExcelUrl;
  DateTime? _studentInfoExcelUploadedAt;
  bool _isUploadingStudentInfo = false;
  bool _isLoadingStudentInfoView = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentBanner();
    _loadStudentInfoExcelMeta();
  }

  Future<void> _loadCurrentBanner() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('home').get();
      if (doc.exists) {
        setState(() {
          _currentBannerUrl = doc.data()?['bannerImageUrl'] as String?;
        });
      }
    } catch (e) {
      debugPrint('배너 로드 오류: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadBanner() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;

    setState(() => _isUploading = true);
    try {
      final file = File(path);
      final downloadUrl = await _storageService.uploadHomeBanner(file);
      await FirebaseFirestore.instance.collection('settings').doc('home').set({
        'bannerImageUrl': downloadUrl,
      }, SetOptions(merge: true));
      setState(() => _currentBannerUrl = downloadUrl);
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => ContentDialog(
            title: const Text('완료'),
            content: const Text('배너 이미지가 성공적으로 업데이트되었습니다.'),
            actions: [
              FilledButton(child: const Text('확인'), onPressed: () => Navigator.pop(context)),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => ContentDialog(
            title: const Text('오류'),
            content: Text('배너 업로드 실패: $e'),
            actions: [Button(child: const Text('확인'), onPressed: () => Navigator.pop(context))],
          ),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _loadStudentInfoExcelMeta() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('home').get();
      if (doc.exists) {
        final data = doc.data();
        final ts = data?['studentInfoExcelUploadedAt'] as Timestamp?;
        setState(() {
          _studentInfoExcelUrl = data?['studentInfoExcelUrl'] as String?;
          _studentInfoExcelUploadedAt = ts?.toDate();
        });
      }
    } catch (e) {
      debugPrint('사생 기본 정보 엑셀 메타 로드 오류: $e');
    }
  }

  Future<void> _pickAndUploadStudentInfoExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;

    setState(() => _isUploadingStudentInfo = true);
    try {
      final file = File(path);
      final originalBytes = await file.readAsBytes();

      // 업로드 전 형식 검증 (.xlsx가 아니거나 손상된 파일이면 업로드하지 않음)
      Excel? excel;
      Object? decodeError;
      try {
        excel = Excel.decodeBytes(originalBytes);
      } catch (e) {
        decodeError = e;
      }

      // 엑셀이 아닌 프로그램(메신저 미리보기, 한컴/WPS, 변환기 등)으로 저장한 .xlsx는 같은 문자열이
      // 중복 등록되어 있어 엑셀 패키지가 읽지 못하는 경우가 있다. 중복을 정리한 사본으로 다시 시도하고,
      // 성공하면 정리된 파일을 올린다 (이 파일을 읽는 다른 화면과 층장앱도 함께 정상 동작하도록).
      var uploadFile = file;
      var repaired = false;
      if (excel == null) {
        for (final byText in [false, true]) {
          try {
            final fixed = dedupeSharedStrings(originalBytes, matchByText: byText);
            if (fixed == null) continue;
            final decoded = Excel.decodeBytes(fixed);
            final tmp = File(
                '${Directory.systemTemp.path}${Platform.pathSeparator}student_info_repaired.xlsx');
            await tmp.writeAsBytes(fixed, flush: true);
            excel = decoded;
            uploadFile = tmp;
            repaired = true;
            break;
          } catch (_) {}
        }
      }

      if (excel == null) {
        final detail = '$decodeError';
        if (mounted) {
          await displayInfoBar(
            context,
            builder: (context, close) => InfoBar(
              title: const Text('오류'),
              content: Text('엑셀 파일을 읽지 못했습니다. .xlsx 형식(구형 .xls 불가)이고 손상되지 않은 파일인지 '
                  '확인해주세요. 엑셀에서 열어 "다른 이름으로 저장(.xlsx)" 후 다시 시도하면 해결되는 경우가 많습니다.\n'
                  '(상세: ${detail.length > 120 ? '${detail.substring(0, 120)}…' : detail})'),
              severity: InfoBarSeverity.error,
              action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
            ),
          );
        }
        return;
      }

      final downloadUrl = await _storageService.uploadStudentInfoExcel(uploadFile);
      if (repaired) {
        try {
          await uploadFile.delete();
        } catch (_) {}
      }
      final now = Timestamp.now();
      await FirebaseFirestore.instance.collection('settings').doc('home').set({
        'studentInfoExcelUrl': downloadUrl,
        'studentInfoExcelUploadedAt': now,
      }, SetOptions(merge: true));
      setState(() {
        _studentInfoExcelUrl = downloadUrl;
        _studentInfoExcelUploadedAt = now.toDate();
      });
      // 학생앱 회원가입 시 "명단에 있는 학번인지" 확인하는 데 쓰는 학번 목록을 함께 갱신한다.
      final rosterCount = await _syncStudentRoster(excel);
      if (mounted) {
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: Text(rosterCount > 0 ? '완료' : '업로드 완료 (주의)'),
            content: Text(rosterCount > 0
                ? '사생 기본 정보 엑셀이 업로드되었습니다. (회원가입 검증용 학번 $rosterCount건 반영)'
                    '${repaired ? '\n파일 안의 중복 문자열을 자동으로 정리해서 올렸습니다.' : ''}'
                : '엑셀은 업로드되었지만 학번 열을 찾지 못해 회원가입 검증용 학번 명단은 갱신하지 않았습니다.'),
            severity: rosterCount > 0 ? InfoBarSeverity.success : InfoBarSeverity.warning,
            action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('오류'),
            content: Text('엑셀 업로드 실패: $e'),
            severity: InfoBarSeverity.error,
            action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingStudentInfo = false);
    }
  }

  /// 엑셀의 학번을 student_roster/{학번} 문서로 동기화한다 (학생앱 회원가입 시 명단 확인용).
  /// 학번 외 개인정보는 저장하지 않고, 이번 엑셀에 없는 학번 문서는 지워 명단을 최신 상태로 맞춘다.
  /// 학번을 하나도 찾지 못하면(열 인식 실패 등) 기존 명단을 건드리지 않고 0을 반환한다.
  Future<int> _syncStudentRoster(Excel excel) async {
    final sheet = excel.sheets.values.first;
    final rows = sheet.rows
        .map((row) => row.map((cell) => cell?.value?.toString() ?? '').toList())
        .toList();
    if (rows.isEmpty) return 0;
    final headerIdx = ExcelStudentRow.findHeaderRowIndex(rows);
    final header = rows[headerIdx];
    final ids = <String>{};
    for (final row in rows.skip(headerIdx + 1)) {
      // 숫자 셀은 '2026123456.0'처럼 읽힐 수 있어 소수점 이하를 떼어낸다.
      final id = (ExcelStudentRow.fromRow(header, row).studentId ?? '')
          .trim()
          .replaceFirst(RegExp(r'\.0+$'), '');
      if (id.isNotEmpty) ids.add(id);
    }
    if (ids.isEmpty) return 0;

    final firestore = FirebaseFirestore.instance;
    final col = firestore.collection('student_roster');
    final existing = await col.get();
    var batch = firestore.batch();
    var ops = 0;
    Future<void> flushIfFull() async {
      // Firestore batch는 500건 제한이 있어 넉넉히 400건마다 커밋한다.
      if (ops >= 400) {
        await batch.commit();
        batch = firestore.batch();
        ops = 0;
      }
    }

    for (final doc in existing.docs) {
      if (doc.id == '_meta' || ids.contains(doc.id)) continue;
      batch.delete(doc.reference);
      ops++;
      await flushIfFull();
    }
    for (final id in ids) {
      batch.set(col.doc(id), {'updatedAt': FieldValue.serverTimestamp()});
      ops++;
      await flushIfFull();
    }
    batch.set(col.doc('_meta'), {
      'count': ids.length,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return ids.length;
  }

  Future<void> _viewStudentInfoExcel() async {
    if (_studentInfoExcelUrl == null) {
      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('알림'),
          content: const Text('업로드된 사생 기본 정보 엑셀이 없습니다.'),
          severity: InfoBarSeverity.warning,
          action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
        ),
      );
      return;
    }

    setState(() => _isLoadingStudentInfoView = true);
    try {
      final response = await http.get(Uri.parse(_studentInfoExcelUrl!));
      if (response.statusCode != 200) {
        throw Exception('파일 다운로드 실패 (${response.statusCode})');
      }
      final excel = Excel.decodeBytes(response.bodyBytes);
      final sheet = excel.sheets.values.first;
      final rows = sheet.rows
          .map((row) => row.map((cell) => cell?.value?.toString() ?? '').toList())
          .toList();

      if (!mounted) return;
      if (rows.isEmpty) {
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('알림'),
            content: const Text('엑셀 파일에 데이터가 없습니다.'),
            severity: InfoBarSeverity.warning,
            action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
          ),
        );
        return;
      }

      // 엑셀 첫 줄이 '2026학년도 2학기 학생정보' 같은 제목 행일 수 있으므로,
      // '학번' 열이 있는 행을 실제 헤더로 찾는다. (없으면 첫 줄을 헤더로 사용)
      int headerRowIndex = rows.indexWhere(
        (r) => r.any((h) => h.replaceAll(' ', '').contains('학번')),
      );
      if (headerRowIndex == -1) headerRowIndex = 0;

      final excelHeader = rows[headerRowIndex];
      final excelDataRows = rows.skip(headerRowIndex + 1).toList();

      // 학번 열 인덱스 탐색 (공백 제거 후 비교)
      final studentIdColIndex = excelHeader.indexWhere((h) => h.replaceAll(' ', '').contains('학번'));

      // users 컬렉션 전체를 학번 기준으로 조회 (인실/학과/휴대폰/자리번호 조인용)
      final Map<String, Map<String, dynamic>> usersByStudentId = {};
      if (studentIdColIndex != -1) {
        final usersSnap = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'student')
            .get();
        for (final doc in usersSnap.docs) {
          // 필드가 하나도 없는 문서는 data()가 null을 반환해 크래시하므로 건너뛴다.
          final userData = doc.data() as Map<String, dynamic>?;
          if (userData == null) continue;
          final sid = userData['studentId']?.toString().trim() ?? '';
          if (sid.isNotEmpty) usersByStudentId[sid] = userData;
        }
      }

      // 엑셀 원본에 이미 있는 열은 앱에서 다시 붙이지 않는다.
      // (엑셀에 '인실/학과/휴대폰/자리번호'가 이미 있어 중복 표시되던 문제)
      String norm(String s) => s.replaceAll(RegExp(r'\s+'), '');
      bool excelHas(List<String> keywords) =>
          excelHeader.any((h) => keywords.any((k) => norm(h).contains(k)));

      final extraLabels = <String>[];
      final extraGetters = <String Function(UserModel)>[];
      void addExtra(String label, List<String> keys, String Function(UserModel) get) {
        if (excelHas(keys)) return;
        extraLabels.add(label);
        extraGetters.add(get);
      }

      addExtra('인실', ['인실'], (u) => u.roomCapacity);
      addExtra('학과', ['학과', '학부'], (u) => u.department ?? '');
      addExtra('휴대폰', ['휴대폰', '전화'], (u) => u.phoneNumber);
      addExtra('자리번호', ['자리번호'], (u) => u.seatNumber ?? '');

      final header = studentIdColIndex != -1
          ? [...excelHeader, ...extraLabels]
          : excelHeader;

      // 학번이 users에 존재하는지를 별도로 기록한다.
      // (조회된 값이 비어 있어도 '매칭'은 성공한 것으로 세야 한다)
      final matchedFlags = <bool>[];
      final dataRows = excelDataRows.map((row) {
        if (studentIdColIndex == -1) {
          matchedFlags.add(false);
          return row;
        }
        final sid = (studentIdColIndex < row.length ? row[studentIdColIndex] : '').trim();
        final userData = usersByStudentId[sid];
        matchedFlags.add(userData != null);
        if (userData == null) {
          return [...row, ...extraLabels.map((_) => '')];
        }
        final user = UserModel.fromMap(userData);
        return [...row, ...extraGetters.map((g) => g(user))];
      }).toList();

      final matchedCount = matchedFlags.where((m) => m).length;

      await showDialog(
        context: context,
        builder: (dialogContext) {
          final screenSize = MediaQuery.of(dialogContext).size;
          final dialogWidth = (screenSize.width * 0.9).clamp(600.0, 1400.0);
          final dialogHeight = (screenSize.height * 0.85).clamp(400.0, 900.0);
          return ContentDialog(
            constraints: BoxConstraints(maxWidth: dialogWidth, maxHeight: dialogHeight),
            title: const Text('사생 기본 정보'),
            content: SizedBox(
              width: dialogWidth - 40,
              height: dialogHeight - 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (studentIdColIndex != -1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '학번 매칭: $matchedCount / ${dataRows.length}명 (인실/학과/휴대폰/자리번호 조회됨)',
                        style: TextStyle(fontSize: 12, color: Colors.grey[100]),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '엑셀에서 "학번" 열을 찾지 못해 추가 정보를 표시할 수 없습니다.',
                        style: TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columnSpacing: 10,
                          horizontalMargin: 8,
                          headingRowHeight: 36,
                          dataRowMinHeight: 32,
                          dataRowMaxHeight: 40,
                          columns: header
                              .map(
                                (h) => DataColumn(
                                  label: Text(
                                    h,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          rows: dataRows
                              .map(
                                (row) => DataRow(
                                  cells: List.generate(
                                    header.length,
                                    (i) => DataCell(
                                      Text(
                                        i < row.length ? row[i] : '',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('닫기')),
            ],
          );
        },
      );
    } catch (e) {
      if (mounted) {
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('오류'),
            content: Text('엑셀 파일을 불러오는 중 오류가 발생했습니다: $e'),
            severity: InfoBarSeverity.error,
            action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingStudentInfoView = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: const PageHeader(title: Text('설정')),
      content: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 홈 배너 이미지 설정
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(FluentIcons.picture_fill),
                        SizedBox(width: 8),
                        Text(
                          '홈 배너 이미지',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '학생 앱 홈 화면에 표시될 배너 이미지를 설정합니다.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      const Center(child: ProgressRing())
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 현재 배너 미리보기 (실제 배너는 1080x1920 세로형이므로 9:16 비율로 보여준다)
                          Container(
                            width: 180,
                            height: 320,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                              borderRadius: BorderRadius.circular(4),
                              color: Colors.grey.withValues(alpha: 0.1),
                            ),
                            child: _currentBannerUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(
                                      _currentBannerUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Center(
                                        child: Icon(FluentIcons.picture_fill, size: 40),
                                      ),
                                    ),
                                  )
                                : const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(FluentIcons.picture_fill, size: 40),
                                        SizedBox(height: 8),
                                        Text('배너 이미지 없음'),
                                      ],
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 24),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('권장 크기: 1080 x 1920px (세로형)'),
                              const Text('지원 형식: JPG, PNG, WEBP'),
                              const SizedBox(height: 16),
                              if (_isUploading)
                                const Row(
                                  children: [ProgressRing(), SizedBox(width: 12), Text('업로드 중...')],
                                )
                              else
                                FilledButton(
                                  onPressed: _pickAndUploadBanner,
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(FluentIcons.upload, size: 16),
                                      SizedBox(width: 8),
                                      Text('이미지 선택 및 업로드'),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 사생 기본 정보
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(FluentIcons.excel_document),
                        SizedBox(width: 8),
                        Text(
                          '사생 기본 정보',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _studentInfoExcelUploadedAt != null
                          ? '마지막 업로드: ${_studentInfoExcelUploadedAt!.toString().substring(0, 16)}'
                          : '업로드된 사생 기본 정보 엑셀이 없습니다.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (_isUploadingStudentInfo)
                          const Row(
                            children: [ProgressRing(), SizedBox(width: 12), Text('업로드 중...')],
                          )
                        else
                          FilledButton(
                            onPressed: _pickAndUploadStudentInfoExcel,
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(FluentIcons.upload, size: 16),
                                SizedBox(width: 8),
                                Text('엑셀업로드'),
                              ],
                            ),
                          ),
                        const SizedBox(width: 12),
                        Button(
                          onPressed: _isLoadingStudentInfoView ? null : _viewStudentInfoExcel,
                          child: _isLoadingStudentInfoView
                              ? const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: ProgressRing(strokeWidth: 2),
                                    ),
                                    SizedBox(width: 8),
                                    Text('불러오는 중...'),
                                  ],
                                )
                              : const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(FluentIcons.table, size: 16),
                                    SizedBox(width: 8),
                                    Text('사생기본 정보 보기'),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Icon(FluentIcons.info),
                title: const Text('버전 정보'),
                subtitle: const Text('SWU 샬롬하우스 관리 시스템 v1.0.0'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
