import 'package:flutter/material.dart' hide Colors, FilledButton, IconButton, Card, ListTile, showDialog, Divider, Checkbox, Tooltip, ButtonStyle;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:swu_dormi_admin/services/storage_service.dart';
import 'package:swu_dormi_admin/services/auth_service.dart';
import 'package:intl/intl.dart';

class WindowsInternNoticesScreen extends StatefulWidget {
  const WindowsInternNoticesScreen({super.key});

  @override
  State<WindowsInternNoticesScreen> createState() => _WindowsInternNoticesScreenState();
}

class _WindowsInternNoticesScreenState extends State<WindowsInternNoticesScreen> {
  final _dateFormat = DateFormat('yyyy.MM.dd');
  _InternNotice? _selectedNotice;
  String _searchQuery = '';

  Stream<List<_InternNotice>> _noticesStream() {
    return FirebaseFirestore.instance
        .collection('intern_notices')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_InternNotice.fromDoc).toList());
  }

  void _openCreateDialog({_InternNotice? editing}) {
    showDialog(
      context: context,
      builder: (ctx) => _InternNoticeDialog(editing: editing),
    ).then((_) {
      if (editing != null && _selectedNotice?.id == editing.id) {
        setState(() => _selectedNotice = null);
      }
    });
  }

  Future<void> _deleteNotice(_InternNotice notice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('공지 삭제'),
        content: Text('「${notice.title}」을(를) 삭제하시겠습니까?'),
        actions: [
          Button(child: const Text('취소'), onPressed: () => Navigator.pop(ctx, false)),
          FilledButton(
            style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Colors.red)),
            child: const Text('삭제'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance.collection('intern_notices').doc(notice.id).delete();
      if (_selectedNotice?.id == notice.id) {
        setState(() => _selectedNotice = null);
      }
      if (mounted) {
        displayInfoBar(context, builder: (ctx, close) => InfoBar(
          title: const Text('삭제 완료'),
          severity: InfoBarSeverity.success,
          action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
        ));
      }
    } catch (e) {
      if (mounted) {
        displayInfoBar(context, builder: (ctx, close) => InfoBar(
          title: const Text('삭제 실패'),
          content: Text('$e'),
          severity: InfoBarSeverity.error,
          action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: const Text('인턴 공지사항'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.add),
              label: const Text('공지 작성'),
              onPressed: () => _openCreateDialog(),
            ),
          ],
        ),
      ),
      content: Row(
        children: [
          // ── 목록 패널 ──
          SizedBox(
            width: 340,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextBox(
                    placeholder: '제목 검색',
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(FluentIcons.search, size: 14),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<_InternNotice>>(
                    stream: _noticesStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: ProgressRing());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('오류: ${snapshot.error}'));
                      }
                      final all = snapshot.data ?? [];
                      final filtered = _searchQuery.isEmpty
                          ? all
                          : all.where((n) => n.title.contains(_searchQuery)).toList();

                      if (filtered.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(FluentIcons.megaphone, size: 48),
                              SizedBox(height: 12),
                              Text('등록된 공지가 없습니다.'),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final n = filtered[i];
                          final isSelected = _selectedNotice?.id == n.id;
                          return Card(
                            backgroundColor: isSelected
                                ? FluentTheme.of(context).accentColor.withOpacity(0.1)
                                : null,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              onPressed: () => setState(() => _selectedNotice = n),
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: n.isPinned
                                      ? Colors.orange.withOpacity(0.12)
                                      : Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  n.isPinned ? FluentIcons.pinned : FluentIcons.megaphone,
                                  color: n.isPinned ? Colors.orange : Colors.blue,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                n.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                '${n.authorName}  ·  ${_dateFormat.format(n.createdAt)}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[100]),
                              ),
                              trailing: n.isPinned
                                  ? Icon(FluentIcons.pinned, size: 12, color: Colors.orange)
                                  : null,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // 구분선
          const Divider(direction: Axis.vertical),
          // ── 상세 패널 ──
          Expanded(
            child: _selectedNotice == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(FluentIcons.megaphone, size: 56, color: Colors.grey[80]),
                        const SizedBox(height: 16),
                        Text('공지를 선택하세요', style: TextStyle(color: Colors.grey[100], fontSize: 15)),
                      ],
                    ),
                  )
                : _buildDetail(_selectedNotice!),
          ),
        ],
      ),
    );
  }

  Widget _buildDetail(_InternNotice n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (n.isPinned) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.orange.withOpacity(0.4)),
                  ),
                  child: Text('중요', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  n.title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              Button(
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Icon(FluentIcons.edit, size: 14), SizedBox(width: 6), Text('수정')],
                ),
                onPressed: () => _openCreateDialog(editing: n),
              ),
              const SizedBox(width: 8),
              Button(
                style: ButtonStyle(backgroundColor: WidgetStateProperty.all(Colors.red.withOpacity(0.1))),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Icon(FluentIcons.delete, size: 14, color: Colors.red), const SizedBox(width: 6), Text('삭제', style: TextStyle(color: Colors.red))],
                ),
                onPressed: () => _deleteNotice(n),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${n.authorName}  ·  ${DateFormat('yyyy-MM-dd HH:mm').format(n.createdAt)}',
            style: TextStyle(fontSize: 13, color: Colors.grey[100]),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          if (n.imageUrls.isNotEmpty) ...[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: n.imageUrls.map((url) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(url, height: 200, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(height: 200, width: 200,
                        child: Center(child: Icon(FluentIcons.error_badge)))),
              )).toList(),
            ),
            const SizedBox(height: 20),
          ],
          Text(n.content, style: const TextStyle(fontSize: 15, height: 1.7)),
        ],
      ),
    );
  }
}

