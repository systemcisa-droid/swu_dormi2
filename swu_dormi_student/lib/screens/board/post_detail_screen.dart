import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/post_model.dart';
import '../../models/comment_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/database_service.dart';
import '../../utils/board_strings.dart';
import '../../widgets/linkified_text.dart';
import '../../widgets/timetable_preview.dart';
import '../timetable/timetable_page.dart';
import 'add_post_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _db = DatabaseService();
  final _commentController = TextEditingController();
  bool _isLoadingComment = false;

  @override
  void initState() {
    super.initState();
    _incrementViewCount();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _incrementViewCount() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;
    await _db.incrementPostViewCount(widget.postId, user.uid);
  }

  /// 게시판에 공유된 시간표를 내 시간표 목록(SharedPreferences)에 새 시간표로 추가한다.
  /// timetable_page.dart가 쓰는 저장 형식(ClassItem/TimetableData)을 그대로 재사용한다.
  Future<void> _importTimetable(PostModel post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('시간표 가져오기'),
        content: const Text('이 시간표를 내 시간표 목록에 추가하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('가져오기')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final existingJson = prefs.getString('timetables_data');
      final timetables = existingJson != null
          ? List<dynamic>.from(jsonDecode(existingJson)).map((x) => TimetableData.fromMap(x)).toList()
          : <TimetableData>[];

      final now = DateTime.now().millisecondsSinceEpoch;
      var importedName = post.title.replaceFirst(RegExp(r'\s*시간표 공유\s*$'), '').trim();
      if (importedName.isEmpty) importedName = '가져온 시간표';

      // id가 원본 시간표와 겹치면(같은 기기에 이미 이 글의 원본이 있는 경우) 편집/삭제
      // 시 서로 섞일 수 있으므로 새 id를 새로 부여한다.
      final newClasses = <ClassItem>[
        for (var i = 0; i < post.timetableClasses.length; i++)
          ClassItem.fromMap(post.timetableClasses[i])..id = '$now-$i',
      ];
      final newTimetable = TimetableData(id: '$now', name: importedName, classes: newClasses);
      timetables.add(newTimetable);

      await prefs.setString(
        'timetables_data',
        jsonEncode(timetables.map((t) => t.toMap()).toList()),
      );
      await prefs.setString('current_timetable_id', newTimetable.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내 시간표 목록에 추가했어요')),
      );
      Navigator.push(context, MaterialPageRoute(builder: (_) => const TimetablePage()));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('가져오기에 실패했습니다: $e')),
      );
    }
  }

  Future<void> _toggleLike(PostModel post, String userId) async {
    try {
      final isLiked = post.likes.contains(userId);
      if (isLiked) {
        await _firestore.collection('board_posts').doc(widget.postId).update({
          'likes': FieldValue.arrayRemove([userId]),
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        await _firestore.collection('board_posts').doc(widget.postId).update({
          'likes': FieldValue.arrayUnion([userId]),
          'likeCount': FieldValue.increment(1),
        });
      }
    } catch (e) {
      if (mounted) {
        final s = BoardStrings(Provider.of<LocaleProvider>(context, listen: false).isEnglish);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.genericError(e))),
        );
      }
    }
  }

  Future<void> _addComment(String userId, String userName, String? userNickname, String? profileImageUrl) async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    if (_isLoadingComment) return;

    setState(() => _isLoadingComment = true);

    try {
      final commentId = _firestore.collection('board_comments').doc().id;
      final comment = CommentModel(
        id: commentId,
        postId: widget.postId,
        content: content,
        authorId: userId,
        authorName: userNickname ?? userName,
        authorProfileImageUrl: profileImageUrl,
        createdAt: DateTime.now(),
      );

      _commentController.clear();

      await _firestore.collection('board_comments').doc(commentId).set(comment.toMap());
      await _firestore.collection('board_posts').doc(widget.postId).update({
        'commentCount': FieldValue.increment(1),
      });

      // 게시글 작성자에게 댓글 알림 생성 (본인 글에 본인이 단 댓글은 제외)
      await _notifyPostAuthor(
        commenterName: userNickname ?? userName,
        content: content,
        commenterId: userId,
      );

      if (mounted) {
        final s = BoardStrings(Provider.of<LocaleProvider>(context, listen: false).isEnglish);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.commentPosted),
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final s = BoardStrings(Provider.of<LocaleProvider>(context, listen: false).isEnglish);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.commentPostError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingComment = false);
    }
  }

  /// 내 게시글에 댓글이 달리면 작성자에게 알림을 남긴다.
  /// 알림 실패가 댓글 등록을 되돌리지 않도록 예외는 삼킨다.
  Future<void> _notifyPostAuthor({
    required String commenterName,
    required String content,
    required String commenterId,
  }) async {
    try {
      final postDoc =
          await _firestore.collection('board_posts').doc(widget.postId).get();
      final postData = postDoc.data();
      if (postData == null) return;

      final authorId = (postData['authorId'] as String?) ?? '';
      // 본인 글에 본인이 단 댓글은 알리지 않는다.
      if (authorId.isEmpty || authorId == commenterId) return;

      final postTitle = (postData['title'] as String?) ?? '';
      // 알림 목록에서 길어지지 않도록 본문은 앞부분만 담는다.
      final preview = content.length > 40 ? '${content.substring(0, 40)}...' : content;

      await _firestore.collection('user_notifications').add({
        'userId': authorId,
        'type': 'board_comment',
        'title': '내 게시글에 새 댓글',
        'content': '$commenterName님: $preview',
        'data': {
          'postId': widget.postId,
          'postTitle': postTitle,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      debugPrint('댓글 알림 생성 실패: $e');
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final s = BoardStrings(Provider.of<LocaleProvider>(context, listen: false).isEnglish);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.deleteCommentTitle),
        content: Text(s.deleteCommentConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _firestore.collection('board_comments').doc(commentId).delete();
      await _firestore.collection('board_posts').doc(widget.postId).update({
        'commentCount': FieldValue.increment(-1),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.commentDeleted)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.commentDeleteError(e))),
        );
      }
    }
  }

  Future<void> _deletePost() async {
    final s = BoardStrings(Provider.of<LocaleProvider>(context, listen: false).isEnglish);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.deletePostTitle),
        content: Text(s.deletePostConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final commentsSnapshot = await _firestore
          .collection('board_comments')
          .where('postId', isEqualTo: widget.postId)
          .get();
      for (var doc in commentsSnapshot.docs) {
        await doc.reference.delete();
      }
      await _firestore.collection('board_posts').doc(widget.postId).delete();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.postDeleted)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.postDeleteError(e))),
        );
      }
    }
  }

  // 신고 다이얼로그 (게시글 / 댓글 공용)
  Future<void> _showReportDialog({
    required String reporterId,
    required String targetId,
    required String targetType, // 'post' | 'comment'
    required String targetAuthorId,
  }) async {
    final s = BoardStrings(Provider.of<LocaleProvider>(context, listen: false).isEnglish);
    // 표시는 번역된 라벨을 쓰되, Firestore에는 한국어 원본 사유를 저장해 관리자 화면과 일관성 유지
    const reportReasonsKo = ['비방·욕설', '허위 사실 유포', '음란·불건전 내용', '개인정보 침해', '기타'];
    final reportReasons = s.reportReasons;
    String? selectedReasonKo;
    final etcController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(s.reportDialogTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  targetType == 'post' ? s.reportPostPrompt : s.reportCommentPrompt,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                ...List.generate(reportReasonsKo.length, (i) {
                  final reasonKo = reportReasonsKo[i];
                  final reasonLabel = reportReasons[i];
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedReasonKo = reasonKo),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            selectedReasonKo == reasonKo
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            size: 20,
                            color: selectedReasonKo == reasonKo
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(reasonLabel, style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  );
                }),
                if (selectedReasonKo == '기타') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: etcController,
                    decoration: InputDecoration(
                      hintText: s.reportDetailHint,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    maxLines: 3,
                    maxLength: 200,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(s.cancel),
            ),
            TextButton(
              onPressed: selectedReasonKo == null
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: Text(s.report, style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || selectedReasonKo == null) {
      etcController.dispose();
      return;
    }

    try {
      await _firestore.collection('reports').add({
        'reporterId': reporterId,
        'targetId': targetId,
        'targetType': targetType,
        'targetAuthorId': targetAuthorId,
        'reason': selectedReasonKo,
        'detail': selectedReasonKo == '기타' ? etcController.text.trim() : '',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.reportSubmitted)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.reportSubmitError(e))),
        );
      }
    } finally {
      etcController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final s = BoardStrings(Provider.of<LocaleProvider>(context).isEnglish);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.postDetailTitle),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('board_posts').doc(widget.postId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(s.detailError(snapshot.error!)));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text(s.postNotFound));
          }

          final post = PostModel.fromMap(snapshot.data!.data() as Map<String, dynamic>);
          final isAuthor = user != null && post.authorId == user.uid;
          final isLiked = user != null && post.likes.contains(user.uid);

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildPostContent(post, isAuthor, isLiked, user, s),
                    const Divider(height: 32, thickness: 1),
                    _buildCommentsList(user, s),
                  ],
                ),
              ),
              if (user != null) _buildCommentInput(user, s),
            ],
          );
        },
      ),
    );
  }

  Future<void> _blockUser(String targetUid) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isBlocked = authProvider.blockedUsers.contains(targetUid);
    final s = BoardStrings(Provider.of<LocaleProvider>(context, listen: false).isEnglish);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isBlocked ? s.unblockTitle : s.blockTitle),
        content: Text(isBlocked ? s.unblockConfirm : s.blockConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isBlocked ? s.unblockAction : s.blockAction, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final error = isBlocked
        ? await authProvider.unblockUser(targetUid)
        : await authProvider.blockUser(targetUid);

    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isBlocked ? s.unblockedMessage : s.blockedMessage)),
      );
      if (!isBlocked) Navigator.pop(context);
    }
  }

  Widget _buildPostContent(PostModel post, bool isAuthor, bool isLiked, dynamic user, BoardStrings s) {
    final DateFormat dateFormat = DateFormat('yyyy.MM.dd HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey[300],
              backgroundImage: post.authorProfileImageUrl != null
                  ? NetworkImage(post.authorProfileImageUrl!)
                  : null,
              child: post.authorProfileImageUrl == null
                  ? Text(
                      (post.authorNickname ?? post.authorName).isNotEmpty
                          ? (post.authorNickname ?? post.authorName)[0]
                          : '?',
                      style: const TextStyle(fontSize: 16),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.authorNickname ?? post.authorName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    dateFormat.format(post.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.visibility, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text('${post.viewCount}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            // ··· 메뉴: 본인 = 수정/삭제, 타인 = 신고/차단
            if (user != null)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => AddPostScreen(post: post)));
                  } else if (value == 'delete') {
                    _deletePost();
                  } else if (value == 'report') {
                    _showReportDialog(
                      reporterId: user.uid,
                      targetId: widget.postId,
                      targetType: 'post',
                      targetAuthorId: post.authorId,
                    );
                  } else if (value == 'block') {
                    _blockUser(post.authorId);
                  }
                },
                itemBuilder: (context) {
                  if (isAuthor) {
                    return [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [const Icon(Icons.edit_outlined), const SizedBox(width: 8), Text(s.editMenu)]),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          const Icon(Icons.delete_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(s.deleteMenu, style: const TextStyle(color: Colors.red)),
                        ]),
                      ),
                    ];
                  }
                  final isBlocked = Provider.of<AuthProvider>(context, listen: false)
                      .blockedUsers.contains(post.authorId);
                  return [
                    PopupMenuItem(
                      value: 'report',
                      child: Row(children: [
                        const Icon(Icons.flag_outlined, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(s.reportMenu, style: const TextStyle(color: Colors.red)),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'block',
                      child: Row(children: [
                        Icon(isBlocked ? Icons.lock_open_outlined : Icons.block_outlined,
                            color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(isBlocked ? s.unblockUser : s.blockUser,
                            style: const TextStyle(color: Colors.orange)),
                      ]),
                    ),
                  ];
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(post.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (post.imageUrls.isNotEmpty) ...[
          ...post.imageUrls.map((url) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    url,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Center(child: Icon(Icons.broken_image, size: 48)),
                    ),
                  ),
                ),
              )),
          const SizedBox(height: 16),
        ],
        if (post.category == '시간표 공유' && post.timetableClasses.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TimetablePreview(classes: post.timetableClasses),
          ),
          const SizedBox(height: 10),
          // 본인이 공유한 시간표는 가져올 필요가 없으므로 다른 학생에게만 보여준다.
          if (user != null && user.uid != post.authorId)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _importTimetable(post),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('내 시간표로 가져오기'),
              ),
            ),
          const SizedBox(height: 16),
        ],
        LinkifiedText(text: post.content, style: const TextStyle(fontSize: 15, height: 1.5)),
        const SizedBox(height: 16),
        Row(
          children: [
            IconButton(
              onPressed: user != null
                  ? () => _toggleLike(post, user.uid)
                  : () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.loginRequired))),
              icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : null),
            ),
            Text('${post.likeCount}'),
            const SizedBox(width: 16),
            Icon(Icons.comment_outlined, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text('${post.commentCount}'),
          ],
        ),
      ],
    );
  }

  Widget _buildCommentsList(dynamic user, BoardStrings s) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('board_comments')
          .where('postId', isEqualTo: widget.postId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text(s.commentsLoadError);
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(child: Text(s.noCommentsYet, style: const TextStyle(color: Colors.grey))),
          );
        }

        final blockedUsers = Provider.of<AuthProvider>(context, listen: false).blockedUsers;
        final comments = snapshot.data!.docs
            .map((doc) => CommentModel.fromMap(doc.data() as Map<String, dynamic>))
            .where((c) => !blockedUsers.contains(c.authorId))
            .toList();
        comments.sort((a, b) => a.createdAt.compareTo(b.createdAt));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.commentsCount(comments.length), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ...comments.map((comment) => _buildCommentItem(comment, user, s)),
          ],
        );
      },
    );
  }

  Widget _buildCommentItem(CommentModel comment, dynamic user, BoardStrings s) {
    final DateFormat dateFormat = DateFormat('yyyy.MM.dd HH:mm');
    final isAuthor = user != null && comment.authorId == user.uid;

    if (isAuthor) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 48),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => _deleteComment(comment.id),
                        color: Colors.red,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      Text(dateFormat.format(comment.createdAt),
                          style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          comment.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: LinkifiedText(text: comment.content, style: const TextStyle(fontSize: 14, height: 1.4)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              backgroundImage: comment.authorProfileImageUrl != null
                  ? NetworkImage(comment.authorProfileImageUrl!)
                  : null,
              child: comment.authorProfileImageUrl == null
                  ? Text(comment.authorName.isNotEmpty ? comment.authorName[0] : '?',
                      style: const TextStyle(fontSize: 12))
                  : null,
            ),
          ],
        ),
      );
    }

    // 타인 댓글: 왼쪽 정렬 + ··· 신고 버튼
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey[300],
            backgroundImage: comment.authorProfileImageUrl != null
                ? NetworkImage(comment.authorProfileImageUrl!)
                : null,
            child: comment.authorProfileImageUrl == null
                ? Text(comment.authorName.isNotEmpty ? comment.authorName[0] : '?',
                    style: const TextStyle(fontSize: 12))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        comment.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(dateFormat.format(comment.createdAt),
                        style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    const Spacer(),
                    // ··· 신고/차단 버튼
                    if (user != null)
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        icon: Icon(Icons.more_horiz, color: Colors.grey[500], size: 18),
                        onSelected: (value) {
                          if (value == 'report') {
                            _showReportDialog(
                              reporterId: user.uid,
                              targetId: comment.id,
                              targetType: 'comment',
                              targetAuthorId: comment.authorId,
                            );
                          } else if (value == 'block') {
                            _blockUser(comment.authorId);
                          }
                        },
                        itemBuilder: (context) {
                          final isBlocked = Provider.of<AuthProvider>(context, listen: false)
                              .blockedUsers.contains(comment.authorId);
                          return [
                            PopupMenuItem(
                              value: 'report',
                              child: Row(children: [
                                const Icon(Icons.flag_outlined, color: Colors.red, size: 18),
                                const SizedBox(width: 8),
                                Text(s.reportMenu, style: const TextStyle(color: Colors.red, fontSize: 14)),
                              ]),
                            ),
                            PopupMenuItem(
                              value: 'block',
                              child: Row(children: [
                                Icon(isBlocked ? Icons.lock_open_outlined : Icons.block_outlined,
                                    color: Colors.orange, size: 18),
                                const SizedBox(width: 8),
                                Text(isBlocked ? s.unblockUser : s.blockUser,
                                    style: const TextStyle(color: Colors.orange, fontSize: 14)),
                              ]),
                            ),
                          ];
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(comment.content, style: const TextStyle(fontSize: 14, height: 1.4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput(dynamic user, BoardStrings s) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                enabled: !_isLoadingComment,
                decoration: InputDecoration(
                  hintText: s.commentHint,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                minLines: 1,
                maxLines: 6,
                textInputAction: TextInputAction.newline,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _isLoadingComment
                  ? null
                  : () => _addComment(user.uid, user.name, user.nickname, user.profileImageUrl),
              icon: _isLoadingComment
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              color: Theme.of(context).primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
