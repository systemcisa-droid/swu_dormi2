import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_player/video_player.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../models/facility_report_model.dart';
import '../../utils/building_utils.dart';

const Map<int, int> _kShalomCapacities = {
  1: 2, 2: 4, 3: 2, 4: 2, 5: 4, 6: 2, 7: 1, 8: 2, 9: 1, 10: 2,
  11: 1, 12: 1, 13: 4, 14: 4, 15: 4, 16: 4, 17: 4, 18: 4, 19: 4, 20: 4,
  21: 2, 22: 4, 23: 2, 24: 2, 25: 4, 26: 2, 27: 2, 28: 2, 29: 1, 30: 4,
  31: 4, 32: 4, 33: 4, 34: 4, 35: 4,
};

String _roomLabel(String roomNumber, String dormBuilding) {
  final n = int.tryParse(roomNumber) ?? 0;
  if (dormBuilding == '샬롬하우스' && n > 0) {
    final cap = _kShalomCapacities[n % 100] ?? 4;
    return '$roomNumber호 ($cap)';
  }
  return '$roomNumber호';
}

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
    extends State<FacilitiesManagementScreen> {
  final _firestoreService = FirestoreService();
  Map<String, String> _dormBuildingMap = {};
  String? _selectedFloor;
  String? _selectedStatus;
  String? _selectedCategory;

  static const _floorOptions = [
    '샬롬하우스 A동 2층', '샬롬하우스 A동 3층', '샬롬하우스 A동 4층',
    '샬롬하우스 A동 5층', '샬롬하우스 A동 6층', '샬롬하우스 A동 7층',
    '샬롬하우스 B동 2층', '샬롬하우스 B동 3층', '샬롬하우스 B동 4층',
    '샬롬하우스 B동 5층', '샬롬하우스 B동 6층', '샬롬하우스 B동 7층',
    '국제생활관 A동 1층', '국제생활관 A동 2층',
    '국제생활관 B동 2층', '국제생활관 B동 3층',
    '바롬인성교육관 10층',
  ];

  @override
  void initState() {
    super.initState();
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: Colors.grey.shade50,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _selectedFloor,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: '점검구역',
                          prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('전체 구역', style: TextStyle(fontSize: 13))),
                          ..._floorOptions.map((f) => DropdownMenuItem<String?>(
                                value: f,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: buildingColor(f),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    Expanded(child: Text(f, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                                  ],
                                ),
                              )),
                        ],
                        onChanged: (val) => setState(() => _selectedFloor = val),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _selectedStatus,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: '처리 상태',
                          prefixIcon: Icon(Icons.flag_outlined, size: 18),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        items: const [
                          DropdownMenuItem<String?>(value: null, child: Text('전체', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem<String?>(value: 'pending', child: Text('대기중', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem<String?>(value: 'in_progress', child: Text('처리중', style: TextStyle(fontSize: 13))),
                          DropdownMenuItem<String?>(value: 'completed', child: Text('완료됨', style: TextStyle(fontSize: 13))),
                        ],
                        onChanged: (val) => setState(() => _selectedStatus = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // 카테고리 칩 필터
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _CategoryChip(label: '전체', value: null, selected: _selectedCategory == null,
                          onTap: () => setState(() => _selectedCategory = null)),
                      const SizedBox(width: 6),
                      _CategoryChip(label: '수도/냉난방', value: 'plumbing', selected: _selectedCategory == 'plumbing',
                          onTap: () => setState(() => _selectedCategory = _selectedCategory == 'plumbing' ? null : 'plumbing')),
                      const SizedBox(width: 6),
                      _CategoryChip(label: '가구/도어', value: 'maintenance', selected: _selectedCategory == 'maintenance',
                          onTap: () => setState(() => _selectedCategory = _selectedCategory == 'maintenance' ? null : 'maintenance')),
                      const SizedBox(width: 6),
                      _CategoryChip(label: '전기', value: 'electrical', selected: _selectedCategory == 'electrical',
                          onTap: () => setState(() => _selectedCategory = _selectedCategory == 'electrical' ? null : 'electrical')),
                      const SizedBox(width: 6),
                      _CategoryChip(label: '공동구역', value: 'common_area', selected: _selectedCategory == 'common_area',
                          onTap: () => setState(() => _selectedCategory = _selectedCategory == 'common_area' ? null : 'common_area')),
                      const SizedBox(width: 6),
                      _CategoryChip(label: '기타', value: 'other', selected: _selectedCategory == 'other',
                          onTap: () => setState(() => _selectedCategory = _selectedCategory == 'other' ? null : 'other')),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          Expanded(
            child: _ReportList(
              status: _selectedStatus,
              service: _firestoreService,
              dormBuildingMap: _dormBuildingMap,
              selectedFloor: _selectedFloor,
              selectedCategory: _selectedCategory,
            ),
          ),
        ],
      ),
    );
  }
}

