import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:excel/excel.dart' hide Border;

class HomeScreen extends StatefulWidget {
  final String? assignedFloor;
  final String? userName;
  final int totalUnreadMessages;
  final int totalMessages;
  final void Function(int index) onNavigate;

  const HomeScreen({
    super.key,
    this.assignedFloor,
    this.userName,
    this.totalUnreadMessages = 0,
    this.totalMessages = 0,
    required this.onNavigate,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _studentCount = 0;
  int _unregisteredCount = 0;
  int _pendingMonthlyCount = 0;
  int _totalMonthlyCount = 0;
  int _pendingMoveOutCount = 0;
  int _totalMoveOutCount = 0;
  int _activeAttendanceCount = 0;
  int _totalAttendanceCount = 0;
  int _pendingFacilityCount = 0;
  int _totalFacilityCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final floor = userDoc.data()?['assignedFloor'] as String?;

      // 담당 층 학생 수 + 미가입 수 동시 계산 (쿼리 1회)
      int studentCount = 0;
      int unregisteredCount = 0;
      if (floor != null) {
        final result = await _getStudentAndUnregisteredCount(floor);
        studentCount = result['student'] ?? 0;
        unregisteredCount = result['unregistered'] ?? 0;
      }

      final futures = await Future.wait([
        // 0: 월청소 전체
        floor != null
            ? FirebaseFirestore.instance
                .collection('cleaning_schedules')
                .where('inspectionType', isEqualTo: 'monthly')
                .where('floor', isEqualTo: floor)
                .get()
            : Future.value(null),
        // 1: 월청소 대기중
        floor != null
            ? FirebaseFirestore.instance
                .collection('cleaning_schedules')
                .where('inspectionType', isEqualTo: 'monthly')
                .where('floor', isEqualTo: floor)
                .where('status', isEqualTo: 'pending')
                .get()
            : Future.value(null),
        // 2: 퇴사청소 전체
        floor != null
            ? FirebaseFirestore.instance
                .collection('cleaning_schedules')
                .where('inspectionType', isEqualTo: 'move_out')
                .where('floor', isEqualTo: floor)
                .get()
            : Future.value(null),
        // 3: 퇴사청소 대기중
        floor != null
            ? FirebaseFirestore.instance
                .collection('cleaning_schedules')
                .where('inspectionType', isEqualTo: 'move_out')
                .where('floor', isEqualTo: floor)
                .where('status', isEqualTo: 'pending')
                .get()
            : Future.value(null),
        // 4: 출석체크 진행중
        floor != null
            ? FirebaseFirestore.instance
                .collection('attendance_events')
                .where('floor', isEqualTo: floor)
                .where('status', isEqualTo: 'active')
                .get()
            : Future.value(null),
        // 5: 출석체크 전체
        floor != null
            ? FirebaseFirestore.instance
                .collection('attendance_events')
                .where('floor', isEqualTo: floor)
                .get()
            : Future.value(null),
        // 6: 시설 신고 (pending/total 함께)
        floor != null
            ? _getFacilityCountForFloor(floor)
            : Future.value(<String, int>{'total': 0, 'pending': 0}),
      ]);

      if (mounted) {
        setState(() {
          _studentCount = studentCount;
          _unregisteredCount = unregisteredCount;
          _totalMonthlyCount = (futures[0] as QuerySnapshot?)?.docs.length ?? 0;
          _pendingMonthlyCount = (futures[1] as QuerySnapshot?)?.docs.length ?? 0;
          _totalMoveOutCount = (futures[2] as QuerySnapshot?)?.docs.length ?? 0;
          _pendingMoveOutCount = (futures[3] as QuerySnapshot?)?.docs.length ?? 0;
          _activeAttendanceCount = (futures[4] as QuerySnapshot?)?.docs.length ?? 0;
          _totalAttendanceCount = (futures[5] as QuerySnapshot?)?.docs.length ?? 0;
          final facilityResult = futures[6] as Map<String, int>? ?? {};
          _pendingFacilityCount = facilityResult['pending'] ?? 0;
          _totalFacilityCount = facilityResult['total'] ?? 0;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Map<String, int>> _getFacilityCountForFloor(String assignedFloor) async {
    const empty = {'total': 0, 'pending': 0};
    try {
      final wingMatch = RegExp(r'[A-Z]동').firstMatch(assignedFloor);
      final floorMatch = RegExp(r'(\d+)층').firstMatch(assignedFloor);
      String dormBuilding;
      if (assignedFloor.startsWith('샬롬하우스(겨울방학)')) {
        dormBuilding = '샬롬하우스(겨울방학)';
      } else if (assignedFloor.startsWith('샬롬하우스')) {
        dormBuilding = '샬롬하우스';
      } else if (assignedFloor.startsWith('국제생활관')) {
        dormBuilding = '국제생활관';
      } else if (assignedFloor.startsWith('바롬인성교육관')) {
        dormBuilding = '바롬인성교육관';
      } else {
        return empty;
      }
      final building = wingMatch?.group(0) ?? '';
      final floorNum = floorMatch != null ? int.tryParse(floorMatch.group(1)!) ?? 0 : 0;
      if (building.isEmpty || floorNum == 0) return empty;

      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('dormBuilding', isEqualTo: dormBuilding)
          .where('building', isEqualTo: building)
          .get();

      final floorUids = <String>{};
      for (final doc in usersSnap.docs) {
        final room = doc.data()['roomNumber'] as String? ?? '';
        if ((int.tryParse(room) ?? 0) ~/ 100 == floorNum) {
          floorUids.add(doc.id);
        }
      }
      if (floorUids.isEmpty) return empty;

      final reportsSnap = await FirebaseFirestore.instance
          .collection('facility_reports')
          .get();

      int total = 0;
      int pending = 0;
      for (final doc in reportsSnap.docs) {
        final data = doc.data();
        final uid = data['userId'] as String? ?? '';
        if (!floorUids.contains(uid)) continue;
        total++;
        if ((data['status'] as String? ?? '') == 'pending') pending++;
      }
      return {'total': total, 'pending': pending};
    } catch (_) {
      return empty;
    }
  }

  // 재실중 학생 수(student)와 앱 미가입 수(unregistered)를 동시 계산
  // 미가입 = 엑셀 배정명단에 있으나 users 컬렉션에 이메일이 없는 학생 (윈도우 관리프로그램과 동일 로직)
  Future<Map<String, int>> _getStudentAndUnregisteredCount(String assignedFloor) async {
    const empty = {'student': 0, 'unregistered': 0};
    try {
      final wingMatch = RegExp(r'[A-Z]동').firstMatch(assignedFloor);
      final floorMatch = RegExp(r'(\d+)층').firstMatch(assignedFloor);
      String dormBuilding;
      if (assignedFloor.startsWith('샬롬하우스(겨울방학)')) {
        dormBuilding = '샬롬하우스(겨울방학)';
      } else if (assignedFloor.startsWith('샬롬하우스')) {
        dormBuilding = '샬롬하우스';
      } else if (assignedFloor.startsWith('국제생활관')) {
        dormBuilding = '국제생활관';
      } else if (assignedFloor.startsWith('바롬인성교육관')) {
        dormBuilding = '바롬인성교육관';
      } else {
        return empty;
      }
      final building = wingMatch?.group(0) ?? '';
      final floorNum = floorMatch != null ? int.tryParse(floorMatch.group(1)!) ?? 0 : 0;
      if (building.isEmpty || floorNum == 0) return empty;

      // 1. 재실중 학생 수 계산 (users 컬렉션)
      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('dormBuilding', isEqualTo: dormBuilding)
          .where('building', isEqualTo: building)
          .get();

      int student = 0;
      final registeredEmails = <String>{};
      for (final doc in usersSnap.docs) {
        final data = doc.data();
        if ((data['role'] as String? ?? '') != 'student') continue;
        final room = data['roomNumber'] as String? ?? '';
        if ((int.tryParse(room) ?? 0) ~/ 100 != floorNum) continue;
        final residentStatus = data['residentStatus'] as String? ?? '재실중';
        if (residentStatus != '재실중') continue;
        student++;
        final email = (data['email'] as String? ?? '').trim().toLowerCase();
        if (email.isNotEmpty) registeredEmails.add(email);
      }

      // 2. 엑셀 배정명단에서 해당 층 미가입자 수 계산 (윈도우 관리프로그램과 동일)
      int unregistered = 0;
      try {
        final settingsDoc = await FirebaseFirestore.instance
            .collection('settings')
            .doc('home')
            .get();
        final excelUrl = settingsDoc.data()?['studentInfoExcelUrl'] as String?;
        if (excelUrl != null && excelUrl.trim().isNotEmpty) {
          final response = await http.get(Uri.parse(excelUrl));
          if (response.statusCode == 200) {
            final excel = Excel.decodeBytes(response.bodyBytes);
            final sheet = excel.sheets.values.first;
            final rows = sheet.rows
                .map((r) => r.map((c) => c?.value?.toString() ?? '').toList())
                .toList();
            if (rows.length > 1) {
              final header = rows.first;
              // 헤더에서 이메일·기숙사·호실 컬럼 인덱스 찾기
              final norm = header
                  .map((h) => h.replaceAll(RegExp(r'\s+'), '').toLowerCase())
                  .toList();
              int findCol(List<String> keywords, {List<String> exclude = const []}) {
                for (int i = 0; i < norm.length; i++) {
                  if (exclude.any((e) => norm[i].contains(e))) continue;
                  if (keywords.any((k) => norm[i].contains(k))) return i;
                }
                return -1;
              }
              final emailIdx = findCol(['이메일', 'email']);
              final dormIdx = findCol(['기숙사', '건물']);
              final roomIdx = findCol(['호실'], exclude: ['인실']);

              for (final row in rows.skip(1)) {
                String cell(int idx) =>
                    (idx >= 0 && idx < row.length) ? row[idx].trim() : '';

                // 해당 기숙사 + 해당 층 필터
                final rowDorm = cell(dormIdx);
                final rowRoom = cell(roomIdx);
                if (!rowDorm.contains(dormBuilding)) continue;
                if ((int.tryParse(rowRoom) ?? 0) ~/ 100 != floorNum) continue;

                // 이메일이 가입자 목록에 없으면 미가입
                final rowEmail = cell(emailIdx).toLowerCase();
                if (rowEmail.isEmpty) {
                  unregistered++;
                } else if (!registeredEmails.contains(rowEmail)) {
                  unregistered++;
                }
              }
            }
          }
        }
      } catch (_) {
        // 엑셀 로드 실패 시 미가입 수는 0으로 유지
      }

      return {'student': student, 'unregistered': unregistered};
    } catch (_) {
      return empty;
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy년 M월 d일 (E)', 'ko').format(now);
    final name = widget.userName ?? '관리자';
    final floor = widget.assignedFloor ?? '';

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGreetingCard(name, floor, dateStr),
                const SizedBox(height: 16),
                _buildStatGrid(),
                const SizedBox(height: 20),
                const Text(
                  '공지사항',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          Expanded(child: _buildNoticeList()),
        ],
      ),
    );
  }

  Widget _buildGreetingCard(String name, String floor, String dateStr) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB44F4F), Color(0xFF8B3030)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB44F4F).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateStr, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            '$name 님',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          if (floor.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('점검구역: $floor', style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatGrid() {
    return Column(
      children: [
        Row(
          children: [
            _buildStatCard(
              icon: Icons.people,
              label: '총 학생수',
              count: _loading ? null : _studentCount,
              subLabel: '미가입 $_unregisteredCount명',
              color: const Color(0xFF5C8DEF),
            ),
            const SizedBox(width: 8),
            _buildStatCard(
              icon: Icons.build_outlined,
              label: '시설 신고',
              count: _loading ? null : _pendingFacilityCount,
              subLabel: '총 $_totalFacilityCount건',
              color: const Color(0xFFEF5350),
            ),
            const SizedBox(width: 8),
            _buildStatCard(
              icon: Icons.cleaning_services_outlined,
              label: '월청소점검',
              count: _loading ? null : _pendingMonthlyCount,
              subLabel: '총 $_totalMonthlyCount건',
              color: const Color(0xFF26A69A),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildStatCard(
              icon: Icons.cleaning_services,
              label: '퇴사청소점검',
              count: _loading ? null : _pendingMoveOutCount,
              subLabel: '총 $_totalMoveOutCount건',
              color: const Color(0xFF00897B),
            ),
            const SizedBox(width: 8),
            _buildStatCard(
              icon: Icons.qr_code_scanner,
              label: '출석체크',
              count: _loading ? null : _activeAttendanceCount,
              subLabel: '총 $_totalAttendanceCount건',
              color: const Color(0xFF5C6BC0),
            ),
            const SizedBox(width: 8),
            _buildStatCard(
              icon: Icons.chat_bubble_outline,
              label: '메세지',
              count: _loading ? null : widget.totalUnreadMessages,
              subLabel: '총 ${widget.totalMessages}건',
              color: const Color(0xFFEC407A),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required int? count,
    required String subLabel,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  count == null ? '-' : '$count',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(subLabel, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('intern_notices')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('공지사항을 불러오는 중 오류가 발생했습니다.'));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.campaign_outlined, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text('등록된 공지사항이 없습니다.', style: TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          );
        }

        final notices = docs.map((d) => _NoticeItem.fromDoc(d)).toList();
        final pinned = notices.where((n) => n.isPinned).toList();
        final normal = notices.where((n) => !n.isPinned).toList();
        final all = [...pinned, ...normal];

        return ListView.separated(
          itemCount: all.length,
          separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
          itemBuilder: (context, index) {
            final n = all[index];
            return InkWell(
              onTap: () => _showNoticeDetail(context, n),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: n.imageUrls.isNotEmpty
                          ? Image.network(n.imageUrls.first, width: 64, height: 64, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _noticePlaceholder(n.isPinned))
                          : _noticePlaceholder(n.isPinned),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (n.isPinned)
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFB44F4F),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('중요', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          Text(n.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, height: 1.3)),
                          const SizedBox(height: 3),
                          Text(n.content,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 3),
                          Text(
                            '${n.authorName}  |  ${DateFormat('yyyy.MM.dd').format(n.createdAt)}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _noticePlaceholder(bool isPinned) {
    return Container(
      width: 64,
      height: 64,
      color: isPinned ? const Color(0xFFFFEBEB) : const Color(0xFFE3F2FD),
      child: Icon(
        isPinned ? Icons.priority_high : Icons.campaign_outlined,
        size: 28,
        color: isPinned ? const Color(0xFFB44F4F) : Colors.blue.shade300,
      ),
    );
  }

  void _showNoticeDetail(BuildContext context, _NoticeItem n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              if (n.isPinned)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFB44F4F), borderRadius: BorderRadius.circular(4)),
                  child: const Text('중요', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              Text(n.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.3)),
              const SizedBox(height: 8),
              Text(
                '${n.authorName}  |  ${DateFormat('yyyy-MM-dd HH:mm').format(n.createdAt)}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const Divider(height: 28),
              ...n.imageUrls.map((url) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(url, fit: BoxFit.cover, width: double.infinity,
                      errorBuilder: (_, __, ___) => Container(height: 100, color: Colors.grey.shade200)),
                ),
              )),
              Text(n.content, style: const TextStyle(fontSize: 15, height: 1.7)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoticeItem {
  final String title;
  final String content;
  final String authorName;
  final DateTime createdAt;
  final bool isPinned;
  final List<String> imageUrls;

  const _NoticeItem({
    required this.title,
    required this.content,
    required this.authorName,
    required this.createdAt,
    required this.isPinned,
    required this.imageUrls,
  });

  factory _NoticeItem.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    DateTime dt;
    final raw = d['createdAt'];
    if (raw is Timestamp) {
      dt = raw.toDate();
    } else {
      dt = DateTime.now();
    }
    return _NoticeItem(
      title: d['title'] ?? '',
      content: d['content'] ?? '',
      authorName: d['authorName'] ?? '',
      createdAt: dt,
      isPinned: d['isPinned'] ?? false,
      imageUrls: List<String>.from(d['imageUrls'] ?? []),
    );
  }
}