// ── 공지 데이터 모델 ──────────────────────────────────────────────
class _InternNotice {
  final String id;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final DateTime createdAt;
  final bool isPinned;
  final List<String> imageUrls;

  const _InternNotice({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    required this.isPinned,
    required this.imageUrls,
  });

  factory _InternNotice.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    DateTime dt;
    final raw = d['createdAt'];
    if (raw is Timestamp) {
      dt = raw.toDate();
    } else {
      dt = DateTime.now();
    }
    return _InternNotice(
      id: doc.id,
      title: d['title'] ?? '',
      content: d['content'] ?? '',
      authorId: d['authorId'] ?? '',
      authorName: d['authorName'] ?? '',
      createdAt: dt,
      isPinned: d['isPinned'] ?? false,
      imageUrls: List<String>.from(d['imageUrls'] ?? []),
    );
  }
}

// ── 공지 작성/수정 다이얼로그 ─────────────────────────────────────
class _InternNoticeDialog extends StatefulWidget {
  final _InternNotice? editing;
  const _InternNoticeDialog({this.editing});

  @override
  State<_InternNoticeDialog> createState() => _InternNoticeDialogState();
}

class _InternNoticeDialogState extends State<_InternNoticeDialog> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  bool _isPinned = false;
  List<String> _imageUrls = [];
  List<File> _pendingImages = [];
  bool _isLoading = false;
  final _storage = StorageService();
  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    if (widget.editing != null) {
      final e = widget.editing!;
      _titleCtrl.text = e.title;
      _contentCtrl.text = e.content;
      _isPinned = e.isPinned;
      _imageUrls = List.from(e.imageUrls);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) return;
    setState(() {
      _pendingImages.addAll(result.paths.whereType<String>().map((p) => File(p)));
    });
  }

  void _removeExistingImage(int index) {
    setState(() => _imageUrls.removeAt(index));
  }

  void _removePendingImage(int index) {
    setState(() => _pendingImages.removeAt(index));
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty || content.isEmpty) {
      displayInfoBar(context, builder: (ctx, close) => InfoBar(
        title: const Text('입력 오류'),
        content: const Text('제목과 내용을 입력해주세요.'),
        severity: InfoBarSeverity.warning,
        action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
      ));
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 신규 이미지 업로드
      for (final file in _pendingImages) {
        final fileName = 'intern_${DateTime.now().millisecondsSinceEpoch}_${_pendingImages.indexOf(file)}.jpg';
        final url = await _storage.uploadNoticeImage(file, fileName);
        _imageUrls.add(url);
      }

      final user = _auth.currentUser;
      final data = {
        'title': title,
        'content': content,
        'isPinned': _isPinned,
        'imageUrls': _imageUrls,
        'authorId': user?.uid ?? '',
        'authorName': user?.email?.split('@').first ?? '관리자',
      };

      if (widget.editing != null) {
        await FirebaseFirestore.instance
            .collection('intern_notices')
            .doc(widget.editing!.id)
            .update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('intern_notices').add(data);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        displayInfoBar(context, builder: (ctx, close) => InfoBar(
          title: const Text('저장 실패'),
          content: Text('$e'),
          severity: InfoBarSeverity.error,
          action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editing != null;
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 640, maxHeight: 700),
      title: Text(isEditing ? '공지 수정' : '인턴 공지 작성'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextBox(
              controller: _titleCtrl,
              placeholder: '제목',
              maxLines: 1,
            ),
            const SizedBox(height: 12),
            TextBox(
              controller: _contentCtrl,
              placeholder: '내용을 입력하세요.',
              maxLines: 10,
              minLines: 6,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  checked: _isPinned,
                  onChanged: (v) => setState(() => _isPinned = v ?? false),
                ),
                const SizedBox(width: 8),
                const Text('중요 공지로 설정'),
              ],
            ),
            const SizedBox(height: 16),
            // 기존 이미지
            if (_imageUrls.isNotEmpty) ...[
              const Text('첨부 이미지', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_imageUrls.length, (i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(_imageUrls[i], width: 80, height: 80, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => _removeExistingImage(i),
                        child: Container(
                          decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          padding: const EdgeInsets.all(2),
                          child: const Icon(FluentIcons.clear, size: 10, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                )),
              ),
              const SizedBox(height: 8),
            ],
            // 새로 추가할 이미지
            if (_pendingImages.isNotEmpty) ...[
              const Text('추가할 이미지', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_pendingImages.length, (i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(_pendingImages[i], width: 80, height: 80, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => _removePendingImage(i),
                        child: Container(
                          decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          padding: const EdgeInsets.all(2),
                          child: const Icon(FluentIcons.clear, size: 10, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                )),
              ),
              const SizedBox(height: 8),
            ],
            Button(
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [Icon(FluentIcons.photo2_add, size: 14), SizedBox(width: 6), Text('이미지 추가')],
              ),
              onPressed: _pickImages,
            ),
          ],
        ),
      ),
      actions: [
        Button(child: const Text('취소'), onPressed: () => Navigator.pop(context)),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: ProgressRing(strokeWidth: 2))
              : Text(isEditing ? '수정 완료' : '작성'),
        ),
      ],
    );
  }
}
