import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import 'notification_settings_screen.dart';
import 'privacy_policy_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _adminData;
  bool _isLoading = true;

  static const List<String> _floorOptions = [
    '샬롬하우스 A동 2층',
    '샬롬하우스 A동 3층',
    '샬롬하우스 A동 4층',
    '샬롬하우스 A동 5층',
    '샬롬하우스 A동 6층',
    '샬롬하우스 A동 7층',
    '샬롬하우스 B동 2층',
    '샬롬하우스 B동 3층',
    '샬롬하우스 B동 4층',
    '샬롬하우스 B동 5층',
    '샬롬하우스 B동 6층',
    '샬롬하우스 B동 7층',
    '국제생활관 A동 1층',
    '국제생활관 A동 2층',
    '국제생활관 B동 2층',
    '국제생활관 B동 3층',
    '바롬인성교육관 10층',
    '샬롬하우스(겨울방학) A동 5층',
    '샬롬하우스(겨울방학) A동 6층',
    '샬롬하우스(겨울방학) A동 7층',
  ];

  static const List<String> _dormBuildingOptions = [
    '샬롬하우스',
    '국제생활관',
    '바롬인성교육관',
    '샬롬하우스(겨울방학)',
  ];

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    setState(() => _isLoading = true);
    try {
      final uid = _authService.currentUser?.uid;
      if (uid == null) return;
      final doc = await _firestore.collection('users').doc(uid).get();
      if (mounted) {
        setState(() {
          _adminData = doc.data();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _authService.signOut();
    }
  }

  void _showChangePasswordDialog() {
    final currentPwCtrl = TextEditingController();
    final newPwCtrl = TextEditingController();
    final confirmPwCtrl = TextEditingController();
    bool obscure1 = true, obscure2 = true, obscure3 = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('비밀번호 변경'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPwCtrl,
                obscureText: obscure1,
                decoration: InputDecoration(
                  labelText: '현재 비밀번호',
                  suffixIcon: IconButton(
                    icon: Icon(obscure1 ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => obscure1 = !obscure1),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPwCtrl,
                obscureText: obscure2,
                decoration: InputDecoration(
                  labelText: '새 비밀번호',
                  suffixIcon: IconButton(
                    icon: Icon(obscure2 ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => obscure2 = !obscure2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPwCtrl,
                obscureText: obscure3,
                decoration: InputDecoration(
                  labelText: '새 비밀번호 확인',
                  suffixIcon: IconButton(
                    icon: Icon(obscure3 ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => obscure3 = !obscure3),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _changePassword(
                  currentPwCtrl.text.trim(),
                  newPwCtrl.text.trim(),
                  confirmPwCtrl.text.trim(),
                );
              },
              child: const Text('변경'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePassword(
      String current, String newPw, String confirm) async {
    if (newPw != confirm) {
      _showSnack('새 비밀번호가 일치하지 않습니다', Colors.red);
      return;
    }
    if (newPw.length < 6) {
      _showSnack('비밀번호는 6자 이상이어야 합니다', Colors.red);
      return;
    }
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final cred = EmailAuthProvider.credential(
          email: user.email!, password: current);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPw);
      _showSnack('비밀번호가 변경되었습니다', Colors.green);
    } on FirebaseAuthException catch (e) {
      _showSnack(
        e.code == 'wrong-password' ? '현재 비밀번호가 올바르지 않습니다' : '오류: ${e.message}',
        Colors.red,
      );
    }
  }

  Future<void> _saveAssignedFloor(String? floor) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore.collection('users').doc(uid).update({
        'assignedFloor': floor,
      });
      setState(() {
        _adminData = {...?_adminData, 'assignedFloor': floor};
      });
      _showSnack('담당 점검구역이 저장되었습니다', Colors.green);
    } catch (_) {
      _showSnack('저장에 실패했습니다', Colors.red);
    }
  }

  void _showEditProfileDialog({
    required String currentName,
    required String currentStudentId,
    required String currentDepartment,
  }) {
    final nameCtrl = TextEditingController(text: currentName);
    final studentIdCtrl = TextEditingController(text: currentStudentId);
    final departmentCtrl = TextEditingController(text: currentDepartment);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('프로필 수정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: '이름',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: studentIdCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '학번',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: departmentCtrl,
                decoration: const InputDecoration(
                  labelText: '학과',
                  prefixIcon: Icon(Icons.history_edu_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    '이메일은 변경할 수 없습니다',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final studentId = studentIdCtrl.text.trim();
              final department = departmentCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              _saveProfileData(
                name: name,
                studentId: studentId,
                department: department,
              );
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfileData({
    required String name,
    required String studentId,
    required String department,
  }) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore.collection('users').doc(uid).update({
        'name': name,
        'studentId': studentId,
        'department': department,
      });
      setState(() {
        _adminData = {
          ...?_adminData,
          'name': name,
          'studentId': studentId,
          'department': department,
        };
      });
      _showSnack('프로필 정보가 변경되었습니다', Colors.green);
    } catch (_) {
      _showSnack('저장에 실패했습니다', Colors.red);
    }
  }

  void _showEditContactDialog() {
    final phoneCtrl = TextEditingController(
        text: _adminData?['phone'] as String? ?? '');
    String? selectedBuilding = _adminData?['dormBuilding'] as String?;
    if (selectedBuilding != null &&
        !_dormBuildingOptions.contains(selectedBuilding)) {
      selectedBuilding = null;
    }
    final roomCtrl = TextEditingController(
        text: _adminData?['roomNumber'] as String? ?? '');
    final seatCtrl = TextEditingController(
        text: _adminData?['seatNumber'] as String? ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('기숙사 정보 편집'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: '전화번호',
                    prefixIcon: Icon(Icons.phone_outlined),
                    hintText: '010-0000-0000',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedBuilding,
                  decoration: const InputDecoration(
                    labelText: '기숙사 건물',
                    prefixIcon: Icon(Icons.apartment_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('선택 안함')),
                    ..._dormBuildingOptions.map((b) =>
                        DropdownMenuItem(value: b, child: Text(b))),
                  ],
                  onChanged: (v) => setDialogState(() => selectedBuilding = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: roomCtrl,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    labelText: '호실',
                    prefixIcon: Icon(Icons.door_front_door_outlined),
                    hintText: '예) 301',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: seatCtrl,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    labelText: '자리번호',
                    prefixIcon: Icon(Icons.event_seat_outlined),
                    hintText: '예) A',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _saveContactInfo(
                  phone: phoneCtrl.text.trim(),
                  dormBuilding: selectedBuilding,
                  roomNumber: roomCtrl.text.trim(),
                  seatNumber: seatCtrl.text.trim(),
                );
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveContactInfo({
    required String phone,
    required String? dormBuilding,
    required String roomNumber,
    required String seatNumber,
  }) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore.collection('users').doc(uid).update({
        'phone': phone,
        'dormBuilding': dormBuilding,
        'roomNumber': roomNumber,
        'seatNumber': seatNumber,
      });
      setState(() {
        _adminData = {
          ...?_adminData,
          'phone': phone,
          'dormBuilding': dormBuilding,
          'roomNumber': roomNumber,
          'seatNumber': seatNumber,
        };
      });
      _showSnack('기숙사 정보가 저장되었습니다', Colors.green);
    } catch (_) {
      _showSnack('저장에 실패했습니다', Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final name = _adminData?['name'] as String? ?? user?.email ?? '-';
    final email = user?.email ?? '-';
    final role = _adminData?['role'] as String? ?? 'admin';
    final createdAtRaw = _adminData?['createdAt'];
    final createdAt = createdAtRaw is Timestamp
        ? createdAtRaw.toDate()
        : createdAtRaw is String
            ? DateTime.tryParse(createdAtRaw)
            : null;
    final assignedFloor = _adminData?['assignedFloor'] as String?;
    final phone = _adminData?['phone'] as String?;
    final dormBuilding = _adminData?['dormBuilding'] as String?;
    final roomNumber = _adminData?['roomNumber'] as String?;
    final seatNumber = _adminData?['seatNumber'] as String?;
    final studentId = _adminData?['studentId'] as String? ?? '';
    final department = _adminData?['department'] as String? ?? '';

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAdminData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // 프로필 헤더
                    Container(
                      width: double.infinity,
                      color: Theme.of(context).primaryColor,
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'A',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              role == 'admin' ? '층장' : role,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 계정 정보
                    _buildSection(
                      title: '계정 정보',
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _showEditProfileDialog(
                          currentName: name,
                          currentStudentId: studentId,
                          currentDepartment: department,
                        ),
                        tooltip: '편집',
                      ),
                      children: [
                        _buildInfoTile(Icons.person_outline, '이름', name),
                        _buildInfoTile(Icons.email_outlined, '이메일', email),
                        _buildInfoTile(
                          Icons.badge_outlined,
                          '학번',
                          studentId.isNotEmpty ? studentId : '-',
                        ),
                        _buildInfoTile(
                          Icons.history_edu_outlined,
                          '학과',
                          department.isNotEmpty ? department : '-',
                        ),

                        _buildInfoTile(Icons.admin_panel_settings_outlined, '권한',
                            role == 'admin' ? '층장' : role),
                        if (createdAt != null)
                          _buildInfoTile(
                            Icons.calendar_today_outlined,
                            '가입일',
                            '${createdAt.year}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.day.toString().padLeft(2, '0')}',
                          ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // 기숙사 정보
                    _buildSection(
                      title: '기숙사 정보',
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: _showEditContactDialog,
                        tooltip: '편집',
                      ),
                      children: [
                        _buildInfoTile(
                          Icons.phone_outlined,
                          '전화번호',
                          phone?.isNotEmpty == true ? phone! : '-',
                        ),
                        _buildInfoTile(
                          Icons.apartment_outlined,
                          '기숙사 건물',
                          dormBuilding?.isNotEmpty == true ? dormBuilding! : '-',
                        ),
                        _buildInfoTile(
                          Icons.door_front_door_outlined,
                          '호실',
                          roomNumber?.isNotEmpty == true ? roomNumber! : '-',
                        ),
                        _buildInfoTile(
                          Icons.event_seat_outlined,
                          '자리번호',
                          seatNumber?.isNotEmpty == true ? seatNumber! : '-',
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // 담당 점검 구역
                    _buildSection(
                      title: '담당 점검 구역',
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: DropdownButtonFormField<String>(
                            key: ValueKey(assignedFloor),
                            initialValue: _floorOptions.contains(assignedFloor)
                                ? assignedFloor
                                : null,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.layers_outlined),
                            ),
                            items: [
                              const DropdownMenuItem(
                                  value: null, child: Text('미지정')),
                              ..._floorOptions.map((f) =>
                                  DropdownMenuItem(value: f, child: Text(f))),
                            ],
                            onChanged: _saveAssignedFloor,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // 알림 설정
                    _buildSection(
                      title: '알림 설정',
                      children: [
                        ListTile(
                          leading: const Icon(Icons.notifications_outlined),
                          title: const Text('알림 설정'),
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const NotificationSettingsScreen()),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // 보안
                    _buildSection(
                      title: '보안',
                      children: [
                        ListTile(
                          leading: const Icon(Icons.lock_outline),
                          title: const Text('비밀번호 변경'),
                          trailing: const Icon(Icons.chevron_right,
                              color: Colors.grey),
                          onTap: _showChangePasswordDialog,
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // 약관 및 정책
                    _buildSection(
                      title: '약관 및 정책',
                      children: [
                        ListTile(
                          leading: const Icon(Icons.privacy_tip_outlined),
                          title: const Text('개인정보 처리방침 및 회원탈퇴'),
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // 로그아웃
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _handleLogout,
                          icon: const Icon(Icons.logout, color: Colors.red),
                          label: const Text('로그아웃',
                              style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.5,
                ),
              ),
              if (trailing != null) ...[
                const Spacer(),
                trailing,
              ],
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey.shade600),
      title: Text(label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
      subtitle: Text(value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
    );
  }
}
