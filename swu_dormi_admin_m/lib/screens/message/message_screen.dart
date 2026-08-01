import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MessageScreen extends StatefulWidget {
  const MessageScreen({super.key});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  bool _isLoadingStudents = true;
  bool _isSending = false;
  List<Map<String, dynamic>> _students = [];
  Set<String> _selectedStudentIds = {};
  String _filterType = 'all'; // all, floor, building

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoadingStudents = true);
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .orderBy('roomNumber')
          .get();
      
      setState(() {
        _students = snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
        _isLoadingStudents = false;
      });
    } catch (e) {
      debugPrint('학생 목록 로딩 오류: $e');
      setState(() => _isLoadingStudents = false);
    }
  }

  List<String> _getFilteredUserIds() {
    if (_filterType == 'all') {
      return _students.map((s) => s['id'] as String).toList();
    }
    
    // 선택된 학생만
    return _selectedStudentIds.toList();
  }

  Future<void> _sendMessage() async {
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목과 내용을 입력해주세요')),
      );
      return;
    }

    final userIds = _getFilteredUserIds();
    if (userIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('수신자를 선택해주세요')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('메시지 발송'),
        content: Text('${userIds.length}명에게 메시지를 발송하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('발송'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSending = true);

    try {
      final batch = _firestore.batch();
      final now = FieldValue.serverTimestamp();

      for (final userId in userIds) {
        final notificationRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .doc();
        
        batch.set(notificationRef, {
          'type': 'message',
          'title': _titleController.text,
          'content': _contentController.text,
          'createdAt': now,
          'isRead': false,
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${userIds.length}명에게 메시지를 발송했습니다')),
        );
        _titleController.clear();
        _contentController.clear();
        setState(() {
          _selectedStudentIds.clear();
          _filterType = 'all';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('메시지 전송'),
      ),
      body: _isLoadingStudents
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 수신자 선택
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.people, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                '수신자',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _filterType == 'all'
                                    ? '전체 ${_students.length}명'
                                    : '${_selectedStudentIds.length}명 선택',
                                style: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'all', label: Text('전체')),
                              ButtonSegment(value: 'select', label: Text('선택')),
                            ],
                            selected: {_filterType == 'all' ? 'all' : 'select'},
                            onSelectionChanged: (value) {
                              setState(() {
                                _filterType = value.first;
                                if (_filterType == 'all') {
                                  _selectedStudentIds.clear();
                                }
                              });
                            },
                          ),
                          if (_filterType != 'all') ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 200,
                              child: ListView.builder(
                                itemCount: _students.length,
                                itemBuilder: (context, index) {
                                  final student = _students[index];
                                  final studentId = student['id'] as String;
                                  final name = student['name'] ?? '이름 없음';
                                  final roomNumber = student['roomNumber'] ?? '';
                                  final isSelected = _selectedStudentIds.contains(studentId);

                                  return CheckboxListTile(
                                    dense: true,
                                    title: Row(
                                      children: [
                                        Text(name),
                                        if (roomNumber.isNotEmpty)
                                          Text(
                                            ' ($roomNumber호)',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 13,
                                            ),
                                          ),
                                      ],
                                    ),
                                    value: isSelected,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedStudentIds.add(studentId);
                                        } else {
                                          _selectedStudentIds.remove(studentId);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedStudentIds = _students
                                          .map((s) => s['id'] as String)
                                          .toSet();
                                    });
                                  },
                                  child: const Text('전체 선택'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() => _selectedStudentIds.clear());
                                  },
                                  child: const Text('선택 해제'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 메시지 입력
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.message, size: 20),
                              SizedBox(width: 8),
                              Text(
                                '메시지',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: '제목',
                              hintText: '메시지 제목을 입력하세요',
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _contentController,
                            decoration: const InputDecoration(
                              labelText: '내용',
                              hintText: '메시지 내용을 입력하세요',
                              alignLabelWithHint: true,
                            ),
                            maxLines: 5,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 발송 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _isSending ? null : _sendMessage,
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send),
                      label: Text(_isSending ? '발송 중...' : '메시지 발송'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
