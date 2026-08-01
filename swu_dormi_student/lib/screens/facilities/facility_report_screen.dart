import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_player/video_player.dart';
import 'package:video_compress/video_compress.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';
import '../../models/facility_report_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/facility_report_strings.dart';

class FacilityReportScreen extends StatefulWidget {
  const FacilityReportScreen({super.key});

  @override
  State<FacilityReportScreen> createState() => _FacilityReportScreenState();
}

class _FacilityReportScreenState extends State<FacilityReportScreen> {
  int _viewMode = 0; // 0: 신고하기, 1: 신고 내역

  @override
  Widget build(BuildContext context) {
    final s = FacilityReportStrings(Provider.of<LocaleProvider>(context).isEnglish);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.title),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 탭 버튼
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _viewMode == 0
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade200,
                      foregroundColor: _viewMode == 0 ? Colors.white : Colors.black87,
                    ),
                    onPressed: () => setState(() => _viewMode = 0),
                    icon: const Icon(Icons.edit, size: 18),
                    label: Text(s.tabSubmit),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _viewMode == 1
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade200,
                      foregroundColor: _viewMode == 1 ? Colors.white : Colors.black87,
                    ),
                    onPressed: () => setState(() => _viewMode = 1),
                    icon: const Icon(Icons.list_alt, size: 18),
                    label: Text(s.tabHistory),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _viewMode == 0
                ? _FacilityReportForm(
              onReportSubmitted: () => setState(() => _viewMode = 1),
            )
                : const _FacilityReportList(),
          ),
        ],
      ),
    );
  }
}

// 신고하기 폼
class _FacilityReportForm extends StatefulWidget {
  final VoidCallback onReportSubmitted;

  const _FacilityReportForm({required this.onReportSubmitted});

  @override
  State<_FacilityReportForm> createState() => _FacilityReportFormState();
}

