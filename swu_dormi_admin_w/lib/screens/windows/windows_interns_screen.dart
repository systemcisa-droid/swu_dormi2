import 'package:fluent_ui/fluent_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:swu_dormi_admin/models/user_model.dart';
import 'package:swu_dormi_admin/constants/floor_captain_accounts.dart';
import 'package:swu_dormi_admin/data/checklist_data.dart';
import 'package:intl/intl.dart';
import 'package:swu_dormi_admin/screens/windows/windows_intern_notices_screen.dart';

/// 인턴 관리와 인턴 공지사항을 "관리 / 공지사항" 2탭으로 보여주는 화면.
/// 단위실 청소점검(WindowsInspectionTabScreen)과 동일한 구조로 사이드바 메뉴를 통합할 때 사용한다.
class WindowsInternManagementTabScreen extends StatefulWidget {
  const WindowsInternManagementTabScreen({super.key});

  @override
  State<WindowsInternManagementTabScreen> createState() =>
      _WindowsInternManagementTabScreenState();
}

class _WindowsInternManagementTabScreenState
    extends State<WindowsInternManagementTabScreen> {
  // 0: 관리, 1: 공지사항
  int _tabIndex = 0;

  final _accentColor = Colors.teal;

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
                _buildTab(0, '인턴 관리', FluentIcons.education),
                const SizedBox(width: 8),
                _buildTab(1, '인턴 공지사항', FluentIcons.megaphone),
              ],
            ),
          ),
          // 탭 콘텐츠
          Expanded(
            child: _tabIndex == 1
                ? const WindowsInternNoticesScreen()
                : const WindowsInternsScreen(),
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

class WindowsInternsScreen extends StatefulWidget {
  const WindowsInternsScreen({super.key});

  @override
  State<WindowsInternsScreen> createState() => _WindowsInternsScreenState();
}

class _WindowsInternsScreenState extends State<WindowsInternsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _dateFormat = DateFormat('yyyy.MM.dd');

  List<UserModel> _allInterns = [];
  UserModel? _selectedIntern;
  bool _isLoading = true;
  int _selectedTab = 0; // 0: 인턴정보, 1: 관내점검표, 2: 인턴근무일지

  @override
  void initState() {
    super.initState();
    _loadInterns();
  }

  Future<void> _loadInterns() async {
    setState(() => _isLoading = true);
    try {
      final snap = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin_m')
          .get();
      final interns = snap.docs
          .map((d) => UserModel.fromFirestore(d))
          .toList();
      interns.sort((a, b) => a.email.compareTo(b.email));
      setState(() {
        _allInterns = interns;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: const Text('인턴 관리'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.refresh),
              label: const Text('새로고침'),
              onPressed: _loadInterns,
            ),
          ],
        ),
      ),
      content: _isLoading
          ? const Center(child: ProgressRing())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 좌측 목록 ──
        Expanded(
          flex: 5,
          child: _buildTable(_allInterns),
        ),
        // ── 우측 상세 패널 ──
        if (_selectedIntern != null) ...[
          const SizedBox(width: 1),
          Container(width: 1, color: Colors.grey.withValues(alpha: 0.3)),
          Expanded(
            flex: 4,
            child: _buildRightPanel(_selectedIntern!),
          ),
        ],
      ],
    );
  }

  Widget _buildTable(List<UserModel> interns) {
    if (interns.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FluentIcons.people, size: 48, color: Colors.grey[60]),
            const SizedBox(height: 12),
            Text('인턴이 없습니다',
                style: TextStyle(color: Colors.grey[60], fontSize: 16)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.06),
            border: Border(
              bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
          ),
          child: Row(
            children: [
              _headerCell('이름', flex: 2),
              _headerCell('이메일 (아이디)', flex: 2),
              _headerCell('담당 점검 구역', flex: 2),
            ],
          ),
        ),
        // 행 목록
        Expanded(
          child: ListView.builder(
            itemCount: interns.length,
            itemBuilder: (context, i) => _buildRow(interns[i]),
          ),
        ),
        // 하단 카운트
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Text(
                '총 ${interns.length}명',
                style: TextStyle(fontSize: 12, color: Colors.grey[80]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _headerCell(String text, {int flex = 1}) => Expanded(
        flex: flex,
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );

  Widget _buildRow(UserModel intern) {
    final isSelected = _selectedIntern?.uid == intern.uid;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedIntern = intern;
        _selectedTab = 0;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withValues(alpha: 0.08)
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
            left: isSelected
                ? BorderSide(color: Colors.blue, width: 3)
                : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(intern.name,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            Expanded(
              flex: 2,
              child: Text(intern.email,
                  style: TextStyle(fontSize: 13, color: Colors.grey[120])),
            ),
            Expanded(
              flex: 2,
              child: Text(
                kFloorCaptainAccounts[intern.email] ?? '-',
                style: TextStyle(fontSize: 13, color: Colors.grey[120]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 우측 패널: 탭(인턴정보 / 관내점검표 / 인턴근무일지) ──
  Widget _buildRightPanel(UserModel intern) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 탭 바
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
            ),
          ),
          child: Row(
            children: [
              _tabButton('인턴 정보', 0),
              _tabButton('관내점검표', 1),
              _tabButton('인턴근무일지', 2),
              const Spacer(),
              IconButton(
                icon: Icon(FluentIcons.chrome_close,
                    size: 14, color: Colors.grey[80]),
                onPressed: () => setState(() => _selectedIntern = null),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        // 탭 콘텐츠
        Expanded(
          child: _selectedTab == 0
              ? _buildDetailPanel(intern)
              : _selectedTab == 1
                  ? _ChecklistTab(uid: intern.uid, internName: intern.name)
                  : _InternLogTab(uid: intern.uid, internName: intern.name),
        ),
      ],
    );
  }

  Widget _tabButton(String label, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: isSelected
                ? BorderSide(color: Colors.blue, width: 2)
                : BorderSide.none,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Colors.blue : Colors.grey[120],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailPanel(UserModel intern) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 28, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    intern.name.isNotEmpty ? intern.name[0] : '?',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(intern.name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(intern.email,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[120])),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(FluentIcons.edit, size: 16),
                onPressed: () => _showEditDialog(intern),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          // 기본 정보
          _sectionTitle('기본 정보'),
          _infoRow('이름', intern.name),
          _infoRow('학번', intern.studentId),
          _infoRow('전화번호', intern.phoneNumber),
          _infoRow('학과', intern.department ?? '-'),
          const SizedBox(height: 16),
          _sectionTitle('근무 정보'),
          _infoRow('담당 점검 구역', kFloorCaptainAccounts[intern.email] ?? '-'),
          _infoRow('호실', intern.roomNumber == '000' ? '-' : intern.roomNumber),
          _infoRow('자리번호', intern.seatNumber ?? '-'),
          const SizedBox(height: 16),
          _sectionTitle('기타'),
          _infoRow('가입일', _dateFormat.format(intern.createdAt)),
          if (intern.nickname != null && intern.nickname!.isNotEmpty)
            _infoRow('별명', intern.nickname!),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[100]),
        ),
      );

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(label,
                  style: TextStyle(fontSize: 13, color: Colors.grey[100])),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );

  Future<void> _showEditDialog(UserModel intern) async {
    final nameCtrl = TextEditingController(text: intern.name);
    final phoneCtrl = TextEditingController(text: intern.phoneNumber);
    final roomCtrl = TextEditingController(
        text: intern.roomNumber == '000' ? '' : intern.roomNumber);
    final seatCtrl = TextEditingController(text: intern.seatNumber ?? '');
    final deptCtrl = TextEditingController(text: intern.department ?? '');
    String? selectedBuilding = intern.dormBuilding;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => ContentDialog(
          title: const Text('인턴 정보 수정'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('이름',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextBox(controller: nameCtrl, placeholder: '이름'),
                  const SizedBox(height: 12),
                  const Text('전화번호',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextBox(
                      controller: phoneCtrl,
                      placeholder: '010-0000-0000'),
                  const SizedBox(height: 12),
                  const Text('담당 기숙사',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  ComboBox<String>(
                    value: selectedBuilding,
                    placeholder: const Text('선택'),
                    items: const [
                      ComboBoxItem(
                          value: '샬롬하우스', child: Text('샬롬하우스')),
                      ComboBoxItem(
                          value: '국제생활관', child: Text('국제생활관')),
                      ComboBoxItem(
                          value: '바롬인성교육관',
                          child: Text('바롬인성교육관')),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => selectedBuilding = v),
                  ),
                  const SizedBox(height: 12),
                  const Text('호실',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextBox(controller: roomCtrl, placeholder: '예: 301'),
                  const SizedBox(height: 12),
                  const Text('자리번호',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextBox(
                      controller: seatCtrl, placeholder: '자리번호'),
                  const SizedBox(height: 12),
                  const Text('학과',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextBox(controller: deptCtrl, placeholder: '학과명'),
                ],
              ),
            ),
          ),
          actions: [
            Button(
              child: const Text('취소'),
              onPressed: () => Navigator.pop(ctx, false),
            ),
            FilledButton(
              child: const Text('저장'),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;

    try {
      await _firestore.collection('users').doc(intern.uid).update({
        'name': nameCtrl.text.trim(),
        'phoneNumber': phoneCtrl.text.trim(),
        'dormBuilding': selectedBuilding,
        'roomNumber': roomCtrl.text.trim().isEmpty
            ? '000'
            : roomCtrl.text.trim(),
        'seatNumber': seatCtrl.text.trim().isEmpty
            ? null
            : seatCtrl.text.trim(),
        'department': deptCtrl.text.trim().isEmpty
            ? null
            : deptCtrl.text.trim(),
      });
      await _loadInterns();
      final updated = _allInterns.firstWhere(
        (u) => u.uid == intern.uid,
        orElse: () => intern,
      );
      setState(() => _selectedIntern = updated);
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('수정되었습니다'),
            severity: InfoBarSeverity.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: Text('오류: $e'),
            severity: InfoBarSeverity.error,
          ),
        );
      }
    }
  }
}

// ── 관내점검표 탭 ──
class _ChecklistTab extends StatefulWidget {
  final String uid;
  final String internName;
  const _ChecklistTab({required this.uid, required this.internName});

  @override
  State<_ChecklistTab> createState() => _ChecklistTabState();
}

class _ChecklistTabState extends State<_ChecklistTab> {
  final _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _submissions = [];
  bool _isLoading = true;
  final _df = DateFormat('yyyy.MM.dd HH:mm');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_ChecklistTab old) {
    super.didUpdateWidget(old);
    if (old.uid != widget.uid) _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final snap = await _firestore
          .collection('checklist_submissions')
          .where('uid', isEqualTo: widget.uid)
          .get();
      final docs = snap.docs.map((d) {
        final data = d.data();
        data['_id'] = d.id;
        return data;
      }).toList();
      docs.sort((a, b) {
        final aT =
            (a['submittedAt'] as Timestamp?)?.toDate() ?? DateTime(0);
        final bT =
            (b['submittedAt'] as Timestamp?)?.toDate() ?? DateTime(0);
        return bT.compareTo(aT);
      });
      if (mounted) setState(() { _submissions = docs; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _templateLabel(String? id) {
    switch (id) {
      case 'shalom_floor': return '샬롬 각층';
      case 'guksaeng_floor': return '국생 모든층';
      case 'guksaeng_saenghoei': return '국생 사생회';
      default: return '샬롬 지하';
    }
  }

  Color _badgeColor(String? id) {
    switch (id) {
      case 'shalom_floor': return Colors.blue;
      case 'guksaeng_floor': return Colors.orange;
      case 'guksaeng_saenghoei': return Colors.purple;
      default: return Colors.green;
    }
  }

  int _checkedCount(Map<String, dynamic> data) {
    final checks = data['checks'] as Map<String, dynamic>?;
    if (checks == null) return 0;
    return checks.values.where((v) => v == true).length;
  }

  int _totalItems(String? typeId) {
    final template = kChecklistTemplates.firstWhere(
      (t) => t.id == typeId,
      orElse: () => kChecklistShalomB1,
    );
    int count = 0;
    for (final loc in template.locations) {
      for (final sub in loc.subjects) { count += sub.items.length; }
    }
    return count;
  }

  void _showDetail(BuildContext context, Map<String, dynamic> data) {
    final typeId = data['checklistType'] as String?;
    final checks = data['checks'] as Map<String, dynamic>? ?? {};
    final remarks = data['remarks'] as Map<String, dynamic>? ?? {};
    final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();

    final template = kChecklistTemplates.firstWhere(
      (t) => t.id == typeId,
      orElse: () => kChecklistShalomB1,
    );

    String checkKey(int no, int si, int ii) => '${no}_${si}_$ii';
    String remarkKey(int no, int si) => '${no}_$si';

    showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 700),
        title: Row(
          children: [
            Expanded(
              child: Text(template.title,
                  style: const TextStyle(fontSize: 16)),
            ),
            if (submittedAt != null)
              Text(
                DateFormat('yyyy.MM.dd HH:mm').format(submittedAt),
                style: TextStyle(fontSize: 12, color: Colors.grey[100],
                    fontWeight: FontWeight.normal),
              ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: template.locations.map((loc) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 구역 헤더
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.08),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                        border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.8),
                              shape: BoxShape.circle,
                            ),
                            child: Text('${loc.no}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              loc.location.replaceAll('\n', ' '),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 과목별 항목
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.2)),
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(6)),
                      ),
                      child: Column(
                        children: loc.subjects.asMap().entries.map((se) {
                          final si = se.key;
                          final sub = se.value;
                          final rKey = remarkKey(loc.no, si);
                          final remark = remarks[rKey] as String?;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (si > 0)
                                Padding(
                                  padding: EdgeInsets.zero,
                                  child: Divider(
                                      style: DividerThemeData(
                                          horizontalMargin: EdgeInsets.zero)),
                                ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    12, 8, 12, 2),
                                child: Text(sub.name.replaceAll('\n', ' '),
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue.withValues(
                                            alpha: 0.8))),
                              ),
                              ...sub.items.asMap().entries.map((ie) {
                                final ii = ie.key;
                                final item = ie.value;
                                final cKey = checkKey(loc.no, si, ii);
                                final checked = checks[cKey] == true;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 3),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        checked
                                            ? FluentIcons.check_mark
                                            : FluentIcons.checkbox_composite,
                                        size: 14,
                                        color: checked
                                            ? Colors.green
                                            : Colors.grey[60],
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          item.content,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: checked
                                                ? Colors.grey[100]
                                                : Colors.grey[160],
                                            decoration: checked
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              if (remark != null && remark.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      12, 4, 12, 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.yellow
                                          .withValues(alpha: 0.08),
                                      borderRadius:
                                          BorderRadius.circular(4),
                                      border: Border.all(
                                          color: Colors.yellow
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('비고  ',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey[120])),
                                        Expanded(
                                          child: Text(remark,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[160])),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(height: 6),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          FilledButton(
            child: const Text('닫기'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: ProgressRing());
    }
    return Column(
      children: [
        // 요약 바
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.grey.withValues(alpha: 0.05),
          child: Row(
            children: [
              const Icon(FluentIcons.checkbox_composite, size: 16),
              const SizedBox(width: 8),
              Text(
                widget.internName.isNotEmpty
                    ? '작성자: ${widget.internName} (총 ${_submissions.length}건)'
                    : '총 ${_submissions.length}건',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Button(
                onPressed: _load,
                child: const Row(
                  children: [
                    Icon(FluentIcons.refresh, size: 14),
                    SizedBox(width: 4),
                    Text('새로고침', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_submissions.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(FluentIcons.checkbox_composite,
                      size: 48, color: Colors.grey[60]),
                  const SizedBox(height: 12),
                  Text('작성된 점검표가 없습니다',
                      style: TextStyle(color: Colors.grey[80])),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _submissions.length,
              separatorBuilder: (context, i2) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _buildCard(_submissions[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildCard(Map<String, dynamic> data) {
    final submittedAt =
        (data['submittedAt'] as Timestamp?)?.toDate();
    final typeId = data['checklistType'] as String?;
    final checked = _checkedCount(data);
    final total = _totalItems(typeId);
    final progress = total > 0 ? (checked / total).clamp(0.0, 1.0) : 0.0;
    final color = _badgeColor(typeId);

    return GestureDetector(
      onTap: () => _showDetail(context, data),
      child: Card(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _templateLabel(typeId),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                submittedAt != null ? _df.format(submittedAt) : '-',
                style:
                    TextStyle(fontSize: 12, color: Colors.grey[100]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ProgressBar(
                  value: (progress * 100).clamp(0.0, 100.0),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$checked / $total',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: progress >= 1.0 ? Colors.green : Colors.grey[120],
                ),
              ),
            ],
          ),
          if (progress >= 1.0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(FluentIcons.check_mark, size: 12,
                    color: Colors.green),
                const SizedBox(width: 4),
                Text('점검 완료',
                    style: TextStyle(fontSize: 11, color: Colors.green)),
              ],
            ),
          ],
        ],
      ),
    ));
  }
}

// ── 인턴근무일지 탭 ──
class _InternLogTab extends StatefulWidget {
  final String uid;
  final String internName;
  const _InternLogTab({required this.uid, required this.internName});

  @override
  State<_InternLogTab> createState() => _InternLogTabState();
}

class _InternLogTabState extends State<_InternLogTab> {
  final _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  final _df = DateFormat('yyyy.MM.dd (E)', 'ko');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_InternLogTab old) {
    super.didUpdateWidget(old);
    if (old.uid != widget.uid) _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final snap = await _firestore
          .collection('intern_logs')
          .where('uid', isEqualTo: widget.uid)
          .get();
      final docs = snap.docs.map((d) {
        final data = d.data();
        data['_id'] = d.id;
        return data;
      }).toList();
      docs.sort((a, b) {
        final aT =
            (a['workDate'] as Timestamp?)?.toDate() ?? DateTime(0);
        final bT =
            (b['workDate'] as Timestamp?)?.toDate() ?? DateTime(0);
        return bT.compareTo(aT);
      });
      if (mounted) setState(() { _logs = docs; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _totalHours {
    double total = 0;
    for (final log in _logs) {
      total += (log['workHours'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: ProgressRing());
    }
    return Column(
      children: [
        // 요약 바
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFFB44F4F).withValues(alpha: 0.06),
          child: Row(
            children: [
              const Icon(FluentIcons.timer, size: 16,
                  color: Color(0xFFB44F4F)),
              const SizedBox(width: 8),
              Text(
                widget.internName.isNotEmpty
                    ? '작성자: ${widget.internName} (총 ${_logs.length}건)'
                    : '총 ${_logs.length}건',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '누적 ${_totalHours.toStringAsFixed(1)}시간',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFFB44F4F),
                ),
              ),
              const SizedBox(width: 12),
              Button(
                onPressed: _load,
                child: const Row(
                  children: [
                    Icon(FluentIcons.refresh, size: 14),
                    SizedBox(width: 4),
                    Text('새로고침', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_logs.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(FluentIcons.timer, size: 48, color: Colors.grey[60]),
                  const SizedBox(height: 12),
                  Text('작성된 근무일지가 없습니다',
                      style: TextStyle(color: Colors.grey[80])),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _logs.length,
              separatorBuilder: (context, i2) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _buildCard(_logs[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildCard(Map<String, dynamic> log) {
    final workDate =
        (log['workDate'] as Timestamp?)?.toDate();
    final startTime = log['startTime'] as String?;
    final endTime = log['endTime'] as String?;
    final workHours =
        (log['workHours'] as num?)?.toDouble();
    final accHours =
        (log['accumulatedHours'] as num?)?.toDouble();
    final workTypes = log['workTypes'] is List
        ? (log['workTypes'] as List).map((e) => e as String).toList()
        : <String>[];

    return Card(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFB44F4F).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  workDate != null ? _df.format(workDate) : '-',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Color(0xFFB44F4F),
                  ),
                ),
              ),
              const Spacer(),
              if (workHours != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${workHours.toStringAsFixed(1)}시간',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
            ],
          ),
          if (startTime != null && endTime != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(FluentIcons.clock, size: 12, color: Colors.grey[80]),
                const SizedBox(width: 4),
                Text(
                  '$startTime ~ $endTime',
                  style: TextStyle(fontSize: 12, color: Colors.grey[100]),
                ),
              ],
            ),
          ],
          if (workTypes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: workTypes
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.teal.withValues(alpha: 0.3)),
                        ),
                        child: Text(t,
                            style: TextStyle(
                                fontSize: 11, color: Colors.teal)),
                      ))
                  .toList(),
            ),
          ],
          if (accHours != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(FluentIcons.timer, size: 12, color: Colors.grey[80]),
                const SizedBox(width: 4),
                Text(
                  '누적 ${accHours.toStringAsFixed(1)}시간',
                  style: TextStyle(fontSize: 12, color: Colors.grey[100]),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
