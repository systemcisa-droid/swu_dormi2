import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../notices/notices_screen.dart';
import '../check_in_out/check_in_out_screen.dart';
import '../meal/meal_screen.dart';
import '../facilities/facility_report_screen.dart';
import '../board/post_detail_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;


  Stream<List<NotificationModel>> _getNotificationsStream(String userId) {
    return _firestore
        .collection('user_notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return NotificationModel(
          id: doc.id,
          type: data['type'] ?? 'general',
          title: data['title'] ?? '',
          content: data['content'] ?? '',
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          isRead: data['isRead'] ?? false,
          data: (data['data'] as Map<String, dynamic>?),
        );
      }).toList();
    });
  }

  Future<void> _markAsRead(String id) async {
    try {
      await _firestore.collection('user_notifications').doc(id).update({
        'isRead': true,
      });
    } catch (e) {
      debugPrint('알림 읽음 처리 실패: $e');
    }
  }

  Future<void> _markAllAsRead(String userId) async {
    try {
      final unreadDocs = await _firestore
          .collection('user_notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in unreadDocs.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('알림 전체 읽음 처리 실패: $e');
    }
  }

  /// 알림 한 건 삭제. 성공 여부를 돌려줘 실패 시 목록을 되돌릴 수 있게 한다.
  Future<bool> _deleteNotification(String id) async {
    try {
      await _firestore.collection('user_notifications').doc(id).delete();
      return true;
    } catch (e) {
      debugPrint('알림 삭제 실패: $e');
      return false;
    }
  }

  /// 화면에 보이는 알림을 모두 삭제한다.
  /// 수신을 꺼둔 종류는 목록에 없으므로 삭제 대상에서도 제외한다.
  Future<void> _deleteAll(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('알림 전체 삭제'),
        content: const Text('알림을 모두 삭제하시겠습니까? 삭제된 알림은 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final snap = await _firestore
          .collection('user_notifications')
          .where('userId', isEqualTo: userId)
          .get();

      // Firestore 배치는 최대 500개 쓰기까지 지원하므로 청크로 나눠 커밋한다.
      const chunkSize = 400;
      final list = snap.docs.toList();
      for (var i = 0; i < list.length; i += chunkSize) {
        final batch = _firestore.batch();
        for (final doc in list.skip(i).take(chunkSize)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('알림을 모두 삭제했습니다')),
        );
      }
    } catch (e) {
      debugPrint('알림 전체 삭제 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('알림 삭제 중 오류가 발생했습니다')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userId = authProvider.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(
        body: Center(
          child: Text('로그인이 필요합니다'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: '전체 삭제',
            onPressed: () => _deleteAll(userId),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _getNotificationsStream(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('알림을 불러오는 중 오류가 발생했습니다'),
            );
          }

          final notifications = snapshot.data ?? [];
          final unreadCount = notifications.where((n) => !n.isRead).length;

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '알림이 없습니다',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              if (unreadCount > 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '읽지 않은 알림 $unreadCount개',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      TextButton(
                        onPressed: () => _markAllAsRead(userId),
                        child: Text(
                          '모두 읽음',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: notifications
                        .map((n) => _buildNotificationItem(n))
                        .toList(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(NotificationModel notification) {
    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) async {
        final ok = await _deleteNotification(notification.id);
        if (!ok && mounted) {
          // 삭제 실패 시 스트림이 다시 항목을 되살리므로 안내만 한다.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('알림 삭제에 실패했습니다')),
          );
        }
      },
      child: InkWell(
      onTap: () {
        if (!notification.isRead) {
          _markAsRead(notification.id);
        }
        _showNotificationDetail(notification);
      },
      child: Container(
        color: notification.isRead ? null : Colors.blue.shade50,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getTypeColor(notification.type).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getTypeIcon(notification.type),
                      color: _getTypeColor(notification.type),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getTypeColor(notification.type),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                notification.getTypeDisplayName(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!notification.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: notification.isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.content,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getTimeAgo(notification.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
        ),
      ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'notice': return Icons.announcement;
      case 'chat': return Icons.chat_bubble;
      case 'check_in_out': return Icons.meeting_room;
      case 'meal': return Icons.restaurant;
      case 'facility_report': return Icons.build;
      case 'message': return Icons.mark_email_unread;
      case 'board_comment': return Icons.forum;
      default: return Icons.notifications;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'notice': return Colors.blue;
      case 'chat': return Colors.green;
      case 'check_in_out': return Colors.purple;
      case 'meal': return Colors.teal;
      case 'facility_report': return Colors.red;
      case 'message': return Colors.orange;
      case 'board_comment': return Colors.deepPurple;
      default: return Colors.grey;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('yyyy.MM.dd').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금 전';
    }
  }

  bool _hasNavigationTarget(NotificationModel n) {
    if (n.type == 'board_comment') {
      // 댓글 알림은 대상 게시글을 알 수 있을 때만 이동한다.
      return (n.data?['postId'] as String?)?.isNotEmpty ?? false;
    }
    return n.type == 'notice' ||
        n.type == 'check_in_out' ||
        n.type == 'meal' ||
        n.type == 'facility_report';
  }

  void _navigateToTarget(NotificationModel n) {
    Widget? targetScreen;

    switch (n.type) {
      case 'notice': targetScreen = const NoticesScreen(); break;
      case 'check_in_out': targetScreen = const CheckInOutScreen(); break;
      case 'meal': targetScreen = const MealScreen(); break;
      case 'facility_report': targetScreen = const FacilityReportScreen(); break;
      case 'board_comment':
        final postId = n.data?['postId'] as String?;
        if (postId != null && postId.isNotEmpty) {
          targetScreen = PostDetailScreen(postId: postId);
        }
        break;
    }

    if (targetScreen != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => targetScreen!),
      );
    }
  }

  void _showNotificationDetail(NotificationModel notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getTypeIcon(notification.type),
              color: _getTypeColor(notification.type),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                notification.title,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getTypeColor(notification.type),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                notification.getTypeDisplayName(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              notification.content,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              DateFormat('yyyy년 MM월 dd일 HH:mm').format(notification.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          if (_hasNavigationTarget(notification))
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _navigateToTarget(notification);
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('바로가기'),
              style: TextButton.styleFrom(
                foregroundColor: _getTypeColor(notification.type),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}
