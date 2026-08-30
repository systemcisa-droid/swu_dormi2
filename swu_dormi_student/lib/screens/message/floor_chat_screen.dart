import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/floor_chat_strings.dart';
import 'chat_media.dart';
import 'chat_upload.dart';

/// 기숙사 건물과 호실 번호로 동(A동/B동)을 계산한다.
///
/// 국제생활관은 호실 번호만으로 동이 정해지므로, 저장된 building 값이
/// '미배정'이어도 여기서 올바른 동을 구할 수 있다.
/// '(겨울방학)'은 같은 건물을 학기중/방학으로 나눈 개념이라 호실 체계가 같다.
String? _wingFromRoom(String dormBuilding, String roomNumber) {
  final room = int.tryParse(roomNumber) ?? 0;
  if (room == 0) return null;

  if (dormBuilding.startsWith('국제생활관')) {
    if ((room >= 101 && room <= 132) || (room >= 201 && room <= 229)) return 'A동';
    if ((room >= 233 && room <= 260) || (room >= 301 && room <= 329)) return 'B동';
    return null;
  }
  if (dormBuilding.startsWith('샬롬하우스')) {
    final roomInFloor = room % 100;
    if (roomInFloor >= 1 && roomInFloor <= 20) return 'A동';
    if (roomInFloor >= 21 && roomInFloor <= 35) return 'B동';
    return null;
  }
  return null;
}

