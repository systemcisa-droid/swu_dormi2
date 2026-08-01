class MealStrings {
  final bool isEnglish;
  const MealStrings(this.isEnglish);

  String _t(String ko, String en) => isEnglish ? en : ko;

  String get title => _t('식단표', 'Meal Plan');
  String loadError(Object e) => _t('오류가 발생했습니다: $e', 'An error occurred: $e');

  String get yearMonthPickerTitle => _t('연도/월 선택', 'Select Year/Month');
  String yearLabel(int year) => _t('$year년', '$year');
  String monthLabel(int month) => _t('$month월', 'Month $month');
  String get confirm => _t('확인', 'OK');

  String weekLabel(int week) => _t('$week째주', 'Week $week');

  String get notRegisteredYet => _t('아직 식단표가 등록되지 않았습니다', 'The meal plan has not been registered yet');
  String get noMealImage => _t('식단표 이미지가 없습니다', 'There is no meal plan image');
  String get imageLoadError => _t('이미지를 불러올 수 없습니다', 'Unable to load image');

  String yearMonth(int year, int month) {
    if (isEnglish) {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[month - 1]} $year';
    }
    return '$year.${month.toString().padLeft(2, '0')}';
  }

  String slotName(int year, int month, int week) {
    return '${yearMonth(year, month)} ${weekLabel(week)}';
  }
}
