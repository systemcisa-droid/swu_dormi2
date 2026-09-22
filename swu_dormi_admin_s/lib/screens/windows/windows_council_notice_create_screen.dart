import 'package:flutter/material.dart' hide Colors, FilledButton, IconButton, Card, ListTile, showDialog, Divider, Checkbox, Tooltip, ButtonStyle;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:swu_dormi_admin/services/storage_service.dart';
import 'package:swu_dormi_admin/services/auth_service.dart';

/// 사생회 공지 작성/수정 화면.
/// 기숙사 공지사항 작성 화면([WindowsNoticeCreateScreen])과 동일한 UI·기능을 쓰되,
/// 사생회 공지는 학생 대상 푸시 알림을 보내지 않는다 (캠페인/선거와 동일한 정책).
/// (이미지 여러 장 / PDF 첨부 / 고정 공지)
class WindowsCouncilNoticeCreateScreen extends StatefulWidget {
  /// null 이면 새 공지, 값이 있으면 수정 모드
  final String? noticeId;
  final Map<String, dynamic>? notice;

  const WindowsCouncilNoticeCreateScreen({super.key, this.noticeId, this.notice});

  @override
  State<WindowsCouncilNoticeCreateScreen> createState() =>
      _WindowsCouncilNoticeCreateScreenState();
}