// roomId: 샬롬하우스_A동_301호 (호실 단위 채팅방)
String? buildRoomId(String? dormBuilding, String building, String roomNumber) {
  if (dormBuilding == null || dormBuilding.isEmpty) return null;
  if (roomNumber.isEmpty || roomNumber == '000') return null;
  // 저장된 building 이 '미배정' 이어도 호실로 동을 계산해 채팅방을 찾는다.
  final wing = _wingFromRoom(dormBuilding, roomNumber) ??
      (building == '미배정' || building.isEmpty ? null : building);
  if (wing == null) return null;
  return '${dormBuilding}_${wing}_$roomNumber호';
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
  /// 첨부 업로드 진행 상태 (압축/업로드 중 입력창에 표시)
  final _uploadingNotifier = ValueNotifier<String?>(null);
  int _prevDocCount = 0;

  /// 채팅방 참여자 수 (해당 호실 학생 + 담당 층장)
  /// 안 읽은 사람 수 = 참여자 수 - readBy 길이
  int _memberCount = 0;

  /// 현재 언어 설정에 맞는 문자열
  FloorChatStrings get _s => FloorChatStrings(
      Provider.of<LocaleProvider>(context, listen: false).isEnglish);

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
    _loadMemberCount(user);
  }

  /// 채팅방 참여자 수를 구한다. (해당 호실 재실 학생 + 담당 층장)
  /// 안 읽은 사람 수 계산의 기준이 되며, 알림 발송 대상과 같은 규칙이다.
  Future<void> _loadMemberCount(dynamic user) async {
    final dormBuilding = (user.dormBuilding as String?) ?? '';
    final roomNumber = (user.roomNumber as String?) ?? '';
    if (dormBuilding.isEmpty || roomNumber.isEmpty) return;

    try {
      final studentsSnap = await _firestore
          .collection('users')
          .where('dormBuilding', isEqualTo: dormBuilding)
          .where('roomNumber', isEqualTo: roomNumber)
          .get();
      final students = studentsSnap.docs.where((d) {
        final data = d.data();
        if ((data['role'] as String?) != 'student') return false;
        return ((data['residentStatus'] as String?) ?? '재실중') == '재실중';
      }).length;

      // 담당 층장 (assignedFloor 예: '샬롬하우스 A동 3층')
      final wing = _wingFromRoom(dormBuilding, roomNumber);
      int captains = 0;
      if (wing != null) {
        final floorNum = (int.tryParse(roomNumber) ?? 0) ~/ 100;
        final captainsSnap = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'admin_m')
            .where('assignedFloor',
                isEqualTo: '$dormBuilding $wing $floorNum층')
            .get();
        captains = captainsSnap.docs.length;
      }

      if (mounted) setState(() => _memberCount = students + captains);
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
    super.dispose();
  }

  // 00:30 ~ 09:00 사용 불가
  bool _isRestrictedTime() {
    final now = TimeOfDay.now();
    final minutes = now.hour * 60 + now.minute;
    return minutes >= 30 && minutes < 9 * 60;
  }

  /// 첨부(사진/영상) 선택 → 압축 → 업로드 → 메시지 전송
  Future<void> _sendMedia(
    String roomId,
    String senderName,
    String roomNumber, {
    required ImageSource source,
    required bool isVideo,
  }) async {
    if (_isRestrictedTime()) return;
    if (_uploadingNotifier.value != null) return;

    // 파일 선택 전에 읽어둔다 (await 이후 context 사용을 피하기 위해)
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;
    final s = _s;

    try {
      final picked = isVideo
          ? await ChatUpload.pickVideo(source)
          : await ChatUpload.pickImage(source);
      if (picked == null) return;

      File file = picked;
      if (isVideo) {
        _uploadingNotifier.value = s.compressingVideo;
        file = await ChatUpload.compressVideo(picked);
      }

      // 압축 후에도 너무 크면 중단한다.
      if (await file.length() > ChatUpload.maxUploadBytes) {
        _uploadingNotifier.value = null;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.fileTooLarge)),
          );
        }
        return;
      }

      _uploadingNotifier.value =
          isVideo ? s.uploadingVideo : s.uploadingImage;
      final url = await ChatUpload.upload(
        file: file,
        roomId: roomId,
        isVideo: isVideo,
      );

      await _firestore
          .collection('floor_chats')
          .doc(roomId)
          .collection('messages')
          .add({
        'text': '',
        'mediaUrl': url,
        'mediaType': isVideo ? 'video' : 'image',
        'senderId': user.uid,
        'senderName': senderName,
        'roomNumber': roomNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': [user.uid],
      });

      await _firestore.collection('floor_chats').doc(roomId).set({
        'lastMessage': isVideo ? s.lastMessageVideo : s.lastMessageImage,
        'lastAt': FieldValue.serverTimestamp(),
        'roomId': roomId,
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.sendError(e))));
      }
    } finally {
      _uploadingNotifier.value = null;
    }
  }

  /// 첨부 방식 선택 시트
  void _showAttachSheet(String roomId, String senderName, String roomNumber) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.cyan),
              title: Text(_s.pickImage),
              onTap: () {
                Navigator.pop(ctx);
                _sendMedia(roomId, senderName, roomNumber,
                    source: ImageSource.gallery, isVideo: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library, color: Colors.cyan),
              title: Text(_s.pickVideo),
              subtitle: Text(_s.pickVideoHint,
                  style: const TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                _sendMedia(roomId, senderName, roomNumber,
                    source: ImageSource.gallery, isVideo: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send(String roomId, String senderName, String roomNumber) async {
    if (_isRestrictedTime()) return;
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    _sendingNotifier.value = true;
    final s = _s;
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
            .showSnackBar(SnackBar(content: Text(s.sendError(e))));
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
            Text(_s.title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            if (user != null && roomId != null)
              Text(
                _s.roomChatSubtitle(user.roomNumber),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
        // 앱바가 흰색이므로 상태표시줄 아이콘을 어둡게 한다.
        systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.white,
        ),
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
                          _s.roomChatBanner(user!.roomNumber),
                          style: TextStyle(fontSize: 12, color: Colors.cyan.shade800),
                        ),
                      ),
                      Icon(Icons.access_time, size: 13, color: Colors.cyan.shade600),
                      const SizedBox(width: 4),
                      Text(
                        _s.usageHours,
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
            Text(_s.noRoomInfoTitle,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_s.noRoomInfoHint,
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
                Text(_s.emptyMessages,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
              ],
            ),
          );
        }

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
            // 안 읽은 사람 수 = 참여자 수 - 읽은 사람 수
            final readBy = (data['readBy'] as List<dynamic>?) ?? const [];
            final unreadCount = _memberCount > 0
                ? (_memberCount - readBy.length).clamp(0, _memberCount)
                : 0;
            final ts = data['createdAt'] as Timestamp?;
            final time = ts != null ? DateFormat('HH:mm').format(ts.toDate()) : '';

            String? dateDivider;
            if (index == 0 && ts != null) {
              dateDivider =
                  DateFormat(_s.dateFormat, _s.dateLocale).format(ts.toDate());
            } else if (index > 0 && ts != null) {
              final prevTs = (docs[index - 1].data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              if (prevTs != null) {
                final prev = prevTs.toDate();
                final curr = ts.toDate();
                if (prev.day != curr.day || prev.month != curr.month || prev.year != curr.year) {
                  dateDivider =
                      DateFormat(_s.dateFormat, _s.dateLocale).format(curr);
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
                _buildBubble(
                  isMine: isMine,
                  senderName: senderName,
                  roomNumber: roomNumber,
                  text: text,
                  time: isLastOfGroup ? time : '',
                  isFirstOfGroup: isFirstOfGroup,
                  mediaUrl: mediaUrl,
                  mediaType: mediaType,
                  unreadCount: unreadCount,
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
  }) {
    final hasMedia = mediaUrl != null && mediaUrl.isNotEmpty;
    final bubbleColor = isMine ? Colors.cyan.shade500 : Colors.white;
    final textColor = isMine ? Colors.white : Colors.black87;
    final nameLabel = _s.senderLabel(senderName, roomNumber);

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
                      // 층장은 연한 녹색, 같은 호실 학생은 하늘색으로 구분한다.
                      CircleAvatar(
                        radius: 16.5,
                        backgroundColor: roomNumber == '층장'
                            ? Colors.green.shade100
                            : Colors.cyan.shade100,
                        child: Icon(Icons.person,
                            size: 20,
                            color: roomNumber == '층장'
                                ? Colors.green.shade700
                                : Colors.cyan.shade700),
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
                        : Container(
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
                            child: Text(text,
                                style: TextStyle(
                                    fontSize: 14, color: textColor, height: 1.4)),
                          ),
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
                _s.restrictedTime,
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
                  onPressed: uploading != null
                      ? null
                      : () => _showAttachSheet(roomId, senderName, roomNumber),
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: uploading != null
                        ? Colors.grey.shade300
                        : Colors.cyan.shade600,
                  ),
                  tooltip: _s.attachTooltip,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: _s.inputHint,
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
        ],
      ),
    );
  }
}
