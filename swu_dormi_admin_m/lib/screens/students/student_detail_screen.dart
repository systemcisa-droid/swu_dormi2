import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/student_model.dart';

class StudentDetailScreen extends StatefulWidget {
  final StudentModel student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _dateFormat = DateFormat('yyyy.MM.dd HH:mm');

  // 동의 서명
  Map<String, dynamic>? _regulationAgreement;
  Map<String, dynamic>? _moveOutAgreement;
  bool _isLoadingAgreements = true;

  static const _moveOutStatusOptions = ['만기퇴사', '자진퇴사', '강제퇴사', '영구퇴사'];
  static bool _isMoveOutStatus(String status) => status == '퇴사' || _moveOutStatusOptions.contains(status);

  static Color _statusColor(String status) {
    if (status == '바롬인성교육관') return Colors.orange.shade800;
    if (_isMoveOutStatus(status)) return Colors.red.shade700;
    return Colors.green.shade700;
  }

  @override
  void initState() {
    super.initState();
    _loadAgreements();
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

  @override
  Widget build(BuildContext context) {
    final student = widget.student;

    return Scaffold(
      appBar: AppBar(
        title: Text(student.name),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
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
              ],
            ),
            const SizedBox(height: 20),

            // ── 기본 정보 ──
            _sectionCard(
              title: '기본 정보',
              child: Column(
                children: [
                  _infoRow('건물', student.dormBuilding ?? '-'),
                  _divider(),
                  _infoRow('호실', student.roomCapacity.isNotEmpty ? '${student.roomNumber}호 (${student.roomCapacity})' : '${student.roomNumber}호'),
                  if (student.seatNumber != null && student.seatNumber!.isNotEmpty) ...[
                    _divider(),
                    _infoRow('자리번호', student.seatNumber!),
                  ],
                  _divider(),
                  _infoRow('학번', student.studentId),
                  _divider(),
                  _infoRow('이메일', student.email),
                  _divider(),
                  _infoRow('학과', (student.department != null && student.department!.isNotEmpty) ? student.department! : '-'),
                  _divider(),
                  _infoRow('가입일', DateFormat('yyyy년 MM월 dd일').format(student.createdAt)),
                  _divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(
                            '학생상태',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColor(student.residentStatus.isEmpty ? '재실중' : student.residentStatus).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _statusColor(student.residentStatus.isEmpty ? '재실중' : student.residentStatus).withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              student.residentStatus.isEmpty ? '재실중' : student.residentStatus,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _statusColor(student.residentStatus.isEmpty ? '재실중' : student.residentStatus),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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

  Widget _sectionCard({required String title, required Widget child}) {
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
