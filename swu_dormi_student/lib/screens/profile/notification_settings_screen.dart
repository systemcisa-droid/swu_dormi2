import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/notification_settings_strings.dart';
import '../../providers/auth_provider.dart';
import '../../utils/notification_prefs.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _allNotifications = true;
  bool _noticeNotifications = true;
  // 식단표 알림은 기본 꺼짐(사용자가 직접 켜야 받는다)
  bool _checkInOutNotifications = true;
  bool _messageNotifications = true;
  bool _adminMessageNotifications = true;
  bool _boardCommentNotifications = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final userId =
        Provider.of<AuthProvider>(context, listen: false).currentUser?.uid;
    if (userId == null) return;
    final settings = await NotificationPrefs.load(userId);
    if (!mounted) return;
    setState(() {
      _allNotifications = settings['all_notifications'] ?? true;
      _noticeNotifications = settings['notice_notifications'] ?? true;
      _checkInOutNotifications =
          settings['check_in_out_notifications'] ?? true;
      _messageNotifications = settings['message_notifications'] ?? true;
      _adminMessageNotifications =
          settings['admin_message_notifications'] ?? true;
      _boardCommentNotifications =
          settings['board_comment_notifications'] ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final userId =
        Provider.of<AuthProvider>(context, listen: false).currentUser?.uid;
    if (userId == null) return;
    // Firestore에 저장해 알림을 만드는 쪽(관리 프로그램)이 참고할 수 있게 한다.
    await NotificationPrefs.save(userId, {
      'all_notifications': _allNotifications,
      'notice_notifications': _noticeNotifications,
      'check_in_out_notifications': _checkInOutNotifications,
      'message_notifications': _messageNotifications,
      'admin_message_notifications': _adminMessageNotifications,
      'board_comment_notifications': _boardCommentNotifications,
    });

    if (mounted) {
      final s = NotificationSettingsStrings(
          Provider.of<LocaleProvider>(context, listen: false).isEnglish);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.settingsSaved),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = NotificationSettingsStrings(Provider.of<LocaleProvider>(context).isEnglish);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.title),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          // 전체 알림 설정
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.all(16.0),
            child: Text(
              s.manageDescription,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
          ListTile(
            leading: Icon(Icons.notifications,
                color: _allNotifications ? Colors.blue : Colors.grey),
            title: Text(s.allNotifications),
            subtitle: Text(s.allNotificationsSubtitle),
            trailing: Switch(
              value: _allNotifications,
              onChanged: (value) {
                setState(() {
                  _allNotifications = value;
                  if (!value) {
                    _noticeNotifications = false;
                    _checkInOutNotifications = false;
                    _messageNotifications = false;
                    _adminMessageNotifications = false;
                    _boardCommentNotifications = false;
                  } else {
                    _noticeNotifications = true;
                    _checkInOutNotifications = true;
                    _messageNotifications = true;
                    _adminMessageNotifications = true;
                    _boardCommentNotifications = true;
                  }
                });
                _saveSettings();
              },
            ),
          ),
          const Divider(height: 1),

          // 개별 알림 설정
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              s.typeSettings,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),

          _buildNotificationTile(
            icon: Icons.announcement,
            iconColor: Colors.blue,
            title: s.notices,
            subtitle: s.noticesSubtitle,
            value: _noticeNotifications,
            enabled: _allNotifications,
            onChanged: (value) {
              setState(() {
                _noticeNotifications = value;
              });
              _saveSettings();
            },
          ),
          const Divider(height: 1, indent: 72),

          _buildNotificationTile(
            icon: Icons.meeting_room,
            iconColor: Colors.purple,
            title: s.checkInOut,
            subtitle: s.checkInOutSubtitle,
            value: _checkInOutNotifications,
            enabled: _allNotifications,
            onChanged: (value) {
              setState(() {
                _checkInOutNotifications = value;
              });
              _saveSettings();
            },
          ),
          const Divider(height: 1, indent: 72),

          _buildNotificationTile(
            icon: Icons.chat_bubble_outline,
            iconColor: Colors.orange,
            title: s.floorChat,
            subtitle: s.floorChatSubtitle,
            value: _messageNotifications,
            enabled: _allNotifications,
            onChanged: (value) {
              setState(() {
                _messageNotifications = value;
              });
              _saveSettings();
            },
          ),
          const Divider(height: 1, indent: 72),

          _buildNotificationTile(
            icon: Icons.admin_panel_settings,
            iconColor: Colors.teal,
            title: s.adminMessage,
            subtitle: s.adminMessageSubtitle,
            value: _adminMessageNotifications,
            enabled: _allNotifications,
            onChanged: (value) {
              setState(() {
                _adminMessageNotifications = value;
              });
              _saveSettings();
            },
          ),
          const Divider(height: 1, indent: 72),

          _buildNotificationTile(
            icon: Icons.forum,
            iconColor: Colors.deepPurple,
            title: s.boardComment,
            subtitle: s.boardCommentSubtitle,
            value: _boardCommentNotifications,
            enabled: _allNotifications,
            onChanged: (value) {
              setState(() {
                _boardCommentNotifications = value;
              });
              _saveSettings();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: enabled ? iconColor : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: enabled ? Colors.black87 : Colors.grey,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: enabled ? Colors.grey.shade600 : Colors.grey.shade400,
          fontSize: 13,
        ),
      ),
      trailing: Switch(
        value: value && enabled,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}
