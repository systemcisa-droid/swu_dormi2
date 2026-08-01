import 'package:flutter/material.dart' hide Colors, FilledButton, IconButton, Card, ListTile, showDialog, Divider, Checkbox, Tooltip, ButtonStyle;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:swu_dormi_admin/services/firestore_service.dart';
import 'package:swu_dormi_admin/services/storage_service.dart';
import 'package:swu_dormi_admin/services/auth_service.dart';
import 'package:swu_dormi_admin/services/notification_service.dart';
import 'package:swu_dormi_admin/models/notice_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WindowsNoticeCreateScreen extends StatefulWidget {
  final NoticeModel? notice; // null이면 새 공지사항, 값이 있으면 수정 모드

  const WindowsNoticeCreateScreen({super.key, this.notice});

  @override
  State<WindowsNoticeCreateScreen> createState() => _WindowsNoticeCreateScreenState();
}

class _WindowsNoticeCreateScreenState extends State<WindowsNoticeCreateScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final List<File> _selectedImages = []; // 새로 추가할 이미지 파일
  List<String> _existingImageUrls = []; // 기존 이미지 URL (수정 모드)
  File? _selectedPdf; // 새로 선택한 PDF 파일
  String? _selectedPdfName;
  String? _existingPdfUrl; // 기존 PDF URL (수정 모드)
  String? _existingPdfFileName; // 기존 PDF 파일명 (수정 모드)
  bool _isPinned = false;
  bool _skipNotification = false;
  bool _isLoading = false;

  bool get _isEditMode => widget.notice != null;

  @override
  void initState() {
    super.initState();
    final notice = widget.notice;
    if (notice != null) {
      _titleController.text = notice.title;
      _contentController.text = notice.content;
      _isPinned = notice.isPinned;
      _existingImageUrls = List<String>.from(notice.imageUrls);
      _existingPdfUrl = notice.pdfUrl;
      _existingPdfFileName = notice.pdfFileName;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null) {
        setState(() {
          for (var file in result.files) {
            if (file.path != null) {
              _selectedImages.add(File(file.path!));
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('오류'),
            content: Text('이미지 선택 중 오류가 발생했습니다: $e'),
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
            severity: InfoBarSeverity.error,
          ),
        );
      }
    }
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedPdf = File(result.files.single.path!);
          _selectedPdfName = result.files.single.name;
        });
      }
    } catch (e) {
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('오류'),
            content: Text('PDF 파일 선택 중 오류가 발생했습니다: $e'),
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
            severity: InfoBarSeverity.error,
          ),
        );
      }
    }
  }

  Future<void> _saveNotice() async {
    if (_titleController.text.trim().isEmpty || _contentController.text.trim().isEmpty) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('입력 오류'),
          content: const Text('제목과 내용을 모두 입력해주세요'),
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
          severity: InfoBarSeverity.warning,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final storageService = StorageService();
      final noticeId = _isEditMode
          ? widget.notice!.id
          : DateTime.now().millisecondsSinceEpoch.toString();

      // 새 이미지 업로드
      final List<String> imageUrls = List<String>.from(_existingImageUrls);
      for (int i = 0; i < _selectedImages.length; i++) {
        final fileName = '${noticeId}_new_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final imageUrl = await storageService.uploadNoticeImage(
          _selectedImages[i],
          fileName,
        );
        imageUrls.add(imageUrl);
      }

      // PDF 처리
      String? pdfUrl = _existingPdfUrl;
      String? pdfFileName = _existingPdfFileName;
      if (_selectedPdf != null && _selectedPdfName != null) {
        pdfUrl = await storageService.uploadNoticePdf(
          _selectedPdf!,
          '${noticeId}_$_selectedPdfName',
        );
        pdfFileName = _selectedPdfName;
      }

      final noticeData = {
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'imageUrls': imageUrls,
        'pdfUrl': pdfUrl,
        'pdfFileName': pdfFileName,
        'isPinned': _isPinned,
      };

      if (_isEditMode) {
        // 수정 모드
        await FirestoreService().updateNotice(noticeId, noticeData);
      } else {
        // 새 공지사항 생성
        final authService = AuthService();
        final currentUser = authService.currentUser;
        if (currentUser == null) throw Exception('로그인이 필요합니다');

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        final userName = userDoc.data()?['name'] ?? '관리자';

        await FirestoreService().addNotice({
          ...noticeData,
          'authorId': currentUser.uid,
          'authorName': userName,
        });

        // 알림 전송
        if (!_skipNotification) {
          await NotificationService().sendNoticeNotification(
            noticeId: noticeId,
            title: _titleController.text.trim(),
            content: _contentController.text.trim(),
          );
        }
      }

      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('성공'),
            content: Text(_isEditMode
                ? '공지사항이 수정되었습니다'
                : (_skipNotification
                    ? '공지사항이 등록되었습니다 (알림 미전송)'
                    : '공지사항이 등록되고 알림이 전송되었습니다')),
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
            severity: InfoBarSeverity.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('오류'),
            content: Text('오류가 발생했습니다: $e'),
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
            severity: InfoBarSeverity.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: Text(_isEditMode ? '공지사항 수정' : '공지사항 작성'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.save),
              label: Text(_isEditMode ? '저장' : '등록'),
              onPressed: _isLoading ? null : _saveNotice,
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.cancel),
              label: const Text('취소'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
      content: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목
                    InfoLabel(
                      label: '제목 *',
                      child: TextBox(
                        controller: _titleController,
                        placeholder: '공지사항 제목을 입력하세요',
                        maxLines: 1,
                        enabled: !_isLoading,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 내용
                    InfoLabel(
                      label: '내용 *',
                      child: TextBox(
                        controller: _contentController,
                        placeholder: '공지사항 내용을 입력하세요',
                        maxLines: 15,
                        enabled: !_isLoading,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 고정 공지사항
                    Row(
                      children: [
                        Checkbox(
                          checked: _isPinned,
                          onChanged: _isLoading ? null : (value) {
                            setState(() {
                              _isPinned = value ?? false;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        const Text('고정 공지사항으로 설정'),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: '고정 공지사항은 목록 상단에 고정되어 표시됩니다',
                          child: Icon(
                            FluentIcons.info,
                            size: 14,
                            color: Colors.grey[100],
                          ),
                        ),
                      ],
                    ),
                    if (!_isEditMode) ...[
                      const SizedBox(height: 12),
                      // 알림 없이 올리기 (새 공지사항 작성 시에만 표시)
                      Row(
                        children: [
                          Checkbox(
                            checked: _skipNotification,
                            onChanged: _isLoading ? null : (value) {
                              setState(() {
                                _skipNotification = value ?? false;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          const Text('알림 없이 올리기'),
                          const SizedBox(width: 8),
                          Tooltip(
                            message: '체크하면 학생들에게 푸시 알림이 전송되지 않습니다',
                            child: Icon(
                              FluentIcons.info,
                              size: 14,
                              color: Colors.grey[100],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 첨부 파일
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '첨부 파일',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 이미지 추가
                    Row(
                      children: [
                        FilledButton(
                          onPressed: _isLoading ? null : _pickImage,
                          child: Row(
                            children: const [
                              Icon(FluentIcons.photo2, size: 16),
                              SizedBox(width: 8),
                              Text('이미지 추가'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Button(
                          onPressed: _isLoading ? null : _pickPdf,
                          child: Row(
                            children: const [
                              Icon(FluentIcons.document, size: 16),
                              SizedBox(width: 8),
                              Text('PDF 추가'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 기존 이미지 (수정 모드)
                    if (_existingImageUrls.isNotEmpty) ...[
                      const Text(
                        '기존 이미지',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _existingImageUrls.asMap().entries.map((entry) {
                          final index = entry.key;
                          final url = entry.value;
                          return Stack(
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey[60],
                                    width: 1,
                                  ),
                                  image: DecorationImage(
                                    image: NetworkImage(url),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: IconButton(
                                  icon: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      FluentIcons.clear,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _existingImageUrls.removeAt(index);
                                    });
                                  },
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 새로 선택된 이미지
                    if (_selectedImages.isNotEmpty) ...[
                      const Text(
                        '이미지',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _selectedImages.asMap().entries.map((entry) {
                          final index = entry.key;
                          final file = entry.value;
                          return Stack(
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey[60],
                                    width: 1,
                                  ),
                                  image: DecorationImage(
                                    image: FileImage(file),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: IconButton(
                                  icon: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      FluentIcons.clear,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _selectedImages.removeAt(index);
                                    });
                                  },
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 기존 PDF (수정 모드, 새 PDF를 선택하지 않은 경우)
                    if (_existingPdfUrl != null && _selectedPdf == null) ...[
                      const Text(
                        '기존 PDF 파일',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        backgroundColor: Colors.grey[20],
                        child: ListTile(
                          leading: Icon(
                            FluentIcons.document,
                            color: Colors.red,
                            size: 32,
                          ),
                          title: Text(_existingPdfFileName ?? 'PDF 파일'),
                          subtitle: const Text('클릭하여 제거'),
                          onPressed: () {
                            setState(() {
                              _existingPdfUrl = null;
                              _existingPdfFileName = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 새로 선택된 PDF 파일
                    if (_selectedPdf != null) ...[
                      const Text(
                        'PDF 파일',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        backgroundColor: Colors.grey[20],
                        child: ListTile(
                          leading: Icon(
                            FluentIcons.document,
                            color: Colors.red,
                            size: 32,
                          ),
                          title: Text(_selectedPdfName ?? 'PDF 파일'),
                          subtitle: const Text('클릭하여 제거'),
                          onPressed: () {
                            setState(() {
                              _selectedPdf = null;
                              _selectedPdfName = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // 로딩 표시
            if (_isLoading)
              Container(
                margin: const EdgeInsets.only(top: 24),
                child: const Center(
                  child: ProgressRing(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}