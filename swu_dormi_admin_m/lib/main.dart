import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/fcm_service.dart';
import 'constants/floor_captain_accounts.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/privacy_consent_screen.dart';
import 'screens/facilities/facilities_management_screen.dart';
import 'screens/cleaning/cleaning_inspection_screen.dart';
import 'screens/attendance/attendance_screen.dart';
import 'screens/message/message_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/students/students_management_screen.dart';
import 'screens/checklist/checklist_screen.dart';
import 'screens/intern/intern_log_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // [디버그] Firebase 초기화 직후 로컬에 복원된 세션이 있는지 확인.
    // null이면 이 시점에 이미 세션이 없다는 뜻이므로 Firebase Auth persistence
    // 자체의 문제로 확정할 수 있다.
    debugPrint('[Auth디버그] Firebase.initializeApp 직후 currentUser='
        '${FirebaseAuth.instance.currentUser?.email ?? "null"}');
    // 한국어 locale 초기화
    await initializeDateFormatting('ko_KR', null);
    // FCM 초기화
    await FcmService().initialize();
  } catch (e) {
    debugPrint('Firebase 초기화 오류: $e');
  }

  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '샬롬하우스 관리',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
      ],
      locale: const Locale('ko', 'KR'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFA6BF96),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Color(0xFFA6BF96),
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

// 인증 래퍼 위젯
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _authService = AuthService();
  bool _privacyAgreed = false;
  bool _checkingPrivacy = true;

  // authStateChanges()는 호출할 때마다 새 Stream 인스턴스를 반환하므로,
  // build()에서 매번 새로 얻으면 StreamBuilder가 재구독되어 기존 로그인 상태를
  // 잃어버리고(ConnectionState.waiting) 새 스트림의 첫 이벤트를 기다리게 된다.
  // 이 첫 이벤트가 세션 복원 전 null이면 그대로 로그인 화면에 머물러
  // "재실행 시 자동 로그아웃"처럼 보이는 문제가 생길 수 있어 한 번만 생성해 캐싱한다.
  late final Stream<User?> _authStateChanges = _authService.authStateChanges;

  // 이용 정지 여부 확인 Future도 build()마다 새로 생성되면 FutureBuilder가
  // 매번 재시작되어 화면이 깜빡이거나 불필요한 Firestore 조회가 반복되므로,
  // 로그인 상태가 확인된 시점에 한 번만 생성해 캐싱한다.
  Future<bool>? _disabledCheckFuture;

  @override
  void initState() {
    super.initState();
    _checkPrivacyAgreement();
  }

  Future<void> _checkPrivacyAgreement() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _privacyAgreed = prefs.getBool('privacy_policy_agreed') ?? false;
        _checkingPrivacy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingPrivacy) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_privacyAgreed) {
      return PrivacyConsentScreen(
        onAgreed: () => setState(() => _privacyAgreed = true),
      );
    }

    return StreamBuilder<User?>(
      stream: _authStateChanges,
      // FirebaseAuth가 세션 복원을 완료하기 전 스트림의 첫 이벤트를 기다리는
      // 동안에도, 이미 기기에 저장된 세션이 있다면 currentUser로 즉시 알 수
      // 있다. 이 값을 initialData로 주면 그 대기 구간에 로그인 화면이
      // 잠깐 보였다가 사라지는 깜빡임(체감상 "자동 로그아웃")을 막을 수 있다.
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        // [디버그] 스트림이 실제로 방출하는 값과 연결 상태를 확인한다.
        debugPrint('[Auth디버그] StreamBuilder state=${snapshot.connectionState} '
            'hasData=${snapshot.hasData} email=${snapshot.data?.email ?? "null"}');
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          // 이용 정지된 계정이면 즉시 로그아웃 (App Store 가이드라인 1.2)
          // Future는 로그인 상태가 확인될 때 한 번만 생성해 캐싱한다(매 build마다
          // 재생성하면 FutureBuilder가 재시작되어 화면이 깜빡일 수 있음).
          _disabledCheckFuture ??= _authService.isCurrentUserDisabled();
          return FutureBuilder<bool>(
            future: _disabledCheckFuture,
            builder: (context, disabledSnap) {
              if (disabledSnap.data == true) {
                _authService.signOut();
                return const LoginScreen();
              }
              return const NavigationShell();
            },
          );
        }

        // 로그아웃 상태로 돌아왔으므로 다음 로그인 시 이용 정지 여부를
        // 다시 확인할 수 있도록 캐시를 초기화한다.
        _disabledCheckFuture = null;
        return const LoginScreen();
      },
    );
  }
}

