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
import 'package:swu_dormi_admin/screens/windows/windows_dashboard.dart';
import 'package:swu_dormi_admin/screens/windows/windows_notices_screen.dart';
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
        title: const Text('출석체크'),
        body: const WindowsAttendanceTabScreen(),
        selectedTileColor: WidgetStateProperty.all(Colors.purple.withValues(alpha: 0.1)),
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
              const Text('샬롬하우스 관리 시스템'),
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

      // 업로드 전 형식 검증 (.xlsx가 아니거나 손상된 파일이면 업로드하지 않음)
      try {
        Excel.decodeBytes(await file.readAsBytes());
      } catch (_) {
        if (mounted) {
          await displayInfoBar(
            context,
            builder: (context, close) => InfoBar(
              title: const Text('오류'),
              content: const Text('.xlsx 형식의 엑셀 파일만 업로드할 수 있습니다. (구형 .xls 파일은 지원하지 않습니다)'),
              severity: InfoBarSeverity.error,
              action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
            ),
          );
        }
        return;
      }

      final downloadUrl = await _storageService.uploadStudentInfoExcel(file);
      final now = Timestamp.now();
      await FirebaseFirestore.instance.collection('settings').doc('home').set({
        'studentInfoExcelUrl': downloadUrl,
        'studentInfoExcelUploadedAt': now,
      }, SetOptions(merge: true));
      setState(() {
        _studentInfoExcelUrl = downloadUrl;
        _studentInfoExcelUploadedAt = now.toDate();
      });
      if (mounted) {
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('완료'),
            content: const Text('사생 기본 정보 엑셀이 업로드되었습니다.'),
            severity: InfoBarSeverity.success,
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

      final excelHeader = rows.first;
      final excelDataRows = rows.skip(1).toList();

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
          final sid = doc.data()['studentId']?.toString().trim() ?? '';
          if (sid.isNotEmpty) usersByStudentId[sid] = doc.data();
        }
      }

      const extraColumns = ['인실', '학과', '휴대폰', '자리번호'];
      final header = studentIdColIndex != -1 ? [...excelHeader, ...extraColumns] : excelHeader;
      final dataRows = excelDataRows.map((row) {
        if (studentIdColIndex == -1) return row;
        final sid = (studentIdColIndex < row.length ? row[studentIdColIndex] : '').trim();
        final userData = usersByStudentId[sid];
        if (userData == null) {
          return [...row, '', '', '', ''];
        }
        final user = UserModel.fromMap(userData);
        return [
          ...row,
          user.roomCapacity,
          user.department ?? '',
          user.phoneNumber,
          user.seatNumber ?? '',
        ];
      }).toList();

      final matchedCount = dataRows.where((row) {
        if (studentIdColIndex == -1) return false;
        final extraStart = excelHeader.length;
        return extraStart < row.length && row[extraStart].isNotEmpty;
      }).length;

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
                          columnSpacing: 20,
                          horizontalMargin: 12,
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
                          // 현재 배너 미리보기
                          Container(
                            width: 320,
                            height: 180,
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
