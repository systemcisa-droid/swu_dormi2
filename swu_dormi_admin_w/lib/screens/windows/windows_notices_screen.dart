import 'package:flutter/material.dart' hide Colors, FilledButton, IconButton, Card, ListTile, showDialog, Divider, Checkbox, Tooltip, ButtonStyle;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:swu_dormi_admin/widgets/shimmer.dart';
import 'package:swu_dormi_admin/services/firestore_service.dart';
import 'package:swu_dormi_admin/services/storage_service.dart';
import 'package:swu_dormi_admin/models/notice_model.dart';
import 'package:swu_dormi_admin/screens/windows/windows_notice_create_screen.dart';
import 'package:swu_dormi_admin/screens/windows/windows_monthly_plan_screen.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// 공지사항과 월간 계획을 "공지사항 / 월간 계획" 2탭으로 보여주는 화면.
/// 단위실 청소점검(WindowsInspectionTabScreen)과 동일한 구조로 사이드바 메뉴를 통합할 때 사용한다.
class WindowsNoticesTabScreen extends StatefulWidget {
  const WindowsNoticesTabScreen({super.key});

  @override
  State<WindowsNoticesTabScreen> createState() =>
      _WindowsNoticesTabScreenState();
}

class _WindowsNoticesTabScreenState extends State<WindowsNoticesTabScreen> {
  // 0: 공지사항, 1: 월간 계획
  int _tabIndex = 0;

  final _accentColor = Colors.blue;

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Column(
        children: [
          // 탭 헤더
          Container(
            color: FluentTheme.of(context).cardColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _buildTab(0, '공지사항', FluentIcons.megaphone),
                const SizedBox(width: 8),
                _buildTab(1, '월간 계획', FluentIcons.calendar),
              ],
            ),
          ),
          // 탭 콘텐츠
          Expanded(
            child: _tabIndex == 1
                ? const MonthlyPlanCalendar()
                : const WindowsNoticesScreen(),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label, IconData icon) {
    final isSelected = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? _accentColor.withValues(alpha: 0.12)
              : Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? _accentColor : Colors.grey.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? _accentColor : Colors.grey),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? _accentColor : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WindowsNoticesScreen extends StatefulWidget {
  const WindowsNoticesScreen({super.key});

  @override
  State<WindowsNoticesScreen> createState() => _WindowsNoticesScreenState();
}

class _WindowsNoticesScreenState extends State<WindowsNoticesScreen> {
  final _firestoreService = FirestoreService();
  final _dateFormat = DateFormat('yyyy.MM.dd');
  NoticeModel? _selectedNotice;
  String _searchQuery = '';
  String _filterType = '전체';

