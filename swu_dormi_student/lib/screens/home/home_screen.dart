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
import '../notices/notices_screen.dart';
import '../check_in_out/check_in_out_screen.dart';
import '../facilities/facility_report_screen.dart';
import '../meal/meal_screen.dart';
import '../profile/profile_screen.dart';
import '../notification/notification_screen.dart';
import '../profile/regulation_screen.dart';
import '../profile/reward_penalty_screen.dart';
import '../board/board_screen.dart';
import '../cleaning/cleaning_inspection_screen.dart';
import '../cleaning/move_out_inspection_screen.dart';
import '../message/floor_chat_screen.dart';
import '../ot/ot_screen.dart';
import '../attendance/attendance_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  StreamSubscription<QuerySnapshot>? _chatSubscription;
  bool _isFirstSnapshot = true;
  bool _isRedColor = true;
  String? _bannerImageUrl;
  int _unreadChatCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _setupNotificationListener();
    _setupChatListener();
    _loadBannerImage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowPopupNotice();
    });
  }

  Future<void> _checkAndShowPopupNotice() async {
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

      final title = (data['title'] as String?) ?? '공지사항';
      final content = (data['content'] as String?) ?? '';
      final imageUrl = data['imageUrl'] as String?;

      if (!mounted) return;

      _showNoticePopupDialog(
        title: title,
        content: content,
        imageUrl: imageUrl,
        todayStr: todayStr,
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
                        '오늘 하루 보지 않기',
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
                      child: const Text(
                        '닫기',
                        style: TextStyle(
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
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FloorChatScreen()),
              ),
              tooltip: '층장단톡방',
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
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: user?.profileImageUrl != null
                  ? CircleAvatar(
                      radius: 18,
                      backgroundImage: NetworkImage(user!.profileImageUrl!),
                    )
                  : const CircleAvatar(
                      radius: 18,
                      child: Icon(Icons.person, size: 20),
                    ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
            ),
          ),
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
                  CircleAvatar(
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        user?.name ?? s.student,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (user?.nickname != null && user!.nickname!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          '(${user.nickname})',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    user?.studentId ?? '',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.announcement, color: Colors.blue),
              title: Text(s.menuNotices),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const NoticesScreen()));
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.forum, color: Colors.deepPurple),
              title: Text(s.menuBoard),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const BoardScreen()));
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.restaurant, color: Colors.green),
              title: Text(s.menuMeal),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const MealScreen()));
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.build, color: Colors.red),
              title: Text(s.menuFacilityReport),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const FacilityReportScreen()));
              },
            ),
            const Divider(height: 1),
            ExpansionTile(
              leading: const Icon(Icons.cleaning_services, color: Colors.cyan),
              title: Text(s.menuCleaningInspection),
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_month, color: Colors.cyan),
                  title: Text(s.menuCleaningMonthly),
                  contentPadding: const EdgeInsets.only(left: 32, right: 16),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => const CleaningInspectionScreen(inspectionType: 'monthly'),
                    ));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.cyan),
                  title: Text(s.menuMoveOutCheck),
                  contentPadding: const EdgeInsets.only(left: 32, right: 16),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => const MoveOutInspectionScreen(),
                    ));
                  },
                ),
                _buildChatDrawerTile(context, user),
              ],
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.fact_check, color: Colors.indigo),
              title: Text(s.menuAttendance),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AttendanceScreen()));
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.orange),
              title: Text(s.menuOt),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const OtScreen()));
              },
            ),
            const Divider(height: 1),
            ExpansionTile(
              leading: const Icon(Icons.description, color: Colors.indigo),
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
                  leading: const Icon(Icons.meeting_room, color: Colors.indigo),
                  title: Text(s.menuCheckInOut),
                  contentPadding: const EdgeInsets.only(left: 32, right: 16),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const CheckInOutScreen()));
                  },
                ),
              ],
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.stars, color: Colors.amber),
              title: Text(s.menuRewardPenalty),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const RewardPenaltyScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatDrawerTile(BuildContext context, dynamic user) {
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
          title: const Text('층장단톡방'),
          contentPadding: const EdgeInsets.only(left: 32, right: 16),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(
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
          _isRedColor = !_isRedColor;
        });
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 30,
            width: 30,
            decoration: BoxDecoration(
              color: _isRedColor ? const Color(0xFFB13B3B) : Colors.blue,
              borderRadius: BorderRadius.circular(4),
            ),
            transform: Matrix4.rotationZ(0.785398),
            child: Transform.rotate(
              angle: -0.785398,
              child: const Center(
                child: Text(
                  'SWU',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
          const Text(
            '샬롬하우스',
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
