import 'package:fluent_ui/fluent_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── 상수 ──────────────────────────────────────────────────────
const _roles = ['실장', '직원', '근로학생'];
const _roleColors = {
  '실장': Color(0xFF1565C0),
  '직원': Color(0xFF2E7D32),
  '근로학생': Color(0xFF6A1B9A),
};
const _roleIcons = {
  '실장': FluentIcons.manager_self_service,
  '직원': FluentIcons.contact,
  '근로학생': FluentIcons.education,
};

class WindowsOrganizationScreen extends StatefulWidget {
  const WindowsOrganizationScreen({super.key});

  @override
  State<WindowsOrganizationScreen> createState() =>
      _WindowsOrganizationScreenState();
}

class _WindowsOrganizationScreenState
    extends State<WindowsOrganizationScreen> {

  // ──────────────────── 다이얼로그 ────────────────────────────
  Future<void> _showAddEditDialog({
    Map<String, dynamic>? member,
    String? defaultRole,
  }) async {
    final isEdit = member != null;
    String selRole =
        isEdit ? (member['role'] as String? ?? '직원') : (defaultRole ?? '직원');
    final nameCtrl =
        TextEditingController(text: isEdit ? member['name'] as String? ?? '' : '');
    final phoneCtrl =
        TextEditingController(text: isEdit ? member['phone'] as String? ?? '' : '');
    final emailCtrl =
        TextEditingController(text: isEdit ? member['email'] as String? ?? '' : '');
    final noteCtrl =
        TextEditingController(text: isEdit ? member['note'] as String? ?? '' : '');

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => ContentDialog(
          title: Text(isEdit ? '구성원 수정' : '구성원 추가'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 직책
                  const Text('직책',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: _roles.map((role) {
                      final color = _roleColors[role]!;
                      final sel = selRole == role;
                      return GestureDetector(
                        onTap: () => setD(() => selRole = role),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: sel
                                ? color.withValues(alpha: 0.15)
                                : Colors.grey.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: sel
                                  ? color
                                  : Colors.grey.withValues(alpha: 0.25),
                              width: sel ? 1.5 : 1,
                            ),
                          ),
                          child: Text(role,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: sel ? color : null,
                                  fontWeight: sel
                                      ? FontWeight.w600
                                      : FontWeight.normal)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('이름',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextBox(controller: nameCtrl, placeholder: '이름을 입력하세요'),
                  const SizedBox(height: 14),
                  const Text('연락처',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextBox(
                      controller: phoneCtrl,
                      placeholder: '010-0000-0000 (선택)'),
                  const SizedBox(height: 14),
                  const Text('이메일',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextBox(
                      controller: emailCtrl,
                      placeholder: '이메일 (선택)'),
                  const SizedBox(height: 14),
                  const Text('메모',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextBox(
                      controller: noteCtrl,
                      placeholder: '메모 (선택)',
                      maxLines: 2),
                ],
              ),
            ),
          ),
          actions: [
            if (isEdit)
              Button(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(
                      Colors.red.withValues(alpha: 0.1)),
                ),
                child: Text('삭제', style: TextStyle(color: Colors.red)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _delete(member['id'] as String);
                },
              ),
            Button(
                child: const Text('취소'),
                onPressed: () => Navigator.pop(ctx)),
            FilledButton(
              child: Text(isEdit ? '저장' : '추가'),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                await _save(
                  id: isEdit ? member['id'] as String : null,
                  role: selRole,
                  name: name,
                  phone: phoneCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  note: noteCtrl.text.trim(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save({
    String? id,
    required String role,
    required String name,
    required String phone,
    required String email,
    required String note,
  }) async {
    try {
      final data = {
        'role': role,
        'name': name,
        'phone': phone,
        'email': email,
        'note': note,
        'order': _roles.indexOf(role),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final col =
          FirebaseFirestore.instance.collection('organization');
      if (id == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await col.add(data);
      } else {
        await col.doc(id).update(data);
      }
    } catch (e) {
      if (mounted) {
        await displayInfoBar(context,
            builder: (c, _) => InfoBar(
                title: Text('오류: $e'),
                severity: InfoBarSeverity.error));
      }
    }
  }

  Future<void> _delete(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection('organization')
          .doc(id)
          .delete();
    } catch (e) {
      if (mounted) {
        await displayInfoBar(context,
            builder: (c, _) => InfoBar(
                title: Text('오류: $e'),
                severity: InfoBarSeverity.error));
      }
    }
  }

  // ──────────────────── build ─────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: const Text('조직도'),
        commandBar: FilledButton(
          onPressed: () => _showAddEditDialog(),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.add, size: 14),
              SizedBox(width: 6),
              Text('구성원 추가'),
            ],
          ),
        ),
      ),
      content: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('organization')
            .orderBy('order')
            .orderBy('createdAt')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: ProgressRing());
          }

          final docs = snapshot.data?.docs ?? [];
          final members = docs
              .map((d) => {'id': d.id, ...(d.data() as Map<String, dynamic>)})
              .toList();

          final byRole = <String, List<Map<String, dynamic>>>{};
          for (final role in _roles) {
            byRole[role] = members
                .where((m) => m['role'] == role)
                .toList();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                // ── 실장 ─────────────────────────────────────
                _buildRoleSection('실장', byRole['실장'] ?? []),
                _buildConnector(),
                // ── 직원 ─────────────────────────────────────
                _buildRoleSection('직원', byRole['직원'] ?? []),
                _buildConnector(),
                // ── 근로학생 ──────────────────────────────────
                _buildRoleSection('근로학생', byRole['근로학생'] ?? []),
              ],
            ),
          );
        },
      ),
    );
  }

  // ──────────────────── 직책별 섹션 ───────────────────────────
  Widget _buildRoleSection(
      String role, List<Map<String, dynamic>> members) {
    final color = _roleColors[role]!;
    final icon = _roleIcons[role]!;

    return Column(
      children: [
        // 직책 레이블
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(role,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${members.length}명',
                    style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // 멤버 카드들
        members.isEmpty
            ? _buildEmptyCard(role, color)
            : Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  ...members.map((m) => _buildMemberCard(m, color)),
                  // 추가 버튼
                  _buildAddCard(color, role),
                ],
              ),
      ],
    );
  }

  // ──────────────────── 멤버 카드 ─────────────────────────────
  Widget _buildMemberCard(Map<String, dynamic> m, Color color) {
    final name = m['name'] as String? ?? '';
    final phone = m['phone'] as String? ?? '';
    final email = m['email'] as String? ?? '';
    final note = m['note'] as String? ?? '';

    return GestureDetector(
      onTap: () => _showAddEditDialog(member: m),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FluentTheme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 아바타
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                    color: color.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0] : '?',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // 이름
            Text(name,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            // 연락처
            if (phone.isNotEmpty) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.phone, size: 11, color: Colors.grey),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(phone,
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 2),
            ],
            // 이메일
            if (email.isNotEmpty) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.mail, size: 11, color: Colors.grey),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(email,
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 2),
            ],
            // 메모
            if (note.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(note,
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2),
              ),
          ],
        ),
      ),
    );
  }

  // ──────────────────── 추가 카드 ─────────────────────────────
  Widget _buildAddCard(Color color, String role) {
    return GestureDetector(
      onTap: () => _showAddEditDialog(defaultRole: role),
      child: Container(
        width: 160,
        height: 130,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: Colors.grey.withValues(alpha: 0.2),
              style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(FluentIcons.add, size: 16, color: color),
            ),
            const SizedBox(height: 6),
            Text('$role 추가',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // ──────────────────── 빈 섹션 카드 ──────────────────────────
  Widget _buildEmptyCard(String role, Color color) {
    return GestureDetector(
      onTap: () => _showAddEditDialog(defaultRole: role),
      child: Container(
        width: 200,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(FluentIcons.add_friend, size: 28,
                color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            Text('$role 추가',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }

  // ──────────────────── 계층 연결선 ───────────────────────────
  Widget _buildConnector() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: CustomPaint(
        size: const Size(double.infinity, 30),
        painter: _ConnectorPainter(),
      ),
    );
  }
}

// ── 계층 연결선 Painter ────────────────────────────────────────
class _ConnectorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF9E9E9E).withValues(alpha: 0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    // 수직선
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), paint);
    // 화살표
    canvas.drawLine(
        Offset(cx, size.height),
        Offset(cx - 6, size.height - 8),
        paint);
    canvas.drawLine(
        Offset(cx, size.height),
        Offset(cx + 6, size.height - 8),
        paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