class _FacilityReportFormState extends State<_FacilityReportForm> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  String _selectedCategory = 'maintenance';
  final List<File> _selectedMedia = [];
  bool _isLoading = false;
  String _loadingText = '';

  static const int _maxMedia = 5;
  static const List<String> _videoExtensions = ['mp4', 'mov', 'avi', '3gp', 'mkv'];

  bool _isVideo(File file) {
    final ext = file.path.split('.').last.toLowerCase();
    return _videoExtensions.contains(ext);
  }

  static const List<Map<String, dynamic>> _categories = [
    {'value': 'maintenance', 'label': '가구/도어', 'icon': Icons.eco},
    {'value': 'plumbing', 'label': '수도/냉난방', 'icon': Icons.build},
    {'value': 'electrical', 'label': '전기', 'icon': Icons.electrical_services},
    {'value': 'common_area', 'label': '공동구역(헬스장, 기도실 등)', 'icon': Icons.meeting_room},
    {'value': 'other', 'label': '기타', 'icon': Icons.more_horiz},
  ];

  Future<File?> _compressVideo(File videoFile) async {
    try {
      final info = await VideoCompress.compressVideo(
        videoFile.path,
        quality: VideoQuality.LowQuality,
        deleteOrigin: false,
        includeAudio: true,
      );
      return info?.file;
    } catch (e) {
      debugPrint('영상 압축 실패: $e');
      return null;
    }
  }

  @override
  void dispose() {
    VideoCompress.cancelCompression();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(ImageSource source, {bool isVideo = false}) async {
    final s = FacilityReportStrings(Provider.of<LocaleProvider>(context, listen: false).isEnglish);
    if (_selectedMedia.length >= _maxMedia) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.maxAttachNotice)),
      );
      return;
    }
    try {
      final ImagePicker picker = ImagePicker();
      XFile? file;
      if (isVideo) {
        file = await picker.pickVideo(source: source, maxDuration: const Duration(minutes: 3));
      } else {
        file = await picker.pickImage(
          source: source,
          maxWidth: 1280,
          maxHeight: 720,
          imageQuality: 70,
        );
      }
      if (file != null) {
        setState(() {
          _selectedMedia.add(File(file!.path));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.cannotSelectFile)),
        );
      }
    }
  }

  void _showMediaSourceDialog() {
    final s = FacilityReportStrings(Provider.of<LocaleProvider>(context, listen: false).isEnglish);
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
                _pickMedia(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: Text(s.recordVideo),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.camera, isVideo: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(s.chooseImageFromGallery),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: Text(s.chooseVideoFromGallery),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.gallery, isVideo: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _hasValidResidenceInfo(dynamic user) {
    final hasDormBuilding = user.dormBuilding != null && user.dormBuilding!.isNotEmpty;
    final hasRoomNumber = user.roomNumber.isNotEmpty && user.roomNumber != '000';
    final hasSeatNumber = user.seatNumber != null && user.seatNumber!.isNotEmpty;
    return hasDormBuilding && hasRoomNumber && hasSeatNumber;
  }

  Future<void> _submitReport() async {
    final s = FacilityReportStrings(Provider.of<LocaleProvider>(context, listen: false).isEnglish);
    if (_formKey.currentState == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.formNotReady)),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.loginRequired)),
      );
      return;
    }
    setState(() { _isLoading = true; _loadingText = s.processing; });

    try {
      final reportId = DateTime.now().millisecondsSinceEpoch.toString();

      final List<String> mediaUrls = [];
      for (int i = 0; i < _selectedMedia.length; i++) {
        try {
          File fileToUpload = _selectedMedia[i];

          if (_isVideo(fileToUpload)) {
            if (mounted) setState(() => _loadingText = s.compressingVideo(i + 1, _selectedMedia.length));
            final compressed = await _compressVideo(fileToUpload);
            if (compressed != null) fileToUpload = compressed;
          } else {
            if (mounted) setState(() => _loadingText = s.optimizingImage(i + 1, _selectedMedia.length));
          }

          if (mounted) setState(() => _loadingText = s.uploading(i + 1, _selectedMedia.length));
          final url = await StorageService().uploadRepairMedia(reportId, fileToUpload, i);
          if (url != null) mediaUrls.add(url);
        } catch (e) {
          debugPrint('미디어 업로드 실패 ($i): $e');
        }
      }
      if (_selectedMedia.isNotEmpty && mediaUrls.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.uploadFailedSubmitWithoutFile)),
        );
      }

      final report = FacilityReportModel(
        id: reportId,
        userId: user.uid,
        userName: user.name,
        roomNumber: user.roomNumber,
        seatNumber: user.seatNumber,
        building: user.building,
        dormBuilding: user.dormBuilding,
        category: _selectedCategory,
        description: _descriptionController.text.trim(),
        mediaUrls: mediaUrls.isEmpty ? null : mediaUrls,
        reportedAt: DateTime.now(),
      );

      await DatabaseService().submitFacilityReport(report);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.submitSuccess),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        _formKey.currentState?.reset();
        _descriptionController.clear();
        setState(() {
          _selectedCategory = 'maintenance';
          _selectedMedia.clear();
        });

        widget.onReportSubmitted();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.submitError),
            backgroundColor: Colors.red,
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
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final residenceInfoMissing = user == null || !_hasValidResidenceInfo(user);
    final s = FacilityReportStrings(Provider.of<LocaleProvider>(context).isEnglish);

    return _isLoading
        ? Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (_loadingText.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(_loadingText, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          ],
        ],
      ),
    )
        : SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 사용자 정보 카드
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          s.residentInfo,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    _buildInfoRow(s.name, user?.name ?? s.noInfo),
                    const SizedBox(height: 8),
                    if (user != null && user.dormBuilding != null && user.dormBuilding!.isNotEmpty) ...[
                      _buildInfoRow(s.dormBuilding, user.dormBuilding!),
                      const SizedBox(height: 8),
                      if (user.building.isNotEmpty)
                        _buildInfoRow(s.area, user.building),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        Expanded(child: _buildInfoRow(s.room, user?.roomNumber ?? s.noInfo)),
                        if (user?.seatNumber != null && user!.seatNumber!.isNotEmpty)
                          Expanded(child: _buildInfoRow(s.seatNumber, user.seatNumber!)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (residenceInfoMissing) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.residenceInfoMissingBanner,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            // 사진/영상 첨부
            Row(
              children: [
                Flexible(
                  child: Text(
                    s.photoVideoAttachOptional,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_selectedMedia.length}/$_maxMedia',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_selectedMedia.isNotEmpty)
              SizedBox(
                height: 100,
                child: Row(
                  children: [
                    ..._selectedMedia.asMap().entries.map((entry) {
                      final index = entry.key;
                      final file = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          alignment: Alignment.topRight,
                          children: [
                            _isVideo(file)
                                ? _VideoThumbnailWidget(
                              file: file,
                              width: 100,
                              height: 100,
                              borderRadius: BorderRadius.circular(8),
                            )
                                : ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(file, width: 100, height: 100, fit: BoxFit.cover),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _selectedMedia.removeAt(index)),
                              child: Container(
                                margin: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (_selectedMedia.length < _maxMedia)
                      GestureDetector(
                        onTap: _showMediaSourceDialog,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _showMediaSourceDialog,
                icon: const Icon(Icons.add_photo_alternate),
                label: Text(s.addPhotoVideo),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            const SizedBox(height: 32),

            // 신고 카테고리
            Text(
              s.requestType,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((category) {
                final isSelected = _selectedCategory == category['value'];
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        category['icon'] as IconData,
                        size: 18,
                        color: isSelected ? Colors.white : Colors.grey[700],
                      ),
                      const SizedBox(width: 4),
                      Text(s.category(category['label'] as String)),
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = category['value'] as String;
                    });
                  },
                  selectedColor: Theme.of(context).colorScheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // 상세 설명
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: s.detailDescription,
                hintText: s.detailDescriptionHint,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              maxLength: 500,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return s.detailDescriptionRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text(
              s.guideText,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // 제출 버튼
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_isLoading || residenceInfoMissing) ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  s.submit,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// 신고 내역 리스트
class _FacilityReportList extends StatefulWidget {
  const _FacilityReportList();

  @override
  State<_FacilityReportList> createState() => _FacilityReportListState();
}

class _FacilityReportListState extends State<_FacilityReportList> {
  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return '접수 대기';
      case 'in_progress': return '처리 중';
      case 'completed': return '처리 완료';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'in_progress': return Colors.blue;
      case 'completed': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _getCategoryText(String category) {
    switch (category) {
      case 'maintenance': return '가구/도어';
      case 'plumbing': return '수도/냉난방';
      case 'electrical': return '전기';
      case 'other': return '기타';
      default: return category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final s = FacilityReportStrings(Provider.of<LocaleProvider>(context).isEnglish);

    if (user == null) {
      return Center(child: Text(s.historyLoginRequired));
    }

    return StreamBuilder<List<FacilityReportModel>>(
      stream: DatabaseService().getUserFacilityReports(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(s.historyLoadError),
          );
        }

        final reports = snapshot.data ?? [];

        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  s.noHistory,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: reports.map((report) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildReportCard(report, s),
            )).toList(),
          ),
        );
      },
    );
  }

  Widget _buildReportCard(FacilityReportModel report, FacilityReportStrings s) {
    final canEdit = report.status == 'pending';
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _showReportDetail(report, s),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(report.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getStatusColor(report.status)),
                    ),
                    child: Text(
                      s.status(_getStatusText(report.status)),
                      style: TextStyle(
                        color: _getStatusColor(report.status),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (canEdit) ...[
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                        tooltip: s.edit,
                        onPressed: () => _showEditDialog(report, s),
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        tooltip: s.delete,
                        onPressed: () => _deleteReport(report, s),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.category, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    s.category(_getCategoryText(report.category)),
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('yyyy-MM-dd HH:mm').format(report.reportedAt),
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                report.description,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (report.technicianNote != null && report.technicianNote!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.note_alt, size: 16, color: Colors.blue.shade600),
                          const SizedBox(width: 6),
                          Text(
                            s.adminNote,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        report.technicianNote!,
                        style: TextStyle(fontSize: 13, color: Colors.blue.shade800),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
              if (report.mediaUrls != null && report.mediaUrls!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Builder(builder: (context) {
                  final firstUrl = report.mediaUrls!.first;
                  final isVideo = ['mp4', 'mov', 'avi', '3gp', 'mkv']
                      .any((ext) => firstUrl.toLowerCase().contains('.$ext'));
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isVideo)
                        _VideoThumbnailWidget(url: firstUrl, height: 120)
                      else
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            firstUrl,
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 120,
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 36),
                              ),
                            ),
                          ),
                        ),
                      if (report.mediaUrls!.length > 1) ...[
                        const SizedBox(height: 4),
                        Text(
                          s.moreCount(report.mediaUrls!.length - 1),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showReportDetail(FacilityReportModel report, FacilityReportStrings s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getStatusColor(report.status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _getStatusColor(report.status), width: 1.5),
                            ),
                            child: Text(
                              s.status(_getStatusText(report.status)),
                              style: TextStyle(
                                color: _getStatusColor(report.status),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildDetailRow(Icons.category, s.requestTypeLabel, s.category(_getCategoryText(report.category))),
                      const SizedBox(height: 12),
                      if (report.dormBuilding != null && report.dormBuilding!.isNotEmpty) ...[
                        _buildDetailRow(Icons.home_work, s.dormBuilding, report.dormBuilding!),
                        const SizedBox(height: 12),
                        if (report.building != null && report.building!.isNotEmpty)
                          _buildDetailRow(Icons.apartment, s.area, report.building!),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Expanded(child: _buildDetailRow(Icons.door_front_door, s.room, report.roomNumber)),
                          if (report.seatNumber != null && report.seatNumber!.isNotEmpty)
                            Expanded(child: _buildDetailRow(Icons.chair, s.seatNumber, report.seatNumber!)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.calendar_today,
                        s.requestDateTime,
                        DateFormat('yyyy-MM-dd HH:mm').format(report.reportedAt),
                      ),
                      if (report.completedAt != null) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          Icons.check_circle,
                          s.completedDateTime,
                          DateFormat('yyyy-MM-dd HH:mm').format(report.completedAt!),
                        ),
                      ],
                      const Divider(height: 32),
                      Text(
                        s.detailDescription,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(report.description, style: const TextStyle(fontSize: 15, height: 1.5)),
                      if (report.technicianNote != null) ...[
                        const Divider(height: 32),
                        Text(
                          s.adminNote,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            report.technicianNote!,
                            style: const TextStyle(fontSize: 15, height: 1.5),
                          ),
                        ),
                      ],
                      if (report.mediaUrls != null && report.mediaUrls!.isNotEmpty) ...[
                        const Divider(height: 32),
                        Text(
                          s.attachedFiles,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        ...report.mediaUrls!.map((url) {
                          final isVideo = ['mp4', 'mov', 'avi', '3gp', 'mkv']
                              .any((ext) => url.toLowerCase().contains('.$ext'));
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: isVideo
                                ? _VideoThumbnailWidget(
                              url: url,
                              height: 200,
                              borderRadius: BorderRadius.circular(12),
                            )
                                : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                url,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 160,
                                  color: Colors.grey[200],
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40),
                                        const SizedBox(height: 8),
                                        Text(s.imageLoadError, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        SizedBox(
          width: 100,
          child: Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  // ── 수정 다이얼로그 ────────────────────────────────────────────
  void _showEditDialog(FacilityReportModel report, FacilityReportStrings s) {
    final descCtrl = TextEditingController(text: report.description);
    String selectedCat = report.category;
    final List<String> remainingUrls = List<String>.from(report.mediaUrls ?? []);
    final List<File> newFiles = [];
    final picker = ImagePicker();

    void pickImage(StateSetter setS) async {
      if (remainingUrls.length + newFiles.length >= 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.maxAttachNotice)),
        );
        return;
      }
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 720,
        imageQuality: 70,
      );
      if (file != null) setS(() => newFiles.add(File(file.path)));
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.editRequestTitle,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text(s.requestTypeLabel,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _FacilityReportFormState._categories.map((cat) {
                    final isSel = selectedCat == cat['value'];
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(cat['icon'] as IconData,
                              size: 16,
                              color: isSel ? Colors.white : Colors.grey[700]),
                          const SizedBox(width: 4),
                          Text(s.category(cat['label'] as String)),
                        ],
                      ),
                      selected: isSel,
                      onSelected: (_) =>
                          setS(() => selectedCat = cat['value'] as String),
                      selectedColor: Theme.of(context).colorScheme.primary,
                      labelStyle: TextStyle(
                          color: isSel ? Colors.white : Colors.grey[700]),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    labelText: s.detailDescription,
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                  maxLength: 500,
                ),
                const SizedBox(height: 16),
                // ── 첨부 이미지 ──────────────────────────────
                Row(
                  children: [
                    Text(s.attachedImages(remainingUrls.length + newFiles.length),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => pickImage(setS),
                      icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                      label: Text(s.add),
                    ),
                  ],
                ),
                if (remainingUrls.isNotEmpty || newFiles.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // 기존 이미지 (URL)
                      ...remainingUrls.asMap().entries.map((e) => _buildEditThumb(
                        child: Image.network(e.value, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey)),
                        onRemove: () => setS(() => remainingUrls.removeAt(e.key)),
                      )),
                      // 새로 추가한 이미지 (파일)
                      ...newFiles.asMap().entries.map((e) => _buildEditThumb(
                        child: Image.file(e.value, fit: BoxFit.cover),
                        onRemove: () => setS(() => newFiles.removeAt(e.key)),
                      )),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    final desc = descCtrl.text.trim();
                    if (desc.isEmpty) return;
                    Navigator.pop(ctx);
                    await _doUpdate(
                      report.id,
                      selectedCat,
                      desc,
                      remainingUrls: remainingUrls,
                      newFiles: newFiles,
                      s: s,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(s.save, style: const TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditThumb({required Widget child, required VoidCallback onRemove}) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: child,
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _doUpdate(
    String id,
    String category,
    String description, {
    required List<String> remainingUrls,
    required List<File> newFiles,
    required FacilityReportStrings s,
  }) async {
    try {
      final List<String> uploadedUrls = [];
      final startIdx = remainingUrls.length;
      for (int i = 0; i < newFiles.length; i++) {
        final url = await StorageService().uploadRepairMedia(id, newFiles[i], startIdx + i);
        if (url != null) uploadedUrls.add(url);
      }
      final allUrls = [...remainingUrls, ...uploadedUrls];

      await FirebaseFirestore.instance
          .collection('facility_reports')
          .doc(id)
          .update({
        'category': category,
        'description': description,
        'mediaUrls': allUrls.isEmpty ? null : allUrls,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.updated), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.updateError(e))));
      }
    }
  }

  // ── 삭제 ────────────────────────────────────────────────────
  Future<void> _deleteReport(FacilityReportModel report, FacilityReportStrings s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteRequestTitle),
        content: Text(s.deleteRequestConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                Text(s.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('facility_reports')
          .doc(report.id)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(s.deleted), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.deleteError(e))));
      }
    }
  }
}

// 영상 썸네일 위젯 (로컬 파일 또는 네트워크 URL)
class _VideoThumbnailWidget extends StatefulWidget {
  final String? url;
  final File? file;
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const _VideoThumbnailWidget({
    this.url,
    this.file,
    this.width = double.infinity,
    this.height = 120,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<_VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<_VideoThumbnailWidget> {
  Uint8List? _thumbnail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    try {
      final path = widget.file?.path ?? widget.url!;
      final bytes = await VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 512,
        quality: 75,
      );
      if (mounted) setState(() { _thumbnail = bytes; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openPlayer(BuildContext context) {
    final path = widget.file?.path ?? widget.url!;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _VideoPlayerScreen(path: path, isLocal: widget.file != null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openPlayer(context),
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_loading)
              Container(
                width: widget.width,
                height: widget.height,
                color: Colors.black54,
                child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
              )
            else if (_thumbnail != null)
              Image.memory(
                _thumbnail!,
                width: widget.width,
                height: widget.height,
                fit: BoxFit.cover,
              )
            else
              Container(
                width: widget.width,
                height: widget.height,
                color: Colors.black87,
              ),
            const Icon(Icons.play_circle_filled, color: Colors.white, size: 48),
          ],
        ),
      ),
    );
  }
}

// 전체화면 영상 플레이어
class _VideoPlayerScreen extends StatefulWidget {
  final String path;
  final bool isLocal;

  const _VideoPlayerScreen({required this.path, required this.isLocal});

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.isLocal
        ? VideoPlayerController.file(File(widget.path))
        : VideoPlayerController.networkUrl(Uri.parse(widget.path));
    _controller.initialize().then((_) {
      if (mounted) {
        setState(() => _initialized = true);
        _controller.play();
      }
    });
    _controller.setLooping(false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _initialized
            ? GestureDetector(
          onTap: () {
            setState(() {
              _controller.value.isPlaying ? _controller.pause() : _controller.play();
            });
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
              ValueListenableBuilder(
                valueListenable: _controller,
                builder: (context, value, _) {
                  return AnimatedOpacity(
                    opacity: value.isPlaying ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: const Icon(Icons.play_circle_filled, color: Colors.white, size: 64),
                  );
                },
              ),
            ],
          ),
        )
            : const CircularProgressIndicator(color: Colors.white),
      ),
      bottomNavigationBar: _initialized
          ? SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: VideoProgressIndicator(
            _controller,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: Colors.white,
              bufferedColor: Colors.white30,
              backgroundColor: Colors.white10,
            ),
          ),
        ),
      )
          : null,
    );
  }
}