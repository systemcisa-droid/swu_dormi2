import 'package:fluent_ui/fluent_ui.dart';
import 'package:swu_dormi_admin/widgets/shimmer.dart';
import 'package:swu_dormi_admin/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class WindowsMessageScreen extends StatefulWidget {
  const WindowsMessageScreen({super.key});

  @override
  State<WindowsMessageScreen> createState() => _WindowsMessageScreenState();
}

// ── 메시지 템플릿 ──
const _messageTemplates = [
  {
    'category': '청소점검',
    'title': '월 정기 청소점검 안내',
    'content':
        '안녕하세요, 서울여자대학교 기숙사입니다.\n\n월 정기 청소점검이 예정되어 있습니다.\n\n'
        '■ 점검 일정: [날짜] [시간]\n'
        '■ 점검 대상: [층/호실]\n\n'
        '점검 전 호실 정리정돈을 부탁드립니다.\n'
        '문의사항은 기숙사 사무실로 연락해주세요.',
  },
  {
    'category': '퇴사검사',
    'title': '퇴사검사 신청 안내',
    'content':
        '안녕하세요, 서울여자대학교 기숙사입니다.\n\n퇴사 예정자는 퇴사검사를 신청해주시기 바랍니다.\n\n'
        '■ 신청 방법: 기숙사 앱 > 퇴사검사 > 동의 및 서명\n'
        '■ 퇴사 기한: [날짜]\n\n'
        '⚠ 퇴사 당일 청소확인을 받지 않고 퇴사 시 강제퇴사 처리됩니다.\n'
        '퇴사 전 모든 개인 소지품을 완전히 반출해주세요.',
  },
  {
    'category': '규정 위반',
    'title': '생활관 규정 위반 안내',
    'content':
        '안녕하세요, 서울여자대학교 기숙사입니다.\n\n'
        '귀하의 생활관 규정 위반 사항이 확인되어 안내 드립니다.\n\n'
        '■ 위반 내용: [내용]\n'
        '■ 조치 사항: [벌점/경고 등]\n\n'
        '향후 반복 위반 시 퇴사 처리될 수 있으니 규정 준수를 부탁드립니다.',
  },
  {
    'category': '소음 주의',
    'title': '소음 자제 요청',
    'content':
        '안녕하세요, 서울여자대학교 기숙사입니다.\n\n'
        '야간 소음으로 인한 민원이 접수되었습니다.\n\n'
        '■ 생활관 내 취침시간(23:00 이후)에는 소음을 자제해주세요.\n'
        '■ 복도에서의 큰 소리, 뛰기 등은 삼가주세요.\n\n'
        '이웃을 배려하는 생활관 문화를 만들어주시기 바랍니다.',
  },
  {
    'category': '시설 점검',
    'title': '시설 점검 공지',
    'content':
        '안녕하세요, 서울여자대학교 기숙사입니다.\n\n'
        '시설 정기 점검이 예정되어 있습니다.\n\n'
        '■ 점검 일시: [날짜] [시간]\n'
        '■ 점검 항목: [내용]\n'
        '■ 영향 범위: [층/구역]\n\n'
        '점검 시간 중 불편을 드려 죄송합니다.\n'
        '문의사항은 기숙사 사무실로 연락해주세요.',
  },
  {
    'category': '벌점/상점',
    'title': '벌점/상점 내역 안내',
    'content':
        '안녕하세요, 서울여자대학교 기숙사입니다.\n\n'
        '귀하의 [벌점/상점] 내역을 안내 드립니다.\n\n'
        '■ 항목: [내용]\n'
        '■ 점수: [점수]\n'
        '■ 누적 점수: [누적]\n\n'
        '자세한 내용은 기숙사 앱에서 확인하실 수 있습니다.',
  },
  {
    'category': '공동시설',
    'title': '공동시설 이용 안내',
    'content':
        '안녕하세요, 서울여자대학교 기숙사입니다.\n\n'
        '공동시설 이용 관련 안내사항을 전달드립니다.\n\n'
        '■ 이용 가능 시간: [시간]\n'
        '■ 주의사항: [내용]\n\n'
        '쾌적한 공동시설 이용을 위해 사용 후 정리정돈 부탁드립니다.',
  },
  {
    'category': '퇴사 기한',
    'title': '퇴사 기한 안내',
    'content':
        '안녕하세요, 서울여자대학교 기숙사입니다.\n\n'
        '퇴사 기한을 안내 드립니다.\n\n'
        '■ 퇴사 기한: [날짜]\n'
        '■ 퇴사 절차: 짐 정리 → 호실 청소 → 퇴사검사 신청\n\n'
        '기한 내 퇴사하지 않을 경우 불이익이 발생할 수 있습니다.\n'
        '문의사항은 기숙사 사무실로 연락해주세요.',
  },
];

