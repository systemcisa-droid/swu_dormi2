import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/meal_strings.dart';

class MealScreen extends StatefulWidget {
  const MealScreen({super.key});

  @override
  State<MealScreen> createState() => _MealScreenState();
}

class _MealScreenState extends State<MealScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 선택된 연도/월/주차
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  int _selectedWeekNumber = _currentWeekOfMonth();

  // 현재 날짜가 해당 월의 몇 번째 주인지 계산 (1~5)
  // 1~7일 → 1주, 8~14일 → 2주, 15~21일 → 3주, 22~28일 → 4주, 29일~ → 5주
  static int _currentWeekOfMonth() {
    return ((DateTime.now().day - 1) ~/ 7) + 1;
  }

  // 현재 월의 식단표 맵 (weekNumber -> meal data)
  Map<int, Map<String, dynamic>> _mealsByWeek = {};

  @override
  Widget build(BuildContext context) {
    final s = MealStrings(Provider.of<LocaleProvider>(context).isEnglish);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.title),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('meals')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(s.loadError(snapshot.error!)),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 현재 선택된 연도/월의 식단표만 필터링
          _mealsByWeek = {};
          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final year = data['year'] ?? DateTime.now().year;
              final month = data['month'] ?? DateTime.now().month;
              final weekNumber = data['weekNumber'] ?? 1;

              if (year == _selectedYear && month == _selectedMonth) {
                _mealsByWeek[weekNumber] = {
                  ...data,
                  'id': doc.id,
                };
              }
            }
          }

          final selectedMeal = _mealsByWeek[_selectedWeekNumber];

          return Column(
            children: [
              // 상단: 연도/월 선택
              _buildYearMonthSelector(s),
              // 중간: 주차 슬롯
              _buildWeekSlots(s),
              // 하단: PDF 뷰어
              Expanded(
                child: _buildPdfViewer(selectedMeal, s),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 연도/월 선택 위젯
  Widget _buildYearMonthSelector(MealStrings s) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 이전 월 버튼
          IconButton(
            onPressed: () {
              setState(() {
                if (_selectedMonth == 1) {
                  _selectedMonth = 12;
                  _selectedYear--;
                } else {
                  _selectedMonth--;
                }
                _selectedWeekNumber = 1;
              });
            },
            icon: Icon(
              Icons.chevron_left,
              color: Theme.of(context).primaryColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 8),
          // 연도/월 표시
          GestureDetector(
            onTap: () => _showYearMonthPicker(s),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                s.yearMonth(_selectedYear, _selectedMonth),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 다음 월 버튼
          IconButton(
            onPressed: () {
              setState(() {
                if (_selectedMonth == 12) {
                  _selectedMonth = 1;
                  _selectedYear++;
                } else {
                  _selectedMonth++;
                }
                _selectedWeekNumber = 1;
              });
            },
            icon: Icon(
              Icons.chevron_right,
              color: Theme.of(context).primaryColor,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  /// 연도/월 선택 다이얼로그
  void _showYearMonthPicker(MealStrings s) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        int tempYear = _selectedYear;
        int tempMonth = _selectedMonth;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.yearMonthPickerTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 연도 선택
                      DropdownButton<int>(
                        value: tempYear,
                        items: List.generate(5, (index) {
                          final year = DateTime.now().year - 2 + index;
                          return DropdownMenuItem(
                            value: year,
                            child: Text(s.yearLabel(year)),
                          );
                        }),
                        onChanged: (value) {
                          if (value != null) {
                            setModalState(() => tempYear = value);
                          }
                        },
                      ),
                      const SizedBox(width: 20),
                      // 월 선택
                      DropdownButton<int>(
                        value: tempMonth,
                        items: List.generate(12, (index) {
                          final month = index + 1;
                          return DropdownMenuItem(
                            value: month,
                            child: Text(s.monthLabel(month)),
                          );
                        }),
                        onChanged: (value) {
                          if (value != null) {
                            setModalState(() => tempMonth = value);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedYear = tempYear;
                        _selectedMonth = tempMonth;
                        _selectedWeekNumber = 1;
                      });
                      Navigator.pop(context);
                    },
                    child: Text(s.confirm),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 주차 슬롯 위젯
  Widget _buildWeekSlots(MealStrings s) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: List.generate(5, (index) {
            final weekNumber = index + 1;
            final meal = _mealsByWeek[weekNumber];
            final isRegistered = meal != null;
            final isSelected = _selectedWeekNumber == weekNumber;

            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedWeekNumber = weekNumber;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : isRegistered
                            ? Colors.green.shade50
                            : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : isRegistered
                              ? Colors.green.shade300
                              : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        s.weekLabel(weekNumber),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : isRegistered
                                  ? Colors.green.shade700
                                  : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        isRegistered
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 16,
                        color: isSelected
                            ? Colors.white
                            : isRegistered
                                ? Colors.green
                                : Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  /// 이미지 뷰어 위젯
  Widget _buildPdfViewer(Map<String, dynamic>? meal, MealStrings s) {
    final slotName = s.slotName(_selectedYear, _selectedMonth, _selectedWeekNumber);

    if (meal == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(slotName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(s.notRegisteredYet,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    final imageUrl = meal['imageUrl'] ?? meal['pdfUrl'] ?? '';

    if (imageUrl.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(s.noMealImage,
                style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 정보 바
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.image, size: 20, color: Colors.orange.shade700),
              const SizedBox(width: 10),
              Text(slotName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        // 이미지 뷰어
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.orange.shade200),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(12)),
              child: LayoutBuilder(
                builder: (context, constraints) => InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return SizedBox(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(s.imageLoadError,
                                style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
