import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/student_model.dart';
import '../../services/firestore_service.dart';

class StudentDetailScreen extends StatefulWidget {
  final StudentModel student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _dateFormat = DateFormat('yyyy.MM.dd HH:mm');

  // 상벌점
  List<Map<String, dynamic>> _pointHistory = [];
  bool _isLoadingPoints = true;
  String _pointError = '';

  // 동의 서명
  Map<String, dynamic>? _regulationAgreement;
  Map<String, dynamic>? _moveOutAgreement;
  bool _isLoadingAgreements = true;

  int get _totalPoints {
    int total = 0;
    for (final item in _pointHistory) {
      final pts = (item['points'] as num?)?.toInt() ?? 0;
      final type = (item['type'] ?? 'penalty') as String;
      total += type == 'reward' ? pts : -pts;
    }
    return total;
  }

  static const _penaltyReasons = [
    {'reason': '지각 (24시~24시15분)', 'points': 3},
    {'reason': '지각 (24시15분~01시)', 'points': 7},
    {'reason': '인원확인 지각', 'points': 1},
    {'reason': '비사생과 출입', 'points': 13},
    {'reason': '외부인 출입 묵인', 'points': 5},
    {'reason': '출입카드 무단사용', 'points': 3},
    {'reason': '출입카드 미소지 3회', 'points': 1},
    {'reason': '출입카드 미소지 4회', 'points': 2},
    {'reason': '출입카드 미소지 5회 이상', 'points': 3},
    {'reason': '직원지시 불응', 'points': 5},
    {'reason': '화재대피훈련 불참', 'points': 1},
    {'reason': '반입불가물품 소지', 'points': 10},
    {'reason': '청소점검 미실시', 'points': 4},
    {'reason': '기간외 청소신청', 'points': 2},
    {'reason': '기타', 'points': 1},
  ];

  static const _rewardReasons = [
    {'reason': '안전교육 참석', 'points': 3},
    {'reason': '응급상황 사생동행', 'points': 2},
    {'reason': '심폐소생술 교육이수증', 'points': 5},
    {'reason': '안전보안 실천', 'points': 3},
    {'reason': '위급상황 협조', 'points': 1},
    {'reason': '엔젤호실 지정엔젤', 'points': 2},
    {'reason': '입퇴사 도우미', 'points': 2},
    {'reason': '택배정리 지원', 'points': 1},
    {'reason': '행정실 업무 지원', 'points': 1},
    {'reason': '청소 우수 호실', 'points': 2},
    {'reason': '시설물 운영 개선', 'points': 2},
    {'reason': '에너지 절약', 'points': 2},
    {'reason': '시설물 보전관리 지원', 'points': 2},
    {'reason': '주요행사 참여', 'points': 1},
    {'reason': '책임교수 판단 협조', 'points': 1},
    {'reason': '기타', 'points': 1},
  ];

  @override
  void initState() {
    super.initState();
    _loadPointHistory();
    _loadAgreements();
  }

  Future<void> _loadPointHistory() async {
    setState(() { _isLoadingPoints = true; _pointError = ''; });
    try {
      final snap = await _firestore
          .collection('users')
          .doc(widget.student.id)
          .collection('point_history')
          .get();
      final docs = snap.docs.map((d) => d.data()).toList();
      docs.sort((a, b) {
        final at = a['createdAt'];
        final bt = b['createdAt'];
        if (at is Timestamp && bt is Timestamp) return bt.compareTo(at);
        return 0;
      });
      if (!mounted) return;
      setState(() { _pointHistory = docs; _isLoadingPoints = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoadingPoints = false; _pointError = e.toString(); });
    }
  }