class _WindowsCouncilNoticeCreateScreenState
    extends State<WindowsCouncilNoticeCreateScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final List<File> _selectedImages = []; // 새로 추가할 이미지 파일
  List<String> _existingImageUrls = []; // 기존 이미지 URL (수정 모드)
  File? _selectedPdf; // 새로 선택한 PDF 파일
  String? _selectedPdfName;
  String? _existingPdfUrl; // 기존 PDF URL (수정 모드)
  String? _existingPdfFileName; // 기존 PDF 파일명 (수정 모드)
  bool _isPinned = false;
  bool _isLoading = false;

  bool get _isEditMode => widget.noticeId != null;

  @override
  void initState() {
    super.initState();
    final n = widget.notice;
    if (n != null) {
      _titleController.text = (n['title'] ?? '').toString();
      _contentController.text = (n['content'] ?? '').toString();
      _isPinned = n['isPinned'] == true;
      _existingImageUrls = (n['imageUrls'] as List?)
              ?.map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList() ??
          [];
      final pdfUrl = (n['pdfUrl'] ?? '').toString();
      if (pdfUrl.isNotEmpty) {
        _existingPdfUrl = pdfUrl;
        _existingPdfFileName = (n['pdfFileName'] ?? '').toString();
      }
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
      _showError('이미지 선택 중 오류가 발생했습니다: $e');
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
      _showError('PDF 선택 중 오류가 발생했습니다: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    displayInfoBar(
      context,
      builder: (context, close) => InfoBar(
        title: const Text('오류'),
        content: Text(message),
        action: IconButton(
            icon: const Icon(FluentIcons.clear), onPressed: close),
        severity: InfoBarSeverity.error,
      ),
    );
  }

  Future<void> _saveNotice() async {
    // 처리 중 재진입(중복 등록) 방지
    if (_isLoading) return;
    if (_titleController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('입력 오류'),
          content: const Text('제목과 내용을 모두 입력해주세요'),
          action: IconButton(
              icon: const Icon(FluentIcons.clear), onPressed: close),
          severity: InfoBarSeverity.warning,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final storageService = StorageService();
      final col = FirebaseFirestore.instance.collection('council_notices');
      final docId = _isEditMode
          ? widget.noticeId!
          : DateTime.now().millisecondsSinceEpoch.toString();

      // 새 이미지 업로드
      final List<String> imageUrls = List<String>.from(_existingImageUrls);
      for (int i = 0; i < _selectedImages.length; i++) {
        final fileName =
            '${docId}_new_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final imageUrl =
            await storageService.uploadNoticeImage(_selectedImages[i], fileName);
        imageUrls.add(imageUrl);
      }

      // PDF 처리
      String? pdfUrl = _existingPdfUrl;
      String? pdfFileName = _existingPdfFileName;
      if (_selectedPdf != null && _selectedPdfName != null) {
        pdfUrl = await storageService.uploadNoticePdf(
          _selectedPdf!,
          '${docId}_$_selectedPdfName',
        );
        pdfFileName = _selectedPdfName;
      }

      final noticeData = <String, dynamic>{
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'imageUrls': imageUrls,
        'pdfUrl': pdfUrl,
        'pdfFileName': pdfFileName,
        'isPinned': _isPinned,
      };

      if (_isEditMode) {
        await col.doc(docId).update(noticeData);
      } else {
        final currentUser = AuthService().currentUser;
        if (currentUser == null) throw Exception('로그인이 필요합니다');

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        final userName = userDoc.data()?['name'] ?? '관리자';

        await col.doc(docId).set({
          ...noticeData,
          'authorId': currentUser.uid,
          'authorName': userName,
          'createdAt': FieldValue.serverTimestamp(),
        });
        // 사생회 공지는 캠페인/선거와 마찬가지로 학생 대상 알림을 보내지 않는다.
      }

      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('성공'),
            content: Text(_isEditMode ? '사생회 공지가 수정되었습니다' : '사생회 공지가 등록되었습니다'),
            action: IconButton(
                icon: const Icon(FluentIcons.clear), onPressed: close),
            severity: InfoBarSeverity.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('오류가 발생했습니다: $e');
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
        title: Text(_isEditMode ? '사생회 공지 수정' : '사생회 공지 작성'),
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
                        placeholder: '공지 제목을 입력하세요',
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
                        placeholder: '공지 내용을 입력하세요',
                        maxLines: 15,
                        enabled: !_isLoading,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 고정 공지
                    Row(
                      children: [
                        Checkbox(
                          checked: _isPinned,
                          onChanged: _isLoading
                              ? null
                              : (value) =>
                                  setState(() => _isPinned = value ?? false),
                        ),
                        const SizedBox(width: 8),
                        const Text('고정 공지사항으로 설정'),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: '고정 공지사항은 목록 상단에 고정되어 표시됩니다',
                          child: Icon(FluentIcons.info,
                              size: 14, color: Colors.grey[100]),
                        ),
                      ],
                    ),
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
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        FilledButton(
                          onPressed: _isLoading ? null : _pickImage,
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(FluentIcons.photo2, size: 16),
                              SizedBox(width: 8),
                              Text('이미지 추가'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Button(
                          onPressed: _isLoading ? null : _pickPdf,
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
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
                      const Text('기존 이미지', style: TextStyle(fontSize: 14)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children:
                            _existingImageUrls.asMap().entries.map((entry) {
                          return _buildThumb(
                            image: NetworkImage(entry.value),
                            onRemove: () => setState(
                                () => _existingImageUrls.removeAt(entry.key)),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 새로 선택된 이미지
                    if (_selectedImages.isNotEmpty) ...[
                      const Text('이미지', style: TextStyle(fontSize: 14)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _selectedImages.asMap().entries.map((entry) {
                          return _buildThumb(
                            image: FileImage(entry.value),
                            onRemove: () => setState(
                                () => _selectedImages.removeAt(entry.key)),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 기존 PDF (수정 모드, 새 PDF를 선택하지 않은 경우)
                    if (_existingPdfUrl != null && _selectedPdf == null)
                      _buildPdfRow(
                        _existingPdfFileName?.isNotEmpty == true
                            ? _existingPdfFileName!
                            : 'PDF 첨부됨',
                        onRemove: () => setState(() {
                          _existingPdfUrl = null;
                          _existingPdfFileName = null;
                        }),
                      ),

                    // 새로 선택한 PDF
                    if (_selectedPdf != null)
                      _buildPdfRow(
                        _selectedPdfName ?? 'PDF',
                        onRemove: () => setState(() {
                          _selectedPdf = null;
                          _selectedPdfName = null;
                        }),
                      ),
                  ],
                ),
              ),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 20),
              const Center(child: ProgressRing()),
            ],
          ],
        ),
      ),
    );
  }

  /// 이미지 미리보기 썸네일 (우상단 삭제 버튼)
  Widget _buildThumb(
      {required ImageProvider image, required VoidCallback onRemove}) {
    return Stack(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[60], width: 1),
            image: DecorationImage(image: image, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle),
              child: const Icon(FluentIcons.clear,
                  size: 12, color: Colors.white),
            ),
            onPressed: _isLoading ? null : onRemove,
          ),
        ),
      ],
    );
  }

  Widget _buildPdfRow(String fileName, {required VoidCallback onRemove}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[60], width: 1),
      ),
      child: Row(
        children: [
          Icon(FluentIcons.pdf, size: 18, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(fileName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13)),
          ),
          IconButton(
            icon: const Icon(FluentIcons.clear, size: 12),
            onPressed: _isLoading ? null : onRemove,
          ),
        ],
      ),
    );
  }
}
