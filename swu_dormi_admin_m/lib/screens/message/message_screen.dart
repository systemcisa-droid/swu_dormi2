import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
// captainFloor: "샬롬하우스 A동 3층"
// roomId:       "샬롬하우스_A동_301호"
String _toRoomId(String dormBuilding, String building, String roomNumber) =>
    '${dormBuilding}_${building}_$roomNumber호';

Future<String?> _getAssignedFloor() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return null;
  final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  return doc.data()?['assignedFloor'] as String?;
}

// "샬롬하우스 A동 3층" → (dormBuilding: "샬롬하우스", building: "A동", floorNum: 3)
({String dormBuilding, String building, int floorNum})? _parseFloor(String assignedFloor) {
  final wingMatch = RegExp(r'[A-Z]동').firstMatch(assignedFloor);
  final floorMatch = RegExp(r'(\d+)층').firstMatch(assignedFloor);

  String dormBuilding;
  if (assignedFloor.startsWith('샬롬하우스(겨울방학)')) {
    dormBuilding = '샬롬하우스(겨울방학)';
  } else if (assignedFloor.startsWith('샬롬하우스')) {
    dormBuilding = '샬롬하우스';
  } else if (assignedFloor.startsWith('국제생활관')) {
    dormBuilding = '국제생활관';
  } else if (assignedFloor.startsWith('바롬인성교육관')) {
    dormBuilding = '바롬인성교육관';
  } else {
    return null;
  }

  final building = wingMatch?.group(0) ?? ''; // e.g. "A동"
  final floorNum = floorMatch != null ? int.tryParse(floorMatch.group(1)!) ?? 0 : 0;
  if (building.isEmpty || floorNum == 0) return null;
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

  Future<void> _loadRooms() async {
    if (_parsed == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      var query = _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('dormBuilding', isEqualTo: _parsed!.dormBuilding);

      if (_parsed!.building.isNotEmpty) {
        query = query.where('building', isEqualTo: _parsed!.building);
      }

      final snap = await query.orderBy('roomNumber').get();

      final rooms = <String>{};
      for (final doc in snap.docs) {
        final room = doc.data()['roomNumber'] as String? ?? '';
        if (room.isEmpty || room == '000') continue;
        final floorNum = int.tryParse(room) ?? 0;
        if ((floorNum ~/ 100) == _parsed!.floorNum) {
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
  int _prevDocCount = 0;

  @override
  void initState() {
    super.initState();
    _markAllRead();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _sendingNotifier.dispose();
    super.dispose();
  }

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
  bool _isRestrictedTime() {
    final now = TimeOfDay.now();
    final minutes = now.hour * 60 + now.minute;
    return minutes >= 30 && minutes < 9 * 60; // 00:30(30) ~ 09:00(540)
  }

  Future<void> _send() async {
    if (_isRestrictedTime()) return;
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    final captainUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    // 전송 버튼만 비활성화 — setState로 전체 rebuild 없이 ValueNotifier 사용
    _sendingNotifier.value = true;
    try {
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
      });

      await _firestore.collection('floor_chats').doc(widget.roomId).set({
        'lastMessage': text,
        'lastAt': FieldValue.serverTimestamp(),
        'roomId': widget.roomId,
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
        final docs = snapshot.data?.docs ?? [];
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
                if (prev.year != curr.year || prev.month != curr.month || prev.day != curr.day) {
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
              backgroundColor: Colors.orange.shade100,
              child: Icon(Icons.person, size: 18, color: Colors.orange.shade700),
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
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600)),
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
    );
  }
}