  Future<void> _loadAgreements() async {
    setState(() => _isLoadingAgreements = true);
    try {
      final regDoc = await _firestore.collection('regulation_agreements').doc(widget.student.id).get();
      final moveDoc = await _firestore.collection('move_out_agreements').doc(widget.student.id).get();
      if (!mounted) return;
      setState(() {
        _regulationAgreement = regDoc.exists ? regDoc.data() : null;
        _moveOutAgreement = moveDoc.exists ? moveDoc.data() : null;
        _isLoadingAgreements = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingAgreements = false);
    }
  }

  Future<void> _addPoint(String type, int pts, String reason) async {
    try {
      final userRef = _firestore.collection('users').doc(widget.student.id);
      await userRef.collection('point_history').add({
        'userId': widget.student.id,
        'type': type,
        'points': pts,
        'reason': reason,
        'createdAt': Timestamp.now(),
      });
      final delta = type == 'reward' ? pts : -pts;
      await userRef.update({'points': FieldValue.increment(delta)});
      await _loadPointHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${type == 'reward' ? '상점' : '벌점'} $pts점 입력 완료'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('오류: $e'), backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _showAddPointDialog() {
    String selectedType = 'penalty';
    String? selectedReason;
    final pointsController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final reasons = selectedType == 'reward' ? _rewardReasons : _penaltyReasons;
          return AlertDialog(
            title: const Text('상벌점 입력'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('유형', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _typeChip(setDialogState, selectedType, 'reward', '상점', Colors.blue, (v) {
                        selectedType = v; selectedReason = null; pointsController.text = '1';
                      }),
                      const SizedBox(width: 8),
                      _typeChip(setDialogState, selectedType, 'penalty', '벌점', Colors.red, (v) {
                        selectedType = v; selectedReason = null; pointsController.text = '1';
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('사유', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    hint: const Text('사유를 선택하세요'),
                    isExpanded: true,
                    items: reasons.map((item) => DropdownMenuItem<String>(
                      value: item['reason'] as String,
                      child: Text('${item['reason']}  (${item['points']}점)', style: const TextStyle(fontSize: 13)),
                    )).toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      final matched = reasons.firstWhere((r) => r['reason'] == val, orElse: () => {'points': 1});
                      setDialogState(() {
                        selectedReason = val;
                        pointsController.text = '${matched['points']}';
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('점수', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: pointsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        suffixText: '점',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
              FilledButton(
                onPressed: () {
                  final pts = int.tryParse(pointsController.text.trim()) ?? 0;
                  if (pts <= 0 || selectedReason == null) return;
                  Navigator.pop(ctx);
                  _addPoint(selectedType, pts, selectedReason!);
                },
                child: const Text('저장'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _typeChip(StateSetter set, String current, String value, String label, Color color, Function(String) onSelect) {
    final isSelected = current == value;
    return GestureDetector(
      onTap: () => set(() => onSelect(value)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? color : Colors.grey.shade700,
        )),
      ),
    );
  }

  void _showEditDialog() {
    final nameCtrl = TextEditingController(text: widget.student.name);
    final studentIdCtrl = TextEditingController(text: widget.student.studentId);
    final phoneCtrl = TextEditingController(text: widget.student.phoneNumber);
    final roomCtrl = TextEditingController(text: widget.student.roomNumber);
    final collegeCtrl = TextEditingController(text: widget.student.college ?? '');
    final deptCtrl = TextEditingController(text: widget.student.department ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('학생 정보 수정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _editField('이름', nameCtrl),
              const SizedBox(height: 12),
              _editField('학번', studentIdCtrl),
              const SizedBox(height: 12),
              _editField('전화번호', phoneCtrl, hint: '010-0000-0000'),
              const SizedBox(height: 12),
              _editField('호실', roomCtrl, hint: '401', keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              _editField('학부 (선택)', collegeCtrl),
              const SizedBox(height: 12),
              _editField('학과 (선택)', deptCtrl),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                await FirestoreService().updateStudent(widget.student.id, {
                  'name': nameCtrl.text.trim(),
                  'studentId': studentIdCtrl.text.trim(),
                  'phoneNumber': phoneCtrl.text.trim(),
                  'roomNumber': roomCtrl.text.trim(),
                  'college': collegeCtrl.text.trim().isEmpty ? null : collegeCtrl.text.trim(),
                  'department': deptCtrl.text.trim().isEmpty ? null : deptCtrl.text.trim(),
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('학생 정보가 수정되었습니다'), backgroundColor: Colors.green,
                  ));
                  Navigator.pop(context); // 목록으로 돌아가 리프레시
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('오류: $e'), backgroundColor: Colors.red,
                  ));
                }
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  Widget _editField(String label, TextEditingController ctrl,
      {String? hint, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.student;
    final totalPts = _totalPoints;

    return Scaffold(
      appBar: AppBar(
        title: Text(student.name),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditDialog,
            tooltip: '정보 수정',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── 프로필 헤더 ──
            Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  backgroundImage: student.profileImageUrl != null
                      ? NetworkImage(student.profileImageUrl!)
                      : null,
                  child: student.profileImageUrl == null
                      ? Icon(Icons.person, size: 38, color: Theme.of(context).colorScheme.primary)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.name,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      if (student.nickname != null)
                        Text('별명: ${student.nickname}',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                      Text(student.studentId,
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                // 총 상벌점 배지
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (totalPts >= 0 ? Colors.blue : Colors.red).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: (totalPts >= 0 ? Colors.blue : Colors.red).withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '${totalPts > 0 ? '+' : ''}$totalPts점',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: totalPts >= 0 ? Colors.blue : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── 기본 정보 ──
            _sectionCard(
              title: '기본 정보',
              child: Column(
                children: [
                  _infoRow('학번', student.studentId),
                  _divider(),
                  _infoRow('이메일', student.email),
                  _divider(),
                  _infoRow('전화번호', student.phoneNumber),
                  _divider(),
                  _infoRow('건물', student.dormBuilding ?? '-'),
                  _divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              SizedBox(
                                width: 80,
                                child: Text('호실',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                              ),
                              Text(student.roomCapacity.isNotEmpty ? '${student.roomNumber}호 (${student.roomCapacity})' : '${student.roomNumber}호', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        if (student.seatNumber != null && student.seatNumber!.isNotEmpty)
                          Expanded(
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 80,
                                  child: Text('자리번호',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                                ),
                                Text(student.seatNumber!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (student.college != null) ...[
                    _divider(),
                    _infoRow('학부', student.college!),
                  ],
                  if (student.department != null) ...[
                    _divider(),
                    _infoRow('학과', student.department!),
                  ],
                  _divider(),
                  _infoRow('가입일', DateFormat('yyyy년 MM월 dd일').format(student.createdAt)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 상벌점 ──
            _sectionCard(
              title: '상벌점',
              trailing: FilledButton.icon(
                onPressed: _showAddPointDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('입력', style: TextStyle(fontSize: 13)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              child: _isLoadingPoints
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _pointError.isNotEmpty
                      ? Column(children: [
                          Text('로드 실패', style: TextStyle(color: Colors.red.shade600)),
                          TextButton(onPressed: _loadPointHistory, child: const Text('다시 시도')),
                        ])
                      : _pointHistory.isEmpty
                          ? Text('이력이 없습니다',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade500))
                          : Column(
                              children: _pointHistory.map((item) {
                                final type = item['type'] as String? ?? 'penalty';
                                final pts = (item['points'] as num?)?.toInt() ?? 0;
                                final reason = item['reason'] as String? ?? '';
                                final isReward = type == 'reward';
                                final color = isReward ? Colors.blue : Colors.red;
                                final raw = item['createdAt'];
                                DateTime? date;
                                if (raw is Timestamp) date = raw.toDate();

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: color.withValues(alpha: 0.4)),
                                        ),
                                        child: Text(
                                          '${isReward ? '+' : '-'}$pts점',
                                          style: TextStyle(
                                              fontSize: 12, fontWeight: FontWeight.bold, color: color),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                          child: Text(reason, style: const TextStyle(fontSize: 13))),
                                      if (date != null)
                                        Text(DateFormat('yyyy.MM.dd').format(date),
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
            ),
            const SizedBox(height: 16),

            // ── 서명 ──
            if (_isLoadingAgreements)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else ...[
              _agreementCard('사행수칙 동의 서명', _regulationAgreement),
              const SizedBox(height: 12),
              _agreementCard('퇴사확인 서명', _moveOutAgreement),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child, Widget? trailing}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4, height: 16,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ),
          Expanded(
              child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _divider() => Divider(height: 1, color: Colors.grey.shade200);

  Widget _agreementCard(String title, Map<String, dynamic>? data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4, height: 16,
                decoration: BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          if (data == null)
            Text('미동의', style: TextStyle(fontSize: 13, color: Colors.grey.shade500))
          else ...[
            _infoRow('이름', data['userName'] ?? '-'),
            _divider(),
            _infoRow(
              '동의일시',
              data['agreedAt'] != null
                  ? _dateFormat.format((data['agreedAt'] as Timestamp).toDate())
                  : '-',
            ),
            const SizedBox(height: 12),
            const Text('서명', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            if (data['signatureUrl'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: double.infinity,
                  height: 120,
                  color: Colors.white,
                  child: Image.network(
                    data['signatureUrl'],
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        Center(child: Text('이미지 로드 실패', style: TextStyle(color: Colors.grey.shade500))),
                  ),
                ),
              )
            else
              Text('서명 없음', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          ],
        ],
      ),
    );
  }
}
