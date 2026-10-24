import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import 'chat_media.dart';
import 'chat_upload.dart';
// captainFloor: "샬롬하우스 A동 3층"      → roomId: "샬롬하우스_A동_301호"
// captainFloor: "바롬인성교육관 10층"      → roomId: "바롬인성교육관_1001-A호" (동 없음)
String _toRoomId(String dormBuilding, String building, String roomNumber) =>
    building.isEmpty
        ? '${dormBuilding}_$roomNumber호'
        : '${dormBuilding}_${building}_$roomNumber호';

Future<String?> _getAssignedFloor() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return null;
  final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  return doc.data()?['assignedFloor'] as String?;
}

// "샬롬하우스 A동 3층" → (dormBuilding: "샬롬하우스", building: "A동", floorNum: 3)
// "바롬인성교육관 10층" → (dormBuilding: "바롬인성교육관", building: "", floorNum: 10)
//   바롬인성교육관은 동(wing) 구분이 없고 호실이 '1001-A' 형식이다.
({String dormBuilding, String building, int floorNum})? _parseFloor(String assignedFloor) {
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
    return null;
  }

  final building = wingMatch?.group(0) ?? ''; // e.g. "A동"
  final floorNum = floorMatch != null ? int.tryParse(floorMatch.group(1)!) ?? 0 : 0;
  if (floorNum == 0) return null;
  // 바롬인성교육관은 동이 없어도 되지만, 그 외 건물은 동이 필수다.
  if (dormBuilding != '바롬인성교육관' && building.isEmpty) return null;
  return (dormBuilding: dormBuilding, building: building, floorNum: floorNum);
}

class MessageScreen extends StatelessWidget {
  const MessageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _RoomListScreen();
  }
}

// ── 호실 목록 화면 ──────────────────────────────────────────────
class _RoomListScreen extends StatefulWidget {
  const _RoomListScreen();

