import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/notification_service.dart';
import '../../utils/home_strings.dart';
import '../../utils/notification_prefs.dart';
import '../notices/notices_screen.dart';
import '../check_in_out/check_in_out_screen.dart';
import '../student_council/student_council_screen.dart';
import '../facilities/facility_report_screen.dart';
import '../profile/profile_screen.dart';
import '../notification/notification_screen.dart';
import '../profile/regulation_screen.dart';
import '../board/board_meal_screen.dart';
import '../cleaning/cleaning_inspection_screen.dart';
import '../cleaning/move_out_inspection_screen.dart';
import '../message/floor_chat_screen.dart';
import '../attendance/attendance_screen.dart';
import '../attendance/my_qr_code_page.dart';
import '../reservation/reservation_screen.dart';
import '../timetable/timetable_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  StreamSubscription<QuerySnapshot>? _chatSubscription;
  bool _isFirstSnapshot = true;
  bool _isRedLogo = true;
  String? _bannerImageUrl;
  int _unreadChatCount = 0;
  /// 사생수칙 동의서 제출 여부 (미제출 시 일부 메뉴 사용 불가)
  bool _hasRegulationAgreement = false;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _setupNotificationListener();
    _setupChatListener();
    _loadBannerImage();
    _loadRegulationAgreement();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowPopupNotice();
    });
  }

  /// 사생수칙 동의서 제출 여부를 확인한다.
  Future<void> _loadRegulationAgreement() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('regulation_agreements')
          .doc(user.uid)
          .get();
      if (mounted) {
        setState(() => _hasRegulationAgreement = doc.exists);
      }
    } catch (e) {
      debugPrint('사생수칙 동의 확인 오류: $e');
    }
  }

  /// 동의서를 제출했는지 확인하고, 미제출이면 안내 후 false 를 반환한다.
  Future<bool> _requireRegulationAgreement() async {
    if (_hasRegulationAgreement) return true;

    // 다른 기기에서 제출했을 수 있으므로 한 번 더 확인한다.
    await _loadRegulationAgreement();
    if (_hasRegulationAgreement) return true;

    if (!mounted) return false;
    final s = HomeStrings(
        Provider.of<LocaleProvider>(context, listen: false).isEnglish);
    final goToRegulation = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.regulationRequiredTitle),
        content: Text(s.regulationRequiredContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.regulationRequiredClose),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.regulationRequiredGo),
          ),
        ],
      ),
    );

    if (goToRegulation == true && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const RegulationScreen()),
      );
      // 동의서를 제출하고 돌아왔을 수 있으므로 다시 확인한다.
      await _loadRegulationAgreement();
    }
    return false;
  }

  /// 프로필에 기숙사 건물·호실·자리 번호가 모두 등록되어 있는지 확인하고,
  /// 빠진 항목이 있으면 안내 후 false 를 반환한다.
  /// 층장이 QR을 스캔할 때 학생 호실을 대조하므로 이 정보가 없으면 출석 처리가 어긋난다.
  Future<bool> _requireCompleteProfile() async {
    final user =
        Provider.of<AuthProvider>(context, listen: false).currentUser;
    final s = HomeStrings(
        Provider.of<LocaleProvider>(context, listen: false).isEnglish);
    final roomNumber = user?.roomNumber.trim() ?? '';
    final missing = <String>[
      if ((user?.dormBuilding ?? '').trim().isEmpty) s.profileFieldDormBuilding,
      // '000' 은 가입 시 채워지는 기본값이라 미등록으로 본다.
      if (roomNumber.isEmpty || roomNumber == '000') s.profileFieldRoomNumber,
      if ((user?.seatNumber ?? '').trim().isEmpty) s.profileFieldSeatNumber,
    ];
    if (missing.isEmpty) return true;

    if (!mounted) return false;
    final goToProfile = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.profileRequiredTitle),
        content: Text(s.profileRequiredContent(missing.join(', '))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.profileRequiredClose),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.profileRequiredGo),
          ),
        ],
      ),
    );

    if (goToProfile == true && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    }
    return false;
  }

  Future<void> _checkAndShowPopupNotice() async {
    // await 이후 context 접근을 피하기 위해 먼저 확보한다.
    final s = HomeStrings(
        Provider.of<LocaleProvider>(context, listen: false).isEnglish);
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final hiddenDate = prefs.getString('hide_popup_notice_date');

      if (hiddenDate == todayStr) {
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('popup_notice')
          .get();

      if (!doc.exists || !mounted) return;

      final data = doc.data();
      if (data == null) return;

      final isEnabled = data['isEnabled'] as bool? ?? false;
      if (!isEnabled) return;

      final title = (data['title'] as String?) ?? s.popupNoticeDefaultTitle;
      final content = (data['content'] as String?) ?? '';
      final imageUrl = data['imageUrl'] as String?;

      if (!mounted) return;

      _showNoticePopupDialog(
        title: title,
        content: content,
        imageUrl: imageUrl,
        todayStr: todayStr,
        s: s,
      );
    } catch (e) {
      debugPrint('팝업 공지 로드 오류: $e');
    }
  }

  void _showNoticePopupDialog({
    required String title,
    required String content,
    String? imageUrl,
    required String todayStr,
    required HomeStrings s,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.campaign, color: Color(0xFFB13B3B), size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        content,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('hide_popup_notice_date', todayStr);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Text(
                        s.popupNoticeHideToday,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  Container(width: 1, height: 44, color: Colors.grey.shade300),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        s.popupNoticeClose,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadBannerImage() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('home')
          .get();
      if (doc.exists && mounted) {
        final url = doc.data()?['bannerImageUrl'] as String?;
        if (url != null && url.isNotEmpty) {
          setState(() => _bannerImageUrl = url);
        }
      }
    } catch (e) {
      debugPrint('배너 이미지 로드 오류: $e');
    }
  }

  Future<void> _initializeNotifications() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user != null) {
      await NotificationService().initialize(user.uid);
      // 알림 설정이 아직 없으면 기본값을 저장해 둔다.
      await NotificationPrefs.ensureInitialized(user.uid);
    }
  }

  void _setupNotificationListener() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) return;

    _notificationSubscription = FirebaseFirestore.instance
        .collection('user_notifications')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .listen((snapshot) {
      if (_isFirstSnapshot) {
        _isFirstSnapshot = false;
        return;
      }

      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            // 알림 종류별 수신 설정이 꺼져 있으면 진동/토스트를 띄우지 않는다.
            // (알림 문서 자체는 남아 알림 목록에서 확인할 수 있다)
            NotificationPrefs.isEnabled(data['type'] as String?).then((enabled) {
              if (!enabled || !mounted) return;
              final title = data['title'] ?? '새로운 알림';
              final content = data['content'] ?? '';
              _triggerVibration();
              Fluttertoast.showToast(
                msg: '📢 $title\n$content',
                toastLength: Toast.LENGTH_LONG,
                gravity: ToastGravity.TOP,
                timeInSecForIosWeb: 4,
                backgroundColor: Colors.black87,
                textColor: Colors.white,
                fontSize: 15.0,
              );
            });
          }
        }
      }
    }, onError: (error) {
      debugPrint('알림 리스너 오류: $error');
    });
  }

  void _setupChatListener() {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;
    final roomId = buildRoomId(user.dormBuilding, user.building, user.roomNumber);
    if (roomId == null) return;

    bool chatInitialized = false;
    int prevCount = 0;

    _chatSubscription = FirebaseFirestore.instance
        .collection('floor_chats')
        .doc(roomId)
        .collection('messages')
        .snapshots()
        .listen((snap) async {
      int count = 0;
      for (final doc in snap.docs) {
        final readBy = (doc.data()['readBy'] as List<dynamic>?) ?? [];
        if (!readBy.contains(user.uid)) count++;
      }

      // 초기 스냅샷 이후 미읽음이 증가했을 때만 진동
      if (chatInitialized && count > prevCount) {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool('message_notifications') ?? true) {
          if ((await Vibration.hasVibrator()) == true) {
            Vibration.vibrate(pattern: [0, 200, 100, 200]);
          }
        }
      }
      chatInitialized = true;
      prevCount = count;

      if (mounted) setState(() => _unreadChatCount = count);
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _chatSubscription?.cancel();
    super.dispose();
  }

  Future<void> _triggerVibration() async {
    try {
      if ((await Vibration.hasVibrator()) == true) {
        await Vibration.vibrate(pattern: [0, 200, 100, 200]);
      }
    } catch (e) {
      debugPrint('진동 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final localeProvider = Provider.of<LocaleProvider>(context);
    final s = HomeStrings(localeProvider.isEnglish);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        centerTitle: true,
        title: _buildLogo(),
        actions: [
          if (_unreadChatCount > 0)
            IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.chat_bubble_outline),
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        _unreadChatCount > 99 ? '99+' : '$_unreadChatCount',
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
              onPressed: () async {
                final navigator = Navigator.of(context);
                if (!await _requireRegulationAgreement()) return;
                navigator.push(
                  MaterialPageRoute(builder: (_) => const FloorChatScreen()),
                );
              },
              tooltip: s.floorChatTooltip,
            ),
          StreamBuilder<QuerySnapshot>(
            stream: user != null
                ? FirebaseFirestore.instance
                    .collection('user_notifications')
                    .where('userId', isEqualTo: user.uid)
                    .where('isRead', isEqualTo: false)
                    .snapshots()
                : null,
            builder: (context, snapshot) {
              final unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
              final hasUnread = unreadCount > 0;

              return IconButton(
                icon: Stack(
                  children: [
                    Icon(
                      hasUnread ? Icons.notifications : Icons.notifications_outlined,
                    ),
                    if (hasUnread)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
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
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationScreen(),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildDrawer(context, user, s),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_bannerImageUrl != null)
              Stack(
                children: [
                  Container(
                    height: 710,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(_bannerImageUrl!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                      child: Text(
                        s.dormOfficeContact,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, dynamic user, HomeStrings s) {
    return Drawer(
      child: SingleChildScrollView(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      // 아바타를 누르면 프로필 화면으로 이동한다.
                      InkWell(
                        borderRadius: BorderRadius.circular(30),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfileScreen(),
                            ),
                          );
                        },
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          backgroundImage: user?.profileImageUrl != null
                              ? NetworkImage(user!.profileImageUrl!)
                              : null,
                          child: user?.profileImageUrl == null
                              ? Text(
                                  user?.name?.substring(0, 1) ?? 'S',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const Spacer(),
                      // 내 QR 코드 생성
                      if (user != null)
                        Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () async {
                              final navigator = Navigator.of(context);
                              navigator.pop();
                              if (!await _requireRegulationAgreement()) return;
                              if (!await _requireCompleteProfile()) return;
                              // 층장이 스캔해 출석이 기록되면(true) 인원점검 화면으로 이동한다.
                              final checkedIn = await navigator.push<bool>(
                                MaterialPageRoute(
                                  builder: (context) => MyQrCodePage(
                                    uid: user.uid,
                                    studentId: user.studentId,
                                    profileImageUrl: user.profileImageUrl,
                                    userName: user.name,
                                  ),
                                ),
                              );
                              if (checkedIn == true && context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const AttendanceScreen(),
                                  ),
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.qr_code_2,
                                    size: 44,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  Text(
                                    s.menuMyQrShort,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      // 내 시간표
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TimetablePage(),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_view_week,
                                  size: 44,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                Text(
                                  s.menuTimetableShort,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user?.name ?? s.student,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (user?.nickname != null && user!.nickname!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '(${user.nickname})',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.announcement, color: Colors.red),
              title: Text(s.menuNotices),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const NoticesScreen()));
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.forum, color: Colors.deepPurple),
              title: Text(s.menuBoardMeal),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const BoardMealScreen()));
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.build, color: Colors.pinkAccent),
              title: Text(s.menuFacilityReport),
              onTap: () async {
                final navigator = Navigator.of(context);
                navigator.pop();
                if (!await _requireRegulationAgreement()) return;
                navigator.push(MaterialPageRoute(builder: (context) => const FacilityReportScreen()));
              },
            ),
            const Divider(height: 1),
            ExpansionTile(
              leading: const Icon(Icons.cleaning_services, color: Colors.cyan),
              title: Text(s.menuCleaningInspection),
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_month, color: Colors.deepPurple),
                  title: Text(s.menuCleaningMonthly),
                  contentPadding: const EdgeInsets.only(left: 32, right: 16),
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    if (!await _requireRegulationAgreement()) return;
                    navigator.push(MaterialPageRoute(
                      builder: (context) => const CleaningInspectionScreen(inspectionType: 'monthly'),
                    ));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
                  title: Text(s.menuMoveOutCheck),
                  contentPadding: const EdgeInsets.only(left: 32, right: 16),
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    navigator.pop();
                    if (!await _requireRegulationAgreement()) return;
                    navigator.push(MaterialPageRoute(
                      builder: (context) => const MoveOutInspectionScreen(),
                    ));
                  },
                ),
              ],
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.fact_check, color: Colors.indigo),
              title: Text(s.menuAttendance),
              onTap: () async {
                final navigator = Navigator.of(context);
                navigator.pop();
                if (!await _requireRegulationAgreement()) return;
                navigator.push(MaterialPageRoute(builder: (context) => const AttendanceScreen()));
              },
            ),
            const Divider(height: 1),
            _buildChatDrawerTile(context, user, s),
            const Divider(height: 1),
            ExpansionTile(
              leading: const Icon(Icons.groups, color: Colors.orange),
              title: Text(s.menuStudentCouncil),
              children: [
                ListTile(
                  leading: const Icon(Icons.campaign_outlined, color: Colors.redAccent),
                  title: Text(s.menuCouncilNotices),
                  contentPadding: const EdgeInsets.only(left: 32, right: 16),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                        builder: (context) => const CouncilNoticesScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.volunteer_activism_outlined, color: Colors.green),
                  title: Text(s.menuCouncilCampaigns),
                  contentPadding: const EdgeInsets.only(left: 32, right: 16),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                        builder: (context) => const CouncilCampaignsScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.how_to_vote_outlined, color: Colors.lightBlue),
                  title: Text(s.menuCouncilElections),
                  contentPadding: const EdgeInsets.only(left: 32, right: 16),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                        builder: (context) => const CouncilElectionsScreen()));
                  },
                ),
              ],
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.event_seat, color: Colors.indigo),
              title: Text(s.menuReservation),
              onTap: () async {
                final navigator = Navigator.of(context);
                navigator.pop();
                if (!await _requireRegulationAgreement()) return;
                navigator.push(MaterialPageRoute(builder: (context) => const ReservationScreen()));
              },
            ),
            const Divider(height: 1),
            ExpansionTile(
              leading: const Icon(Icons.description, color: Colors.black),
              title: Text(s.menuRegulationGroup),
              children: [
                ListTile(
                  leading: const Icon(Icons.description, color: Colors.indigo),
                  title: Text(s.menuRegulation),
                  contentPadding: const EdgeInsets.only(left: 32, right: 16),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const RegulationScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.meeting_room, color: Colors.deepPurple),
                  title: Text(s.menuCheckInOut),
                  contentPadding: const EdgeInsets.only(left: 32, right: 16),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const CheckInOutScreen()));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatDrawerTile(BuildContext context, dynamic user, HomeStrings s) {
    final roomId = user != null
        ? buildRoomId(user.dormBuilding, user.building, user.roomNumber)
        : null;
    final myUid = user?.uid as String?;

    return StreamBuilder<QuerySnapshot>(
      stream: roomId != null && myUid != null
          ? FirebaseFirestore.instance
              .collection('floor_chats')
              .doc(roomId)
              .collection('messages')
              .snapshots()
          : null,
      builder: (context, snapshot) {
        int unread = 0;
        if (snapshot.hasData && myUid != null) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final readBy = (data['readBy'] as List<dynamic>?) ?? [];
            if (!readBy.contains(myUid)) unread++;
          }
        }

        return ListTile(
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.chat_bubble_outline, color: Colors.cyan),
              if (unread > 0)
                Positioned(
                  top: -4,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      unread > 99 ? '99+' : unread.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(s.menuFloorChat),
          onTap: () async {
            final navigator = Navigator.of(context);
            navigator.pop();
            if (!await _requireRegulationAgreement()) return;
            navigator.push(MaterialPageRoute(
              builder: (context) => const FloorChatScreen(),
            ));
          },
        );
      },
    );
  }

  Widget _buildLogo() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isRedLogo = !_isRedLogo;
        });
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            _isRedLogo ? 'assets/images/swu_R.png' : 'assets/images/swu_B.png',
            height: 36,
            width: 36,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 6),
          const Text(
            '기숙사',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
