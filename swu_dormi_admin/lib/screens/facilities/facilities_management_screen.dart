import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_player/video_player.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../models/facility_report_model.dart';

bool _isVideoUrl(String url) {
  final path = url.split('?').first.toLowerCase();
  return ['mp4', 'mov', 'avi', '3gp', 'mkv'].any((ext) => path.endsWith('.$ext'));
}

Color _statusColor(String status) {
  switch (status) {
    case 'completed': return Colors.green;
    case 'in_progress': return Colors.blue;
    default: return Colors.orange;
  }
}

String _statusText(String status) {
  switch (status) {
    case 'completed': return '완료됨';
    case 'in_progress': return '처리중';
    default: return '대기중';
  }
}

class FacilitiesManagementScreen extends StatefulWidget {
  const FacilitiesManagementScreen({super.key});

  @override
  State<FacilitiesManagementScreen> createState() =>
      _FacilitiesManagementScreenState();
}

class _FacilitiesManagementScreenState
    extends State<FacilitiesManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _firestoreService = FirestoreService();
  Map<String, String> _dormBuildingMap = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDormBuildingMap();
  }

  Future<void> _loadDormBuildingMap() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('users').get();
      if (!mounted) return;
      final map = <String, String>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final dormBuilding = (data['dormBuilding'] as String?) ?? '';
        if (dormBuilding.isNotEmpty) map[doc.id] = dormBuilding;
      }
      setState(() => _dormBuildingMap = map);
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.primary,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: '전체'),
                Tab(text: '대기중'),
                Tab(text: '처리중'),
                Tab(text: '완료됨'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ReportList(status: null, service: _firestoreService, dormBuildingMap: _dormBuildingMap),
                _ReportList(status: 'pending', service: _firestoreService, dormBuildingMap: _dormBuildingMap),
                _ReportList(status: 'in_progress', service: _firestoreService, dormBuildingMap: _dormBuildingMap),
                _ReportList(status: 'completed', service: _firestoreService, dormBuildingMap: _dormBuildingMap),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 신청 목록 ──
class _ReportList extends StatelessWidget {
  final String? status;
  final FirestoreService service;
  final Map<String, String> dormBuildingMap;

  const _ReportList({required this.status, required this.service, required this.dormBuildingMap});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: service.getRepairReports(status: status),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('오류: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_outlined,
                    size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('신청 내역이 없습니다',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600])),
              ],
            ),
          );
        }

        final reports = snapshot.data!.docs
            .map((doc) => FacilityReportModel.fromFirestore(doc))
            .toList()
          ..sort((a, b) => b.reportedAt.compareTo(a.reportedAt));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (_, i) => _ReportCard(report: reports[i], dormBuildingMap: dormBuildingMap),
        );
      },
    );
  }
}

// ── 신청 카드 ──
class _ReportCard extends StatelessWidget {
  final FacilityReportModel report;
  final Map<String, String> dormBuildingMap;