  @override
  State<_RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<_RoomListScreen> {
  final _firestore = FirebaseFirestore.instance;
  List<String> _roomNumbers = [];
  bool _loading = true;

  late String? _assignedFloor;
  late ({String dormBuilding, String building, int floorNum})? _parsed;

  @override
  void initState() {
    super.initState();
    _loadFloorThenRooms();
  }

  Future<void> _loadFloorThenRooms() async {
    _assignedFloor = await _getAssignedFloor();
    _parsed = _assignedFloor != null ? _parseFloor(_assignedFloor!) : null;
    _loadRooms();
  }

  /// 호실 번호에서 동(A동/B동)을 계산한다. 저장된 building 필드('미배정' 등)를 믿지 않는다.
  /// 국제생활관: 101~132·201~229 = A동 / 233~260·301~329 = B동
  /// 샬롬하우스: 층내 01~20 = A동 / 21~35 = B동
  String? _wingFromRoom(String dormBuilding, int roomNum) {
    if (roomNum == 0) return null;
    if (dormBuilding.startsWith('국제생활관')) {
      if ((roomNum >= 101 && roomNum <= 132) || (roomNum >= 201 && roomNum <= 229)) return 'A동';
      if ((roomNum >= 233 && roomNum <= 260) || (roomNum >= 301 && roomNum <= 329)) return 'B동';
      return null;
    }
    if (dormBuilding.startsWith('샬롬하우스')) {
      final last = roomNum % 100;
      if (last >= 1 && last <= 20) return 'A동';
      if (last >= 21 && last <= 35) return 'B동';
      return null;
    }
    return null;
  }

  Future<void> _loadRooms() async {
    if (_parsed == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      // building 필드는 '미배정'으로 저장된 경우가 있어 필터에 쓰지 않고,
      // dormBuilding + role 로만 조회한 뒤 호실 번호로 동/층을 직접 판정한다.
      final snap = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('dormBuilding', isEqualTo: _parsed!.dormBuilding)
          .orderBy('roomNumber')
          .get();

      final rooms = <String>{};
      final isBarom = _parsed!.dormBuilding == '바롬인성교육관';
      for (final doc in snap.docs) {
        final room = doc.data()['roomNumber'] as String? ?? '';
        if (room.isEmpty || room == '000') continue;
        if (isBarom) {
          // 바롬인성교육관 호실: '1001-A' 형식. '-' 앞 숫자의 층(1001~1003 → 10층)으로 필터.
          final base = int.tryParse(room.split('-').first) ?? 0;
          if (base ~/ 100 == _parsed!.floorNum) {
            rooms.add(room);
          }
        } else {
          final floorNum = int.tryParse(room) ?? 0;
          if ((floorNum ~/ 100) != _parsed!.floorNum) continue;
          // 담당 구역에 동이 지정돼 있으면 호실 번호로 계산한 동과 일치할 때만 포함.
          if (_parsed!.building.isNotEmpty &&
              _wingFromRoom(_parsed!.dormBuilding, floorNum) != _parsed!.building) {
            continue;
          }
          rooms.add(room);
        }
      }

      setState(() {
        _roomNumbers = rooms.toList()..sort();
        _loading = false;
      });
    } catch (e) {
      debugPrint('호실 목록 로딩 오류: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_assignedFloor == null || _parsed == null) {
      return const Center(child: Text('담당 구역 정보가 없습니다'));
    }
    if (_roomNumbers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.meeting_room_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('배정된 호실이 없습니다',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('$_assignedFloor\n학생 입사 후 표시됩니다',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadRooms,
              icon: const Icon(Icons.refresh),
              label: const Text('새로고침'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.cyan.shade50,
          child: Row(
            children: [
              Icon(Icons.apartment, size: 16, color: Colors.cyan.shade700),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$_assignedFloor — ${_roomNumbers.length}개 호실',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.cyan.shade800),
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh, size: 18, color: Colors.cyan.shade700),
                onPressed: _loadRooms,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _roomNumbers.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, index) {
              final roomNumber = _roomNumbers[index];
              final roomId = _toRoomId(
                  _parsed!.dormBuilding, _parsed!.building, roomNumber);
              final captainUid = FirebaseAuth.instance.currentUser?.uid ?? '';

              return _RoomTile(
                roomNumber: roomNumber,
                roomId: roomId,
                captainUid: captainUid,
                assignedFloor: _assignedFloor!,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── 호실 타일 (안 읽은 메시지 배지 포함) ────────────────────────
class _RoomTile extends StatelessWidget {
  const _RoomTile({
    required this.roomNumber,
    required this.roomId,
    required this.captainUid,
    required this.assignedFloor,
  });

  final String roomNumber;
  final String roomId;
  final String captainUid;
  final String assignedFloor;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('floor_chats')
          .doc(roomId)
          .collection('messages')
          .where('senderId', isNotEqualTo: captainUid)
          .snapshots(),
      builder: (context, snapshot) {
        int unread = 0;
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final readBy = (data['readBy'] as List<dynamic>?) ?? [];
            if (!readBy.contains(captainUid)) unread++;
          }
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.cyan.shade100,
                child: Text(
                  '$roomNumber호',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.cyan.shade800),
                ),
              ),
              if (unread > 0)
                Positioned(
                  top: -4,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      unread > 99 ? '99+' : unread.toString(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            '$roomNumber호',
            style: TextStyle(
              fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal,
              fontSize: 15,
            ),
          ),
          subtitle: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('floor_chats')
                .doc(roomId)
                .snapshots(),
            builder: (context, metaSnap) {
              final data = metaSnap.data?.data() as Map<String, dynamic>?;
              final lastMsg = data?['lastMessage'] as String?;
              if (lastMsg == null) {
                return Text('대화 없음', style: TextStyle(color: Colors.grey.shade400, fontSize: 12));
              }
              return Text(
                lastMsg,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unread > 0 ? Colors.black87 : Colors.grey.shade500,
                  fontSize: 12,
                  fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal,
                ),
              );
            },
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('floor_chats')
                    .doc(roomId)
                    .snapshots(),
                builder: (context, metaSnap) {
                  final data = metaSnap.data?.data() as Map<String, dynamic>?;
                  final lastAt = data?['lastAt'] as Timestamp?;
                  if (lastAt == null) return const SizedBox.shrink();
                  return Text(
                    _formatTime(lastAt.toDate()),
                    style: TextStyle(
                        fontSize: 11,
                        color: unread > 0 ? Colors.cyan.shade700 : Colors.grey.shade400),
                  );
                },
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 18),
            ],
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _RoomChatScreen(
                roomId: roomId,
                roomNumber: roomNumber,
                assignedFloor: assignedFloor,
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return DateFormat('HH:mm').format(dt);
    }
    return DateFormat('MM/dd').format(dt);
  }
}

// ── 개별 호실 채팅화면 ───────────────────────────────────────────
class _RoomChatScreen extends StatefulWidget {
  const _RoomChatScreen({
    required this.roomId,
    required this.roomNumber,
    required this.assignedFloor,
  });

  final String roomId;
  final String roomNumber;
  final String assignedFloor;

  @override
  State<_RoomChatScreen> createState() => _RoomChatScreenState();
}

class _RoomChatScreenState extends State<_RoomChatScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _sendingNotifier = ValueNotifier<bool>(false);
  /// 첨부 업로드 진행 상태 (압축/업로드 중 입력창에 표시)
  final _uploadingNotifier = ValueNotifier<String?>(null);
  int _prevDocCount = 0;

  /// 답장 대상으로 지정된 메시지 (스와이프로 선택)
  final ValueNotifier<Map<String, dynamic>?> _replyTargetNotifier =
      ValueNotifier(null);

  /// 내가 차단한 사용자 uid 목록. 이 사용자들의 메시지는 표시하지 않는다.
  List<String> _blockedUsers = [];

  /// 채팅방 참여자 수 (해당 호실 학생 + 담당 층장)
  /// 안 읽은 사람 수 = 참여자 수 - readBy 길이
  int _memberCount = 0;

  /// 채팅방에 있는 학생 이름 목록 (상단에 표시)
  List<String> _memberNames = [];

  @override
  void initState() {
    super.initState();
    _markAllRead();
    _loadMemberCount();
    _loadBlockedUsers();
  }

  /// 채팅방 참여자 수를 구한다. (학생앱과 동일한 규칙)
  /// 내가 차단한 사용자 목록을 불러온다.
  Future<void> _loadBlockedUsers() async {
    try {
      final list = await AuthService().getBlockedUsers();
      if (!mounted) return;
      setState(() => _blockedUsers = list);
    } catch (_) {
      // 실패해도 채팅은 정상 동작해야 하므로 무시한다.
    }
  }

  /// 긴 메시지 메뉴에 쓰는 간단 이모티콘 반응 모음.
  static const _kReactionEmojis = ['❤️', '👍', '✅', '😂', '😮', '😢'];

  /// 메시지를 클립보드로 복사한다.
  void _copyMessageText(String text) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('메시지가 복사되었습니다'), duration: Duration(seconds: 1)),
    );
  }

  /// 카카오톡처럼 메시지를 길게 누르면 그 자리에 이모티콘 반응·복사·공지·수정·삭제(그리고
  /// 타인 메시지면 신고/차단) 메뉴를 띄운다. 답장은 메뉴가 아니라 좌측 스와이프로 보낸다.
  Future<void> _showMessageMenu(
    Offset globalPosition,
    String text, {
    VoidCallback? onDelete,
    ValueChanged<String>? onReact,
    VoidCallback? onPin,
    VoidCallback? onEdit,
    VoidCallback? onModerate,
  }) async {
    HapticFeedback.selectionClick();
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      color: Colors.white,
      items: [
        if (onReact != null)
          PopupMenuItem<String>(
            enabled: false,
            padding: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: _kReactionEmojis
                    .map((emoji) => GestureDetector(
                          onTap: () => Navigator.of(context).pop('react:$emoji'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            child: Text(emoji, style: const TextStyle(fontSize: 22)),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
        if (text.isNotEmpty) const PopupMenuItem(value: 'copy', child: Text('복사')),
        if (text.isNotEmpty) const PopupMenuItem(value: 'select_copy', child: Text('선택 복사')),
        if (onPin != null) const PopupMenuItem(value: 'pin', child: Text('공지')),
        if (onEdit != null) const PopupMenuItem(value: 'edit', child: Text('수정')),
        if (onDelete != null)
          const PopupMenuItem(
            value: 'delete',
            child: Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        if (onModerate != null)
          const PopupMenuItem(value: 'moderate', child: Text('신고/차단')),
      ],
    );
    if (selected == null) return;
    if (selected.startsWith('react:')) {
      onReact?.call(selected.substring(6));
      return;
    }
    switch (selected) {
      case 'copy':
        _copyMessageText(text);
        break;
      case 'select_copy':
        _showSelectableText(text);
        break;
      case 'pin':
        onPin?.call();
        break;
      case 'edit':
        onEdit?.call();
        break;
      case 'delete':
        onDelete?.call();
        break;
      case 'moderate':
        onModerate?.call();
        break;
    }
  }

  /// "선택 복사" — 메시지 전체를 바로 클립보드에 넣는 대신, 원하는 부분만 골라 복사할 수 있게
  /// 선택 가능한 텍스트로 띄워준다.
  void _showSelectableText(String text) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: SelectableText(text, style: const TextStyle(fontSize: 15, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
        ],
      ),
    );
  }

  /// 메시지를 채팅방 상단 공지로 등록한다. 해제는 상단 배너의 닫기 버튼으로 한다.
  Future<void> _pinNotice(String senderName, String text) async {
    if (text.isEmpty) return;
    final me = FirebaseAuth.instance.currentUser;
    try {
      await _firestore.collection('floor_chats').doc(widget.roomId).set({
        'pinnedMessage': {
          'text': text,
          'senderName': senderName,
          'pinnedByName': me?.displayName ?? '',
          'pinnedAt': Timestamp.now(),
        },
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _unpinNotice() async {
    try {
      await _firestore
          .collection('floor_chats')
          .doc(widget.roomId)
          .update({'pinnedMessage': FieldValue.delete()});
    } catch (_) {}
  }

  /// 본인이 보낸 메시지의 내용을 수정한다.
  Future<void> _editMessage(DocumentReference<Object?> ref, String currentText) async {
    final controller = TextEditingController(text: currentText);
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('메시지 수정'),
        content: TextField(controller: controller, maxLines: 4, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (newText == null || newText.isEmpty || newText == currentText) return;
    try {
      await ref.update({'text': newText, 'edited': true, 'editedAt': Timestamp.now()});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('수정 오류: $e')));
      }
    }
  }

  Future<void> _confirmDeleteMessage(DocumentReference<Object?> ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('메시지 삭제'),
        content: const Text('이 메시지를 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 오류: $e')));
      }
    }
  }

  /// 같은 이모티콘을 다시 누르면 반응을 취소하고, 다른 이모티콘을 누르면 교체한다(1인당 1개).
  Future<void> _toggleReaction(DocumentReference<Object?> ref, String emoji) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    HapticFeedback.selectionClick();
    try {
      final doc = await ref.get();
      final data = doc.data() as Map<String, dynamic>?;
      final current = (data?['reactions'] as Map?)?[uid] as String?;
      await ref.update({
        'reactions.$uid': current == emoji ? FieldValue.delete() : emoji,
      });
    } catch (_) {}
  }

