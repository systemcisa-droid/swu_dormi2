import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';

// roomId: 샬롬하우스_A동_301호 (호실 단위 채팅방)
String? buildRoomId(String? dormBuilding, String building, String roomNumber) {
  if (dormBuilding == null || dormBuilding.isEmpty) return null;
  if (building == '미배정' || roomNumber.isEmpty || roomNumber == '000') return null;
  return '${dormBuilding}_${building}_$roomNumber호';
}

class FloorChatScreen extends StatefulWidget {
  const FloorChatScreen({super.key});

  @override
  State<FloorChatScreen> createState() => _FloorChatScreenState();
}

class _FloorChatScreenState extends State<FloorChatScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _sendingNotifier = ValueNotifier<bool>(false);
  int _prevDocCount = 0;

  @override
  void initState() {
    super.initState();
    // build 이후 user 정보가 확정되면 읽음 처리 (build에서 호출하면 매 rebuild마다 실행됨)
    WidgetsBinding.instance.addPostFrameCallback((_) => _initRoom());
  }

  void _initRoom() {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;
    final roomId = buildRoomId(user.dormBuilding, user.building, user.roomNumber);
    if (roomId == null) return;
    _markAllRead(roomId, user.uid);
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _sendingNotifier.dispose();
    super.dispose();
  }

  // 00:30 ~ 09:00 사용 불가
  bool _isRestrictedTime() {
    final now = TimeOfDay.now();
    final minutes = now.hour * 60 + now.minute;
    return minutes >= 30 && minutes < 9 * 60;
  }

  Future<void> _send(String roomId, String senderName, String roomNumber) async {
    if (_isRestrictedTime()) return;
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    _sendingNotifier.value = true;
    try {
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      if (user == null) return;

      await _firestore
          .collection('floor_chats')
          .doc(roomId)
          .collection('messages')
          .add({
        'text': text,
        'senderId': user.uid,
        'senderName': senderName,
        'roomNumber': roomNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': [user.uid],
      });

      await _firestore.collection('floor_chats').doc(roomId).set({
        'lastMessage': text,
        'lastAt': FieldValue.serverTimestamp(),
        'roomId': roomId,
      }, SetOptions(merge: true));

      _msgCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('전송 오류: $e')));
      }
    } finally {
      _sendingNotifier.value = false;
    }
  }

  Future<void> _markAllRead(String roomId, String myUid) async {
    try {
      final snap = await _firestore
          .collection('floor_chats')
          .doc(roomId)
          .collection('messages')
          .get();
      final batch = _firestore.batch();
      bool hasPending = false;
      for (final doc in snap.docs) {
        final readBy = (doc.data()['readBy'] as List<dynamic>?) ?? [];
        if (!readBy.contains(myUid)) {
          batch.update(doc.reference, {
            'readBy': FieldValue.arrayUnion([myUid]),
          });
          hasPending = true;
        }
      }
      if (hasPending) await batch.commit();
    } catch (e) {
      debugPrint('읽음 처리 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;
    final roomId = user != null
        ? buildRoomId(user.dormBuilding, user.building, user.roomNumber)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('층장단톡방', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (user != null && roomId != null)
              Text(
                '${user.roomNumber}호 채팅방',
                style: TextStyle(fontSize: 11, color: Colors.cyan.shade100),
              ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: roomId == null
          ? _buildNoRoomInfo()
          : Column(
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
                          '${user!.roomNumber}호 ↔ 층장 채팅방',
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
                Expanded(child: _buildMessageList(roomId, user.uid)),
                _buildInputBar(roomId, user.name, user.roomNumber),
              ],
            ),
    );
  }

  Widget _buildNoRoomInfo() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('기숙사/호실 정보가 없습니다',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('프로필에서 기숙사와 호실을 먼저 입력해주세요',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(String roomId, String myUid) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('floor_chats')
          .doc(roomId)
          .collection('messages')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('첫 메시지를 보내보세요!',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
              ],
            ),
          );
        }

        // 새 메시지가 추가됐을 때만 스크롤
        if (docs.length > _prevDocCount) {
          _prevDocCount = docs.length;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollCtrl.hasClients) {
              _scrollCtrl.animateTo(
                _scrollCtrl.position.maxScrollExtent,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          });
        }

        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final isMine = (data['senderId'] as String?) == myUid;
            final senderName = data['senderName'] as String? ?? '';
            final roomNumber = data['roomNumber'] as String? ?? '';
            final text = data['text'] as String? ?? '';
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
                if (prev.day != curr.day || prev.month != curr.month || prev.year != curr.year) {
                  dateDivider = DateFormat('yyyy년 MM월 dd일 (E)', 'ko').format(curr);
                }
              }
            }

            return Column(
              children: [
                if (dateDivider != null) _buildDateDivider(dateDivider),
                _buildBubble(
                  isMine: isMine,
                  senderName: senderName,
                  roomNumber: roomNumber,
                  text: text,
                  time: time,
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
  }) {
    final bubbleColor = isMine ? Colors.cyan.shade500 : Colors.white;
    final textColor = isMine ? Colors.white : Colors.black87;
    final nameLabel = roomNumber == '층장' ? '$senderName (층장)' : '$senderName ($roomNumber호)';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.cyan.shade100,
              child: Icon(Icons.person, size: 18, color: Colors.cyan.shade700),
            ),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(nameLabel,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isMine) ...[
                    Text(time, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    const SizedBox(width: 6),
                  ],
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.62,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isMine ? 16 : 4),
                          bottomRight: Radius.circular(isMine ? 4 : 16),
                        ),
                        border: isMine ? null : Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(text,
                          style: TextStyle(fontSize: 14, color: textColor, height: 1.4)),
                    ),
                  ),
                  if (!isMine) ...[
                    const SizedBox(width: 6),
                    Text(time, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                  ],
                ],
              ),
            ],
          ),
          if (isMine) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildInputBar(String roomId, String senderName, String roomNumber) {
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: '메시지를 입력하세요...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
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
                onTap: sending ? null : () => _send(roomId, senderName, roomNumber),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: sending
                        ? Colors.grey.shade300
                        : Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: sending
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
