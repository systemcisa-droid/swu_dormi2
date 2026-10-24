import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/server_clock.dart';
import '../../utils/floor_chat_strings.dart';
import 'chat_media.dart';
import 'chat_upload.dart';

/// 기숙사 건물과 호실 번호로 동(A동/B동)을 계산한다.
///
/// 국제생활관은 호실 번호만으로 동이 정해지므로, 저장된 building 값이
/// '미배정'이어도 여기서 올바른 동을 구할 수 있다.
/// '(방학)'은 같은 건물을 학기중/방학으로 나눈 개념이라 호실 체계가 같다.
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
//         바롬인성교육관_1001-A호 (바롬은 동 구분이 없어 동 세그먼트 없이 구성)
String? buildRoomId(String? dormBuilding, String building, String roomNumber) {
  if (dormBuilding == null || dormBuilding.isEmpty) return null;
  if (roomNumber.isEmpty || roomNumber == '000') return null;
  // 바롬인성교육관은 동(wing)이 없다. 층장앱 _toRoomId 과 동일하게 동 세그먼트를 뺀다.
  if (dormBuilding.startsWith('바롬인성교육관')) {
    return '${dormBuilding}_$roomNumber호';
  }
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

  /// 답장 대상으로 지정된 메시지 (스와이프로 선택)
  final ValueNotifier<Map<String, dynamic>?> _replyTargetNotifier =
      ValueNotifier(null);

  /// 채팅방 참여자 수 (해당 호실 학생 + 담당 층장)
  /// 안 읽은 사람 수 = 참여자 수 - readBy 길이
  int _memberCount = 0;

  /// 채팅방에 있는 학생 이름 목록 (상단에 표시)
  List<String> _memberNames = [];

  /// 현재 언어 설정에 맞는 문자열
  FloorChatStrings get _s => FloorChatStrings(
      Provider.of<LocaleProvider>(context, listen: false).isEnglish);

  @override
  void initState() {
    super.initState();
    // build 이후 user 정보가 확정되면 읽음 처리 (build에서 호출하면 매 rebuild마다 실행됨)
    WidgetsBinding.instance.addPostFrameCallback((_) => _initRoom());
    // 기기 시계가 어긋나 있어도(특히 해외 로밍 폰) 서버 시각 기준으로 이용 제한
    // 시간을 판단하도록 동기화한다. 실패하면 기기 시각으로 계속 판단한다.
    if (!ServerClock.isSynced) {
      ServerClock.sync().then((_) {
        if (mounted) setState(() {});
      });
    }
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

      // 담당 층장 (assignedFloor 예: '샬롬하우스 A동 3층', '바롬인성교육관 10층')
      int captains = 0;
      String? assignedFloorKey;
      if (dormBuilding.startsWith('바롬인성교육관')) {
        // 바롬은 동이 없고 호실이 '1001-A' 형식 → '1001' 앞 숫자로 층 산출
        final base = int.tryParse(roomNumber.split('-').first) ?? 0;
        if (base != 0) assignedFloorKey = '$dormBuilding ${base ~/ 100}층';
      } else {
        final wing = _wingFromRoom(dormBuilding, roomNumber);
        if (wing != null) {
          final floorNum = (int.tryParse(roomNumber) ?? 0) ~/ 100;
          assignedFloorKey = '$dormBuilding $wing $floorNum층';
        }
      }
      if (assignedFloorKey != null) {
        final captainsSnap = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'admin_m')
            .where('assignedFloor', isEqualTo: assignedFloorKey)
            .get();
        captains = captainsSnap.docs.length;
      }

      if (mounted) {
        setState(() {
          _memberCount = students + captains;
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

  // 00:30 ~ 09:00 사용 불가.
  // 기기 로컬 시각(TimeOfDay.now())은 폰 시간대·시계 설정에 따라 조작/오차가 생길 수
  // 있어(예: 해외 로밍 중인 폰), 층장앱 QR 체크와 동일하게 서버 시각을 기준으로 삼는다.
  bool _isRestrictedTime() {
    final now = ServerClock.now().toSeoul();
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

      final replyTo = _replyTargetNotifier.value;

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
        if (replyTo != null) 'replyTo': replyTo,
      });

      await _firestore.collection('floor_chats').doc(roomId).set({
        'lastMessage': isVideo ? s.lastMessageVideo : s.lastMessageImage,
        'lastAt': FieldValue.serverTimestamp(),
        'roomId': roomId,
      }, SetOptions(merge: true));

      _clearReplyTarget();
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

  /// 메시지를 클립보드로 복사한다.
  void _copyMessageText(String text) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_s.messageCopied), duration: const Duration(seconds: 1)),
    );
  }

  /// 긴 메시지 메뉴에 쓰는 간단 이모티콘 반응 모음.
  static const _kReactionEmojis = ['❤️', '👍', '✅', '😂', '😮', '😢'];

  /// 카카오톡처럼 메시지를 길게 누르면 그 자리에 이모티콘 반응·복사·공지·수정·삭제 메뉴를 띄운다.
  /// 답장은 메뉴가 아니라 메시지를 좌측으로 스와이프해서 보낸다.
  Future<void> _showMessageMenu(
    Offset globalPosition,
    String text, {
    VoidCallback? onDelete,
    ValueChanged<String>? onReact,
    VoidCallback? onPin,
    VoidCallback? onEdit,
  }) async {
    HapticFeedback.selectionClick();
    final s = _s;
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
        if (text.isNotEmpty) PopupMenuItem(value: 'copy', child: Text(s.menuCopy)),
        if (text.isNotEmpty) PopupMenuItem(value: 'select_copy', child: Text(s.menuSelectCopy)),
        if (onPin != null) PopupMenuItem(value: 'pin', child: Text(s.menuPin)),
        if (onEdit != null) PopupMenuItem(value: 'edit', child: Text(s.menuEdit)),
        if (onDelete != null)
          PopupMenuItem(
            value: 'delete',
            child: Text(s.menuDelete, style: const TextStyle(color: Colors.red)),
          ),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_s.close)),
        ],
      ),
    );
  }

  /// 메시지를 채팅방 상단 공지로 등록한다. 해제는 상단 배너의 닫기 버튼으로 한다.
  Future<void> _pinNotice(String roomId, String senderName, String text) async {
    if (text.isEmpty) return;
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    try {
      await _firestore.collection('floor_chats').doc(roomId).set({
        'pinnedMessage': {
          'text': text,
          'senderName': senderName,
          'pinnedByName': user?.name ?? '',
          'pinnedAt': Timestamp.now(),
        },
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _unpinNotice(String roomId) async {
    try {
      await _firestore
          .collection('floor_chats')
          .doc(roomId)
          .update({'pinnedMessage': FieldValue.delete()});
    } catch (_) {}
  }

  /// 본인이 보낸 메시지의 내용을 수정한다.
  Future<void> _editMessage(DocumentReference<Object?> ref, String currentText) async {
    final s = _s;
    final controller = TextEditingController(text: currentText);
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.editMessageTitle),
        content: TextField(controller: controller, maxLines: 4, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(s.save),
          ),
        ],
      ),
    );
    if (newText == null || newText.isEmpty || newText == currentText) return;
    try {
      await ref.update({'text': newText, 'edited': true, 'editedAt': Timestamp.now()});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.editError(e))));
      }
    }
  }

  /// 메시지에 달린 이모티콘 반응을 종류별로 묶어 보여준다. 탭하면 내 반응을 토글한다.
  Widget _buildReactionsRow(Map<String, dynamic> reactions, ValueChanged<String>? onReact) {
    final myUid = Provider.of<AuthProvider>(context, listen: false).currentUser?.uid;
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

  /// 같은 이모티콘을 다시 누르면 반응을 취소하고, 다른 이모티콘을 누르면 교체한다(1인당 1개).
  Future<void> _toggleReaction(DocumentReference<Object?> ref, String emoji) async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;
    HapticFeedback.selectionClick();
    try {
      final doc = await ref.get();
      final data = doc.data() as Map<String, dynamic>?;
      final current = (data?['reactions'] as Map?)?[user.uid] as String?;
      await ref.update({
        'reactions.${user.uid}': current == emoji ? FieldValue.delete() : emoji,
      });
    } catch (_) {}
  }

  Future<void> _confirmDeleteMessage(DocumentReference<Object?> ref) async {
    final s = _s;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteMessageTitle),
        content: Text(s.deleteMessageConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.menuDelete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.deleteError(e))));
      }
    }
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

      final replyTo = _replyTargetNotifier.value;

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
        if (replyTo != null) 'replyTo': replyTo,
      });

      await _firestore.collection('floor_chats').doc(roomId).set({
        'lastMessage': text,
        'lastAt': FieldValue.serverTimestamp(),
        'roomId': roomId,
      }, SetOptions(merge: true));

      _msgCtrl.clear();
      _clearReplyTarget();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.sendError(e))));
      }
    } finally {
      _sendingNotifier.value = false;
    }
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
                _buildPinnedNoticeBanner(roomId),
                // 채팅방에 있는 학생 이름
                if (_memberNames.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200)),
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
                  replyTo: replyTo,
                  reactions: reactions,
                  edited: edited,
                  onSwipeReply: () => _setReplyTarget(data),
                  onDelete: isMine ? () => _confirmDeleteMessage(docs[index].reference) : null,
                  onReact: (emoji) => _toggleReaction(docs[index].reference, emoji),
                  onPin: text.isNotEmpty ? () => _pinNotice(roomId, senderName, text) : null,
                  onEdit: isMine && text.isNotEmpty
                      ? () => _editMessage(docs[index].reference, text)
                      : null,
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// "공지"로 등록된 메시지를 채팅방 상단에 고정 배너로 보여준다.
  Widget _buildPinnedNoticeBanner(String roomId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('floor_chats').doc(roomId).snapshots(),
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
                      fontSize: 12,
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.w600),
                ),
              ),
              GestureDetector(
                onTap: () => _unpinNotice(roomId),
                child: Icon(Icons.close, size: 16, color: Colors.amber.shade800),
              ),
            ],
          ),
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
    VoidCallback? onSwipeReply,
    VoidCallback? onDelete,
    ValueChanged<String>? onReact,
    VoidCallback? onPin,
    VoidCallback? onEdit,
  }) {
    final hasMedia = mediaUrl != null && mediaUrl.isNotEmpty;
    final bubbleColor = isMine ? Colors.cyan.shade500 : Colors.white;
    final textColor = isMine ? Colors.white : Colors.black87;
    final nameLabel = _s.senderLabel(senderName, roomNumber);

    return _SwipeToReply(
      onReply: onSwipeReply,
      child: Padding(
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
                                              text: ' ${_s.editedLabel}',
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
                  ],
                ],
                ),
              ),
            ],
          ),
          if (isMine) const SizedBox(width: 4),
        ],
      ),
      ),
    );
  }

  Widget _buildReplyQuote(Map<String, dynamic> replyTo, bool isMine) {
    final name = replyTo['senderName'] as String? ?? '';
    final mediaType = replyTo['mediaType'] as String?;
    final rawText = replyTo['text'] as String? ?? '';
    final preview = mediaType == 'video'
        ? _s.replyMediaVideo
        : mediaType == 'image'
            ? _s.replyMediaImage
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
          // 답장 대상 미리보기
          ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: _replyTargetNotifier,
            builder: (_, replyTo, __) {
              if (replyTo == null) return const SizedBox.shrink();
              final name = replyTo['senderName'] as String? ?? '';
              final mediaType = replyTo['mediaType'] as String?;
              final rawText = replyTo['text'] as String? ?? '';
              final preview = mediaType == 'video'
                  ? _s.replyMediaVideo
                  : mediaType == 'image'
                      ? _s.replyMediaImage
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
                          Text(_s.replyingTo(name),
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

/// 메시지 버블을 좌측으로 스와이프하면 답장 대상으로 지정하는 래퍼.
/// 카카오톡처럼 드래그하는 동안 버블이 따라 움직이고, 손을 떼면 원위치로 스냅한다.
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