  const _ReportCard({required this.report, required this.dormBuildingMap});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(report.status);
    final media = report.mediaUrls;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _ReportDetailSheet(report: report, dormBuildingMap: dormBuildingMap),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상태 칩 + 신청일
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color),
                    ),
                    child: Text(
                      _statusText(report.status),
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    DateFormat('yyyy-MM-dd HH:mm').format(report.reportedAt),
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 유형 + 건물 + 호실
              Row(
                children: [
                  Icon(Icons.category, size: 15, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(report.getCategoryDisplayName(),
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[700])),
                  const SizedBox(width: 16),
                  Icon(Icons.apartment, size: 15, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    [
                      report.dormBuilding?.isNotEmpty == true
                          ? report.dormBuilding!
                          : (dormBuildingMap[report.userId] ?? ''),
                      if (report.building != null && report.building!.isNotEmpty) report.building!,
                      '${report.roomNumber}호',
                      if (report.seatNumber != null && report.seatNumber!.isNotEmpty) report.seatNumber!,
                    ].where((s) => s.isNotEmpty).join(' '),
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.person, size: 15, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(report.userName,
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey[700])),
                ],
              ),
              const SizedBox(height: 8),
              // 설명
              Text(
                report.description,
                style:
                    TextStyle(fontSize: 14, color: Colors.grey[800]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              // 관리자 메모
              if (report.technicianNote != null &&
                  report.technicianNote!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.note_alt,
                          size: 14, color: Colors.blue.shade600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          report.technicianNote!,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade800),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // 미디어 썸네일
              if (media != null && media.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: media.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: 6),
                    itemBuilder: (ctx, i) => GestureDetector(
                      onTap: () => _openMedia(ctx, media, i),
                      child: _mediaThumbnail(media[i], size: 72),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

void _openMedia(BuildContext context, List<String> urls, int index) {
  final url = urls[index];
  if (_isVideoUrl(url)) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _VideoPlayerScreen(url: url)),
    );
  } else {
    // 이미지만 필터링해서 다이얼로그에 전달
    final imageUrls = urls.where((u) => !_isVideoUrl(u)).toList();
    final imageIndex = imageUrls.indexOf(url);
    showDialog(
      context: context,
      builder: (_) => _MediaViewerDialog(
          urls: imageUrls, initialIndex: imageIndex < 0 ? 0 : imageIndex),
    );
  }
}

Widget _mediaThumbnail(String url, {double size = 72}) {
  if (_isVideoUrl(url)) {
    return _VideoThumbnailWidget(url: url, width: size, height: size);
  }
  return ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: SizedBox(
      width: size,
      height: size,
      child: Image.network(url, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
              color: Colors.grey[200],
              child: const Icon(Icons.broken_image, color: Colors.grey))),
    ),
  );
}

// ── 상세 바텀시트 ──
class _ReportDetailSheet extends StatefulWidget {
  final FacilityReportModel report;
  final Map<String, String> dormBuildingMap;

  const _ReportDetailSheet({required this.report, required this.dormBuildingMap});

  @override
  State<_ReportDetailSheet> createState() => _ReportDetailSheetState();
}