  /// 메시지에 달린 이모티콘 반응을 종류별로 묶어 보여준다. 탭하면 내 반응을 토글한다.
  Widget _buildReactionsRow(Map<String, dynamic> reactions, ValueChanged<String>? onReact) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final counts = <String, int>{};
    for (final v in reactions.values) {
      final emoji = v as String;
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: counts.entries.map((entry) {
        final mine = myUid != null && reactions[myUid] == entry.key;
        return GestureDetector(
          onTap: onReact == null ? null : () => onReact(entry.key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: mine ? Colors.cyan.shade50 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: mine ? Colors.cyan.shade300 : Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(entry.key, style: const TextStyle(fontSize: 12)),
                if (entry.value > 1) ...[
                  const SizedBox(width: 3),
                  Text('${entry.value}',
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// "공지"로 등록된 메시지를 채팅방 상단에 고정 배너로 보여준다.
  Widget _buildPinnedNoticeBanner() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('floor_chats').doc(widget.roomId).snapshots(),
      builder: (context, snap) {
        final roomData = snap.data?.data() as Map<String, dynamic>?;
        final pinned = roomData?['pinnedMessage'] as Map<String, dynamic>?;
        if (pinned == null) return const SizedBox.shrink();
        final pinnedText = (pinned['text'] as String?) ?? '';
        if (pinnedText.isEmpty) return const SizedBox.shrink();
        final pinnedSender = (pinned['senderName'] as String?) ?? '';
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.amber.shade50,
          child: Row(
            children: [
              Icon(Icons.campaign, size: 16, color: Colors.amber.shade800),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$pinnedSender: $pinnedText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w600),
                ),
              ),
              GestureDetector(
                onTap: _unpinNotice,
                child: Icon(Icons.close, size: 16, color: Colors.amber.shade800),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 타인의 메시지를 길게 누르면 나오는 신고/차단 메뉴.
  /// App Store 가이드라인 1.2 요구사항(신고·차단 수단)을 충족한다.
  Future<void> _showModerationSheet({
    required String messageId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    final isBlocked = _blockedUsers.contains(senderId);
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined,
                      size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      senderName.isEmpty ? '메시지 신고 및 차단' : senderName,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.red),
              title: const Text('신고하기'),
              subtitle: const Text('부적절한 메시지를 운영자에게 신고합니다',
                  style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _showReportDialog(
                  messageId: messageId,
                  targetAuthorId: senderId,
                  text: text,
                );
              },
            ),
            ListTile(
              leading: Icon(isBlocked ? Icons.person_add_alt : Icons.block,
                  color: isBlocked ? Colors.blue : Colors.red),
              title: Text(isBlocked ? '차단 해제' : '이 사용자 차단'),
              subtitle: Text(
                isBlocked
                    ? '차단을 해제하면 메시지가 다시 표시됩니다'
                    : '차단하면 이 사용자의 메시지가 즉시 보이지 않습니다',
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _toggleBlock(senderId, senderName, isBlocked);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 신고 사유를 선택받아 reports 컬렉션에 기록한다.
  /// 운영자는 관리자 프로그램의 신고 관리 페이지에서 24시간 내 처리한다.
  Future<void> _showReportDialog({
    required String messageId,
    required String targetAuthorId,
    required String text,
  }) async {
    const reasons = ['비방·욕설', '허위 사실 유포', '음란·불건전 내용', '개인정보 침해', '기타'];
    String? selected;
    final etcCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('메시지 신고'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('신고 사유를 선택해주세요.',
                    style: TextStyle(fontSize: 13)),
                const SizedBox(height: 12),
                for (final r in reasons)
                  GestureDetector(
                    onTap: () => setDialogState(() => selected = r),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            selected == r
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            size: 20,
                            color: selected == r
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(r, style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                if (selected == '기타') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: etcCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: '신고 사유를 입력해주세요',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('취소')),
            TextButton(
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(dialogCtx, true),
              child: const Text('신고', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || selected == null) {
      etcCtrl.dispose();
      return;
    }

    try {
      await _firestore.collection('reports').add({
        'reporterId': FirebaseAuth.instance.currentUser?.uid ?? '',
        'targetId': messageId,
        'targetType': 'chat_message',
        'targetAuthorId': targetAuthorId,
        'targetContent': text,
        'roomId': widget.roomId,
        'reason': selected,
        'detail': selected == '기타' ? etcCtrl.text.trim() : '',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('신고가 접수되었습니다. 24시간 이내에 검토 후 조치됩니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('신고 접수에 실패했습니다: $e')),
        );
      }
    } finally {
      etcCtrl.dispose();
    }
  }

  /// 사용자 차단 / 차단 해제.
  /// 차단 시 운영자에게도 알려 부적절한 콘텐츠를 확인할 수 있게 한다.
  Future<void> _toggleBlock(
      String targetUid, String targetName, bool isBlocked) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isBlocked ? '차단 해제' : '사용자 차단'),
        content: Text(
          isBlocked
              ? '차단을 해제하시겠습니까?\n이 사용자의 메시지가 다시 표시됩니다.'
              : '이 사용자를 차단하시겠습니까?\n차단하면 해당 사용자의 메시지가 즉시 보이지 않으며, '
                  '운영자에게도 통보되어 검토가 이루어집니다.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isBlocked ? '차단 해제' : '차단',
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final auth = AuthService();
      if (isBlocked) {
        await auth.unblockUser(targetUid);
      } else {
        await auth.blockUser(targetUid);
        // 차단 사실을 운영자에게 알린다 (가이드라인 1.2).
        await _firestore.collection('reports').add({
          'reporterId': FirebaseAuth.instance.currentUser?.uid ?? '',
          'targetId': targetUid,
          'targetType': 'user_block',
          'targetAuthorId': targetUid,
          'roomId': widget.roomId,
          'reason': '사용자 차단',
          'detail': '$targetName 사용자를 차단했습니다.',
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await _loadBlockedUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isBlocked ? '차단을 해제했습니다.' : '사용자를 차단했습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('처리에 실패했습니다: $e')),
        );
      }
    }
  }

  Future<void> _loadMemberCount() async {
    // roomId 예: '샬롬하우스_A동_320호'  /  '바롬인성교육관_1001-A호' (동 없음)
    final parts = widget.roomId.split('_');
    if (parts.length < 2) return;
    final dormBuilding = parts[0];
    final isBarom = dormBuilding.startsWith('바롬인성교육관');

    // 학생 조회에 쓸 roomNumber. 바롬은 '1001-A' 처럼 접미사까지 포함한다.
    final String roomNumber;
    final String? wing;
    if (isBarom) {
      wing = null;
      roomNumber = parts[1].replaceFirst('호', ''); // '1001-A호' → '1001-A'
    } else {
      if (parts.length < 3) return;
      wing = parts[1];
      roomNumber = RegExp(r'\d+').firstMatch(parts[2])?.group(0) ?? '';
    }
    if (roomNumber.isEmpty) return;

    try {
      final studentsSnap = await _firestore
          .collection('users')
          .where('dormBuilding', isEqualTo: dormBuilding)
          .where('roomNumber', isEqualTo: roomNumber)
          .get();
      final studentDocs = studentsSnap.docs.where((d) {
        final data = d.data();
        if ((data['role'] as String?) != 'student') return false;
        return ((data['residentStatus'] as String?) ?? '재실중') == '재실중';
      }).toList();
      final students = studentDocs.length;
      final names = studentDocs
          .map((d) => (d.data()['name'] as String?)?.trim() ?? '')
          .where((n) => n.isNotEmpty)
          .toList()
        ..sort();

      final floorNum = isBarom
          ? (int.tryParse(roomNumber.split('-').first) ?? 0) ~/ 100
          : (int.tryParse(roomNumber) ?? 0) ~/ 100;
      final assignedFloorKey = isBarom
          ? '$dormBuilding $floorNum층'
          : '$dormBuilding $wing $floorNum층';
      final captainsSnap = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin_m')
          .where('assignedFloor', isEqualTo: assignedFloorKey)
          .get();

      if (mounted) {
        setState(() {
          _memberCount = students + captainsSnap.docs.length;
          _memberNames = names;
        });
      }
    } catch (e) {
      debugPrint('참여자 수 조회 오류: $e');
    }
  }

  @override
  void dispose() {
    ChatUpload.cancelCompression();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _sendingNotifier.dispose();
    _uploadingNotifier.dispose();
    _replyTargetNotifier.dispose();
    super.dispose();
  }

  /// 메시지를 좌측으로 스와이프하면 답장 대상으로 지정한다.
  void _setReplyTarget(Map<String, dynamic> data) {
    HapticFeedback.selectionClick();
    _replyTargetNotifier.value = {
      'senderName': data['senderName'] as String? ?? '',
      'roomNumber': data['roomNumber'] as String? ?? '',
      'text': data['text'] as String? ?? '',
      'mediaType': data['mediaType'] as String?,
    };
  }

  void _clearReplyTarget() => _replyTargetNotifier.value = null;

  Future<void> _markAllRead() async {
    final captainUid = FirebaseAuth.instance.currentUser?.uid;
    if (captainUid == null) return;
    try {
      final snap = await _firestore
          .collection('floor_chats')
          .doc(widget.roomId)
          .collection('messages')
          .get();
      final batch = _firestore.batch();
      bool hasPending = false;
      for (final doc in snap.docs) {
        final data = doc.data();
        final readBy = (data['readBy'] as List<dynamic>?) ?? [];
        if (!readBy.contains(captainUid)) {
          batch.update(doc.reference, {
            'readBy': FieldValue.arrayUnion([captainUid]),
          });
          hasPending = true;
        }
      }
      if (hasPending) await batch.commit();
    } catch (e) {
      debugPrint('읽음 처리 오류: $e');
    }
  }

  // 00:30 ~ 09:00 사용 불가
  // ⚠️ 임시 해제 (사용자 요청) — 몇 시간 후 아래 원본 로직으로 복귀할 것.
  bool _isRestrictedTime() {
    return false;
    // final now = TimeOfDay.now();
    // final minutes = now.hour * 60 + now.minute;
    // return minutes >= 30 && minutes < 9 * 60; // 00:30(30) ~ 09:00(540)
  }

  /// 첨부(사진/영상) 선택 → 압축 → 업로드 → 메시지 전송
  Future<void> _sendMedia({
    required ImageSource source,
    required bool isVideo,
  }) async {
    if (_isRestrictedTime()) return;
    if (_uploadingNotifier.value != null) return;

    final captainUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    try {
      final picked = isVideo
          ? await ChatUpload.pickVideo(source)
          : await ChatUpload.pickImage(source);
      if (picked == null) return;

      File file = picked;
      if (isVideo) {
        _uploadingNotifier.value = '영상 압축 중...';
        file = await ChatUpload.compressVideo(picked);
      }

      // 압축 후에도 너무 크면 중단한다.
      if (await file.length() > ChatUpload.maxUploadBytes) {
        _uploadingNotifier.value = null;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('파일이 너무 큽니다. 더 짧은 영상을 선택해주세요')),
          );
        }
        return;
      }

      _uploadingNotifier.value = isVideo ? '영상 업로드 중...' : '사진 업로드 중...';
      final url = await ChatUpload.upload(
        file: file,
        roomId: widget.roomId,
        isVideo: isVideo,
      );

      final replyTo = _replyTargetNotifier.value;

      await _firestore
          .collection('floor_chats')
          .doc(widget.roomId)
          .collection('messages')
          .add({
        'text': '',
        'mediaUrl': url,
        'mediaType': isVideo ? 'video' : 'image',
        'senderId': captainUid,
        'senderName': '층장(${widget.assignedFloor})',
        'roomNumber': '층장',
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': [captainUid],
        if (replyTo != null) 'replyTo': replyTo,
      });

      await _firestore.collection('floor_chats').doc(widget.roomId).set({
        'lastMessage': isVideo ? '[영상]' : '[사진]',
        'lastAt': FieldValue.serverTimestamp(),
        'roomId': widget.roomId,
      }, SetOptions(merge: true));

      _clearReplyTarget();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('전송 오류: $e')));
      }
    } finally {
      _uploadingNotifier.value = null;
    }
  }

  /// 첨부 방식 선택 시트
  void _showAttachSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.cyan),
              title: const Text('사진 선택'),
              onTap: () {
                Navigator.pop(ctx);
                _sendMedia(source: ImageSource.gallery, isVideo: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library, color: Colors.cyan),
              title: const Text('영상 선택'),
              subtitle: const Text('최대 1분 · 업로드 시 압축됩니다',
                  style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                _sendMedia(source: ImageSource.gallery, isVideo: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    if (_isRestrictedTime()) return;
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    final captainUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    // 전송 버튼만 비활성화 — setState로 전체 rebuild 없이 ValueNotifier 사용
    _sendingNotifier.value = true;
    try {
      final replyTo = _replyTargetNotifier.value;

      await _firestore
          .collection('floor_chats')
          .doc(widget.roomId)
          .collection('messages')
          .add({
        'text': text,
        'senderId': captainUid,
        'senderName': '층장(${widget.assignedFloor})',
        'roomNumber': '층장',
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': [captainUid],
        if (replyTo != null) 'replyTo': replyTo,
      });

      await _firestore.collection('floor_chats').doc(widget.roomId).set({
        'lastMessage': text,
        'lastAt': FieldValue.serverTimestamp(),
        'roomId': widget.roomId,
      }, SetOptions(merge: true));

      _msgCtrl.clear();
      _clearReplyTarget();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('전송 오류: $e')));
      }
    } finally {
      _sendingNotifier.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.roomNumber}호 채팅방',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(widget.assignedFloor,
                style: TextStyle(fontSize: 11, color: Colors.cyan.shade100)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.cyan.shade50,
            child: Row(
              children: [
                Icon(Icons.group, size: 16, color: Colors.cyan.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${widget.roomNumber}호 ↔ 층장 채팅방',
                    style: TextStyle(fontSize: 12, color: Colors.cyan.shade800),
                  ),
                ),
                Icon(Icons.access_time, size: 13, color: Colors.cyan.shade600),
                const SizedBox(width: 4),
                Text(
                  '이용시간 09:00 ~ 00:30',
                  style: TextStyle(fontSize: 11, color: Colors.cyan.shade700),
                ),
              ],
            ),
          ),
          _buildPinnedNoticeBanner(),
          // 채팅방에 있는 학생 이름
          if (_memberNames.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Icon(Icons.people_outline,
                      size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _memberNames.join(', '),
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildMessageList(myUid)),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageList(String myUid) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('floor_chats')
          .doc(widget.roomId)
          .collection('messages')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        // 차단한 사용자의 메시지는 즉시 목록에서 제외한다 (가이드라인 1.2).
        final docs = (snapshot.data?.docs ?? []).where((d) {
          final data = d.data() as Map<String, dynamic>?;
          final sid = (data?['senderId'] ?? '').toString();
          return !_blockedUsers.contains(sid);
        }).toList();
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('아직 대화가 없습니다.\n먼저 인사를 건네보세요!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
              ],
            ),
          );
        }

        // 새 메시지가 추가됐을 때만 스크롤 (rebuild마다 스크롤하면 깜빡임 발생)
        // 새 메시지가 오면 맨 아래(reverse 기준 offset 0)로 이동한다.
        if (docs.length > _prevDocCount) {
          final isFirstLoad = _prevDocCount == 0;
          _prevDocCount = docs.length;
          if (!isFirstLoad) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_scrollCtrl.hasClients) return;
              _scrollCtrl.animateTo(
                0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            });
          }
        }

        // reverse: true 로 아래에서 위로 쌓아 항상 최신 메시지가 먼저 보이게 한다.
        // (ListView.builder 는 지연 렌더링이라 첫 프레임에 전체 높이를 알 수 없어
        //  maxScrollExtent 로 맨 아래로 보내는 방식은 정확히 동작하지 않는다)
        return ListView.builder(
          controller: _scrollCtrl,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, reverseIndex) {
            // reverse 목록이므로 실제 순서로 되돌린다.
            final index = docs.length - 1 - reverseIndex;
            final data = docs[index].data() as Map<String, dynamic>;
            final isMine = (data['senderId'] as String?) == myUid;
            final senderName = data['senderName'] as String? ?? '';
            final roomNumber = data['roomNumber'] as String? ?? '';
            final text = data['text'] as String? ?? '';
            final mediaUrl = data['mediaUrl'] as String?;
            final mediaType = data['mediaType'] as String?;
            final replyTo = data['replyTo'] as Map<String, dynamic>?;
            final reactions = (data['reactions'] as Map?)?.cast<String, dynamic>();
            final edited = data['edited'] == true;
            // 안 읽은 사람 수 = 참여자 수 - 읽은 사람 수
            final readBy = (data['readBy'] as List<dynamic>?) ?? const [];
            final unreadCount = _memberCount > 0
                ? (_memberCount - readBy.length).clamp(0, _memberCount)
                : 0;
            final ts = data['createdAt'] as Timestamp?;
            final time = ts != null ? DateFormat('HH:mm').format(ts.toDate()) : '';

            String? dateDivider;
            if (index == 0 && ts != null) {
              dateDivider = DateFormat('yyyy년 MM월 dd일 (E)', 'ko').format(ts.toDate());
            } else if (index > 0 && ts != null) {
              final prevTs = (docs[index - 1].data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              if (prevTs != null) {
                final prev = prevTs.toDate();
                final curr = ts.toDate();
                if (prev.year != curr.year || prev.month != curr.month || prev.day != curr.day) {
                  dateDivider = DateFormat('yyyy년 MM월 dd일 (E)', 'ko').format(curr);
                }
              }
            }

            // 같은 사람이 연속으로 보낸 메시지는 아바타·이름을 반복하지 않는다.
            // (날짜 구분선이 들어가면 그 아래는 다시 첫 메시지로 취급)
            final senderId = data['senderId'] as String?;
            final prevData = index > 0
                ? docs[index - 1].data() as Map<String, dynamic>
                : null;
            // 분이 다르면 다른 시각의 메시지이므로 별개 묶음으로 본다.
            bool sameMinute(Timestamp? a, Timestamp? b) {
              if (a == null || b == null) return false;
              final x = a.toDate();
              final y = b.toDate();
              return x.year == y.year &&
                  x.month == y.month &&
                  x.day == y.day &&
                  x.hour == y.hour &&
                  x.minute == y.minute;
            }

            final isFirstOfGroup = dateDivider != null ||
                prevData == null ||
                (prevData['senderId'] as String?) != senderId ||
                !sameMinute(prevData['createdAt'] as Timestamp?, ts);

            // 시간은 그룹의 마지막 메시지에만 표시한다.
            final nextData = index < docs.length - 1
                ? docs[index + 1].data() as Map<String, dynamic>
                : null;
            final isLastOfGroup = nextData == null ||
                (nextData['senderId'] as String?) != senderId ||
                !sameMinute(nextData['createdAt'] as Timestamp?, ts);

            return Column(
              children: [
                if (dateDivider != null) _buildDateDivider(dateDivider),
                _SwipeToReply(
                  onReply: () => _setReplyTarget(data),
                  child: _buildBubble(
                    isMine: isMine,
                    senderName: senderName,
                    roomNumber: roomNumber,
                    text: text,
                    time: isLastOfGroup ? time : '',
                    isFirstOfGroup: isFirstOfGroup,
                    mediaUrl: mediaUrl,
                    mediaType: mediaType,
                    unreadCount: unreadCount,
                    replyTo: replyTo,
                    reactions: reactions,
                    edited: edited,
                    onReact: (emoji) => _toggleReaction(docs[index].reference, emoji),
                    onPin: text.isNotEmpty ? () => _pinNotice(senderName, text) : null,
                    onEdit: isMine && text.isNotEmpty
                        ? () => _editMessage(docs[index].reference, text)
                        : null,
                    onDelete: isMine ? () => _confirmDeleteMessage(docs[index].reference) : null,
                    // 타인 메시지에는 신고/차단 메뉴 버튼을 노출한다(가이드라인 1.2).
                    onModerate: isMine || senderId == null
                        ? null
                        : () => _showModerationSheet(
                              messageId: docs[index].id,
                              senderId: senderId,
                              senderName: senderName,
                              text: text,
                            ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDateDivider(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade300)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300)),
        ],
      ),
    );
  }

  Widget _buildBubble({
    required bool isMine,
    required String senderName,
    required String roomNumber,
    required String text,
    required String time,
    bool isFirstOfGroup = true,
    String? mediaUrl,
    String? mediaType,
    int unreadCount = 0,
    Map<String, dynamic>? replyTo,
    Map<String, dynamic>? reactions,
    bool edited = false,
    ValueChanged<String>? onReact,
    VoidCallback? onPin,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    VoidCallback? onModerate,
  }) {
    final hasMedia = mediaUrl != null && mediaUrl.isNotEmpty;
    final bubbleColor = isMine ? Colors.cyan.shade500 : Colors.white;
    final textColor = isMine ? Colors.white : Colors.black87;
    final nameLabel = roomNumber == '층장' ? '$senderName (층장)' : '$senderName ($roomNumber호)';

    return Padding(
      // 연속 메시지는 위 간격을 좁혀 한 덩어리로 보이게 한다.
      padding: EdgeInsets.only(bottom: 2, top: isFirstOfGroup ? 8 : 0),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // 아바타는 이름 옆(같은 줄)에 표시하고, 연속 메시지에서는 둘 다 생략한다.
              if (!isMine && isFirstOfGroup)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 16.5,
                        backgroundColor: Colors.orange.shade100,
                        child: Icon(Icons.person,
                            size: 20, color: Colors.orange.shade700),
                      ),
                      const SizedBox(width: 6),
                      Text(nameLabel,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              // 말풍선은 아바타 오른쪽 라인에 맞춘다. (아바타 33 + 간격 6)
              Padding(
                padding: EdgeInsets.only(left: isMine ? 0 : 39),
                child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isMine) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (unreadCount > 0)
                          Text('$unreadCount',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.amber.shade700,
                                  fontWeight: FontWeight.bold)),
                        Text(time,
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade500)),
                      ],
                    ),
                    const SizedBox(width: 6),
                  ],
                  Column(
                    crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.62,
                    ),
                    child: hasMedia
                        // 첨부는 여백 없이 이미지/영상만 둥글게 보여준다.
                        ? ChatMediaBubble(
                            url: mediaUrl,
                            isVideo: mediaType == 'video',
                            maxWidth: MediaQuery.of(context).size.width * 0.62,
                          )
                        : GestureDetector(
                            onLongPressStart: (details) => _showMessageMenu(
                              details.globalPosition,
                              text,
                              onDelete: onDelete,
                              onReact: onReact,
                              onPin: onPin,
                              onEdit: onEdit,
                              onModerate: onModerate,
                            ),
                            child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: bubbleColor,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(isMine ? 16 : 4),
                                bottomRight: Radius.circular(isMine ? 4 : 16),
                              ),
                              border: isMine
                                  ? null
                                  : Border.all(color: Colors.grey.shade200),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (replyTo != null) ...[
                                  _buildReplyQuote(replyTo, isMine),
                                  const SizedBox(height: 6),
                                ],
                                Text.rich(
                                  TextSpan(
                                    text: text,
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: textColor,
                                        height: 1.4),
                                    children: edited
                                        ? [
                                            TextSpan(
                                              text: ' (수정됨)',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: textColor.withValues(alpha: 0.65)),
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            ),
                          ),
                  ),
                  if (reactions != null && reactions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: _buildReactionsRow(reactions, onReact),
                    ),
                    ],
                  ),
                  if (!isMine) ...[
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (unreadCount > 0)
                          Text('$unreadCount',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.amber.shade700,
                                  fontWeight: FontWeight.bold)),
                        Text(time,
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade500)),
                      ],
                    ),
                    // 신고/차단 메뉴 (App Store 가이드라인 1.2)
                    if (onModerate != null)
                      GestureDetector(
                        onTap: onModerate,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Icon(Icons.more_vert,
                              size: 16, color: Colors.grey.shade400),
                        ),
                      ),
                  ],
                ],
                ),
              ),
            ],
          ),
          if (isMine) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildReplyQuote(Map<String, dynamic> replyTo, bool isMine) {
    final name = replyTo['senderName'] as String? ?? '';
    final mediaType = replyTo['mediaType'] as String?;
    final rawText = replyTo['text'] as String? ?? '';
    final preview = mediaType == 'video'
        ? '[영상]'
        : mediaType == 'image'
            ? '[사진]'
            : rawText;
    final barColor = isMine ? Colors.white70 : Colors.cyan.shade400;
    final bgColor =
        isMine ? Colors.white.withValues(alpha: 0.15) : Colors.cyan.shade50;
    final textColor = isMine ? Colors.white : Colors.grey.shade700;
    final nameColor = isMine ? Colors.white : Colors.cyan.shade800;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: barColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.bold, color: nameColor)),
          const SizedBox(height: 2),
          Text(preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    if (_isRestrictedTime()) {
      return SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bedtime_outlined, size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text(
                '00:30 ~ 09:00 사이에는 채팅을 이용할 수 없습니다',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 답장 대상 미리보기
          ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: _replyTargetNotifier,
            builder: (_, replyTo, __) {
              if (replyTo == null) return const SizedBox.shrink();
              final name = replyTo['senderName'] as String? ?? '';
              final mediaType = replyTo['mediaType'] as String?;
              final rawText = replyTo['text'] as String? ?? '';
              final preview = mediaType == 'video'
                  ? '[영상]'
                  : mediaType == 'image'
                      ? '[사진]'
                      : rawText;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 32,
                      color: Colors.cyan.shade400,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$name님에게 답장',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.cyan.shade800)),
                          const SizedBox(height: 2),
                          Text(preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _clearReplyTarget,
                      icon: Icon(Icons.close, size: 18, color: Colors.grey.shade500),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              );
            },
          ),
          // 압축/업로드 진행 표시
          ValueListenableBuilder<String?>(
            valueListenable: _uploadingNotifier,
            builder: (_, uploading, __) {
              if (uploading == null) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.cyan.shade50,
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.cyan.shade600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(uploading,
                        style: TextStyle(
                            fontSize: 12, color: Colors.cyan.shade800)),
                  ],
                ),
              );
            },
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                // 첨부 버튼
                ValueListenableBuilder<String?>(
                  valueListenable: _uploadingNotifier,
                  builder: (_, uploading, __) => IconButton(
                    onPressed: uploading != null ? null : _showAttachSheet,
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: uploading != null
                          ? Colors.grey.shade300
                          : Colors.cyan.shade600,
                    ),
                    tooltip: '사진/영상 첨부',
                  ),
                ),
                Expanded(
              child: TextField(
                controller: _msgCtrl,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: '메시지를 입력하세요...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.cyan.shade400),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<bool>(
              valueListenable: _sendingNotifier,
              builder: (_, sending, __) => GestureDetector(
                onTap: sending ? null : _send,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: sending ? Colors.grey.shade300 : Colors.cyan.shade500,
                    shape: BoxShape.circle,
                  ),
                  child: sending
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
          ),
        ],
      ),
    );
  }
}

