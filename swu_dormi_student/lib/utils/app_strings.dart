// 여러 화면에서 공통으로 쓰이는 다국어 문자열
class AppStrings {
  final bool isEnglish;
  const AppStrings(this.isEnglish);

  String t(String ko, String en) => isEnglish ? en : ko;

  String get confirm => t('확인', 'OK');
  String get cancel => t('취소', 'Cancel');
  String get save => t('저장', 'Save');
  String get send => t('전송', 'Send');
  String get logout => t('로그아웃', 'Log Out');
}