String? _floorFromReport(FacilityReportModel report, Map<String, String> dormBuildingMap) {
  final building = (report.dormBuilding?.isNotEmpty == true)
      ? report.dormBuilding!
      : (dormBuildingMap[report.userId] ?? '');
  final room = int.tryParse(report.roomNumber) ?? 0;
  if (room == 0 || building.isEmpty) return null;

  if (building == '샬롬하우스') {
    final floorNum = room ~/ 100;
    final roomInFloor = room % 100;
    if (roomInFloor >= 1 && roomInFloor <= 20) return '샬롬하우스 A동 $floorNum층';
    if (roomInFloor >= 21 && roomInFloor <= 35) return '샬롬하우스 B동 $floorNum층';
  } else if (building == '국제생활관') {
    if (room >= 101 && room <= 132) return '국제생활관 A동 1층';
    if (room >= 201 && room <= 229) return '국제생활관 A동 2층';
    if (room >= 233 && room <= 260) return '국제생활관 B동 2층';
    if (room >= 301 && room <= 329) return '국제생활관 B동 3층';
  } else if (building == '바롬인성교육관') {
    final floorNum = room ~/ 100;
    return '바롬인성교육관 $floorNum층';
  }
  return null;
}

// ── 신청 목록 ──
class _ReportList extends StatelessWidget {
  final String? status;
  final FirestoreService service;
  final Map<String, String> dormBuildingMap;
  final String? selectedFloor;
  final String? selectedCategory;

