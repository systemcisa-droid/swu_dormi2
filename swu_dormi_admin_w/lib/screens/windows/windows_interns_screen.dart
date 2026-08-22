import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border, TextSpan;
import 'package:file_picker/file_picker.dart';
import 'package:swu_dormi_admin/models/user_model.dart';
import 'package:swu_dormi_admin/constants/floor_captain_accounts.dart';
import 'package:swu_dormi_admin/data/checklist_data.dart';
import 'package:intl/intl.dart';
import 'package:swu_dormi_admin/screens/windows/windows_intern_notices_screen.dart';
import 'package:swu_dormi_admin/screens/windows/windows_cleaning_inspection_screen.dart' show kFloorOptions;

void _showImagePreview(BuildContext context, String url) {
  showDialog(
    context: context,
    builder: (ctx) => ContentDialog(
      constraints: const BoxConstraints(maxWidth: 800, maxHeight: 800),
      content: InteractiveViewer(
        child: Image.network(
          url,
          errorBuilder: (_, _, _) => const Center(child: Icon(FluentIcons.picture_center, size: 48)),
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
  // 0: 관리, 1: 관내점검표, 2: 공지사항
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
                _buildTab(1, '관내점검표', FluentIcons.checkbox_composite),
                const SizedBox(width: 8),
                _buildTab(2, '인턴 공지사항', FluentIcons.megaphone),
              ],
            ),
          ),
          // 탭 콘텐츠
          Expanded(
            child: _tabIndex == 1
                ? const WindowsAllInternChecklistScreen()
                : _tabIndex == 2
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
    final issues = data['issues'] as Map<String, dynamic>?;
    final checkedCount = checks?.values.where((v) => v == true).length ?? 0;
    final issueCount = issues?.values.where((v) => v == true).length ?? 0;
    return checkedCount + issueCount;
  }

  int _issueCount(Map<String, dynamic> data) {
    final issues = data['issues'] as Map<String, dynamic>?;
    return issues?.values.where((v) => v == true).length ?? 0;
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

  Future<void> _exportChecklistToExcel(
    BuildContext context,
    Map<String, dynamic> data,
    ChecklistTemplate template,
  ) async {
    final checks = data['checks'] as Map<String, dynamic>? ?? {};
    final issues = data['issues'] as Map<String, dynamic>? ?? {};
    final remarks = data['remarks'] as Map<String, dynamic>? ?? {};
    final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();

    String checkKey(int no, int si, int ii) => '${no}_${si}_$ii';
    String remarkKey(int no, int si) => '${no}_$si';

    try {
      final excel = Excel.createExcel();
      final sheet = excel[template.title];

      final headers = ['구역', '항목', '점검내용', '확인여부', '비고'];
      for (int c = 0; c < headers.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).value =
            TextCellValue(headers[c]);
      }

      int rowIdx = 1;
      for (final loc in template.locations) {
        for (final se in loc.subjects.asMap().entries) {
          final si = se.key;
          final sub = se.value;
          final remark = remarks[remarkKey(loc.no, si)] as String? ?? '';
          for (final ie in sub.items.asMap().entries) {
            final ii = ie.key;
            final item = ie.value;
            final cKey = checkKey(loc.no, si, ii);
            final checked = checks[cKey] == true;
            final hasIssue = issues[cKey] == true;
            final values = [
              loc.location.replaceAll('\n', ' '),
              sub.name.replaceAll('\n', ' '),
              item.content,
              hasIssue ? 'X' : (checked ? 'O' : '-'),
              remark,
            ];
            for (int c = 0; c < values.length; c++) {
              sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx)).value =
                  TextCellValue(values[c]);
            }
            rowIdx++;
          }
        }
      }

      if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');

      final bytes = excel.encode();
      if (bytes == null) throw Exception('엑셀 파일 생성 실패');

      final dateLabel = submittedAt != null
          ? DateFormat('yyyyMMdd_HHmm').format(submittedAt)
          : DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: '관내점검표 저장',
        fileName: '관내점검표_${widget.internName}_$dateLabel.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (savePath == null) return;
      await File(savePath).writeAsBytes(bytes);

      if (!context.mounted) return;
      await displayInfoBar(
        context,
        builder: (c, close) => InfoBar(
          title: Text('저장 완료: $savePath'),
          severity: InfoBarSeverity.success,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      await displayInfoBar(
        context,
        builder: (c, close) => InfoBar(
          title: Text('오류: $e'),
          severity: InfoBarSeverity.error,
        ),
      );
    }
  }

  void _showDetail(BuildContext context, Map<String, dynamic> data) {
    final typeId = data['checklistType'] as String?;
    final checks = data['checks'] as Map<String, dynamic>? ?? {};
    final issues = data['issues'] as Map<String, dynamic>? ?? {};
    final remarks = data['remarks'] as Map<String, dynamic>? ?? {};
    final itemImages = data['itemImages'] as Map<String, dynamic>? ?? {};
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
                          final images = (itemImages[rKey] as List?)?.whereType<String>().toList() ?? const <String>[];
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
                                final hasIssue = issues[cKey] == true;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 3),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        hasIssue
                                            ? FluentIcons.chrome_close
                                            : checked
                                                ? FluentIcons.check_mark
                                                : FluentIcons.checkbox_composite,
                                        size: 14,
                                        color: hasIssue
                                            ? Colors.red
                                            : checked
                                                ? Colors.green
                                                : Colors.grey[60],
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          item.content,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: hasIssue
                                                ? Colors.red
                                                : checked
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
                              if (images.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: images.map((url) => GestureDetector(
                                      onTap: () => _showImagePreview(context, url),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.network(
                                          url,
                                          width: 64,
                                          height: 64,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Container(
                                            width: 64,
                                            height: 64,
                                            color: Colors.grey.withValues(alpha: 0.15),
                                            child: Icon(FluentIcons.picture_center, size: 20, color: Colors.grey[100]),
                                          ),
                                        ),
                                      ),
                                    )).toList(),
                                  ),
                                ),
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
          Button(
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.excel_document, size: 14),
                SizedBox(width: 6),
                Text('엑셀 출력'),
              ],
            ),
            onPressed: () => _exportChecklistToExcel(ctx, data, template),
          ),
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
    final issueCount = _issueCount(data);
    final okCount = checked - issueCount;
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Container(height: 6, color: Colors.grey.withValues(alpha: 0.15)),
                      FractionallySizedBox(
                        widthFactor: total > 0 ? (checked / total).clamp(0.0, 1.0) : 0.0,
                        child: Container(
                          height: 6,
                          color: progress >= 1.0 ? Colors.green : color,
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: total > 0 ? (issueCount / total).clamp(0.0, 1.0) : 0.0,
                        child: Container(height: 6, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(text: '$okCount', style: TextStyle(color: Colors.green)),
                    if (issueCount > 0) ...[
                      TextSpan(text: '+', style: TextStyle(color: Colors.grey[120])),
                      TextSpan(text: '$issueCount', style: TextStyle(color: Colors.red)),
                    ],
                    TextSpan(text: ' / $total', style: TextStyle(color: Colors.grey[120])),
                  ],
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

// ── 관내점검표 탭 (전체 인턴이 작성한 점검표를 일자별로 모아보기) ──
class WindowsAllInternChecklistScreen extends StatefulWidget {
  const WindowsAllInternChecklistScreen({super.key});

  @override
  State<WindowsAllInternChecklistScreen> createState() =>
      _WindowsAllInternChecklistScreenState();
}

class _WindowsAllInternChecklistScreenState
    extends State<WindowsAllInternChecklistScreen> {
  final _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _submissions = [];
  // 'yyyy.MM.dd' -> 해당 날짜의 제출 목록
  Map<String, List<Map<String, dynamic>>> _grouped = {};
  List<String> _sortedDates = [];
  String? _selectedDate;
  bool _isLoading = true;
  final _dateKeyFmt = DateFormat('yyyy.MM.dd');
  final _timeFmt = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final snap = await _firestore.collection('checklist_submissions').get();
      final docs = snap.docs.map((d) {
        final data = d.data();
        data['_id'] = d.id;
        return data;
      }).toList();

      // 작성자 이름을 한 번에 조회해 채워 넣는다.
      // 한 명씩 조회하면 작성자 수만큼 왕복이 생기므로 whereIn으로 묶어 읽는다.
      final uids =
          docs.map((d) => d['uid'] as String?).whereType<String>().toSet().toList();
      final nameByUid = <String, String>{};
      for (var i = 0; i < uids.length; i += 30) {
        final chunk = uids.sublist(i, (i + 30).clamp(0, uids.length));
        try {
          final snap = await _firestore
              .collection('users')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          for (final doc in snap.docs) {
            final name = doc.data()['name'] as String?;
            if (name != null && name.isNotEmpty) nameByUid[doc.id] = name;
          }
        } catch (_) {}
      }
      for (final d in docs) {
        d['_writerName'] = nameByUid[d['uid']] ?? '알 수 없음';
      }

      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final d in docs) {
        final submittedAt = (d['submittedAt'] as Timestamp?)?.toDate();
        final key = submittedAt != null ? _dateKeyFmt.format(submittedAt) : '날짜 없음';
        grouped.putIfAbsent(key, () => []).add(d);
      }
      // 날짜별 목록은 점검구역 순서(샬롬 A동 2~7층 → B동 2~7층 → 국생 → 바롬)로 정렬한다.
      for (final list in grouped.values) {
        list.sort((a, b) {
          final ao = _areaOrder(a);
          final bo = _areaOrder(b);
          if (ao != bo) return ao.compareTo(bo);
          final aT = (a['submittedAt'] as Timestamp?)?.toDate() ?? DateTime(0);
          final bT = (b['submittedAt'] as Timestamp?)?.toDate() ?? DateTime(0);
          return aT.compareTo(bT);
        });
      }
      final sortedDates = grouped.keys.toList()
        ..sort((a, b) => b.compareTo(a));

      if (!mounted) return;
      setState(() {
        _submissions = docs;
        _grouped = grouped;
        _sortedDates = sortedDates;
        _selectedDate = sortedDates.isNotEmpty ? sortedDates.first : null;
        _isLoading = false;
      });
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

  /// 점검구역 정렬 순위.
  /// "샬롬 각층"은 저장된 floor 값을 kFloorOptions 순서(샬롬 A동 2~7층 → B동 2~7층
  /// → 국생 → 바롬 10층)로 매핑하고, floor가 없는 템플릿은 템플릿 종류로 순위를 준다.
  int _areaOrder(Map<String, dynamic> data) {
    final floor = data['floor'] as String?;
    if (floor != null && floor.isNotEmpty) {
      final idx = kFloorOptions.indexOf(floor);
      if (idx >= 0) return idx;
      return kFloorOptions.length; // 목록에 없는 구역은 뒤로
    }
    // floor 없는 템플릿: 샬롬 지하 → 국생 모든층 → 국생 사생회 순으로 뒤에 붙인다.
    final base = kFloorOptions.length + 1;
    switch (data['checklistType'] as String?) {
      case 'guksaeng_floor': return base + 1;
      case 'guksaeng_saenghoei': return base + 2;
      default: return base; // shalom_b1 (샬롬 지하)
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
    final issues = data['issues'] as Map<String, dynamic>?;
    final checkedCount = checks?.values.where((v) => v == true).length ?? 0;
    final issueCount = issues?.values.where((v) => v == true).length ?? 0;
    return checkedCount + issueCount;
  }

  int _issueCount(Map<String, dynamic> data) {
    final issues = data['issues'] as Map<String, dynamic>?;
    return issues?.values.where((v) => v == true).length ?? 0;
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: ProgressRing());
    }
    if (_submissions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FluentIcons.checkbox_composite, size: 48, color: Colors.grey[60]),
            const SizedBox(height: 12),
            Text('작성된 점검표가 없습니다', style: TextStyle(color: Colors.grey[60], fontSize: 16)),
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 좌측: 일자 목록 ──
        SizedBox(
          width: 220,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.06),
                  border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
                ),
                child: const Text('작성 일자', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _sortedDates.length,
                  itemBuilder: (context, i) {
                    final date = _sortedDates[i];
                    final count = _grouped[date]!.length;
                    final isSelected = _selectedDate == date;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedDate = date),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.teal.withValues(alpha: 0.1) : Colors.transparent,
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
                            left: isSelected
                                ? BorderSide(color: Colors.teal, width: 3)
                                : BorderSide.none,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                date,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  color: isSelected ? Colors.teal : null,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('$count', style: TextStyle(fontSize: 11, color: Colors.grey[120])),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Container(width: 1, color: Colors.grey.withValues(alpha: 0.3)),
        // ── 우측: 선택 일자의 전체 인턴 제출 목록 ──
        Expanded(
          child: _selectedDate == null
              ? const Center(child: Text('일자를 선택해주세요'))
              : _buildDateList(_grouped[_selectedDate]!),
        ),
      ],
    );
  }

  /// 선택한 일자의 전체 인턴 점검표를 하나의 엑셀 파일로 저장한다.
  Future<void> _exportDateToExcel(
    BuildContext context,
    String dateLabel,
    List<Map<String, dynamic>> items,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ContentDialog(
        title: Text('엑셀 생성 중'),
        content: SizedBox(height: 80, child: Center(child: ProgressRing())),
      ),
    );

    try {
      final excel = Excel.createExcel();
      final sheet = excel['관내점검표'];

      final headers = [
        '작성일자', '작성시각', '작성자', '점검표', '점검구역',
        '구역', '항목', '점검내용', '확인여부', '비고',
      ];
      for (int c = 0; c < headers.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).value =
            TextCellValue(headers[c]);
      }

      String checkKey(int no, int si, int ii) => '${no}_${si}_$ii';
      String remarkKey(int no, int si) => '${no}_$si';

      int rowIdx = 1;
      for (final data in items) {
        final typeId = data['checklistType'] as String?;
        final template = kChecklistTemplates.firstWhere(
          (t) => t.id == typeId,
          orElse: () => kChecklistShalomB1,
        );
        final checks = data['checks'] as Map<String, dynamic>? ?? {};
        final issues = data['issues'] as Map<String, dynamic>? ?? {};
        final remarks = data['remarks'] as Map<String, dynamic>? ?? {};
        final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
        final writerName = data['_writerName'] as String? ?? '알 수 없음';
        final floor = (data['floor'] as String?) ?? '';

        for (final loc in template.locations) {
          for (final se in loc.subjects.asMap().entries) {
            final si = se.key;
            final sub = se.value;
            final remark = remarks[remarkKey(loc.no, si)] as String? ?? '';
            for (final ie in sub.items.asMap().entries) {
              final ii = ie.key;
              final item = ie.value;
              final cKey = checkKey(loc.no, si, ii);
              final checked = checks[cKey] == true;
              final hasIssue = issues[cKey] == true;
              final values = [
                dateLabel,
                submittedAt != null ? _timeFmt.format(submittedAt) : '',
                writerName,
                _templateLabel(typeId),
                floor,
                loc.location.replaceAll('\n', ' '),
                sub.name.replaceAll('\n', ' '),
                item.content,
                hasIssue ? 'X' : (checked ? 'O' : '-'),
                remark,
              ];
              for (int c = 0; c < values.length; c++) {
                sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIdx)).value =
                    TextCellValue(values[c]);
              }
              rowIdx++;
            }
          }
        }
      }

      if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');

      final bytes = excel.encode();
      if (bytes == null) throw Exception('엑셀 파일 생성 실패');

      if (!context.mounted) return;
      Navigator.pop(context);

      final fileDate = dateLabel.replaceAll('.', '');
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: '관내점검표 저장',
        fileName: '관내점검표_$fileDate.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (savePath == null) return;
      await File(savePath).writeAsBytes(bytes);

      if (!context.mounted) return;
      await displayInfoBar(
        context,
        builder: (c, close) => InfoBar(
          title: Text('저장 완료: $savePath'),
          severity: InfoBarSeverity.success,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      await displayInfoBar(
        context,
        builder: (c, close) => InfoBar(
          title: Text('오류: $e'),
          severity: InfoBarSeverity.error,
        ),
      );
    }
  }

  /// 카드/서머리에 표시할 구역명. "샬롬 각층"은 저장된 점검구역(예: 샬롬하우스 A동 2층)을 쓰고,
  /// 점검구역 없이 저장된 옛 기록은 구역 미지정으로 표시한다. 그 외 템플릿은 템플릿명이 곧 구역이다.
  String _areaLabel(Map<String, dynamic> data) {
    final floor = data['floor'] as String?;
    if (floor != null && floor.isNotEmpty) return floor;
    if (data['checklistType'] == 'shalom_floor') return '점검구역 미지정';
    return _templateLabel(data['checklistType'] as String?);
  }

  /// 선택한 일자의 전체 점검표에서 비고/사진이 작성된 항목만 구역별로 모아 보여준다.
  void _showSummaryDialog(
    BuildContext context,
    String dateLabel,
    List<Map<String, dynamic>> items,
  ) {
    // (구역, 작성자, 비고 목록) 형태로 정리 — 비고와 사진이 모두 없는 점검표는 제외한다.
    final entries = <Map<String, dynamic>>[];
    for (final data in items) {
      final templateId = data['checklistType'] as String? ?? 'shalom_b1';
      final template = kChecklistTemplates.firstWhere(
        (t) => t.id == templateId,
        orElse: () => kChecklistShalomB1,
      );
      final remarks = data['remarks'] as Map<String, dynamic>? ?? {};
      final itemImages = data['itemImages'] as Map<String, dynamic>? ?? {};

      final rows = <Map<String, dynamic>>[];
      for (final loc in template.locations) {
        for (var si = 0; si < loc.subjects.length; si++) {
          final key = '${loc.no}_$si';
          final text = (remarks[key] as String?)?.trim() ?? '';
          final images =
              (itemImages[key] as List?)?.whereType<String>().toList() ?? const <String>[];
          if (text.isEmpty && images.isEmpty) continue;
          rows.add({
            'location': loc.location.replaceAll('\n', ' '),
            'subject': loc.subjects[si].name.replaceAll('\n', ' '),
            'text': text,
            'images': images,
          });
        }
      }
      if (rows.isEmpty) continue;
      entries.add({
        'area': _areaLabel(data),
        'writer': (data['_writerName'] as String?) ?? '알 수 없음',
        'rows': rows,
      });
    }

    final totalRemarks = entries.fold<int>(
        0, (acc, e) => acc + (e['rows'] as List).length);

    showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 760),
        title: Row(
          children: [
            const Expanded(
              child: Text('비고 종합', style: TextStyle(fontSize: 16)),
            ),
            Text(
              '$dateLabel · ${entries.length}개 구역 · 비고 $totalRemarks건',
              style: TextStyle(
                  fontSize: 12, color: Colors.grey[100], fontWeight: FontWeight.normal),
            ),
          ],
        ),
        content: entries.isEmpty
            ? const SizedBox(
                height: 120,
                child: Center(child: Text('작성된 비고가 없습니다')),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: entries.map((entry) {
                    final rows = entry['rows'] as List;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 구역 헤더
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.1),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry['area'] as String,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                                Icon(FluentIcons.contact, size: 12, color: Colors.grey[100]),
                                const SizedBox(width: 3),
                                Text(
                                  entry['writer'] as String,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[100]),
                                ),
                              ],
                            ),
                          ),
                          // 비고 목록
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                              borderRadius:
                                  const BorderRadius.vertical(bottom: Radius.circular(6)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var i = 0; i < rows.length; i++)
                                  _buildSummaryRow(ctx, i + 1, rows[i] as Map<String, dynamic>),
                              ],
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

  Widget _buildSummaryRow(BuildContext context, int no, Map<String, dynamic> row) {
    final text = row['text'] as String;
    final images = (row['images'] as List).whereType<String>().toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$no.',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text.isNotEmpty ? text : '(사진만 첨부)',
                      style: TextStyle(
                        fontSize: 13,
                        color: text.isNotEmpty ? null : Colors.grey[100],
                        fontStyle: text.isNotEmpty ? null : FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${row['location']} · ${row['subject']}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[100]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (images.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: images
                    .map((url) => GestureDetector(
                          onTap: () => _showImagePreview(context, url),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              url,
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 70,
                                height: 70,
                                color: Colors.grey.withValues(alpha: 0.15),
                                child: Icon(FluentIcons.picture_center,
                                    size: 20, color: Colors.grey[100]),
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateList(List<Map<String, dynamic>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$_selectedDate 작성 목록 (${items.length}건)',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              Button(
                onPressed: () => _showSummaryDialog(context, _selectedDate!, items),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.bulleted_list, size: 13),
                    SizedBox(width: 6),
                    Text('비고 종합', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Button(
                onPressed: () => _exportDateToExcel(context, _selectedDate!, items),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.excel_document, size: 13),
                    SizedBox(width: 6),
                    Text('엑셀 다운로드', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: items.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildCard(items[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(Map<String, dynamic> data) {
    final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
    final typeId = data['checklistType'] as String?;
    final writerName = data['_writerName'] as String? ?? '알 수 없음';
    final floor = data['floor'] as String?;
    final checked = _checkedCount(data);
    final issueCount = _issueCount(data);
    final okCount = checked - issueCount;
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _templateLabel(typeId),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(FluentIcons.contact, size: 13, color: Colors.grey[100]),
                const SizedBox(width: 3),
                Text(writerName, style: TextStyle(fontSize: 12, color: Colors.grey[100], fontWeight: FontWeight.w600)),
                if (floor != null && floor.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Icon(FluentIcons.location, size: 12, color: Colors.grey[100]),
                  const SizedBox(width: 2),
                  Text(floor, style: TextStyle(fontSize: 12, color: Colors.grey[100])),
                ],
                const Spacer(),
                Text(
                  submittedAt != null ? _timeFmt.format(submittedAt) : '-',
                  style: TextStyle(fontSize: 12, color: Colors.grey[100]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        Container(height: 6, color: Colors.grey.withValues(alpha: 0.15)),
                        FractionallySizedBox(
                          widthFactor: total > 0 ? (checked / total).clamp(0.0, 1.0) : 0.0,
                          child: Container(
                            height: 6,
                            color: progress >= 1.0 ? Colors.green : color,
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: total > 0 ? (issueCount / total).clamp(0.0, 1.0) : 0.0,
                          child: Container(height: 6, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    children: [
                      TextSpan(text: '$okCount', style: TextStyle(color: Colors.green)),
                      if (issueCount > 0) ...[
                        TextSpan(text: '+', style: TextStyle(color: Colors.grey[120])),
                        TextSpan(text: '$issueCount', style: TextStyle(color: Colors.red)),
                      ],
                      TextSpan(text: ' / $total', style: TextStyle(color: Colors.grey[120])),
                    ],
                  ),
                ),
              ],
            ),
            if (progress >= 1.0) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(FluentIcons.check_mark, size: 12, color: Colors.green),
                  const SizedBox(width: 4),
                  Text('점검 완료', style: TextStyle(fontSize: 11, color: Colors.green)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, Map<String, dynamic> data) {
    final typeId = data['checklistType'] as String?;
    final checks = data['checks'] as Map<String, dynamic>? ?? {};
    final issues = data['issues'] as Map<String, dynamic>? ?? {};
    final remarks = data['remarks'] as Map<String, dynamic>? ?? {};
    final itemImages = data['itemImages'] as Map<String, dynamic>? ?? {};
    final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
    final writerName = data['_writerName'] as String? ?? '알 수 없음';

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
              child: Text('${template.title} · $writerName', style: const TextStyle(fontSize: 16)),
            ),
            if (submittedAt != null)
              Text(
                DateFormat('yyyy.MM.dd HH:mm').format(submittedAt),
                style: TextStyle(fontSize: 12, color: Colors.grey[100], fontWeight: FontWeight.normal),
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.08),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
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
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              loc.location.replaceAll('\n', ' '),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
                      ),
                      child: Column(
                        children: loc.subjects.asMap().entries.map((se) {
                          final si = se.key;
                          final sub = se.value;
                          final rKey = remarkKey(loc.no, si);
                          final remark = remarks[rKey] as String?;
                          final images = (itemImages[rKey] as List?)?.whereType<String>().toList() ?? const <String>[];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (si > 0)
                                Padding(
                                  padding: EdgeInsets.zero,
                                  child: Divider(style: DividerThemeData(horizontalMargin: EdgeInsets.zero)),
                                ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                                child: Text(sub.name.replaceAll('\n', ' '),
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blue.withValues(alpha: 0.8))),
                              ),
                              ...sub.items.asMap().entries.map((ie) {
                                final ii = ie.key;
                                final item = ie.value;
                                final cKey = checkKey(loc.no, si, ii);
                                final checked = checks[cKey] == true;
                                final hasIssue = issues[cKey] == true;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        hasIssue
                                            ? FluentIcons.chrome_close
                                            : checked
                                                ? FluentIcons.check_mark
                                                : FluentIcons.checkbox_composite,
                                        size: 14,
                                        color: hasIssue ? Colors.red : (checked ? Colors.green : Colors.grey[60]),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          item.content,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: hasIssue ? Colors.red : (checked ? Colors.grey[100] : Colors.grey[160]),
                                            decoration: checked ? TextDecoration.lineThrough : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              if (remark != null && remark.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.yellow.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.yellow.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('비고  ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[120])),
                                        Expanded(
                                          child: Text(remark, style: TextStyle(fontSize: 12, color: Colors.grey[160])),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(height: 6),
                              if (images.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: images.map((url) => GestureDetector(
                                      onTap: () => _showImagePreview(context, url),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.network(
                                          url,
                                          width: 64,
                                          height: 64,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Container(
                                            width: 64,
                                            height: 64,
                                            color: Colors.grey.withValues(alpha: 0.15),
                                            child: Icon(FluentIcons.picture_center, size: 20, color: Colors.grey[100]),
                                          ),
                                        ),
                                      ),
                                    )).toList(),
                                  ),
                                ),
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
}
