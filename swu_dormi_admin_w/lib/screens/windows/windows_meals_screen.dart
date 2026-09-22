import 'package:fluent_ui/fluent_ui.dart';
import 'package:swu_dormi_admin/services/firestore_service.dart';
import 'package:swu_dormi_admin/services/storage_service.dart';
import 'package:swu_dormi_admin/models/meal_model.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'dart:io';

class WindowsMealsScreen extends StatefulWidget {
  const WindowsMealsScreen({super.key});

  @override
  State<WindowsMealsScreen> createState() => _WindowsMealsScreenState();
}

class _WindowsMealsScreenState extends State<WindowsMealsScreen> {
  final _firestoreService = FirestoreService();
  final _storageService = StorageService();
  final _dateFormat = DateFormat('yyyy.MM.dd HH:mm');
  
  // 선택된 연도/월/주차
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  int? _selectedWeekNumber;
  
  // 현재 월의 식단표 맵 (weekNumber -> MealModel)
  Map<int, MealModel> _mealsByWeek = {};

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Row(
        children: [
          // 왼쪽: 연도/월 선택 + 주차 슬롯 목록
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: FluentTheme.of(context).micaBackgroundColor,
                border: Border(
                  right: BorderSide(
                    color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // 헤더 - 연도/월 선택
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FluentTheme.of(context).cardColor,
                      border: Border(
                        bottom: BorderSide(
                          color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '식단표 관리',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            // 연도 선택
                            SizedBox(
                              width: 100,
                              child: ComboBox<int>(
                                value: _selectedYear,
                                items: List.generate(5, (index) {
                                  final year = DateTime.now().year - 2 + index;
                                  return ComboBoxItem(
                                    value: year,
                                    child: Text('$year년'),
                                  );
                                }),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedYear = value;
                                      _selectedWeekNumber = null;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            // 월 선택
                            SizedBox(
                              width: 80,
                              child: ComboBox<int>(
                                value: _selectedMonth,
                                items: List.generate(12, (index) {
                                  final month = index + 1;
                                  return ComboBoxItem(
                                    value: month,
                                    child: Text('$month월'),
                                  );
                                }),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedMonth = value;
                                      _selectedWeekNumber = null;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // 주차 슬롯 목록
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _firestoreService.getMeals(),
                      builder: (context, snapshot) {
                        // 현재 선택된 연도/월의 식단표만 필터링
                        _mealsByWeek = {};
                        if (snapshot.hasData) {
                          for (var doc in snapshot.data!.docs) {
                            final meal = MealModel.fromFirestore(doc);
                            if (meal.year == _selectedYear && meal.month == _selectedMonth) {
                              _mealsByWeek[meal.weekNumber] = meal;
                            }
                          }
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: 5, // 5주차까지 표시
                          itemBuilder: (context, index) {
                            final weekNumber = index + 1;
                            final meal = _mealsByWeek[weekNumber];
                            final isRegistered = meal != null;
                            final isSelected = _selectedWeekNumber == weekNumber;

                            return Card(
                              backgroundColor: isSelected
                                  ? FluentTheme.of(context).accentColor.withOpacity(0.1)
                                  : null,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                onPressed: () {
                                  setState(() {
                                    _selectedWeekNumber = weekNumber;
                                  });
                                },
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isRegistered
                                        ? Colors.green.withOpacity(0.1)
                                        : Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isRegistered ? FluentIcons.completed : FluentIcons.document,
                                    color: isRegistered ? Colors.green : Colors.grey[100],
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  '$_selectedYear.${_selectedMonth.toString().padLeft(2, '0')} $weekNumber번째주',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  isRegistered ? '등록됨' : '미등록',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isRegistered ? Colors.green : Colors.grey[100],
                                  ),
                                ),
                                trailing: isRegistered
                                    ? Icon(
                                        FluentIcons.photo2,
                                        size: 16,
                                        color: Colors.blue,
                                      )
                                    : null,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 오른쪽: 상세 정보 / 등록
          Expanded(
            flex: 3,
            child: _selectedWeekNumber == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FluentIcons.cafe,
                          size: 64,
                          color: Colors.grey[60],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '주차를 선택해주세요',
                          style: TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  )
                : _buildDetailPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailPanel() {
    final meal = _mealsByWeek[_selectedWeekNumber];
    final slotName = '$_selectedYear.${_selectedMonth.toString().padLeft(2, '0')} $_selectedWeekNumber번째주 식단';

    if (meal == null) {
      // 미등록 상태 - 이미지 업로드 UI
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              slotName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '아직 식단표가 등록되지 않았습니다.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[100],
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Icon(
                    FluentIcons.cloud_upload,
                    size: 64,
                    color: Colors.grey[60],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _uploadImage,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.add, size: 16),
                        SizedBox(width: 8),
                        Text('이미지 파일 등록'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 등록된 상태 - 상세 정보 표시
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slotName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '등록일: ${_dateFormat.format(meal.createdAt)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[100],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(FluentIcons.delete, size: 20),
                onPressed: () => _deleteMeal(meal),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 이미지 정보 바
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(FluentIcons.photo2, size: 20, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    meal.imageName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Button(
                  onPressed: () => _launchUrl(meal.imageUrl),
                  child: const Text('새 창에서 열기'),
                ),
              ],
            ),
          ),
          // 이미지 미리보기
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                child: InteractiveViewer(
                  child: Image.network(
                    meal.imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const Center(child: ProgressRing()),
                    errorBuilder: (_, __, ___) => const Center(
                      child: Text('이미지를 불러올 수 없습니다'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _uploadImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
    );

    if (result == null || result.files.single.path == null) return;

    final selectedPdfFile = File(result.files.single.path!);
    final selectedPdfFileName = result.files.single.name;

    // 프로그레스 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (progressContext) => const ContentDialog(
        title: Text('업로드 중'),
        content: SizedBox(
          height: 100,
          child: Center(
            child: ProgressRing(),
          ),
        ),
      ),
    );

    try {
      // 이미지 업로드
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imageUrl = await _storageService.uploadMealImage(
        selectedPdfFile,
        '${timestamp}_$selectedPdfFileName',
      );

      final slotName = '$_selectedYear.${_selectedMonth.toString().padLeft(2, '0')} $_selectedWeekNumber번째주 식단';

      // Firestore에 저장
      await _firestoreService.addMeal({
        'title': slotName,
        'imageUrl': imageUrl,
        'imageName': selectedPdfFileName,
        'year': _selectedYear,
        'month': _selectedMonth,
        'weekNumber': _selectedWeekNumber,
      });

      if (!mounted) return;

      // 프로그레스 다이얼로그 닫기
      Navigator.pop(context);

      // 성공 메시지
      await showDialog(
        context: context,
        builder: (successContext) => ContentDialog(
          title: const Text('완료'),
          content: const Text('식단표가 등록되었습니다.'),
          actions: [
            FilledButton(
              child: const Text('확인'),
              onPressed: () => Navigator.pop(successContext),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      // 프로그레스 다이얼로그 닫기
      Navigator.pop(context);

      // 에러 메시지
      await showDialog(
        context: context,
        builder: (errorContext) => ContentDialog(
          title: const Text('오류'),
          content: Text('식단표 등록 중 오류가 발생했습니다:\n$e'),
          actions: [
            FilledButton(
              child: const Text('확인'),
              onPressed: () => Navigator.pop(errorContext),
            ),
          ],
        ),
      );
    }
  }

  void _deleteMeal(MealModel meal) {
    showDialog(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: const Text('식단표 삭제'),
        content: Text('"${meal.slotDisplayName}"을(를) 삭제하시겠습니까?'),
        actions: [
          Button(
            child: const Text('취소'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: ButtonState.all(Colors.red),
            ),
            child: const Text('삭제'),
            onPressed: () async {
              Navigator.pop(dialogContext);

              try {
                // 이미지 파일 삭제
                if (meal.imageUrl.isNotEmpty) {
                  await _storageService.deleteFile(meal.imageUrl);
                }

                // Firestore에서 삭제
                await _firestoreService.deleteMeal(meal.id);

                if (!mounted) return;

                // 선택 해제하여 상세 패널 초기화
                setState(() {
                  _selectedWeekNumber = null;
                });

                // 성공 메시지
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  showDialog(
                    context: this.context,
                    builder: (successContext) => ContentDialog(
                      title: const Text('완료'),
                      content: const Text('식단표가 삭제되었습니다.'),
                      actions: [
                        FilledButton(
                          child: const Text('확인'),
                          onPressed: () => Navigator.pop(successContext),
                        ),
                      ],
                    ),
                  );
                });
              } catch (e) {
                if (!mounted) return;

                // 에러 메시지
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  showDialog(
                    context: this.context,
                    builder: (errorContext) => ContentDialog(
                      title: const Text('오류'),
                      content: Text('식단표 삭제 중 오류가 발생했습니다:\n$e'),
                      actions: [
                        FilledButton(
                          child: const Text('확인'),
                          onPressed: () => Navigator.pop(errorContext),
                        ),
                      ],
                    ),
                  );
                });
              }
            },
          ),
        ],
      ),
    );
  }

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await url_launcher.canLaunchUrl(uri)) {
      await url_launcher.launchUrl(uri);
    }
  }
}