/// 메시지 버블을 좌측으로 스와이프하면 답장 대상으로 지정하는 래퍼.
/// 드래그하는 동안 버블이 따라 움직이고, 손을 떼면 원위치로 스냅한다.
class _SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback? onReply;

  const _SwipeToReply({required this.child, this.onReply});

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply>
    with SingleTickerProviderStateMixin {
  static const double _triggerDistance = 56;
  static const double _maxDrag = 72;

  late final AnimationController _controller;
  double _dragStartDx = 0;
  double _dragDx = 0;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _controller.addListener(() {
      setState(() {
        _dragDx = _dragStartDx * (1 - _controller.value);
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onUpdate(DragUpdateDetails details) {
    if (widget.onReply == null) return;
    setState(() {
      _dragDx = (_dragDx + details.delta.dx).clamp(-_maxDrag, 0.0);
      final shouldTrigger = _dragDx <= -_triggerDistance;
      if (shouldTrigger && !_triggered) {
        _triggered = true;
        HapticFeedback.selectionClick();
      } else if (!shouldTrigger && _triggered) {
        _triggered = false;
      }
    });
  }

  void _onEnd(DragEndDetails details) {
    if (widget.onReply == null) return;
    if (_triggered) widget.onReply!();
    _triggered = false;
    _dragStartDx = _dragDx;
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          if (_dragDx < 0)
            Opacity(
              opacity: (-_dragDx / _triggerDistance).clamp(0.0, 1.0),
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.reply, size: 20, color: Colors.cyan.shade400),
              ),
            ),
          Transform.translate(
            offset: Offset(_dragDx, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