class _ReportDetailSheetState extends State<_ReportDetailSheet> {
  late String _selectedStatus;
  final _noteCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.report.status;
    _noteCtrl.text = widget.report.technicianNote ?? '';
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _updateStatus() async {
    setState(() => _isLoading = true);
    try {
      await FirestoreService().updateRepairReportStatus(
        widget.report.id,
        _selectedStatus,
        _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );

      if (_selectedStatus == 'in_progress' ||
          _selectedStatus == 'completed') {
        await NotificationService().sendFacilityReportStatusNotification(
          userId: widget.report.userId,
          reportId: widget.report.id,
          status: _selectedStatus,
          title: widget.report.getCategoryDisplayName(),
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('상태가 업데이트되었습니다'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('오류: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final color = _statusColor(report.status);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
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
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 상태 칩
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: color, width: 1.5),
                          ),
                          child: Text(
                            _statusText(report.status),
                            style: TextStyle(
                                color: color,
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 기본 정보
                    _detailRow(Icons.category, '신청 유형',
                        report.getCategoryDisplayName()),
                    const SizedBox(height: 12),
                    Builder(builder: (context) {
                      final dorm = report.dormBuilding?.isNotEmpty == true
                          ? report.dormBuilding!
                          : (widget.dormBuildingMap[report.userId] ?? '');
                      if (dorm.isEmpty) return const SizedBox.shrink();
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: _detailRow(Icons.home_work, '기숙사', dorm)),
                              if (report.building != null && report.building!.isNotEmpty)
                                Expanded(child: _detailRow(Icons.apartment, '구역', report.building!)),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      );
                    }),
                    Row(
                      children: [
                        Expanded(
                          child: _detailRow(
                              Icons.door_front_door, '호실', '${report.roomNumber}호'),
                        ),
                        if (report.seatNumber != null &&
                            report.seatNumber!.isNotEmpty)
                          Expanded(
                            child: _detailRow(
                                Icons.chair, '자리번호', report.seatNumber!),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _detailRow(Icons.person, '신청자', report.userName),
                    const SizedBox(height: 12),
                    _detailRow(
                      Icons.calendar_today,
                      '신청 일시',
                      DateFormat('yyyy-MM-dd HH:mm').format(report.reportedAt),
                    ),
                    if (report.completedAt != null) ...[
                      const SizedBox(height: 12),
                      _detailRow(
                        Icons.check_circle,
                        '완료 일시',
                        DateFormat('yyyy-MM-dd HH:mm')
                            .format(report.completedAt!),
                      ),
                    ],
                    if (report.processedByName != null) ...[
                      const SizedBox(height: 12),
                      _detailRow(Icons.admin_panel_settings, '처리자',
                          report.processedByName!),
                    ],

                    const Divider(height: 32),

                    // 상세 설명
                    const Text('상세 설명',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(report.description,
                        style: const TextStyle(fontSize: 15, height: 1.5)),

                    // 미디어
                    if (report.mediaUrls != null &&
                        report.mediaUrls!.isNotEmpty) ...[
                      const Divider(height: 32),
                      const Text('첨부 파일',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                        ),
                        itemCount: report.mediaUrls!.length,
                        itemBuilder: (ctx, i) => GestureDetector(
                          onTap: () => _openMedia(ctx, report.mediaUrls!, i),
                          child: _mediaThumbnail(report.mediaUrls![i], size: 100),
                        ),
                      ),
                    ],

                    const Divider(height: 32),

                    // 처리 상태 변경
                    const Text('처리 상태',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'pending',
                            label: Text('대기중'),
                            icon: Icon(Icons.pending, size: 16)),
                        ButtonSegment(
                            value: 'in_progress',
                            label: Text('처리중'),
                            icon: Icon(Icons.build, size: 16)),
                        ButtonSegment(
                            value: 'completed',
                            label: Text('완료됨'),
                            icon: Icon(Icons.check_circle, size: 16)),
                      ],
                      selected: {_selectedStatus},
                      onSelectionChanged: (s) =>
                          setState(() => _selectedStatus = s.first),
                    ),

                    const SizedBox(height: 24),

                    // 관리자 메모
                    const Text('관리자 메모',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteCtrl,
                      decoration: const InputDecoration(
                        hintText: '처리 내용이나 특이사항을 입력하세요',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                    ),

                    const SizedBox(height: 24),

                    // 저장 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updateStatus,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('저장',
                                style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          child: Text(label,
              style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

// ── 미디어 전체화면 뷰어 ──
class _MediaViewerDialog extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const _MediaViewerDialog(
      {required this.urls, required this.initialIndex});

  @override
  State<_MediaViewerDialog> createState() => _MediaViewerDialogState();
}

class _MediaViewerDialogState extends State<_MediaViewerDialog> {
  late PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text('${_current + 1} / ${widget.urls.length}'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: PageView.builder(
          controller: _pageCtrl,
          itemCount: widget.urls.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (_, i) {
            final url = widget.urls[i];
            return InteractiveViewer(
              child: Center(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white)),
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                      size: 64),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── 비디오 썸네일 위젯 ──
class _VideoThumbnailWidget extends StatefulWidget {
  final String url;
  final double width;
  final double height;

  const _VideoThumbnailWidget({
    required this.url,
    this.width = double.infinity,
    this.height = 120,
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
      final bytes = await VideoThumbnail.thumbnailData(
        video: widget.url,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 512,
        quality: 75,
      );
      if (mounted) setState(() { _thumbnail = bytes; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_loading)
              Container(color: Colors.grey[300],
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)))
            else if (_thumbnail != null)
              Image.memory(_thumbnail!, fit: BoxFit.cover)
            else
              Container(color: Colors.grey[300],
                  child: const Icon(Icons.videocam, size: 32, color: Colors.grey)),
            const Center(
              child: Icon(Icons.play_circle_fill, color: Colors.white, size: 28),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 비디오 플레이어 ──
class _VideoPlayerScreen extends StatefulWidget {
  final String url;

  const _VideoPlayerScreen({required this.url});

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  late VideoPlayerController _ctrl;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
        _ctrl.play();
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return GestureDetector(
      onTap: () => setState(() =>
          _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play()),
      child: Center(
        child: AspectRatio(
          aspectRatio: _ctrl.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_ctrl),
              if (!_ctrl.value.isPlaying)
                const Icon(Icons.play_circle_fill,
                    color: Colors.white70, size: 64),
            ],
          ),
        ),
      ),
    );
  }
}
