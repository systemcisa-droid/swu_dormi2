import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../constants/board_categories.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../models/post_model.dart';
import '../../services/storage_service.dart';
import '../../utils/board_strings.dart';

class AddPostScreen extends StatefulWidget {
  final PostModel? post; // null이면 작성 모드, 값이 있으면 수정 모드

  const AddPostScreen({super.key, this.post});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final List<File> _selectedImages = [];
  final List<String> _existingImageUrls = []; // 수정 모드: 기존 이미지 URL
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  String _selectedCategory = 'lost&found';

  static const List<Map<String, dynamic>> _categories = kBoardCategories;

  bool get _isEditMode => widget.post != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _titleController.text = widget.post!.title;
      _contentController.text = widget.post!.content;
      _existingImageUrls.addAll(widget.post!.imageUrls);
      _selectedCategory = widget.post!.category;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (images.isNotEmpty && mounted) {
        final s = BoardStrings(Provider.of<LocaleProvider>(context, listen: false).isEnglish);
        setState(() {
          _selectedImages.addAll(images.map((xFile) => File(xFile.path)));
          // 최대 5개까지만 허용
          if (_selectedImages.length > 5) {
            _selectedImages.removeRange(5, _selectedImages.length);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(s.maxImagesNotice)),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        final s = BoardStrings(Provider.of<LocaleProvider>(context, listen: false).isEnglish);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.imagePickError(e))),
        );
      }
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        if (_selectedImages.length >= 5) {
          if (mounted) {
            final s = BoardStrings(Provider.of<LocaleProvider>(context, listen: false).isEnglish);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(s.maxImagesNotice)),
            );
          }
          return;
        }
        setState(() {
          _selectedImages.add(File(image.path));
        });
      }
    } catch (e) {
      if (mounted) {
        final s = BoardStrings(Provider.of<LocaleProvider>(context, listen: false).isEnglish);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.photoTakeError(e))),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  void _showImageSourceDialog() {
    final s = BoardStrings(Provider.of<LocaleProvider>(context, listen: false).isEnglish);
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: Text(s.takePhoto),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(s.chooseFromGallery),
              onTap: () {
                Navigator.pop(context);
                _pickImages();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    final s = BoardStrings(Provider.of<LocaleProvider>(context, listen: false).isEnglish);

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.loginRequired)),
      );
      return;
    }

    // 수정 모드가 아닐 때만 안내 다이얼로그 표시
    if (!_isEditMode) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(s.confirmDialogTitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.confirmDialogIntro,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 12),
              for (final text in s.restrictedRules)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('❌ ', style: TextStyle(fontSize: 13)),
                      Expanded(
                        child: Text(text, style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                s.confirmDialogOutro,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s.confirmAndPost),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isLoading = true);

    try {
      // 새 이미지 업로드
      List<String> newImageUrls = [];
      if (_selectedImages.isNotEmpty) {
        final storageService = StorageService();
        for (var imageFile in _selectedImages) {
          final imageUrl = await storageService.uploadImage(
            imageFile,
            'board_posts/${user.uid}',
          );
          if (imageUrl != null) newImageUrls.add(imageUrl);
        }
      }

      final allImageUrls = [..._existingImageUrls, ...newImageUrls];

      if (_isEditMode) {
        // 수정 모드: 기존 문서 업데이트
        await FirebaseFirestore.instance
            .collection('board_posts')
            .doc(widget.post!.id)
            .update({
          'title': _titleController.text.trim(),
          'content': _contentController.text.trim(),
          'imageUrls': allImageUrls,
          'category': _selectedCategory,
          'updatedAt': Timestamp.now(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.postUpdated)),
          );
          Navigator.pop(context);
        }
      } else {
        // 작성 모드: 새 문서 생성
        final postId = FirebaseFirestore.instance.collection('board_posts').doc().id;
        final post = PostModel(
          id: postId,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          authorId: user.uid,
          authorName: user.name,
          authorNickname: user.nickname,
          authorProfileImageUrl: user.profileImageUrl,
          createdAt: DateTime.now(),
          imageUrls: allImageUrls,
          category: _selectedCategory,
        );

        await FirebaseFirestore.instance
            .collection('board_posts')
            .doc(postId)
            .set(post.toMap());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.postCreated)),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.genericError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = BoardStrings(Provider.of<LocaleProvider>(context).isEnglish);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? s.editPostTitle : s.writeTitle),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitPost,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _isEditMode ? s.edit : s.register,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // 카테고리 선택
            Text(s.category,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat['value'];
                final color = cat['color'] as Color;
                return ChoiceChip(
                  label: Text(s.categoryLabel(cat['label'] as String)),
                  selected: isSelected,
                  selectedColor: color.withValues(alpha: 0.2),
                  side: BorderSide(color: isSelected ? color : Colors.grey.shade300),
                  labelStyle: TextStyle(
                    color: isSelected ? color : Colors.grey[700],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (_) => setState(() => _selectedCategory = cat['value'] as String),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // 제목 입력
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: s.postTitleLabel,
                hintText: s.postTitleHint,
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return s.titleRequired;
                }
                if (value.trim().length > 100) {
                  return s.titleTooLong;
                }
                return null;
              },
              maxLength: 100,
            ),
            const SizedBox(height: 16),
            // 내용 입력
            TextFormField(
              controller: _contentController,
              decoration: InputDecoration(
                labelText: s.contentLabel,
                hintText: s.contentHint,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 10,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return s.contentRequired;
                }
                if (value.trim().length > 2000) {
                  return s.contentTooLong;
                }
                return null;
              },
              maxLength: 2000,
            ),
            const SizedBox(height: 16),
            // 이미지 첨부 버튼
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _showImageSourceDialog,
              icon: const Icon(Icons.add_photo_alternate),
              label: Text(
                s.imageAttach(_selectedImages.length),
                style: const TextStyle(fontSize: 14),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            // 기존 이미지 미리보기 (수정 모드)
            if (_existingImageUrls.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _existingImageUrls.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _existingImageUrls[index],
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 120,
                                  height: 120,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.broken_image),
                                );
                              },
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeExistingImage(index),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            // 새로 선택된 이미지 미리보기
            if (_selectedImages.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _selectedImages[index],
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