// 네비게이션 쉘 (하단 네비게이션 바 + 드로어 메뉴)
class NavigationShell extends StatefulWidget {
  const NavigationShell({super.key});

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  int _currentIndex = 0;
  String? _assignedFloor;
  String? _defaultFloor;
  String? _userName;
  String? _userId;
  int _totalUnreadMessages = 0;
  int _totalMessages = 0;
  final List<StreamSubscription<QuerySnapshot>> _unreadSubs = [];

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _subscribeUnread();
    // 로그인 완료 시점에 FCM 토큰 저장
    FcmService().saveTokenAfterLogin();
  }

  @override
  void dispose() {
    for (final s in _unreadSubs) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> _subscribeUnread() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // 층장 assignedFloor 기반으로 담당 호실 목록 파악
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final assignedFloor = userDoc.data()?['assignedFloor'] as String?;
    if (assignedFloor == null) return;

    final wingMatch = RegExp(r'[A-Z]동').firstMatch(assignedFloor);
    final floorMatch = RegExp(r'(\d+)층').firstMatch(assignedFloor);
    String dormBuilding;
    if (assignedFloor.startsWith('샬롬하우스(방학)')) {
      dormBuilding = '샬롬하우스(방학)';
    } else if (assignedFloor.startsWith('샬롬하우스')) {
      dormBuilding = '샬롬하우스';
    } else if (assignedFloor.startsWith('국제생활관(방학)')) {
      dormBuilding = '국제생활관(방학)';
    } else if (assignedFloor.startsWith('국제생활관')) {
      dormBuilding = '국제생활관';
    } else if (assignedFloor.startsWith('바롬인성교육관')) {
      dormBuilding = '바롬인성교육관';
    } else {
      return;
    }
    final building = wingMatch?.group(0) ?? '';
    final floorNum = floorMatch != null ? int.tryParse(floorMatch.group(1)!) ?? 0 : 0;
    if (building.isEmpty || floorNum == 0) return;

    var query = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'student')
        .where('dormBuilding', isEqualTo: dormBuilding)
        .where('building', isEqualTo: building);

    final snap = await query.get();
    final roomIds = <String>{};
    for (final doc in snap.docs) {
      final room = doc.data()['roomNumber'] as String? ?? '';
      if (room.isEmpty || room == '000') continue;
      if ((int.tryParse(room) ?? 0) ~/ 100 == floorNum) {
        roomIds.add('${dormBuilding}_${building}_$room호');
      }
    }
    debugPrint('[Unread] 구독 호실 수: ${roomIds.length} / $roomIds');

    // 각 호실별 미확인/전체 메시지 수를 Map으로 관리
    final Map<String, int> roomUnread = {};
    final Map<String, int> roomTotal = {};
    final Map<String, bool> roomInitialized = {};

    for (final roomId in roomIds) {
      final sub = FirebaseFirestore.instance
          .collection('floor_chats')
          .doc(roomId)
          .collection('messages')
          .where('senderId', isNotEqualTo: uid)
          .snapshots()
          .listen((snap) async {
        int unread = 0;
        for (final doc in snap.docs) {
          final readBy = (doc.data()['readBy'] as List<dynamic>?) ?? [];
          if (!readBy.contains(uid)) unread++;
        }
        final prev = roomUnread[roomId] ?? 0;
        final alreadyInit = roomInitialized[roomId] ?? false;
        roomUnread[roomId] = unread;
        roomTotal[roomId] = snap.docs.length;
        roomInitialized[roomId] = true;

        debugPrint('[Unread] $roomId → unread=$unread, prev=$prev, alreadyInit=$alreadyInit');

        // 초기 스냅샷 이후 미읽음이 증가했을 때만 진동
        if (alreadyInit && unread > prev) {
          debugPrint('[Unread] 진동 조건 충족 → 설정 확인 중');
          final prefs = await SharedPreferences.getInstance();
          final vibOn = prefs.getBool('chat_vibration') ?? true;
          final hasVibrator = (await Vibration.hasVibrator()) == true;
          debugPrint('[Unread] chat_vibration=$vibOn, hasVibrator=$hasVibrator');
          if (vibOn && hasVibrator) Vibration.vibrate(duration: 300);
        }

        if (mounted) {
          setState(() {
            _totalUnreadMessages = roomUnread.values.fold(0, (a, b) => a + b);
            _totalMessages = roomTotal.values.fold(0, (a, b) => a + b);
          });
        }
      });
      _unreadSubs.add(sub);
    }
  }

  Future<void> _loadUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final email = user.email;
    String? floor;
    String? name;
    String? studentId;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data();
        floor = data?['assignedFloor'] as String?;
        _defaultFloor = (data?['defaultFloor'] as String?)
            ?? kFloorCaptainAccounts[email];
        name = data?['name'] as String?;
        studentId = data?['studentId'] as String?;
      }
    } catch (_) {}

    name ??= user.displayName ?? (email?.split('@').first ?? '관리자');
    final displayId = (studentId != null && studentId.isNotEmpty)
        ? studentId
        : (email ?? user.uid);

    if (mounted) {
      setState(() {
        _assignedFloor = floor;
        _userName = name;
        _userId = displayId;
      });
    }
  }

  final _monthlyKey = GlobalKey<CleaningInspectionScreenState>();
  final _moveOutKey = GlobalKey<CleaningInspectionScreenState>();

  List<Widget> get _screens => [
    HomeScreen(
      assignedFloor: _assignedFloor,
      userName: _userName,
      totalUnreadMessages: _totalUnreadMessages,
      totalMessages: _totalMessages,
      onNavigate: (index) => setState(() => _currentIndex = index),
    ),
    const StudentsManagementScreen(),
    const FacilitiesManagementScreen(),
    CleaningInspectionScreen(key: _monthlyKey, inspectionType: 'monthly'),
    CleaningInspectionScreen(key: _moveOutKey, inspectionType: 'move_out'),
    const AttendanceScreen(),
    const ChecklistScreen(),
    const InternLogScreen(),
    const MessageScreen(),
    const ProfileScreen(),
  ];

  final List<String> _titles = [
    '행정실(2학기)',
    '학생 관리',
    '수리 보수',
    '월청소 점검',
    '퇴사청소 점검',
    '인원점검(화재대피훈련)',
    '관내점검표',
    '인턴근무일지',
    '층장단톡방',
    '프로필',
  ];


  void _navigateTo(int index) {
    // 청소 페이지 간 이동 시 탭을 스케줄 목록(첫 번째 탭)으로 초기화
    if (index == 3) _monthlyKey.currentState?.resetToFirstTab();
    if (index == 4) _moveOutKey.currentState?.resetToFirstTab();
    setState(() => _currentIndex = index);
    Navigator.pop(context); // 드로어 닫기
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_titles[_currentIndex]),
            if (_assignedFloor != null)
              Text(
                (_defaultFloor != null && _defaultFloor != _assignedFloor)
                    ? '$_assignedFloor($_defaultFloor)'
                    : _assignedFloor!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
        actions: [
          if (_totalUnreadMessages > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline),
                    onPressed: () {
                      setState(() => _currentIndex = 8);
                    },
                    tooltip: '층장단톡방',
                  ),
                  Positioned(
                    top: 6,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        _totalUnreadMessages > 99 ? '99+' : '$_totalUnreadMessages',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      onDrawerChanged: (isOpen) {
        if (!isOpen) _loadUserInfo();
      },
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFFA6BF96)),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.account_circle, color: Colors.white, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      _userName != null && _userName!.isNotEmpty ? '$_userName 님' : '관리자 님',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (_userId != null && _userId!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '아이디: $_userId',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                    if (_assignedFloor != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        (_defaultFloor != null && _defaultFloor != _assignedFloor)
                            ? '$_assignedFloor($_defaultFloor)'
                            : _assignedFloor!,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _DrawerItem(
              icon: Icons.home_outlined,
              label: '행정실(2학기)',
              selected: _currentIndex == 0,
              onTap: () => _navigateTo(0),
            ),
            _DrawerItem(
              icon: Icons.people,
              label: '학생 관리',
              selected: _currentIndex == 1,
              onTap: () => _navigateTo(1),
            ),
            _DrawerItem(
              icon: Icons.build,
              label: '수리 보수',
              selected: _currentIndex == 2,
              onTap: () => _navigateTo(2),
            ),
            _DrawerItem(
              icon: Icons.cleaning_services,
              label: '월청소 점검',
              selected: _currentIndex == 3,
              onTap: () => _navigateTo(3),
            ),
            _DrawerItem(
              icon: Icons.exit_to_app,
              label: '퇴사청소 점검',
              selected: _currentIndex == 4,
              onTap: () => _navigateTo(4),
            ),
            _DrawerItem(
              icon: Icons.qr_code_scanner,
              label: '인원점검(화재대피훈련)',
              selected: _currentIndex == 5,
              onTap: () => _navigateTo(5),
            ),
            const Divider(),
            _DrawerItem(
              icon: Icons.checklist_rtl,
              label: '관내점검표',
              selected: _currentIndex == 6,
              onTap: () => _navigateTo(6),
            ),
            _DrawerItem(
              icon: Icons.assignment,
              label: '인턴근무일지',
              selected: _currentIndex == 7,
              onTap: () => _navigateTo(7),
            ),
            _DrawerItem(
              icon: Icons.chat_bubble_outline,
              label: '층장단톡방',
              selected: _currentIndex == 8,
              onTap: () => _navigateTo(8),
              badgeCount: _totalUnreadMessages,
            ),
            _DrawerItem(
              icon: Icons.person,
              label: '프로필',
              selected: _currentIndex == 9,
              onTap: () => _navigateTo(9),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      body: SafeArea(child: _screens[_currentIndex]),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFFA6BF96) : null;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      trailing: badgeCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            )
          : null,
      selected: selected,
      selectedTileColor: const Color(0xFFA6BF96).withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: onTap,
    );
  }

}