class _WindowsMessageScreenState extends State<WindowsMessageScreen> {
  final _firestoreService = FirestoreService();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();

  int _selectedTab = 0; // 0: 메시지 작성, 1: 보낸 메시지
  String _selectedTarget = 'individual';
  String _searchQuery = '';
  List<String> _selectedUserIds = [];
  List<QueryDocumentSnapshot> _students = [];
  bool _isLoading = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _firestoreService.users
          .where('role', isEqualTo: 'student')
          .get();
      setState(() {
        _students = snapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<String> _getFilteredUserIds(String filter) {
    return _students.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (filter == 'all') return true;
      if (filter == 'individual') return false;

      final dormBuilding = (data['dormBuilding'] ?? '').toString();
      final roomNumber = (data['roomNumber'] ?? '').toString();
      final roomNum = int.tryParse(roomNumber);
      final floorNum = roomNum != null ? roomNum ~/ 100 : 0;
      final lastTwo = roomNum != null ? roomNum % 100 : 0;
      final isADong = lastTwo >= 1 && lastTwo <= 20;
      final isBDong = lastTwo >= 21 && lastTwo <= 35;

      // ── 샬롬하우스 ──
      if (filter == 'shalom_all') return dormBuilding == '샬롬하우스';
      if (filter == 'shalom_a_all') return dormBuilding == '샬롬하우스' && isADong;
      if (filter == 'shalom_b_all') return dormBuilding == '샬롬하우스' && isBDong;
      if (filter.startsWith('shalom_a_floor_')) {
        final f = int.tryParse(filter.replaceFirst('shalom_a_floor_', ''));
        return dormBuilding == '샬롬하우스' && isADong && floorNum == f;
      }
      if (filter.startsWith('shalom_b_floor_')) {
        final f = int.tryParse(filter.replaceFirst('shalom_b_floor_', ''));
        return dormBuilding == '샬롬하우스' && isBDong && floorNum == f;
      }

      // ── 국제생활관 ──
      if (filter == 'intl_all') return dormBuilding == '국제생활관';
      if (filter == 'intl_a_all') return dormBuilding == '국제생활관' && isADong;
      if (filter == 'intl_b_all') return dormBuilding == '국제생활관' && isBDong;
      if (filter.startsWith('intl_a_floor_')) {
        final f = int.tryParse(filter.replaceFirst('intl_a_floor_', ''));
        return dormBuilding == '국제생활관' && isADong && floorNum == f;
      }
      if (filter.startsWith('intl_b_floor_')) {
        final f = int.tryParse(filter.replaceFirst('intl_b_floor_', ''));
        return dormBuilding == '국제생활관' && isBDong && floorNum == f;
      }

      // ── 바롬인성교육관 ──
      if (filter == 'barom_floor_10') return dormBuilding == '바롬인성교육관';

      return false;
    }).map((doc) => doc.id).toList();
  }

