import 'package:flutter/material.dart'
    hide
        Colors,
        FilledButton,
        IconButton,
        Card,
        ListTile,
        showDialog,
        Divider,
        Checkbox,
        Tooltip,
        ButtonStyle;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:swu_dormi_admin/widgets/shimmer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class WindowsBoardScreen extends StatefulWidget {
  const WindowsBoardScreen({super.key});

  @override
  State<WindowsBoardScreen> createState() => _WindowsBoardScreenState();
}

class _WindowsBoardScreenState extends State<WindowsBoardScreen> {
  final _dateFormat = DateFormat('yyyy.MM.dd HH:mm');
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _searchQuery = '';
  String? _selectedCategory; // null = 전체
  Map<String, dynamic>? _selectedPost;
  List<Map<String, dynamic>> _comments = [];
  bool _isLoadingComments = false;

  static const _categories = [
    {'value': null, 'label': '전체'},
    {'value': 'lost&found', 'label': 'Lost&Found'},
    {'value': '배달팟', 'label': '배달팟'},
    {'value': '물품 나눔', 'label': '물품 나눔(당근)'},
    {'value': '정보 알림', 'label': '정보 알림'},
    {'value': '세탁실톡', 'label': '세탁실톡'},
  ];

  Color _categoryColor(String? cat) {
    switch (cat) {
      case 'lost&found':
        return Colors.green;
      case '배달팟':
        return Colors.red;
      case '물품 나눔':
        return Colors.orange;
      case '정보 알림':
        return Colors.blue;
      case '세탁실톡':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('board_posts')
          .orderBy('createdAt', descending: true)
          .get();
      if (!mounted) return;
      setState(() {
        _posts = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadComments(String postId) async {
    setState(() {
      _isLoadingComments = true;
      _comments = [];
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('board_comments')
          .where('postId', isEqualTo: postId)
          .get();
      if (!mounted) return;
      final list = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      list.sort((a, b) {
        final aTs = a['createdAt'];
        final bTs = b['createdAt'];
        if (aTs is Timestamp && bTs is Timestamp) {
          return aTs.compareTo(bTs);
        }
        return 0;
      });
      setState(() {
        _comments = list;
        _isLoadingComments = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingComments = false;
      });
    }
  }

  Future<void> _deletePost(Map<String, dynamic> post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('게시글 삭제'),
        content: const Text('이 게시글을 삭제하시겠습니까?'),
        actions: [
          Button(child: const Text('취소'), onPressed: () => Navigator.pop(ctx, false)),
          FilledButton(child: const Text('삭제'), onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final postId = post['id'] as String;
      // 1. Delete post document
      await FirebaseFirestore.instance.collection('board_posts').doc(postId).delete();

      // 2. Delete all comments associated with this post
      final commentsSnap = await FirebaseFirestore.instance
          .collection('board_comments')
          .where('postId', isEqualTo: postId)
          .get();
      if (commentsSnap.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in commentsSnap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      if (!mounted) return;
      setState(() {
        _posts.removeWhere((p) => p['id'] == postId);
        if (_selectedPost?['id'] == postId) {
          _selectedPost = null;
          _comments = [];
        }
      });
      await displayInfoBar(
        context,
        builder: (context, close) =>
            const InfoBar(title: Text('게시글과 모든 댓글이 삭제되었습니다'), severity: InfoBarSeverity.success),
      );
    } catch (e) {
      if (!mounted) return;
      await displayInfoBar(
        context,
        builder: (context, close) =>
            InfoBar(title: Text('삭제 오류: $e'), severity: InfoBarSeverity.error),
      );
    }
  }

  Future<void> _deleteComment(Map<String, dynamic> comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('댓글 삭제'),
        content: const Text('이 댓글을 삭제하시겠습니까?'),
        actions: [
          Button(child: const Text('취소'), onPressed: () => Navigator.pop(ctx, false)),
          FilledButton(child: const Text('삭제'), onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final commentId = comment['id'] as String;
      await FirebaseFirestore.instance.collection('board_comments').doc(commentId).delete();
      if (!mounted) return;

      setState(() {
        _comments.removeWhere((c) => c['id'] == commentId);
        // update local commentCount on the post
        if (_selectedPost != null) {
          final currentCount = (_selectedPost!['commentCount'] ?? 0) as int;
          final newCount = currentCount > 0 ? currentCount - 1 : 0;
          _selectedPost!['commentCount'] = newCount;

          final idx = _posts.indexWhere((p) => p['id'] == _selectedPost!['id']);
          if (idx != -1) {
            _posts[idx]['commentCount'] = newCount;
          }
        }
      });

      // update commentCount on post in Firestore
      if (_selectedPost != null) {
        await FirebaseFirestore.instance
            .collection('board_posts')
            .doc(_selectedPost!['id'] as String)
            .update({'commentCount': FieldValue.increment(-1)});
      }
    } catch (e) {
      if (!mounted) return;
    }
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '-';
    if (ts is Timestamp) return _dateFormat.format(ts.toDate());
    return '-';
  }

  List<Map<String, dynamic>> get _filteredPosts {
    var list = _posts;
    if (_selectedCategory != null) {
      list = list.where((p) => p['category'] == _selectedCategory).toList();
    }
    if (_searchQuery.isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((p) {
      final title = (p['title'] ?? '').toString().toLowerCase();
      final author = (p['authorName'] ?? '').toString().toLowerCase();
      final nickname = (p['authorNickname'] ?? '').toString().toLowerCase();
      return title.contains(q) || author.contains(q) || nickname.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final posts = _filteredPosts;

    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Row(
        children: [
          // 왼쪽: 게시글 목록
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: FluentTheme.of(context).micaBackgroundColor,
                border: Border(
                  right: BorderSide(
                    color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // 헤더
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FluentTheme.of(context).cardColor,
                      border: Border(
                        bottom: BorderSide(
                          color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text(
                              '게시판',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // 카테고리 필터
                        SizedBox(
                          height: 32,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: _categories.map((cat) {
                              final value = cat['value'];
                              final label = cat['label'] as String;
                              final isSelected = _selectedCategory == value;
                              final color = _categoryColor(value);
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _selectedCategory = value;
                                    _selectedPost = null;
                                    _comments = [];
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? color.withValues(alpha: 0.15)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected
                                            ? color
                                            : Colors.grey.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isSelected ? color : Colors.grey[120],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextBox(
                          placeholder: '제목, 작성자로 검색',
                          prefix: const Padding(
                            padding: EdgeInsets.only(left: 12),
                            child: Icon(FluentIcons.search, size: 16),
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                        ),
                      ],
                    ),
                  ),
                  // 목록
                  Expanded(
                    child: _isLoading
                        ? ShimmerList(itemBuilder: () => const BoardCardShimmer(), count: 7)
                        : _errorMessage.isNotEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(FluentIcons.error, size: 48, color: Colors.red),
                                const SizedBox(height: 12),
                                const Text('데이터 로드 실패'),
                                const SizedBox(height: 8),
                                FilledButton(onPressed: _loadPosts, child: const Text('다시 시도')),
                              ],
                            ),
                          )
                        : posts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(FluentIcons.search, size: 48, color: Colors.grey[60]),
                                const SizedBox(height: 16),
                                Text(_searchQuery.isEmpty ? '게시글이 없습니다' : '검색 결과가 없습니다'),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: posts.length,
                            itemBuilder: (context, index) {
                              final post = posts[index];
                              final isSelected = _selectedPost?['id'] == post['id'];
                              final authorNickname = post['authorNickname']?.toString();
                              final authorName = post['authorName']?.toString() ?? '알 수 없음';
                              final displayName = authorNickname?.isNotEmpty == true
                                  ? authorNickname!
                                  : authorName;
                              final category = post['category']?.toString();
                              final title = post['title']?.toString() ?? '(제목 없음)';

                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  setState(() => _selectedPost = post);
                                  _loadComments(post['id'] as String);
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? FluentTheme.of(context).accentColor.withOpacity(0.1)
                                        : FluentTheme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isSelected
                                          ? FluentTheme.of(context).accentColor.withOpacity(0.5)
                                          : FluentTheme.of(
                                              context,
                                            ).resources.dividerStrokeColorDefault,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (category != null) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _categoryColor(
                                                category,
                                              ).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: _categoryColor(
                                                  category,
                                                ).withValues(alpha: 0.4),
                                              ),
                                            ),
                                            child: Text(
                                              category,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: _categoryColor(category),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                        ],
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(
                                              FluentIcons.contact,
                                              size: 12,
                                              color: Colors.grey[100],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              displayName,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[100],
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              _formatTimestamp(post['createdAt']),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[100],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              FluentIcons.view,
                                              size: 12,
                                              color: Colors.grey[100],
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              '${post['viewCount'] ?? 0}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[100],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Icon(
                                              FluentIcons.heart,
                                              size: 12,
                                              color: Colors.grey[100],
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              '${post['likeCount'] ?? 0}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[100],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Icon(
                                              FluentIcons.comment,
                                              size: 12,
                                              color: Colors.grey[100],
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              '${post['commentCount'] ?? 0}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[100],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          // 오른쪽: 게시글 상세
          Expanded(
            flex: 3,
            child: _selectedPost == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(FluentIcons.search, size: 64, color: Colors.grey[60]),
                        const SizedBox(height: 16),
                        const Text('게시글을 선택해주세요', style: TextStyle(fontSize: 18)),
                      ],
                    ),
                  )
                : _buildPostDetail(_selectedPost!),
          ),
        ],
      ),
    );
  }

  Widget _buildPostDetail(Map<String, dynamic> post) {
    final authorNickname = post['authorNickname']?.toString();
    final authorName = post['authorName']?.toString() ?? '알 수 없음';
    final displayName = authorNickname?.isNotEmpty == true ? authorNickname! : authorName;
    final imageUrls =
        (post['imageUrls'] as List<dynamic>?)
            ?.where((e) => e != null)
            .map((e) => e.toString())
            .toList() ??
        [];
    final category = post['category']?.toString();
    final title = post['title']?.toString() ?? '(제목 없음)';
    final content = post['content']?.toString() ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 카테고리 배지
          if (category != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _categoryColor(category).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _categoryColor(category).withValues(alpha: 0.4)),
              ),
              child: Text(
                category,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _categoryColor(category),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          // 제목 + 삭제 버튼
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              Button(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.delete, size: 14, color: Colors.red),
                    const SizedBox(width: 6),
                    Text('삭제', style: TextStyle(color: Colors.red)),
                  ],
                ),
                onPressed: () => _deletePost(post),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 작성자 / 날짜 / 통계
          Row(
            children: [
              Icon(FluentIcons.contact, size: 14, color: Colors.grey[100]),
              const SizedBox(width: 6),
              Text(displayName, style: TextStyle(fontSize: 13, color: Colors.grey[100])),
              const SizedBox(width: 16),
              Icon(FluentIcons.event_date_missed12, size: 14, color: Colors.grey[100]),
              const SizedBox(width: 6),
              Text(
                _formatTimestamp(post['createdAt']),
                style: TextStyle(fontSize: 13, color: Colors.grey[100]),
              ),
              const Spacer(),
              Icon(FluentIcons.view, size: 13, color: Colors.grey[100]),
              const SizedBox(width: 4),
              Text(
                '${post['viewCount'] ?? 0}',
                style: TextStyle(fontSize: 12, color: Colors.grey[100]),
              ),
              const SizedBox(width: 12),
              Icon(FluentIcons.heart, size: 13, color: Colors.grey[100]),
              const SizedBox(width: 4),
              Text(
                '${post['likeCount'] ?? 0}',
                style: TextStyle(fontSize: 12, color: Colors.grey[100]),
              ),
              const SizedBox(width: 12),
              Icon(FluentIcons.comment, size: 13, color: Colors.grey[100]),
              const SizedBox(width: 4),
              Text(
                '${post['commentCount'] ?? 0}',
                style: TextStyle(fontSize: 12, color: Colors.grey[100]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          // 본문
          Text(content, style: const TextStyle(fontSize: 14, height: 1.6)),
          // 이미지
          if (imageUrls.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: imageUrls.map((url) {
                return Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Icon(FluentIcons.picture_fill, size: 32, color: Colors.grey[100]),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 32),
          // 댓글 섹션
          Row(
            children: [
              const Text('댓글', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: FluentTheme.of(context).accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_comments.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: FluentTheme.of(context).accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingComments)
            Column(
              children: List.generate(
                3,
                (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ShimmerBox(width: double.infinity, height: 52),
                ),
              ),
            )
          else if (_comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('댓글이 없습니다', style: TextStyle(color: Colors.grey[100])),
            )
          else
            Column(
              children: _comments.map((comment) {
                final commentNickname = comment['authorNickname']?.toString();
                final commentName = comment['authorName']?.toString() ?? '알 수 없음';
                final commentAuthor = commentNickname?.isNotEmpty == true
                    ? commentNickname!
                    : commentName;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: FluentTheme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  commentAuthor,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _formatTimestamp(comment['createdAt']),
                                  style: TextStyle(fontSize: 11, color: Colors.grey[100]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              comment['content'] ?? '',
                              style: const TextStyle(fontSize: 13, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(FluentIcons.delete, size: 14, color: Colors.grey[100]),
                        onPressed: () => _deleteComment(comment),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
