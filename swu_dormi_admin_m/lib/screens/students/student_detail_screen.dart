import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/student_model.dart';
import '../../services/firestore_service.dart';

class StudentDetailScreen extends StatefulWidget {
  final StudentModel student;

  const StudentDetailScreen({
    super.key,
    required this.student,
  });

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _roomNumberController;
  late TextEditingController _phoneNumberController;
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _roomNumberController = TextEditingController(text: widget.student.roomNumber);
    _phoneNumberController = TextEditingController(text: widget.student.phoneNumber);
  }

  @override
  void dispose() {
    _roomNumberController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> _updateStudent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirestoreService().updateStudent(
        widget.student.id,
        {
          'roomNumber': _roomNumberController.text.trim(),
          'phoneNumber': _phoneNumberController.text.trim(),
        },
      );

      if (mounted) {
        setState(() {
          _isEditing = false;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('학생 정보가 수정되었습니다'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('학생 정보'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() => _isEditing = true);
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // 프로필 이미지
              CircleAvatar(
                radius: 60,
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                backgroundImage: widget.student.profileImageUrl != null
                    ? NetworkImage(widget.student.profileImageUrl!)
                    : null,
                child: widget.student.profileImageUrl == null
                    ? Icon(
                        Icons.person,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
              ),
              const SizedBox(height: 24),

              // 이름
              Text(
                widget.student.name,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),

              // 학번
              Text(
                widget.student.studentId,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),

              // 정보 섹션
              _buildInfoSection(
                title: '기본 정보',
                children: [
                  _buildInfoRow(
                    icon: Icons.email,
                    label: '이메일',
                    value: widget.student.email,
                  ),
                  const SizedBox(height: 16),
                  _isEditing
                      ? _buildEditableField(
                          icon: Icons.phone,
                          label: '전화번호',
                          controller: _phoneNumberController,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '전화번호를 입력해주세요';
                            }
                            return null;
                          },
                        )
                      : _buildInfoRow(
                          icon: Icons.phone,
                          label: '전화번호',
                          value: widget.student.phoneNumber,
                        ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    icon: Icons.calendar_today,
                    label: '가입일',
                    value: DateFormat('yyyy년 MM월 dd일').format(widget.student.createdAt),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 방 정보
              _buildInfoSection(
                title: '방 정보',
                children: [
                  _isEditing
                      ? _buildEditableField(
                          icon: Icons.door_front_door,
                          label: '방 번호',
                          controller: _roomNumberController,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '방 번호를 입력해주세요';
                            }
                            return null;
                          },
                        )
                      : _buildInfoRow(
                          icon: Icons.door_front_door,
                          label: '방 번호',
                          value: widget.student.roomCapacity.isNotEmpty ? '${widget.student.roomNumber}호 (${widget.student.roomCapacity})' : '${widget.student.roomNumber}호',
                        ),
                ],
              ),
              const SizedBox(height: 32),

              // 수정/취소 버튼
              if (_isEditing) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                setState(() {
                                  _isEditing = false;
                                  _roomNumberController.text = widget.student.roomNumber;
                                  _phoneNumberController.text = widget.student.phoneNumber;
                                });
                              },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('취소'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updateStudent,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('저장'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditableField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: controller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                validator: validator,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