  void _showTemplateDialog() {
    showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('메시지 템플릿 선택'),
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 600),
        content: SizedBox(
          width: 520,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _messageTemplates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final t = _messageTemplates[i];
              return Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[50]),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Button(
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  onPressed: () {
                    _titleController.text = t['title']!;
                    _messageController.text = t['content']!;
                    Navigator.of(ctx).pop();
                  },
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                t['category']!,
                                style: const TextStyle(fontSize: 11, color: Color(0xFFFFFFFF)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              t['title']!,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t['content']!.split('\n').take(2).join(' '),
                          style: TextStyle(fontSize: 12, color: Colors.grey[120]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_titleController.text.trim().isEmpty) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('알림'),
          content: const Text('제목을 입력해주세요.'),
          severity: InfoBarSeverity.warning,
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
        ),
      );
      return;
    }

    if (_messageController.text.trim().isEmpty) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('알림'),
          content: const Text('내용을 입력해주세요.'),
          severity: InfoBarSeverity.warning,
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
        ),
      );
      return;
    }

    if (_selectedTarget == 'individual' && _selectedUserIds.isEmpty) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('알림'),
          content: const Text('메시지를 받을 학생을 선택해주세요.'),
          severity: InfoBarSeverity.warning,
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
        ),
      );
      return;
    }

    // 항상 체크된 학생들에게 전송
    final recipientIds = List<String>.from(_selectedUserIds);
    final labelMap = <String, String>{
      'individual': '개별 선택',
      'all': '전체',
      'shalom_all': '샬롬하우스 전체',
      'shalom_a_all': '샬롬하우스 A동 전체',
      for (int f = 2; f <= 7; f++) 'shalom_a_floor_$f': '샬롬하우스 A동 $f층',
      'shalom_b_all': '샬롬하우스 B동 전체',
      for (int f = 2; f <= 7; f++) 'shalom_b_floor_$f': '샬롬하우스 B동 $f층',
      'intl_all': '국제생활관 전체',
      'intl_a_all': '국제생활관 A동 전체',
      'intl_a_floor_1': '국제생활관 A동 1층',
      'intl_a_floor_2': '국제생활관 A동 2층',
      'intl_b_all': '국제생활관 B동 전체',
      'intl_b_floor_2': '국제생활관 B동 2층',
      'intl_b_floor_3': '국제생활관 B동 3층',
      'barom_floor_10': '바롬인성교육관 10층',
    };
    final targetLabel = labelMap[_selectedTarget] ?? _selectedTarget;
    final recipientInfos = _students
        .where((doc) => recipientIds.contains(doc.id))
        .map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'userId': doc.id,
            'name': (data['name'] ?? '').toString(),
            'studentId': (data['studentId'] ?? '').toString(),
          };
        })
        .toList();

    setState(() => _isSending = true);

    try {
      await _firestoreService.sendNotification(
        userIds: recipientIds,
        type: 'admin_message',
        title: _titleController.text.trim(),
        content: _messageController.text.trim(),
        targetLabel: targetLabel,
        recipients: recipientInfos,
      );

      if (!mounted) return;

      setState(() => _isSending = false);

      // 입력 필드 초기화
      _titleController.clear();
      _messageController.clear();
      setState(() {
        _selectedUserIds.clear();
      });

      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('완료'),
          content: Text('${recipientIds.length}명의 학생에게 메시지가 전송되었습니다.'),
          severity: InfoBarSeverity.success,
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSending = false);

      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('오류'),
          content: Text('메시지 전송 중 오류가 발생했습니다: $e'),
          severity: InfoBarSeverity.error,
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: const Text('메시지 전송'),
        commandBar: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ToggleButton(
              checked: _selectedTab == 0,
              onChanged: (_) => setState(() => _selectedTab = 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.edit, size: 14),
                  const SizedBox(width: 6),
                  const Text('메시지 작성'),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ToggleButton(
              checked: _selectedTab == 1,
              onChanged: (_) => setState(() => _selectedTab = 1),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.mail, size: 14),
                  const SizedBox(width: 6),
                  const Text('보낸 메시지'),
                ],
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
      content: _selectedTab == 0
          ? _buildComposeView()
          : _buildSentMessagesView(),
    );
  }

  Widget _buildComposeView() {
    return _isLoading
        ? ShimmerList(itemBuilder: () => const MessageStudentRowShimmer(), count: 8, padding: EdgeInsets.zero)
        : Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 왼쪽: 수신 대상 선택
                Expanded(
                  flex: 2,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '수신 대상',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          ComboBox<String>(
                            value: _selectedTarget,
                            isExpanded: true,
                            items: [
                              const ComboBoxItem(value: 'individual', child: Text('개별 학생 선택')),
                              // 샬롬하우스
                              const ComboBoxItem(value: 'shalom_all', child: Text('샬롬하우스 전체')),
                              const ComboBoxItem(value: 'shalom_a_all', child: Text('샬롬하우스 A동 전체')),
                              for (int f = 2; f <= 7; f++)
                                ComboBoxItem(value: 'shalom_a_floor_$f', child: Text('샬롬하우스 A동 $f층')),
                              const ComboBoxItem(value: 'shalom_b_all', child: Text('샬롬하우스 B동 전체')),
                              for (int f = 2; f <= 7; f++)
                                ComboBoxItem(value: 'shalom_b_floor_$f', child: Text('샬롬하우스 B동 $f층')),
                              // 국제생활관
                              const ComboBoxItem(value: 'intl_all', child: Text('국제생활관 전체')),
                              const ComboBoxItem(value: 'intl_a_all', child: Text('국제생활관 A동 전체')),
                              const ComboBoxItem(value: 'intl_a_floor_1', child: Text('국제생활관 A동 1층')),
                              const ComboBoxItem(value: 'intl_a_floor_2', child: Text('국제생활관 A동 2층')),
                              const ComboBoxItem(value: 'intl_b_all', child: Text('국제생활관 B동 전체')),
                              const ComboBoxItem(value: 'intl_b_floor_2', child: Text('국제생활관 B동 2층')),
                              const ComboBoxItem(value: 'intl_b_floor_3', child: Text('국제생활관 B동 3층')),
                              // 바롬인성교육관
                              const ComboBoxItem(value: 'barom_floor_10', child: Text('바롬인성교육관 10층')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedTarget = value;
                                  // 필터 변경 시 해당 필터의 학생 전체 자동 선택
                                  if (value == 'all') {
                                    _selectedUserIds = _students.map((d) => d.id).toList();
                                  } else if (value == 'individual') {
                                    _selectedUserIds.clear();
                                  } else {
                                    _selectedUserIds = _getFilteredUserIds(value);
                                  }
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          // 전체 선택 / 해제
                          Builder(builder: (ctx) {
                            final visibleIds = _selectedTarget == 'individual' || _selectedTarget == 'all'
                                ? _students.map((d) => d.id).toList()
                                : _getFilteredUserIds(_selectedTarget);
                            return Row(
                              children: [
                                Button(
                                  onPressed: () => setState(() => _selectedUserIds = List.from(visibleIds)),
                                  child: const Text('전체 선택', style: TextStyle(fontSize: 12)),
                                ),
                                const SizedBox(width: 8),
                                Button(
                                  onPressed: () => setState(() => _selectedUserIds.clear()),
                                  child: const Text('선택 해제', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            );
                          }),
                          const SizedBox(height: 8),
                          TextBox(
                            controller: _searchController,
                            placeholder: '이름, 학번, 호실로 검색',
                            prefix: const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(FluentIcons.search, size: 16),
                            ),
                            suffix: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(FluentIcons.clear, size: 12),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value.toLowerCase();
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[60]),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Builder(
                                builder: (context) {
                                  // 드롭다운 필터로 1차 필터링
                                  List<QueryDocumentSnapshot> filteredStudents =
                                      (_selectedTarget == 'individual' || _selectedTarget == 'all')
                                          ? List.from(_students)
                                          : _students
                                              .where((d) => _getFilteredUserIds(_selectedTarget).contains(d.id))
                                              .toList();

                                  // 검색어로 2차 필터링
                                  if (_searchQuery.isNotEmpty) {
                                    filteredStudents = filteredStudents.where((doc) {
                                      final data = doc.data() as Map<String, dynamic>;
                                      final name = (data['name'] ?? '').toString().toLowerCase();
                                      final studentNo = (data['studentId'] ?? '').toString().toLowerCase();
                                      final room = (data['roomNumber'] ?? '').toString().toLowerCase();
                                      return name.contains(_searchQuery) ||
                                          studentNo.contains(_searchQuery) ||
                                          room.contains(_searchQuery);
                                    }).toList();
                                  }

                                  // 건물 → 호실 순 정렬
                                  const buildingOrder = ['샬롬하우스', '국제생활관', '바롬인성교육관'];
                                  filteredStudents.sort((a, b) {
                                    final da = a.data() as Map<String, dynamic>;
                                    final db = b.data() as Map<String, dynamic>;
                                    final buildingA = (da['dormBuilding'] ?? '').toString();
                                    final buildingB = (db['dormBuilding'] ?? '').toString();
                                    final bia = buildingOrder.indexOf(buildingA);
                                    final bib = buildingOrder.indexOf(buildingB);
                                    final buildingIdxA = bia == -1 ? buildingOrder.length : bia;
                                    final buildingIdxB = bib == -1 ? buildingOrder.length : bib;
                                    if (buildingIdxA != buildingIdxB) {
                                      return buildingIdxA.compareTo(buildingIdxB);
                                    }
                                    final ra = int.tryParse((da['roomNumber'] ?? '0').toString()) ?? 0;
                                    final rb = int.tryParse((db['roomNumber'] ?? '0').toString()) ?? 0;
                                    return ra.compareTo(rb);
                                  });

                                  if (filteredStudents.isEmpty) {
                                    return Center(
                                      child: Text(
                                        '해당하는 학생이 없습니다',
                                        style: TextStyle(fontSize: 14, color: Colors.grey[120]),
                                      ),
                                    );
                                  }

                                  return ListView.builder(
                                    itemCount: filteredStudents.length,
                                    itemBuilder: (context, index) {
                                      final data = filteredStudents[index].data() as Map<String, dynamic>;
                                      final uid = filteredStudents[index].id;
                                      final name = data['name'] ?? '';
                                      final studentNo = data['studentId'] ?? '';
                                      final room = data['roomNumber'] ?? '';
                                      final building = (data['dormBuilding'] ?? '').toString();
                                      final label = building.isNotEmpty
                                          ? '$name ($studentNo) - $room호  [$building]'
                                          : '$name ($studentNo) - $room호';
                                      final isSelected = _selectedUserIds.contains(uid);
                                      return Checkbox(
                                        checked: isSelected,
                                        onChanged: (checked) => setState(() {
                                          if (checked == true) {
                                            _selectedUserIds.add(uid);
                                          } else {
                                            _selectedUserIds.remove(uid);
                                          }
                                        }),
                                        content: Text(label, overflow: TextOverflow.ellipsis),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '선택된 학생: ${_selectedUserIds.length}명',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[100],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // 오른쪽: 메시지 작성
                Expanded(
                  flex: 3,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                '메시지 작성',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              Button(
                                onPressed: _showTemplateDialog,
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(FluentIcons.text_document, size: 14),
                                    SizedBox(width: 6),
                                    Text('템플릿'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text('제목', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          TextBox(
                            controller: _titleController,
                            placeholder: '메시지 제목을 입력하세요',
                            maxLines: 1,
                          ),
                          const SizedBox(height: 16),
                          const Text('내용', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Expanded(
                            child: TextBox(
                              controller: _messageController,
                              placeholder: '메시지 내용을 입력하세요',
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Button(
                                onPressed: _isSending
                                    ? null
                                    : () {
                                        _titleController.clear();
                                        _messageController.clear();
                                        setState(() {
                                          _selectedUserIds.clear();
                                        });
                                      },
                                child: const Text('초기화'),
                              ),
                              const SizedBox(width: 12),
                              FilledButton(
                                onPressed: _isSending ? null : _sendMessage,
                                child: _isSending
                                    ? const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: ProgressRing(strokeWidth: 2),
                                          ),
                                          SizedBox(width: 8),
                                          Text('전송 중...'),
                                        ],
                                      )
                                    : const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(FluentIcons.send, size: 16),
                                          SizedBox(width: 8),
                                          Text('메시지 전송'),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
  }

  Widget _buildSentMessagesView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '보낸 메시지 목록',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestoreService.getSentMessages(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ShimmerList(itemBuilder: () => const MessageStudentRowShimmer(), count: 6);
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.mail, size: 48, color: Colors.grey[80]),
                        const SizedBox(height: 12),
                        Text(
                          '보낸 메시지가 없습니다',
                          style: TextStyle(fontSize: 16, color: Colors.grey[100]),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final title = data['title'] ?? '';
                    final content = data['content'] ?? '';
                    final recipientCount = data['recipientCount'] ?? 0;
                    final targetLabel = data['targetLabel'] ?? '';
                    final sentAt = data['sentAt'] as Timestamp?;
                    final sentDate = sentAt != null
                        ? DateFormat('yyyy.MM.dd HH:mm').format(sentAt.toDate())
                        : '-';
                    final rawRecipients = data['recipients'];
                    final List<Map<String, dynamic>> recipients = rawRecipients is List
                        ? rawRecipients.map((e) => Map<String, dynamic>.from(e as Map)).toList()
                        : [];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  InfoBadge(
                                    source: Text('$targetLabel · $recipientCount명'),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    sentDate,
                                    style: TextStyle(fontSize: 12, color: Colors.grey[100]),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                content,
                                style: TextStyle(fontSize: 13, color: Colors.grey[130]),
                              ),
                              if (recipients.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                const Divider(),
                                const SizedBox(height: 6),
                                Text(
                                  '수신자',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[120],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: recipients.map((r) {
                                    final name = r['name'] ?? '';
                                    final studentId = r['studentId'] ?? '';
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[20],
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.grey[50]),
                                      ),
                                      child: Text(
                                        '$name ($studentId)',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
