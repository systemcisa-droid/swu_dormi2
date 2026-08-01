// 앱 전체에서 사용되는 상수들

class AppConstants {
  // 앱 정보
  static const String appName = 'SWU 샬롬하우스 관리자';
  static const String appVersion = '1.0.0';

  // 색상
  static const int primaryColor = 0xFF0066CC;
  static const int accentColor = 0xFF00A8E8;
  static const int backgroundColor = 0xFFF3F3F3;
  static const int cardColor = 0xFFFFFFFF;

  // 레이아웃
  static const double defaultPadding = 16.0;
  static const double defaultRadius = 8.0;
  static const double defaultElevation = 2.0;

  // 애니메이션
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);

  // Firebase Collections
  static const String studentsCollection = 'students';
  static const String adminsCollection = 'admins';
  static const String noticesCollection = 'notices';
  static const String mealsCollection = 'meals';
  static const String facilitiesCollection = 'facilities';
  static const String facilityReportsCollection = 'facility_reports';
  static const String checkInOutCollection = 'check_in_out';
  static const String overnightCollection = 'overnight';
  static const String notificationsCollection = 'notifications';

  // 페이지 크기
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // 날짜 형식
  static const String dateFormat = 'yyyy-MM-dd';
  static const String dateTimeFormat = 'yyyy-MM-dd HH:mm';
  static const String timeFormat = 'HH:mm';

  // 파일 업로드
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  static const List<String> allowedImageExtensions = ['jpg', 'jpeg', 'png', 'gif'];
  static const List<String> allowedDocumentExtensions = ['pdf', 'doc', 'docx', 'xls', 'xlsx'];

  // 에러 메시지
  static const String networkError = '네트워크 연결을 확인해주세요.';
  static const String unknownError = '알 수 없는 오류가 발생했습니다.';
  static const String permissionDenied = '권한이 없습니다.';
  static const String dataNotFound = '데이터를 찾을 수 없습니다.';

  // 성공 메시지
  static const String saveSuccess = '저장되었습니다.';
  static const String deleteSuccess = '삭제되었습니다.';
  static const String updateSuccess = '수정되었습니다.';
}

// 사용자 역할
enum UserRole {
  superAdmin,  // 최고 관리자
  admin,       // 일반 관리자
  staff,       // 스태프
}

// 시설 상태
enum FacilityStatus {
  available,   // 사용 가능
  inUse,       // 사용 중
  maintenance, // 점검 중
  unavailable, // 사용 불가
}

// 시설 신고 상태
enum ReportStatus {
  pending,     // 대기 중
  inProgress,  // 처리 중
  resolved,    // 해결됨
  rejected,    // 거부됨
}

// 외박 신청 상태
enum OvernightStatus {
  pending,     // 승인 대기
  approved,    // 승인됨
  rejected,    // 거부됨
  cancelled,   // 취소됨
}

// 입퇴사 상태
enum CheckInOutStatus {
  checkIn,     // 입사
  checkOut,    // 퇴사
}

// 공지사항 타입
enum NoticeType {
  general,     // 일반
  important,   // 중요
  urgent,      // 긴급
  event,       // 행사
}
