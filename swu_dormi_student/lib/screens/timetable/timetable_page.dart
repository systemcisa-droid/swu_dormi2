import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/constants.dart';

// --- Models ---

class ClassItem {
  String id;
  String title;
  String room;
  int dayIndex; // 0: Mon, 1: Tue, ...
  int startHour; // e.g., 9
  int startMinute; // e.g., 30
  double durationMinutes; // e.g., 90
  Color color;

  ClassItem({
    required this.id,
    required this.title,
    required this.room,
    required this.dayIndex,
    required this.startHour,
    required this.startMinute,
    required this.durationMinutes,
    required this.color,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'room': room,
      'dayIndex': dayIndex,
      'startHour': startHour,
      'startMinute': startMinute,
      'durationMinutes': durationMinutes,
      'color': color.value,
    };
  }

  factory ClassItem.fromMap(Map<String, dynamic> map) {
    return ClassItem(
      id: map['id'],
      title: map['title'],
      room: map['room'],
      dayIndex: map['dayIndex'],
      startHour: map['startHour'],
      startMinute: map['startMinute'],
      durationMinutes: map['durationMinutes'].toDouble(),
      color: Color(map['color']),
    );
  }
}

class TimetableData {
  String id;
  String name;
  List<ClassItem> classes;

  TimetableData({
    required this.id,
    required this.name,
    required this.classes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'classes': classes.map((x) => x.toMap()).toList(),
    };
  }

  factory TimetableData.fromMap(Map<String, dynamic> map) {
    return TimetableData(
      id: map['id'],
      name: map['name'],
      classes: List<ClassItem>.from(
        map['classes']?.map((x) => ClassItem.fromMap(x)) ?? [],
      ),
    );
  }
}