  const _ReportList({
    required this.status,
    required this.service,
    required this.dormBuildingMap,
    this.selectedFloor,
    this.selectedCategory,
  });

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
                Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('신청 내역이 없습니다',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600])),
              ],
            ),
          );
        }

        var reports = snapshot.data!.docs
            .map((doc) => FacilityReportModel.fromFirestore(doc))
            .toList()
          ..sort((a, b) => b.reportedAt.compareTo(a.reportedAt));

        if (selectedFloor != null) {
          reports = reports.where((r) => _floorFromReport(r, dormBuildingMap) == selectedFloor).toList();
        }
        if (selectedCategory != null) {
          reports = reports.where((r) => r.category == selectedCategory).toList();
        }

        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('신청 내역이 없습니다',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600])),
              ],
            ),
          );
        }

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
    final effectiveBuilding = report.dormBuilding?.isNotEmpty == true
        ? report.dormBuilding!
        : (dormBuildingMap[report.userId] ?? '');
    final stripeColor = buildingColor(effectiveBuilding);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Stack(
        children: [
          Card(
            margin: EdgeInsets.zero,
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
                padding: const EdgeInsets.fromLTRB(21, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: color),
                          ),
                          child: Text(
                            _statusText(report.status),
                            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.category, size: 15, color: Colors.grey[600]),
                        Text(report.getCategoryDisplayName(),
                            style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                        const SizedBox(width: 16),
                        Text(
                          DateFormat('yyyy-MM-dd HH:mm').format(report.reportedAt),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.apartment, size: 15, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            [
                              effectiveBuilding,
                              if (report.building?.isNotEmpty == true) report.building!,
                              _roomLabel(report.roomNumber, effectiveBuilding),
                              if (report.seatNumber?.isNotEmpty == true) report.seatNumber!,
                            ].join(' '),
                            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.person, size: 15, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(report.userName,
                            style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      report.description,
                      style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (report.technicianNote != null && report.technicianNote!.isNotEmpty) ...[
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
                            Icon(Icons.note_alt, size: 14, color: Colors.blue.shade600),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                report.technicianNote!,
                                style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (media != null && media.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 72,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: media.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
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
          ),
          // 왼쪽 건물 색상 스트라이프
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 5,
              decoration: BoxDecoration(
                color: stripeColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
          ),
        ],
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
  final _noteFocus = FocusNode();
  final _scrollCtrl = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.report.status;
    _noteCtrl.text = widget.report.technicianNote ?? '';
    _noteFocus.addListener(_onNoteFocusChange);
  }

  void _onNoteFocusChange() {
    if (_noteFocus.hasFocus) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _noteFocus.removeListener(_onNoteFocusChange);
    _noteFocus.dispose();
    _noteCtrl.dispose();
    _scrollCtrl.dispose();
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

      if (_selectedStatus == 'in_progress' || _selectedStatus == 'completed') {
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
          const SnackBar(content: Text('상태가 업데이트되었습니다'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e'), backgroundColor: Colors.red),
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
      builder: (_, __) => Container(
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
                controller: _scrollCtrl,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: color, width: 1.5),
                          ),
                          child: Text(
                            _statusText(report.status),
                            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _detailRow(Icons.category, '신청 유형', report.getCategoryDisplayName()),
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
                        Expanded(child: _detailRow(Icons.door_front_door, '호실', _roomLabel(report.roomNumber, report.dormBuilding?.isNotEmpty == true ? report.dormBuilding! : (widget.dormBuildingMap[report.userId] ?? '')))),
                        if (report.seatNumber != null && report.seatNumber!.isNotEmpty)
                          Expanded(child: _detailRow(Icons.chair, '자리번호', report.seatNumber!)),
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
                        DateFormat('yyyy-MM-dd HH:mm').format(report.completedAt!),
                      ),
                    ],
                    if (report.processedByName != null) ...[
                      const SizedBox(height: 12),
                      _detailRow(Icons.admin_panel_settings, '처리자', report.processedByName!),
                    ],

                    const Divider(height: 32),

                    const Text('상세 설명', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(report.description, style: const TextStyle(fontSize: 15, height: 1.5)),

                    if (report.mediaUrls != null && report.mediaUrls!.isNotEmpty) ...[
                      const Divider(height: 32),
                      const Text('첨부 파일', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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

                    const Text('처리 상태', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'pending', label: Text('대기중'), icon: Icon(Icons.pending, size: 16)),
                        ButtonSegment(value: 'in_progress', label: Text('처리중'), icon: Icon(Icons.build, size: 16)),
                        ButtonSegment(value: 'completed', label: Text('완료됨'), icon: Icon(Icons.check_circle, size: 16)),
                      ],
                      selected: {_selectedStatus},
                      onSelectionChanged: (s) => setState(() => _selectedStatus = s.first),
                    ),

                    const SizedBox(height: 24),

                    const Text('관리자 메모', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteCtrl,
                      focusNode: _noteFocus,
                      decoration: const InputDecoration(
                        hintText: '처리 내용이나 특이사항을 입력하세요',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                      scrollPadding: const EdgeInsets.only(bottom: 120),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updateStatus,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('저장', style: TextStyle(fontSize: 16)),
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
          child: Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

// ── 미디어 전체화면 뷰어 ──
class _MediaViewerDialog extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const _MediaViewerDialog({required this.urls, required this.initialIndex});

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
            return InteractiveViewer(
              child: Center(
                child: Image.network(
                  widget.urls[i],
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const Center(child: CircularProgressIndicator(color: Colors.white)),
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image, color: Colors.white54, size: 64),
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
            const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 28)),
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
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
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
                  const Icon(Icons.play_circle_fill, color: Colors.white70, size: 64),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final String? value;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Theme.of(context).primaryColor : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}