  // ──────────── 팝업 공지 설정 ────────────
  void _showPopupNoticeDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => const _PopupNoticeDialog(),
    );
  }

  Widget _buildNoticeListItem(NoticeModel notice, bool isSelected) {
    return Card(
      backgroundColor: isSelected
          ? FluentTheme.of(context).accentColor.withOpacity(0.1)
          : null,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onPressed: () {
          setState(() {
            _selectedNotice = notice;
          });
        },
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: notice.isPinned
                ? Colors.orange.withOpacity(0.1)
                : Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            notice.isPinned ? FluentIcons.pinned : FluentIcons.megaphone,
            color: notice.isPinned ? Colors.orange : Colors.blue,
            size: 20,
          ),
        ),
        title: Text(
          notice.title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text(
              notice.authorName,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[100],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '•',
              style: TextStyle(color: Colors.grey[60]),
            ),
            const SizedBox(width: 8),
            Text(
              _dateFormat.format(notice.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[100],
              ),
            ),
            if (notice.imageUrls.isNotEmpty) ...[
              const SizedBox(width: 8),
              Icon(
                FluentIcons.photo2,
                size: 12,
                color: Colors.grey[100],
              ),
            ],
            if (notice.pdfUrl != null) ...[
              const SizedBox(width: 8),
              Icon(
                FluentIcons.document,
                size: 12,
                color: Colors.grey[100],
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '조회 ${notice.viewCount}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[80],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              FluentIcons.chevron_right,
              size: 12,
              color: Colors.grey[80],
            ),
          ],
        ),
      ),
    );
  }

  void _showImageFullscreen(String url) {
    showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 800),
        content: Stack(
          children: [
            Center(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: ProgressRing());
                },
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(FluentIcons.cancel, size: 16),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailView() {
    if (_selectedNotice == null) {
      return Container(
        decoration: BoxDecoration(
          color: FluentTheme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FluentIcons.text_document,
                size: 64,
                color: Colors.grey[60],
              ),
              const SizedBox(height: 16),
              Text(
                '공지사항을 선택해주세요',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[100],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          // 상세보기 헤더
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[30],
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (_selectedNotice!.isPinned)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              FluentIcons.pinned,
                              size: 12,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '고정',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_selectedNotice!.isPinned) const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedNotice!.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(FluentIcons.edit, size: 16),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          FluentPageRoute(
                            builder: (context) => WindowsNoticeCreateScreen(
                              notice: _selectedNotice,
                            ),
                          ),
                        );
                        // 수정 후 선택 상태 초기화 (StreamBuilder가 자동으로 최신 데이터 반영)
                        if (mounted) {
                          setState(() {
                            _selectedNotice = null;
                          });
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(FluentIcons.delete, size: 16),
                      onPressed: () async {
                        final result = await showDialog<bool>(
                          context: context,
                          builder: (context) => ContentDialog(
                            title: const Text('공지사항 삭제'),
                            content: const Text('정말 이 공지사항을 삭제하시겠습니까?'),
                            actions: [
                              Button(
                                child: const Text('취소'),
                                onPressed: () => Navigator.pop(context, false),
                              ),
                              FilledButton(
                                child: const Text('삭제'),
                                onPressed: () => Navigator.pop(context, true),
                              ),
                            ],
                          ),
                        );

                        if (result == true) {
                          await _firestoreService.deleteNotice(_selectedNotice!.id);
                          setState(() {
                            _selectedNotice = null;
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      FluentIcons.contact,
                      size: 14,
                      color: Colors.grey[100],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _selectedNotice!.authorName,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[100],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      FluentIcons.calendar,
                      size: 14,
                      color: Colors.grey[100],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('yyyy년 MM월 dd일 HH:mm').format(_selectedNotice!.createdAt),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[100],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      FluentIcons.view,
                      size: 14,
                      color: Colors.grey[100],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '조회 ${_selectedNotice!.viewCount}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[100],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 내용
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    _selectedNotice!.content,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  if (_selectedNotice!.imageUrls.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      '첨부 이미지',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: _selectedNotice!.imageUrls.map((url) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GestureDetector(
                            onTap: () => _showImageFullscreen(url),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                url,
                                width: double.infinity,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    height: 200,
                                    alignment: Alignment.center,
                                    child: const ProgressRing(),
                                  );
                                },
                                errorBuilder: (_, __, ___) => Container(
                                  height: 120,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[20],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(FluentIcons.photo2, size: 40, color: Colors.grey[80]),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  if (_selectedNotice!.pdfUrl != null) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Icon(FluentIcons.document, size: 16, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(
                          _selectedNotice!.pdfFileName ?? 'PDF 파일',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 600,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[30]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SfPdfViewer.network(
                          _selectedNotice!.pdfUrl!,
                          key: ValueKey(_selectedNotice!.pdfUrl),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: const Text('공지사항 관리'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarBuilderItem(
              wrappedItem: CommandBarButton(
                icon: const Icon(FluentIcons.search),
                label: const Text('검색'),
                onPressed: () {},
              ),
              builder: (context, mode, child) => SizedBox(
                width: 200,
                child: TextBox(
                  placeholder: '검색...',
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Icon(FluentIcons.search, size: 14),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
            ),
            CommandBarBuilderItem(
              wrappedItem: CommandBarButton(
                icon: const Icon(FluentIcons.filter),
                label: const Text('필터'),
                onPressed: () {},
              ),
              builder: (context, mode, child) => ComboBox<String>(
                value: _filterType,
                items: const [
                  ComboBoxItem(value: '전체', child: Text('전체')),
                  ComboBoxItem(value: '고정', child: Text('고정')),
                  ComboBoxItem(value: '일반', child: Text('일반')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _filterType = value;
                    });
                  }
                },
              ),
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.pop_expand),
              label: const Text('팝업 공지 설정'),
              onPressed: _showPopupNoticeDialog,
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.add),
              label: const Text('새 공지사항'),
              onPressed: () {
                Navigator.push(
                  context,
                  FluentPageRoute(
                    builder: (context) => const WindowsNoticeCreateScreen(),
                  ),
                );
              },
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.refresh),
              label: const Text('새로고침'),
              onPressed: () {
                setState(() {});
              },
            ),
          ],
        ),
      ),
      content: Row(
        children: [
          // 왼쪽: 공지사항 목록
          SizedBox(
            width: 400,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestoreService.getNotices(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ShimmerList(itemBuilder: () => const NoticeCardShimmer(), count: 7);
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            FluentIcons.error_badge,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          const Text('공지사항을 불러올 수 없습니다'),
                          const SizedBox(height: 8),
                          FilledButton(
                            child: const Text('다시 시도'),
                            onPressed: () => setState(() {}),
                          ),
                        ],
                      ),
                    );
                  }

                  var notices = (snapshot.data?.docs ?? [])
                      .map((doc) => NoticeModel.fromFirestore(doc))
                      .toList();

                  // 필터링
                  if (_filterType == '고정') {
                    notices = notices.where((n) => n.isPinned).toList();
                  } else if (_filterType == '일반') {
                    notices = notices.where((n) => !n.isPinned).toList();
                  }

                  // 검색
                  if (_searchQuery.isNotEmpty) {
                    notices = notices.where((n) =>
                        n.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                        n.content.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
                  }

                  if (notices.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            FluentIcons.document_search,
                            size: 48,
                            color: Colors.grey[60],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '공지사항이 없습니다',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[100],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: notices.length,
                    itemBuilder: (context, index) {
                      final notice = notices[index];
                      return _buildNoticeListItem(
                        notice,
                        _selectedNotice?.id == notice.id,
                      );
                    },
                  );
                },
              ),
            ),
          ),
          // 구분선
          Container(
            width: 1,
            color: Colors.grey[30],
          ),
          // 오른쪽: 상세보기
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: _buildDetailView(),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────── 팝업 공지 설정 다이얼로그 ────────────
class _PopupNoticeDialog extends StatefulWidget {
  const _PopupNoticeDialog();

  @override
  State<_PopupNoticeDialog> createState() => _PopupNoticeDialogState();
}

class _PopupNoticeDialogState extends State<_PopupNoticeDialog> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _storageService = StorageService();

  bool _isEnabled = false;
  String? _existingImageUrl;
  File? _selectedImage;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSetting();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentSetting() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('popup_notice')
          .get();
      if (doc.exists) {
        final data = doc.data();
        _isEnabled = data?['isEnabled'] as bool? ?? false;
        _titleController.text = (data?['title'] as String?) ?? '';
        _contentController.text = (data?['content'] as String?) ?? '';
        _existingImageUrl = data?['imageUrl'] as String?;
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    setState(() => _selectedImage = File(path));
  }

  Future<void> _save() async {
    if (_isEnabled && _titleController.text.trim().isEmpty) {
      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('입력 오류'),
          content: const Text('팝업을 켜려면 제목을 입력해주세요'),
          severity: InfoBarSeverity.warning,
          action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      String? imageUrl = _existingImageUrl;
      if (_selectedImage != null) {
        final fileName = 'popup_notice_${DateTime.now().millisecondsSinceEpoch}.jpg';
        imageUrl = await _storageService.uploadNoticeImage(_selectedImage!, fileName);
      }

      await FirebaseFirestore.instance.collection('settings').doc('popup_notice').set({
        'isEnabled': _isEnabled,
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        if (imageUrl != null) 'imageUrl': imageUrl,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context);
      await displayInfoBar(
        context,
        builder: (context, close) => const InfoBar(
          title: Text('저장되었습니다'),
          severity: InfoBarSeverity.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('저장 실패'),
          content: Text('$e'),
          severity: InfoBarSeverity.error,
          action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 520, maxHeight: 700),
      title: const Text('팝업 공지 설정'),
      content: _isLoading
          ? const SizedBox(height: 200, child: Center(child: ProgressRing()))
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '학생 앱 홈 화면 진입 시 표시되는 팝업 공지입니다.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ToggleSwitch(
                    checked: _isEnabled,
                    onChanged: (v) => setState(() => _isEnabled = v),
                    content: const Text('팝업 공지 표시'),
                  ),
                  const SizedBox(height: 16),
                  const Text('제목 *', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextBox(controller: _titleController, placeholder: '팝업 제목'),
                  const SizedBox(height: 16),
                  const Text('내용', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextBox(
                    controller: _contentController,
                    placeholder: '팝업 내용',
                    minLines: 4,
                    maxLines: 8,
                  ),
                  const SizedBox(height: 16),
                  const Text('이미지 (선택)', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (_selectedImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_selectedImage!, height: 160, fit: BoxFit.cover),
                    )
                  else if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _existingImageUrl!,
                        height: 160,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Button(
                    onPressed: _pickImage,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.photo2, size: 14),
                        SizedBox(width: 6),
                        Text('이미지 선택'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        Button(
          child: const Text('취소'),
          onPressed: _isSaving ? null : () => Navigator.pop(context),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: ProgressRing(strokeWidth: 2))
              : const Text('저장'),
        ),
      ],
    );
  }
}