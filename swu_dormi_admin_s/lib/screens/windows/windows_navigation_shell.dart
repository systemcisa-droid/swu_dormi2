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
import 'package:swu_dormi_admin/services/auth_service.dart';
import 'package:swu_dormi_admin/screens/windows/windows_student_council_screen.dart';
import 'package:swu_dormi_admin/screens/windows/windows_login_screen.dart';

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
        icon: const Icon(FluentIcons.megaphone),
        title: const Text('공지'),
        body: const WindowsCouncilNoticesTabScreen(),
        selectedTileColor: WidgetStateProperty.all(Colors.purple.withValues(alpha: 0.1)),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.party_leader),
        title: const Text('캠페인'),
        body: const WindowsCouncilCampaignsTabScreen(),
        selectedTileColor: WidgetStateProperty.all(Colors.purple.withValues(alpha: 0.1)),
      ),
      PaneItem(
        icon: const Icon(FluentIcons.check_list),
        title: const Text('선거'),
        body: const WindowsCouncilElectionsTabScreen(),
        selectedTileColor: WidgetStateProperty.all(Colors.purple.withValues(alpha: 0.1)),
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
              const Text('서울여자대학교 기숙사 사생회'),
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
