class NoticesStrings {
  final bool isEnglish;
  const NoticesStrings(this.isEnglish);

  String _t(String ko, String en) => isEnglish ? en : ko;

  String get title => _t('공지사항 & 기숙사일정', 'Notices & Dorm Schedule');
  String get tabNotices => _t('공지사항', 'Notices');
  String get tabSchedule => _t('기숙사일정', 'Dorm Schedule');

  String get noticesLoadError => _t('공지사항을 불러오는 중 오류가 발생했습니다', 'An error occurred while loading notices');
  String get noticesEmpty => _t('공지사항이 없습니다', 'There are no notices');
  String get important => _t('중요', 'Important');
  String get author => _t('작성자', 'Author');
  String get allNotices => _t('전체 공지사항', 'All Notices');
  String get pdfFile => _t('PDF 파일', 'PDF File');
  String get viewPdfFile => _t('PDF 파일 보기', 'View PDF File');

  String get weekSchedule => _t('이번 주 일정', "This Week's Schedule");
  String get noRegisteredSchedule => _t('등록된 일정이 없습니다', 'No schedule registered');
  String get selectDayHint => _t('날짜를 선택하면 일정을 확인할 수 있습니다', 'Select a date to view the schedule');
  String moreCount(int n) => _t('+$n개 더보기', '+$n more');

  static const _weekdayKo = ['일', '월', '화', '수', '목', '금', '토'];
  static const _weekdayEn = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  String weekday(int index) => isEnglish ? _weekdayEn[index] : _weekdayKo[index];

  static const Map<String, String> _categoryEn = {
    '행사': 'Event',
    '청소': 'Cleaning',
    '교육': 'Education',
    '점검': 'Inspection',
    '기타': 'Other',
  };
  String category(String ko) => isEnglish ? (_categoryEn[ko] ?? ko) : ko;

  String yearMonth(DateTime month) {
    if (isEnglish) {
      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
      ];
      return '${months[month.month - 1]} ${month.year}';
    }
    return '${month.year}년 ${month.month}월';
  }

  String monthDayWeekday(DateTime date) {
    if (isEnglish) {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      final wd = _weekdayEn[date.weekday % 7];
      return '${months[date.month - 1]} ${date.day} ($wd)';
    }
    const weekdaysKo = ['월', '화', '수', '목', '금', '토', '일'];
    final wd = weekdaysKo[date.weekday - 1];
    return '${date.month}월 ${date.day}일 ($wd)';
  }
}
