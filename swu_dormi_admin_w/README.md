# SWU 샬롬하우스 관리 시스템

> 서울여자대학교 기숙사 관리자용 Windows 데스크톱 애플리케이션

[![Flutter](https://img.shields.io/badge/Flutter-3.27.2-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore-FFCA28?logo=firebase)](https://firebase.google.com)
[![Windows](https://img.shields.io/badge/Platform-Windows-0078D6?logo=windows)](https://www.microsoft.com/windows)

서울여자대학교 기숙사 관리를 위한 관리자용 Flutter 애플리케이션입니다. Windows Fluent Design UI를 사용하여 네이티브한 Windows 경험을 제공합니다.

## 📋 목차

- [주요 기능](#-주요-기능)
- [기술 스택](#-기술-스택)
- [시작하기](#-시작하기)
- [프로젝트 구조](#-프로젝트-구조)
- [Firebase 구조](#-firebase-구조)
- [주요 화면](#-주요-화면)
- [개발 가이드](#-개발-가이드)

## ✨ 주요 기능

### 1. 대시보드 📊
- **실시간 통계**: 시설 신고 대기, 총 학생 수
- **월간 차트**: 시설 신고 건수 및 학생 수 변화 (최근 7일, fl_chart 사용)
- **활동 내역**: 최근 공지사항, 식단표, 입퇴사/외박 신청, 시설 신고 (24시간 이내 신고는 'NEW' 뱃지)
- **빠른 실행 메뉴**:
  - 공지사항 작성
  - 식단표 등록
  - 학생 조회
  - 통계 보기
  - 메시지 전송 (전체/A동/B동/층별/개별)
  - 설정

### 2. 공지사항 관리 📢
- **마스터-디테일 레이아웃**: 좌측 목록, 우측 상세보기
- **공지사항 작성**: 제목, 내용, 이미지(다중), PDF 첨부
- **중요 공지 고정**: isPinned 플래그로 상단 고정
- **검색 및 필터링**: 제목/내용 검색, 고정/일반 필터
- **PDF 뷰어**: syncfusion_flutter_pdfviewer 사용
- **자동 알림**: 작성 시 전체 학생에게 알림 자동 전송

### 3. 식단표 관리 🍽️
- **PDF 업로드 방식**: 월별 식단표 PDF 파일 등록
- **제목 + PDF**: 예) "2024년 1월 식단표"
- **PDF 다운로드**: url_launcher로 링크 제공
- **삭제 기능**: 등록된 식단표 삭제

### 4. 입퇴사 신청 관리 🏠
- **신청 승인/거부**: 입사/퇴사 신청 처리
- **입사 시간 지정**: 09:00, 14:00 중 선택
- **거부 사유 입력**: 거부 시 사유 필수 입력
- **처리자 추적**: processedBy, processedByName 자동 기록
- **자동 알림**: 상태 변경 시 해당 학생에게 알림 전송

### 5. 외박 신청 관리 🌙
- **신청 승인/거부**: 외박 신청 처리
- **외박 정보 확인**: 시작일, 종료일, 목적지, 긴급연락처, 사유
- **거부 사유 입력**: 거부 시 사유 필수 입력
- **처리자 추적**: processedBy, processedByName 자동 기록
- **자동 알림**: 상태 변경 시 해당 학생에게 알림 전송

### 6. 시설 신고 관리 🔧
- **상태별 필터링**: 전체/대기중/처리중/완료
- **마스터-디테일 레이아웃**: 좌측 목록, 우측 상세보기
- **신고 정보 확인**:
  - 신고자 정보 (이름, 학번, 호실, 동)
  - 위치 정보 (building, faultLocation: 'A방', 'B방', '거실', '화장실' 등)
  - 카테고리 (가구/도어, 수도설비, 전기, 기타)
  - 제목, 설명, 이미지
- **상태 관리**: 대기중 → 처리중 → 완료
- **처리자 메모**: technicianNote 필드에 처리 내용 기록
- **자동 알림**: 상태 변경 시 신고한 학생에게 알림 전송

### 7. 학생 관리 👥
- **학생 목록 조회**: role == 'student' 필터링
- **검색 기능**: 이름, 학번으로 검색
- **필터링**:
  - 동별 (A동/B동)
  - 층별 (2층~7층)
- **학생 정보**:
  - 기본 정보: 이름, 학번, 이메일, 전화번호
  - 거주 정보: 호실, 동, 층
  - 학적 정보: 학부, 학과
- **호실 배정**: 호실 번호 수정 기능

### 8. 메시지 전송 시스템 💬
- **수신 대상 선택**:
  - 전체 학생
  - A동 전체 / A동 층별 (2~7층)
  - B동 전체 / B동 층별 (2~7층)
  - 개별 학생 선택 (체크박스)
- **메시지 작성**: 제목, 내용 입력
- **실시간 수신자 수**: 선택된 학생 수 표시
- **배치 전송**: Firestore Batch로 효율적인 알림 생성

## 🛠 기술 스택

### Frontend
- **Flutter** (3.27.2): 크로스 플랫폼 UI 프레임워크
- **Fluent UI** (4.13.0): Windows Fluent Design 시스템
- **fl_chart** (0.69.0): 차트 및 그래프
- **window_manager** (0.4.3): Windows 창 관리

### Backend
- **Firebase Authentication**: 사용자 인증
- **Cloud Firestore**: NoSQL 데이터베이스
- **Firebase Storage**: 파일 저장소 (PDF, 이미지)

### Utilities
- **intl** (0.20.2): 날짜/시간 국제화
- **file_picker** (8.1.6): 파일 선택
- **url_launcher** (6.3.1): URL 실행
- **syncfusion_flutter_pdfviewer** (28.1.33): PDF 뷰어

## 🚀 시작하기

### 사전 요구사항

- **Flutter SDK**: 3.27.2 이상
- **Dart SDK**: 3.6.0 이상
- **Windows 10/11**: 64-bit
- **Visual Studio 2022**: Windows 개발 환경
- **Firebase 프로젝트**: Firestore, Storage, Authentication 활성화

### 설치 및 실행

### 1. 저장소 클론 및 패키지 설치
```bash
git clone <repository-url>
cd swu_dormi_admin_w
flutter pub get
```

### 2. Firebase 설정

#### 2-1. FlutterFire CLI 설치 및 설정
```bash
# FlutterFire CLI 설치
dart pub global activate flutterfire_cli

# Firebase 프로젝트 설정
flutterfire configure
```

위 명령어를 실행하면 자동으로 `lib/firebase_options.dart` 파일이 생성됩니다.

> **Note**: 학생용 앱(SWU_Dormi)과 동일한 Firebase 프로젝트를 사용합니다.

#### 2-2. Firestore 보안 규칙 설정
Firebase Console > Firestore Database > 규칙 탭에서 다음 규칙 적용:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isAuthenticated() {
      return request.auth != null;
    }

    function isAdmin() {
      return isAuthenticated() &&
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    // 모든 컬렉션: 읽기는 인증된 사용자, 쓰기는 관리자만
    match /{document=**} {
      allow read: if isAuthenticated();
      allow write: if isAdmin();
    }
  }
}
```

#### 2-3. Storage 보안 규칙 설정
Firebase Console > Storage > 규칙 탭에서 다음 규칙 적용:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null &&
                      firestore.get(/databases/(default)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

### 3. 관리자 계정 생성

최초 관리자 계정은 Firebase Console 또는 코드에서 생성합니다:

```dart
// AuthService 사용
await authService.createAdminAccount(
  email: 'admin@swu.ac.kr',
  password: 'secure_password',
  name: '관리자',
);
```

또는 Firebase Console에서:
1. Authentication > Users > "사용자 추가"
2. Firestore > users 컬렉션에 문서 추가:
   ```json
   {
     "email": "admin@swu.ac.kr",
     "name": "관리자",
     "role": "admin",
     "createdAt": "2024-01-01T00:00:00Z"
   }
   ```

### 4. 애플리케이션 실행
```bash
# 디버그 모드
flutter run -d windows

# 릴리즈 빌드
flutter build windows --release
```

빌드된 실행 파일 위치: `build\windows\x64\runner\Release\swu_dormi_admin_w.exe`

## 📁 프로젝트 구조

```
swu_dormi_admin_w/
├── lib/
│   ├── models/                          # 데이터 모델
│   │   ├── admin_model.dart
│   │   ├── check_in_out_model.dart      # 입퇴사 신청
│   │   ├── facility_report_model.dart   # 시설 신고
│   │   ├── meal_model.dart              # 식단표
│   │   ├── notice_model.dart            # 공지사항
│   │   ├── notification_model.dart      # 알림
│   │   ├── overnight_model.dart         # 외박 신청
│   │   └── user_model.dart              # 사용자
│   │
│   ├── screens/                         # 화면
│   │   └── windows/                     # Windows UI
│   │       ├── windows_dashboard.dart           # 대시보드
│   │       ├── windows_facilities_screen.dart   # 시설 신고 관리
│   │       ├── windows_login_screen.dart        # 로그인
│   │       ├── windows_meals_screen.dart        # 식단표 관리
│   │       ├── windows_navigation_shell.dart    # 네비게이션
│   │       ├── windows_notice_create_screen.dart # 공지작성
│   │       ├── windows_notices_screen.dart      # 공지목록
│   │       └── windows_students_screen.dart     # 학생 관리
│   │
│   ├── services/                        # 비즈니스 로직
│   │   ├── auth_service.dart            # 인증 서비스
│   │   ├── firestore_service.dart       # Firestore 서비스
│   │   ├── notification_service.dart    # 알림 서비스
│   │   └── storage_service.dart         # Storage 서비스
│   │
│   ├── utils/                           # 유틸리티
│   │   ├── constants.dart
│   │   ├── date_formatter.dart
│   │   ├── error_handler.dart
│   │   ├── extensions.dart
│   │   └── validators.dart
│   │
│   ├── widgets/                         # 공통 위젯
│   │   ├── empty_state.dart
│   │   └── loading_indicator.dart
│   │
│   ├── firebase_options.dart            # Firebase 설정
│   └── main.dart                        # 앱 진입점
│
├── assets/
│   └── images/                          # 이미지 자산
│
├── windows/                             # Windows 플랫폼 설정
├── pubspec.yaml                         # 패키지 의존성
└── README.md                            # 프로젝트 문서
```

## 🔥 Firebase 구조

### Firestore 컬렉션

#### users (사용자 정보)
```javascript
{
  email: string,
  name: string,
  role: 'admin' | 'student',
  studentId: string,          // 학생만
  roomNumber: string,         // 학생만 (예: "201", "340")
  building: string,           // 계산됨 (A동/B동)
  floor: string,              // 계산됨 (2~7층)
  createdAt: Timestamp
}
```

#### notices (공지사항)
```javascript
{
  title: string,
  content: string,
  authorId: string,
  authorName: string,
  pdfUrl?: string,
  pdfFileName?: string,
  imageUrls: string[],
  isPinned: boolean,          // 고정 여부
  viewCount: number,
  createdAt: Timestamp
}
```

#### repair_reports (시설 신고)
```javascript
{
  userId: string,
  userName: string,
  roomNumber: string,
  building: string,
  faultLocation: string,      // 'A방', 'B방', '거실', '화장실' 등
  category: 'maintenance' | 'plumbing' | 'electrical' | 'other',
  title: string,
  description: string,
  imageUrl?: string,
  reportedAt: Timestamp,
  status: 'pending' | 'in_progress' | 'completed',
  technicianNote?: string,    // 처리자 메모
  processedBy?: string,
  processedByName?: string,
  processedAt?: Timestamp
}
```

#### check_in_out_requests (입퇴사 신청)
```javascript
{
  userId: string,
  userName: string,
  studentId: string,
  type: 'check_in' | 'check_out',
  roomNumber: string,
  requestDate: Timestamp,
  status: 'pending' | 'approved' | 'rejected',
  rejectionReason?: string,
  approvedTime?: string,      // "09:00" | "14:00"
  processedBy?: string,
  processedByName?: string,
  processedAt?: Timestamp,
  createdAt: Timestamp
}
```

#### overnight_requests (외박 신청)
```javascript
{
  userId: string,
  userName: string,
  studentId: string,
  roomNumber: string,
  startDate: Timestamp,
  endDate: Timestamp,
  reason: string,
  destination: string,
  emergencyContact: string,
  status: 'pending' | 'approved' | 'rejected',
  rejectionReason?: string,
  processedBy?: string,
  processedByName?: string,
  processedAt?: Timestamp,
  createdAt: Timestamp
}
```

#### meals (식단표)
```javascript
{
  title: string,              // "2024년 1월 식단표"
  pdfUrl: string,
  pdfName: string,
  createdAt: Timestamp
}
```

#### user_notifications (학생 알림)
```javascript
{
  userId: string,
  type: 'notice' | 'message' | 'facility_report' | 'check_in_out' | 'overnight',
  title: string,
  content: string,
  data: map,                  // 추가 데이터
  createdAt: Timestamp,
  isRead: boolean
}
```

### Firebase Storage 구조

```
storage/
├── notices/
│   ├── pdfs/                   # 공지사항 PDF
│   └── images/                 # 공지사항 이미지
├── meals/
│   └── pdfs/                   # 식단표 PDF
├── facilities/
│   └── images/                 # 시설 신고 이미지
└── profiles/                   # 프로필 이미지
```

### 호실 번호 체계

- **호실 형식**: 3자리 숫자 (예: "201", "340")
- **층**: 백의 자리 (2~7층)
- **동**: 끝 두 자리
  - 01~20: A동
  - 21~40: B동

**예시**:
- `201` → 2층, A동 1호
- `340` → 3층, B동 40호
- `715` → 7층, A동 15호

**계산 로직** (UserModel):
```dart
String get building {
  final lastTwoDigits = int.parse(roomNumber.substring(1));
  return lastTwoDigits <= 20 ? 'A동' : 'B동';
}

String get floor => '${roomNumber[0]}층';
```

## 📱 주요 화면

### 1. 로그인 화면
- 이메일/비밀번호 인증
- 관리자 권한 자동 검증
- Windows Fluent Design 스타일

### 2. 대시보드
- 좌측: Navigation Pane (메뉴)
- 우측 상단: 사용자 정보, 로그아웃, 창 컨트롤
- 메인 영역: 통계 카드, 차트, 활동 내역, 빠른 실행

### 3. 공지사항 관리
- 마스터-디테일 레이아웃
- 좌측 (400px): 목록, 검색, 필터
- 우측: 상세보기, 수정, 삭제

### 4. 시설 신고 관리
- 마스터-디테일 레이아웃
- 좌측: 신고 목록, 상태 필터
- 우측: 신고 상세, 상태 변경, 메모

### 5. 학생 관리
- 테이블 형식
- 검색 및 필터링
- 호실 배정 수정

## 💻 개발 가이드

### 주요 서비스 사용법

#### AuthService (인증)
```dart
final authService = AuthService();

// 로그인
await authService.signInWithEmailAndPassword(email, password);

// 로그아웃
await authService.signOut();

// 현재 사용자
final user = authService.currentUser;
```

#### FirestoreService (데이터베이스)
```dart
final firestoreService = FirestoreService();

// 공지사항 가져오기 (Stream)
Stream<QuerySnapshot> notices = firestoreService.getNotices();

// 공지사항 추가
await firestoreService.addNotice({
  'title': '제목',
  'content': '내용',
  'authorId': userId,
  'authorName': userName,
});

// 입퇴사 승인
await firestoreService.updateCheckInOutStatus(
  requestId,
  'approved',
  null,
  approvedTime: '09:00',
);

// 메시지 전송
await firestoreService.sendNotification(
  userIds: ['userId1', 'userId2'],
  type: 'message',
  title: '제목',
  content: '내용',
);
```

#### NotificationService (알림)
```dart
final notificationService = NotificationService();

// 공지사항 알림
await notificationService.sendNoticeNotification(
  noticeId: noticeId,
  title: title,
  content: content,
);

// 시설 신고 알림
await notificationService.sendFacilityReportStatusNotification(
  userId: userId,
  reportId: reportId,
  status: 'completed',
  title: title,
);
```

#### StorageService (파일 업로드)
```dart
final storageService = StorageService();

// PDF 업로드
String pdfUrl = await storageService.uploadNoticePdf(
  file,
  'notice_${timestamp}.pdf',
);

// 이미지 업로드
String imageUrl = await storageService.uploadNoticeImage(
  file,
  'notice_${timestamp}_1.jpg',
);
```

### 에러 처리

모든 비동기 작업은 try-catch로 감싸고 사용자 친화적인 에러 메시지를 표시합니다:

```dart
try {
  await someAsyncOperation();
  displayInfoBar(context, /* success */);
} catch (e) {
  displayInfoBar(context, /* error */);
  print('Error: $e');
}
```

### 학생용 앱과의 연동

- 동일한 Firebase 프로젝트 사용
- role 기반 권한 제어 (admin/student)
- 실시간 데이터 동기화
- 알림 시스템 통합

## 🔐 보안

- **클라이언트 검증**: AuthService에서 로그인 시 role 확인
- **서버 검증**: Firestore 보안 규칙에서 role 기반 권한 제어
- **이중 검증**: 클라이언트 + 서버 검증으로 보안 강화

## 🐛 문제 해결

### Firebase 연결 오류
- `firebase_options.dart` 파일 확인
- Firebase 프로젝트에 앱 등록 확인

### 로그인 오류
- Firebase Authentication 활성화 확인
- 관리자 계정 role = 'admin' 확인

### 데이터 접근 오류
- Firestore 보안 규칙 확인
- 사용자 role 확인

## 📞 문의

프로젝트에 대한 문의사항이 있으시면 다음으로 연락주세요:
- 이메일: [관리자 이메일]
- 기숙사 사무실: [전화번호]

---

**© 2024 서울여자대학교 샬롬하우스. All rights reserved.**