// --- Page ---

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  bool _isGridView = true;
  
  // Multiple Timetables State
  late List<TimetableData> _timetables;
  late String _currentTimetableId;

  @override
  void initState() {
    super.initState();
    // Initialize with empty/default first, then load
    _timetables = [];
    _currentTimetableId = '';
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? timetablesJson = prefs.getString('timetables_data');
    final String? currentId = prefs.getString('current_timetable_id');

    if (timetablesJson != null) {
      final List<dynamic> decoded = jsonDecode(timetablesJson);
      setState(() {
        _timetables = decoded.map((x) => TimetableData.fromMap(x)).toList();
        if (_timetables.isNotEmpty) {
          // Verify currentId exists
          if (currentId != null && _timetables.any((t) => t.id == currentId)) {
            _currentTimetableId = currentId;
          } else {
            _currentTimetableId = _timetables.first.id;
          }
        } else {
          _initializeData();
        }
      });
    } else {
      _initializeData();
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonStr = jsonEncode(_timetables.map((t) => t.toMap()).toList());
    await prefs.setString('timetables_data', jsonStr);
    await prefs.setString('current_timetable_id', _currentTimetableId);
  }

  void _initializeData() {
    final defaultClasses = [
      ClassItem(
        id: '1', title: '알고리즘', room: '제1과학관 201호', dayIndex: 0,
        startHour: 10, startMinute: 0, durationMinutes: 120, color: const Color(0xFFFDE4E4),
      ),
      ClassItem(
        id: '2', title: '컴퓨터구조', room: '인문사회관 304호', dayIndex: 1,
        startHour: 13, startMinute: 30, durationMinutes: 90, color: const Color(0xFFE4F1FD),
      ),
      ClassItem(
        id: '3', title: '데이터베이스', room: '50주년기념관 402호', dayIndex: 2,
        startHour: 15, startMinute: 0, durationMinutes: 180, color: const Color(0xFFFDF4E4),
      ),
      ClassItem(
        id: '4', title: '운영체제', room: '누리관 101호', dayIndex: 3,
        startHour: 11, startMinute: 0, durationMinutes: 90, color: const Color(0xFFE4FDE9),
      ),
      ClassItem(
        id: '5', title: '졸업프로젝트', room: '제2과학관 303호', dayIndex: 4,
        startHour: 9, startMinute: 0, durationMinutes: 120, color: const Color(0xFFF3E4FD),
      ),
    ];

    _timetables = [
      TimetableData(id: '1', name: '2025년 1학기', classes: defaultClasses),
    ];
    _currentTimetableId = '1';
    _saveData(); // Save initial data
  }

  TimetableData get _currentTimetable {
    if (_timetables.isEmpty) {
      // Return a dummy safe object if empty (shouldn't happen after init)
      return TimetableData(id: 'temp', name: 'Loading...', classes: []);
    }
    return _timetables.firstWhere(
      (t) => t.id == _currentTimetableId,
      orElse: () => _timetables.first,
    );
  }

  List<ClassItem> get _classes => _currentTimetable.classes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        title: GestureDetector(
          onTap: _showTimetableManager,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentTimetable.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, color: Colors.black),
              ],
            ),
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // View Toggle
          IconButton(
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
            icon: Icon(
              _isGridView ? Icons.list : Icons.grid_view,
              color: Colors.grey[700],
            ),
          ),
          IconButton(
            onPressed: () => _showAddEditDialog(),
            icon: Icon(Icons.add_box_outlined, color: Colors.grey[700]),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isGridView ? _buildGridView() : _buildListView(),
    );
  }

  // --- Grid View ---

  Widget _buildGridView() {
    return Column(
      children: [
        // Days Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey[200]!),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 24), // Time column width
              ...List.generate(5, (index) {
                final days = ['월', '화', '수', '목', '금'];
                return Expanded(
                  child: Center(
                    child: Text(
                      days[index],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        // Time Grid
        Expanded(
          child: SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time Column
                SizedBox(
                  width: 24,
                  child: Column(
                    children: List.generate(
                      15, // 8 to 22
                      (index) => SizedBox(
                        height: 60,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '${index + 8}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Grid Area
                Expanded(
                  child: Stack(
                    children: [
                      // Horizontal Lines
                      Column(
                        children: List.generate(
                          15,
                          (index) => Container(
                            height: 60,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.grey[100]!),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Vertical Lines
                      Row(
                        children: List.generate(
                          5,
                          (index) => Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  right: index < 4
                                      ? BorderSide(color: Colors.grey[100]!)
                                      : BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Class Blocks
                      ..._classes.map(_buildGridClassItem),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGridClassItem(ClassItem item) {
    // 1 hour = 60 logical pixels
    // Start 8:00 = 0
    double top = ((item.startHour - 8) * 60.0) + item.startMinute;
    double height = item.durationMinutes;

    return Positioned(
      top: top,
      left: (MediaQuery.of(context).size.width - 24) / 5 * item.dayIndex,
      width: (MediaQuery.of(context).size.width - 24) / 5,
      height: height,
      child: Container(
        margin: const EdgeInsets.all(1),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: item.color,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              item.room,
              style: TextStyle(
                fontSize: 9,
                color: Colors.black.withValues(alpha: 0.6),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // --- List View ---

  Widget _buildListView() {
    // Sort by Day then Time
    final sortedClasses = List<ClassItem>.from(_classes)
      ..sort((a, b) {
        if (a.dayIndex != b.dayIndex) return a.dayIndex.compareTo(b.dayIndex);
        return (a.startHour * 60 + a.startMinute)
            .compareTo(b.startHour * 60 + b.startMinute);
      });

    final days = ['월요일', '화요일', '수요일', '목요일', '금요일'];

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sortedClasses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = sortedClasses[index];
        return Dismissible(
          key: ValueKey(item.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (_) => _confirmDeleteClass(item),
          onDismissed: (_) {
            setState(() {
              _classes.removeWhere((c) => c.id == item.id);
            });
            _saveData();
          },
          child: GestureDetector(
            onTap: () => _showAddEditDialog(item: item),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(color: Colors.grey[100]!),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: item.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${days[item.dayIndex]} ${_formatTime(item.startHour, item.startMinute)} - ${_formatTimeEnd(item.startHour, item.startMinute, item.durationMinutes)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    item.room,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 시간표 삭제 전 확인 다이얼로그. 실수로 스와이프해 지우는 것을 막는다.
  Future<bool> _confirmDeleteClass(ClassItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('시간표 삭제'),
        content: Text('「${item.title}」을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  String _formatTime(int h, int m) {
    return '${h.toString()}:${m.toString().padLeft(2, '0')}';
  }

  String _formatTimeEnd(int h, int m, double duration) {
    int totalMin = h * 60 + m + duration.toInt();
    int endH = totalMin ~/ 60;
    int endM = totalMin % 60;
    return '${endH.toString()}:${endM.toString().padLeft(2, '0')}';
  }

  // --- Timetable Manager ---

  void _showTimetableManager() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '시간표 목록',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ..._timetables.map((timetable) => ListTile(
                leading: Icon(
                  Icons.schedule,
                  color: timetable.id == _currentTimetableId
                      ? AppConstants.primaryColor
                      : Colors.grey,
                ),
                title: Text(
                  timetable.name,
                  style: TextStyle(
                    fontWeight: timetable.id == _currentTimetableId
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: timetable.id == _currentTimetableId
                        ? AppConstants.primaryColor
                        : Colors.black87,
                  ),
                ),
                trailing: timetable.id == _currentTimetableId
                    ? Icon(Icons.check, color: AppConstants.primaryColor)
                    : null,
                onTap: () {
                  setState(() {
                    _currentTimetableId = timetable.id;
                  });
                  _saveData();
                  Navigator.pop(context);
                },
              )),
              ListTile(
                leading: const Icon(Icons.add, color: Colors.grey),
                title: const Text('새 시간표 만들기'),
                onTap: () {
                  Navigator.pop(context);
                  _showCreateTimetableDialog();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateTimetableDialog() {
    // Generate semester options
    final years = List.generate(4, (index) => 2024 + index); // 2024 ~ 2027
    final semesters = ['1학기', '여름학기', '2학기', '겨울학기'];
    final List<String> options = [];
    for (var year in years) {
      for (var semester in semesters) {
        options.add('$year-$semester');
      }
    }
    
    String selectedOption = '2025-2학기'; // Default

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('새 시간표 만들기'),
            content: DropdownButtonFormField<String>(
              value: selectedOption,
              decoration: const InputDecoration(
                labelText: '학기 선택',
                border: OutlineInputBorder(),
              ),
              items: options.map((opt) => DropdownMenuItem(
                value: opt,
                child: Text(opt),
              )).toList(),
              onChanged: (val) {
                if (val != null) {
                  setDialogState(() => selectedOption = val);
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    final newId = DateTime.now().millisecondsSinceEpoch.toString();
                    _timetables.add(TimetableData(
                      id: newId,
                      name: selectedOption,
                      classes: [],
                    ));
                    _currentTimetableId = newId;
                  });
                  _saveData();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('만들기'),
              ),
            ],
          );
        }
      ),
    );
  }


  // --- Add/Edit Dialog ---

  void _showAddEditDialog({ClassItem? item}) {
    final isEditing = item != null;
    final titleController = TextEditingController(text: item?.title ?? '');

    // Parse existing room
    String existingRoom = item?.room ?? '';
    String selectedBuilding = '직접넣기';
    String roomNumber = existingRoom;

    final buildings = ['인사대', '50주년기념관', '1과학관', '2과학관', '조형예술관', '직접넣기'];
    
    for (var building in buildings) {
      if (building != '직접넣기' && existingRoom.startsWith(building)) {
        selectedBuilding = building;
        roomNumber = existingRoom.substring(building.length).trim();
        break;
      }
    }

    final roomController = TextEditingController(text: roomNumber);
    
    int selectedDay = item?.dayIndex ?? 0;
    int startHour = item?.startHour ?? 8;
    int startMinute = item?.startMinute ?? 0;
    int duration = item?.durationMinutes.toInt() ?? 90; // Default 1.5h
    Color selectedColor = item?.color ?? const Color(0xFFFDE4E4);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditing ? '수업 수정' : '새 수업 추가',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: '강의명',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Room Selection (Building Dropdown + Number TextField)
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          value: selectedBuilding,
                          decoration: const InputDecoration(
                            labelText: '건물',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                          ),
                          isExpanded: true,
                          items: buildings.map((b) => DropdownMenuItem(
                            value: b,
                            child: Text(
                              b,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => selectedBuilding = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: roomController,
                          decoration: const InputDecoration(
                            labelText: '호수 (또는 강의실명)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      // Day Dropdown
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<int>(
                          value: selectedDay,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: '요일',
                            isDense: true,
                            contentPadding:
                                EdgeInsets.symmetric(vertical: 12),
                          ),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('월')),
                            DropdownMenuItem(value: 1, child: Text('화')),
                            DropdownMenuItem(value: 2, child: Text('수')),
                            DropdownMenuItem(value: 3, child: Text('목')),
                            DropdownMenuItem(value: 4, child: Text('금')),
                          ],
                          onChanged: (val) => setModalState(() => selectedDay = val!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Start Hour
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<int>(
                          value: startHour,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: '시작 시',
                            isDense: true,
                            contentPadding:
                                EdgeInsets.symmetric(vertical: 12),
                          ),
                          items: List.generate(
                            15,
                            (index) => DropdownMenuItem(
                              value: index + 8,
                              child: Text('${index + 8}시'),
                            ),
                          ),
                          onChanged: (val) => setModalState(() => startHour = val!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Start Minute
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<int>(
                          value: startMinute,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: '분',
                            isDense: true,
                            contentPadding:
                                EdgeInsets.symmetric(vertical: 12),
                          ),
                          items: [0, 15, 30, 45].map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(m == 0 ? '00분' : '$m분'),
                          )).toList(),
                          onChanged: (val) => setModalState(() => startMinute = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Duration Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('수업 시간'),
                      Text(
                        '$duration분 (${(duration / 60).toStringAsFixed(1)}시간)',
                         style: TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Slider(
                    value: duration.toDouble(),
                    min: 15,
                    max: 240,
                    divisions: 15,
                    label: '$duration분',
                    onChanged: (val) => setModalState(() => duration = val.toInt()),
                  ),
                  const SizedBox(height: 12),
                  // Color Picker
                  const Text('색상'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      0xFFFDE4E4, 0xFFE4F1FD, 0xFFFDF4E4, 0xFFE4FDE9,
                      0xFFF3E4FD, 0xFFE4E4FD, 0xFFFDE4F3, 0xFFEAEAEA
                    ].map((colorInt) {
                      final color = Color(colorInt);
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedColor = color),
                        child: CircleAvatar(
                          backgroundColor: color,
                          radius: 16,
                          child: selectedColor == color
                              ? const Icon(Icons.check, size: 16, color: Colors.black54)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            if (titleController.text.isEmpty) return;

                            // Calculate new times
                            int newStart = startHour * 60 + startMinute;
                            int newEnd = newStart + duration;

                            // Check Overlap
                            bool hasOverlap = false;
                            for (var c in _classes) {
                              if (isEditing && c.id == item.id) continue;
                              if (c.dayIndex != selectedDay) continue;

                              int cStart = c.startHour * 60 + c.startMinute;
                              int cEnd = cStart + c.durationMinutes.toInt();

                              if (newStart < cEnd && newEnd > cStart) {
                                hasOverlap = true;
                                break;
                              }
                            }

                            if (hasOverlap) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('시간 중복'),
                                  content: const Text('해당 시간에 이미 수업이 있습니다.\n다른 시간을 선택해주세요.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('확인'),
                                    ),
                                  ],
                                ),
                              );
                              return;
                            }
                            
                            // Combine Building and Room
                            String finalRoom = roomController.text;
                            if (selectedBuilding != '직접넣기') {
                              finalRoom = '$selectedBuilding $finalRoom';
                            }

                            setState(() {
                              if (isEditing) {
                                // Update existing
                                item.title = titleController.text;
                                item.room = finalRoom;
                                item.dayIndex = selectedDay;
                                item.startHour = startHour;
                                item.startMinute = startMinute; 
                                item.durationMinutes = duration.toDouble();
                                item.color = selectedColor;
                              } else {
                                // Add new
                                _classes.add(ClassItem(
                                  id: DateTime.now().toString(),
                                  title: titleController.text,
                                  room: finalRoom,
                                  dayIndex: selectedDay,
                                  startHour: startHour,
                                  startMinute: startMinute,
                                  durationMinutes: duration.toDouble(),
                                  color: selectedColor,
                                ));
                              }
                            });
                            _saveData();
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                          ),
                          child: Text(isEditing ? '수정 완료' : '추가하기', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
