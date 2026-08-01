# SWU Dormi - 샬롬하우스 📱

![Flutter](https://img.shields.io/badge/Flutter-3.9.2-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-Latest-0175C2?logo=dart)
![Firebase](https://img.shields.io/badge/Firebase-Cloud-FFCA28?logo=firebase)
![Provider](https://img.shields.io/badge/State-Provider-6C5CE7)
![Material Design](https://img.shields.io/badge/UI-Material%203-757575)

서울여자대학교 기숙사(샬롬하우스) 학생들을 위한 종합 관리 모바일 애플리케이션

## 📋 목차

- [프로젝트 개요](#-프로젝트-개요)
- [주요 기능](#-주요-기능)
- [기술 스택](#-기술-스택)
- [시작하기](#-시작하기)
- [프로젝트 구조](#-프로젝트-구조)
- [Firebase 구조](#-firebase-구조)
- [데이터 모델](#-데이터-모델)
- [상태 관리](#-상태-관리)
- [디자인 시스템](#-디자인-시스템)
- [개발 가이드](#-개발-가이드)
- [빌드 및 배포](#-빌드-및-배포)
- [문제 해결](#-문제-해결)

---

## 🎯 프로젝트 개요

**SWU Dormi**는 서울여자대학교 기숙사 "샬롬하우스" 거주 학생들의 생활을 지원하기 위한 올인원 모바일 애플리케이션입니다. 학생들은 이 앱을 통해 기숙사 생활의 모든 측면을 편리하게 관리할 수 있습니다.

### 앱 브랜딩
- **기숙사명**: 샬롬하우스 (Shalom House)
- **SWU 브랜드 컬러**: 버건디 (#9E1A20) / 네이비 (#101077)
- **로고**: 인터랙티브 SWU 로고 (탭하여 색상 전환)

### 지원 플랫폼
- 🤖 Android (주요 타겟)
- 🍎 iOS
- 🌐 Web (구성됨)

### 대상 사용자
- **학생**: 기숙사 거주 학생
- **관리자**: 기숙사 운영진 (별도 관리 패널)

---

## 🚀 주요 기능

### 1. 🔐 인증 및 프로필 관리

**위치**: `lib/screens/auth/`, `lib/screens/profile/`

#### 회원 가입 및 로그인
- **이메일/비밀번호 인증**: Firebase Authentication 기반
- **학생 정보 등록**: 이름, 학번, 전화번호, 호실, 단과대학, 학과
- **프로필 사진**: 카메라/갤러리에서 이미지 업로드
- **비밀번호 재설정**: 이메일을 통한 비밀번호 복구

#### 프로필 관리
- **정보 조회**: 이름, 학번, 이메일, 전화번호, 호실, 단과대학, 학과
- **프로필 수정**: 이름, 닉네임, 전화번호, 단과대학, 학과 변경
- **프로필 사진 변경**: 새 이미지 업로드
- **비밀번호 변경**: 현재 비밀번호 확인 후 변경
- **호실 정보**: 건물(A동/B동) 및 층 자동 계산
- **로그아웃**: 계정 로그아웃

**주요 파일**:
- `screens/auth/login_screen.dart`: 로그인 화면
- `screens/auth/signup_screen.dart`: 회원가입 화면
- `screens/profile/profile_screen.dart`: 프로필 조회
- `screens/profile/profile_update_screen.dart`: 프로필 수정
- `screens/profile/change_password_screen.dart`: 비밀번호 변경

### 2. 📢 공지사항

**위치**: `lib/screens/notices/`

기숙사 운영진이 게시하는 공식 공지사항을 확인할 수 있습니다.

#### 주요 기능
- **공지사항 목록**: 최신순 정렬
- **중요 공지 표시**: 상단 고정 (⭐ 아이콘)
- **이미지 첨부**: 여러 이미지 지원
- **PDF 첨부**: PDF 문서 첨부 및 뷰어
- **실시간 업데이트**: Firestore Stream으로 자동 갱신

**주요 파일**:
- `screens/notices/notices_screen.dart`: 공지사항 목록
- `screens/notices/pdf_viewer_screen.dart`: PDF 문서 뷰어
- `models/notice_model.dart`: 공지사항 데이터 모델

### 3. 👥 커뮤니티 게시판

**위치**: `lib/screens/board/`

학생들 간 자유로운 소통을 위한 커뮤니티 공간입니다.

#### 게시글 기능
- **게시글 작성**: 제목, 내용, 이미지(최대 5장)
- **게시글 조회**: 전체 게시글 목록
- **게시글 수정**: 작성자만 수정 가능
- **게시글 삭제**: 작성자만 삭제 가능
- **좋아요**: 게시글 추천 (중복 방지)
- **조회수**: 게시글 열람 횟수 추적

#### 댓글 시스템
- **댓글 작성**: 게시글에 댓글 달기
- **댓글 좋아요**: 유용한 댓글 추천
- **실시간 업데이트**: 댓글 즉시 반영
- **프로필 표시**: 작성자 프로필 사진 및 이름

**주요 파일**:
- `screens/board/board_screen.dart`: 게시판 목록
- `screens/board/add_post_screen.dart`: 게시글 작성/수정
- `screens/board/post_detail_screen.dart`: 게시글 상세 및 댓글
- `models/post_model.dart`: 게시글 데이터 모델
- `models/comment_model.dart`: 댓글 데이터 모델

### 4. 🔧 시설 고장 신고

**위치**: `lib/screens/facilities/`

기숙사 시설 고장 및 수리 요청을 관리합니다.

#### 신고 기능
- **위치 선택**: A방, B방, 거실, 화장실, 샤워실, 책상 A/B/C/D
- **고장 유형**: 가구/도어, 배관, 전기, 기타
- **제목 및 설명**: 고장 내용 상세 기록
- **사진 첨부**: 고장 부위 사진 업로드
- **신고 내역**: 본인이 작성한 신고 목록

#### 처리 상태 추적
- **대기 중** (pending): 신고 접수됨
- **처리 중** (in_progress): 수리 진행 중
- **완료** (completed): 수리 완료

#### 채팅 시스템
- **실시간 메시징**: 관리자와 1:1 채팅
- **진행 상황 공유**: 수리 진행 사항 실시간 확인
- **관리자 노트**: 기술자 코멘트 확인

**주요 파일**:
- `screens/facilities/facility_report_screen.dart`: 신고 작성 및 내역 (탭 UI)
- `models/facility_report_model.dart`: 시설 신고 데이터 모델
- `models/chat_message_model.dart`: 채팅 메시지 모델

### 5. 🏠 입퇴사 신청

**위치**: `lib/screens/check_in_out/`

기숙사 입사 및 퇴사 신청을 관리합니다.

#### 신청 유형
- **입사 신청** (check-in): 기숙사 입주 신청
- **퇴사 신청** (check-out): 기숙사 퇴실 신청

#### 신청 정보
- **일정 선택**: 원하는 입/퇴사 날짜
- **사유 입력**: 퇴사 사유 (퇴사 시)
- **신청 내역**: 본인이 제출한 신청서 목록

#### 승인 프로세스
- **대기 중** (pending): 신청 제출됨
- **승인됨** (approved): 관리자 승인 완료 (시간 배정)
- **거부됨** (rejected): 신청 거부
- **완료됨** (completed): 입/퇴사 완료

**주요 파일**:
- `screens/check_in_out/check_in_out_screen.dart`: 신청 작성 및 내역
- `models/check_in_out_model.dart`: 입퇴사 신청 데이터 모델

### 6. 🍽️ 식단표

**위치**: `lib/screens/meal/`

기숙사 식당의 일일 식단을 확인할 수 있습니다.

#### 기능
- **날짜별 조회**: 원하는 날짜의 식단 확인
- **시간대별 메뉴**: 아침, 점심, 저녁 메뉴 구분
- **메뉴 목록**: 각 끼니별 음식 목록
- **PDF 식단표**: PDF 형식 식단표 지원

**주요 파일**:
- `screens/meal/meal_screen.dart`: 식단표 조회
- `screens/meal/pdf_viewer_screen.dart`: PDF 뷰어
- `models/meal_model.dart`: 식단 데이터 모델

### 7. 🔔 알림 시스템

**위치**: `lib/screens/notification/`, `lib/services/notification_service.dart`

Firebase Cloud Messaging(FCM)을 통한 실시간 푸시 알림 시스템입니다.

#### 알림 유형
- **공지사항** (notice): 새 공지사항 게시
- **채팅** (chat): 시설 신고 관련 메시지
- **입퇴사** (check-in/out): 신청 승인/거부
- **식단** (meal): 새 식단표 등록
- **시설** (facility): 신고 처리 상태 변경

#### 기능
- **실시간 알림**: FCM을 통한 푸시 알림
- **진동 패턴**: 알림 수신 시 진동 (200ms-100ms-200ms)
- **토스트 메시지**: 앱 사용 중 알림 표시
- **읽음 표시**: 알림 읽음/안읽음 상태 관리
- **배지 카운터**: 상단 바에 미확인 알림 개수 표시
- **알림 목록**: 모든 알림 히스토리 확인

**주요 파일**:
- `screens/notification/notification_screen.dart`: 알림 목록
- `services/notification_service.dart`: FCM 설정 및 로컬 알림
- `models/notification_model.dart`: 알림 데이터 모델

### 8. 📋 기숙사 생활 안내

**위치**: `lib/screens/profile/`

기숙사 생활 규정 및 안내사항을 제공합니다.

#### 문서
- **생활수칙** (regulation): 기숙사 규정 및 디지털 서명
- **생활 안내** (dormitory_life_guide): 기숙사 생활 가이드
- **상벌 제도** (reward_penalty): 포인트 및 상벌 규정
- **개인정보 처리방침** (privacy_policy): 개인정보 보호 정책
- **알림 설정** (notification_settings): 알림 수신 설정

#### 디지털 서명 시스템
- **서명 캡처**: 터치스크린으로 서명 입력
- **서명 저장**: Firebase Storage에 이미지 저장
- **법적 효력**: 변경 불가능한 법적 문서

**주요 파일**:
- `screens/profile/regulation_screen.dart`: 생활수칙 및 서명
- `screens/profile/dormitory_life_guide_screen.dart`: 생활 안내
- `screens/profile/reward_penalty_screen.dart`: 상벌 제도
- `screens/profile/privacy_policy_screen.dart`: 개인정보 처리방침
- `screens/profile/notification_settings_screen.dart`: 알림 설정
- `models/regulation_agreement_model.dart`: 서명 데이터 모델

### 9. 🏠 호실 정보

**위치**: `lib/screens/room/`, `lib/models/room_assignment_model.dart`

배정된 호실 정보를 확인할 수 있습니다.

#### 정보
- **건물**: A동 또는 B동 (호실 번호로 자동 계산)
- **층**: 호실 번호 첫 자리
- **호실 번호**: 3자리 호실 번호
- **침대 번호**: 배정된 침대
- **입사일**: 기숙사 입사 날짜
- **퇴사 예정일**: 기숙사 퇴사 예정일
- **룸메이트**: 같은 호실 학생 정보
- **배정 상태**: active, expired, pending

**호실 번호 계산 로직**:
```dart
// UserModel에서 자동 계산
String get building {
  final lastTwoDigits = int.parse(roomNumber.substring(1));
  return lastTwoDigits <= 20 ? 'A동' : 'B동';
}

String get floor => '${roomNumber[0]}층';
```

**주요 파일**:
- `screens/room/room_info_screen.dart`: 호실 정보 화면
- `models/room_assignment_model.dart`: 호실 배정 데이터 모델

---

## 🛠️ 기술 스택

### Core Technologies
- **Framework**: Flutter ^3.9.2
- **언어**: Dart (latest stable)
- **UI**: Material Design 3
- **상태 관리**: Provider ^6.1.2

### Firebase Services
```yaml
firebase_core: ^3.8.1                    # Firebase 초기화
firebase_auth: ^5.3.3                    # 사용자 인증
cloud_firestore: ^5.5.2                  # NoSQL 데이터베이스
firebase_storage: ^12.3.6                # 파일/이미지 저장
firebase_messaging: ^15.1.6              # 푸시 알림
flutter_local_notifications: ^18.0.1     # 로컬 알림 표시
```

### UI 라이브러리
```yaml
google_fonts: ^6.2.1                     # 커스텀 폰트
flutter_svg: ^2.0.10+1                   # SVG 렌더링
cupertino_icons: ^1.0.8                  # iOS 스타일 아이콘
```

### 미디어 및 파일 처리
```yaml
image_picker: ^1.1.2                     # 이미지 선택 (카메라/갤러리)
file_picker: ^8.1.6                      # 파일 선택
video_player: ^2.9.2                     # 비디오 재생
syncfusion_flutter_pdfviewer: ^28.1.33   # PDF 뷰어
```

### 유틸리티
```yaml
intl: ^0.19.0                            # 날짜/시간 포맷팅
url_launcher: ^6.3.1                     # URL/전화번호 실행
shared_preferences: ^2.3.3               # 로컬 저장소
vibration: ^2.0.1                        # 디바이스 진동
fluttertoast: ^8.2.8                     # 토스트 메시지
signature: ^5.5.0                        # 디지털 서명 캡처
webview_flutter: ^4.10.0                 # 웹뷰 통합
```

### 개발 도구
```yaml
flutter_test: SDK                        # 테스팅 프레임워크
flutter_lints: ^5.0.0                    # 린트 규칙
flutter_native_splash: ^2.4.2            # 스플래시 스크린
flutter_launcher_icons: ^0.14.2          # 앱 아이콘 생성
```

---

## 🏁 시작하기

### 사전 요구사항

1. **Flutter SDK ^3.9.2 이상**
   ```bash
   flutter --version
   ```

2. **Dart (최신 안정 버전)**

3. **개발 환경**
   - Android: Android Studio + Android SDK
   - iOS: Xcode (macOS에서만)
   - 에디터: VS Code 또는 Android Studio

4. **Firebase 프로젝트**
   - Firebase Console 계정
   - 프로젝트 생성 및 설정

5. **Node.js 및 npm** (Firebase CLI 용)

### 설치 단계

#### 1️⃣ 저장소 클론
```bash
git clone https://github.com/your-org/swu_dormi.git
cd swu_dormi
```

#### 2️⃣ 패키지 설치
```bash
flutter pub get
```

#### 3️⃣ Firebase 설정

**Firebase 프로젝트 생성**:
1. [Firebase Console](https://console.firebase.google.com/)에서 새 프로젝트 생성
2. 프로젝트 이름: "SWU Dormi" 또는 원하는 이름
3. Google Analytics 활성화 (선택)

**Firebase CLI 및 FlutterFire CLI 설치**:
```bash
# Firebase CLI 설치
npm install -g firebase-tools

# Firebase 로그인
firebase login

# FlutterFire CLI 설치
dart pub global activate flutterfire_cli

# Firebase 프로젝트와 Flutter 앱 연결
flutterfire configure
```

위 명령어를 실행하면 `lib/firebase_options.dart` 파일이 자동 생성됩니다.

**Android 설정**:
1. Firebase Console에서 Android 앱 추가
2. 패키지 이름: `com.swu.dormi` (또는 실제 패키지명)
3. `google-services.json` 다운로드
4. 파일을 `android/app/` 디렉토리에 복사

**iOS 설정**:
1. Firebase Console에서 iOS 앱 추가
2. Bundle ID: `com.swu.dormi` (또는 실제 Bundle ID)
3. `GoogleService-Info.plist` 다운로드
4. Xcode에서 `ios/Runner/` 디렉토리에 추가

**Firebase 서비스 활성화**:

1. **Authentication**:
   - Firebase Console > Authentication > 로그인 방법
   - "이메일/비밀번호" 활성화

2. **Firestore Database**:
   - Firebase Console > Firestore Database
   - "데이터베이스 만들기" 클릭
   - 테스트 모드로 시작 (나중에 보안 규칙 설정)
   - 지역: asia-northeast3 (서울) 권장

3. **Firebase Storage**:
   - Firebase Console > Storage
   - "시작하기" 클릭
   - 테스트 모드로 시작

4. **Cloud Messaging (FCM)**:
   - Firebase Console > Cloud Messaging
   - FCM 자동 활성화됨

**보안 규칙 배포**:
```bash
# Firestore 규칙 배포
firebase deploy --only firestore:rules

# Storage 규칙 배포
firebase deploy --only storage
```

#### 4️⃣ 앱 실행
```bash
# 연결된 디바이스 확인
flutter devices

# 앱 실행
flutter run

# 특정 디바이스에서 실행
flutter run -d <device-id>
```

---

## 📁 프로젝트 구조

### 전체 구조

```
lib/
├── main.dart                           # 앱 진입점, Firebase 초기화
├── firebase_options.dart               # Firebase 자동 생성 설정
│
├── models/                             # 데이터 모델 (11개 파일)
│   ├── user_model.dart                # 사용자 프로필
│   ├── post_model.dart                # 커뮤니티 게시글
│   ├── comment_model.dart             # 댓글
│   ├── notice_model.dart              # 공지사항
│   ├── meal_model.dart                # 식단
│   ├── facility_report_model.dart     # 시설 신고
│   ├── check_in_out_model.dart        # 입퇴사 신청
│   ├── room_assignment_model.dart     # 호실 배정
│   ├── chat_message_model.dart        # 채팅 메시지
│   ├── notification_model.dart        # 알림
│   └── regulation_agreement_model.dart # 규정 동의 서명
│
├── providers/                          # 상태 관리 (1개 파일)
│   └── auth_provider.dart             # 인증 상태 관리
│
├── services/                           # 비즈니스 로직 (4개 파일)
│   ├── auth_service.dart              # Firebase Auth 래퍼
│   ├── database_service.dart          # Firestore 작업
│   ├── storage_service.dart           # Firebase Storage 작업
│   └── notification_service.dart      # FCM 및 알림 관리
│
├── screens/                            # UI 화면 (24+ 파일)
│   ├── auth/                          # 인증 화면
│   │   ├── login_screen.dart         # 로그인
│   │   └── signup_screen.dart        # 회원가입
│   │
│   ├── home/                          # 메인 화면
│   │   └── home_screen.dart          # 홈 대시보드
│   │
│   ├── board/                         # 커뮤니티
│   │   ├── board_screen.dart         # 게시판 목록
│   │   ├── add_post_screen.dart      # 게시글 작성/수정
│   │   └── post_detail_screen.dart   # 게시글 상세 및 댓글
│   │
│   ├── notices/                       # 공지사항
│   │   ├── notices_screen.dart       # 공지사항 목록
│   │   └── pdf_viewer_screen.dart    # PDF 뷰어
│   │
│   ├── facilities/                    # 시설 관리
│   │   └── facility_report_screen.dart # 신고 작성 및 내역
│   │
│   ├── check_in_out/                  # 입퇴사 관리
│   │   └── check_in_out_screen.dart  # 신청 작성 및 내역
│   │
│   ├── meal/                          # 식단
│   │   ├── meal_screen.dart          # 식단표
│   │   └── pdf_viewer_screen.dart    # PDF 뷰어
│   │
│   ├── notification/                  # 알림
│   │   └── notification_screen.dart  # 알림 목록
│   │
│   ├── profile/                       # 프로필 및 설정
│   │   ├── profile_screen.dart       # 프로필 조회
│   │   ├── profile_update_screen.dart # 프로필 수정
│   │   ├── change_password_screen.dart # 비밀번호 변경
│   │   ├── regulation_screen.dart    # 생활수칙 및 서명
│   │   ├── dormitory_life_guide_screen.dart # 생활 안내
│   │   ├── reward_penalty_screen.dart # 상벌 제도
│   │   ├── privacy_policy_screen.dart # 개인정보 처리방침
│   │   └── notification_settings_screen.dart # 알림 설정
│   │
│   └── room/                          # 호실 정보
│       └── room_info_screen.dart     # 호실 상세 정보
│
└── utils/                              # 유틸리티 (1개 파일)
    └── constants.dart                 # 앱 전역 상수 (색상, 스타일, 간격)
```

**총 Dart 파일**: 41개

### 아키텍처 패턴

본 프로젝트는 **레이어드 아키텍처**를 따릅니다:

```
┌─────────────────────────────────────────┐
│          Presentation Layer             │
│  (Screens, Widgets, UI Components)      │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│         State Management Layer          │
│        (Providers, ChangeNotifier)      │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│         Business Logic Layer            │
│   (Services: Auth, Database, Storage)   │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│            Data Layer                   │
│  (Models, Firebase Backend, Firestore)  │
└─────────────────────────────────────────┘
```

**데이터 흐름**:
```
UI → Provider → Service → Firebase
                    ↓
Firebase Stream → Service → Provider → UI 업데이트
```

---

## 🔥 Firebase 구조

### Firestore Collections

#### 1. users (사용자)
```javascript
{
  uid: string,                    // Firebase Auth UID
  email: string,
  name: string,
  nickname?: string,              // 별명
  studentId: string,              // 학번
  phoneNumber: string,
  roomNumber: string,             // 호실 (예: "201", "315")
  building: string,               // A동 또는 B동 (자동 계산)
  floor: string,                  // 층 (자동 계산)
  role: 'student' | 'admin',      // 역할
  college?: string,               // 단과대학
  department?: string,            // 학과
  profileImageUrl?: string,       // 프로필 사진 URL
  fcmToken?: string,              // FCM 토큰
  createdAt: Timestamp,
}
```

**호실 번호 규칙**:
- **A동**: 201-220, 301-320, 401-420
- **B동**: 221-240, 321-340, 421-440
- **층**: 첫 번째 자리 (2층, 3층, 4층)

#### 2. board_posts (커뮤니티 게시글)
```javascript
{
  id: string,
  title: string,
  content: string,
  authorId: string,               // users.uid 참조
  authorName: string,
  authorNickname?: string,
  authorProfileImageUrl?: string,
  createdAt: Timestamp,
  updatedAt: Timestamp,
  likeCount: number,
  commentCount: number,
  viewCount: number,
  likes: string[],                // 좋아요 누른 사용자 uid 배열
  imageUrls: string[],            // 첨부 이미지 URL (최대 5개)
}
```

#### 3. comments (댓글)
```javascript
{
  id: string,
  postId: string,                 // board_posts.id 참조
  content: string,
  authorId: string,               // users.uid 참조
  authorName: string,
  authorProfileImageUrl?: string,
  createdAt: Timestamp,
  likeCount: number,
  likes: string[],                // 좋아요 누른 사용자 uid 배열
}
```

**인덱스**:
- `postId` (ASC) + `createdAt` (ASC)

#### 4. notices (공지사항)
```javascript
{
  id: string,
  title: string,
  content: string,
  authorId: string,               // 관리자 uid
  authorName: string,
  createdAt: Timestamp,
  isImportant: boolean,           // 중요 공지 여부
  imageUrl?: string,              // 대표 이미지 (호환성)
  imageUrls: string[],            // 여러 이미지
  pdfUrl?: string,                // PDF 첨부 파일 URL
  pdfFileName?: string,           // PDF 파일명
}
```

#### 5. meals (식단)
```javascript
{
  id: string,
  date: string,                   // 'YYYY-MM-DD'
  meals: {
    breakfast: string[],          // 아침 메뉴 목록
    lunch: string[],              // 점심 메뉴 목록
    dinner: string[],             // 저녁 메뉴 목록
  },
  createdAt: Timestamp,
}
```

**인덱스**:
- `date` (DESC)

#### 6. repair_reports (시설 신고)
```javascript
{
  id: string,
  userId: string,                 // users.uid 참조
  userName: string,
  roomNumber: string,
  building: string,               // A동 또는 B동
  faultLocation: string,          // 'A방', 'B방', '거실', '화장실', '샤워실', '책상 A/B/C/D'
  category: 'furniture' | 'plumbing' | 'electrical' | 'other',
  title: string,
  description: string,
  imageUrl?: string,              // 고장 부위 사진
  reportedAt: Timestamp,
  status: 'pending' | 'in_progress' | 'completed',
  completedAt?: Timestamp,
  technicianNote?: string,        // 기술자 메모
}
```

**인덱스**:
- `userId` (ASC) + `reportedAt` (DESC)

#### 7. check_in_out_requests (입퇴사 신청)
```javascript
{
  id: string,
  userId: string,                 // users.uid 참조
  userName: string,
  roomNumber: string,
  type: 'check_in' | 'check_out', // 입사 또는 퇴사
  requestDate: Timestamp,         // 신청일
  scheduledDate: Timestamp,       // 희망 입/퇴사 날짜
  reason?: string,                // 퇴사 사유 (퇴사 시)
  status: 'pending' | 'approved' | 'rejected' | 'completed',
  approvedAt?: Timestamp,
  adminNote?: string,             // 관리자 메모
  approvedTime?: string,          // 승인된 시간대 (예: "14:00-15:00")
}
```

**인덱스**:
- `userId` (ASC) + `requestDate` (DESC)

#### 8. room_assignments (호실 배정)
```javascript
{
  id: string,
  userId: string,                 // users.uid 참조
  building: string,               // A동 또는 B동
  roomNumber: string,             // 호실 번호
  bedNumber?: string,             // 침대 번호
  assignedDate: Timestamp,        // 배정일
  endDate?: Timestamp,            // 퇴사 예정일
  roommateIds: string[],          // 룸메이트 uid 배열
  status: 'active' | 'expired' | 'pending',
}
```

#### 9. chat_messages (채팅 메시지)
```javascript
{
  id: string,
  repairReportId: string,         // repair_reports.id 참조
  senderId: string,               // 발신자 uid
  senderName: string,
  isAdmin: boolean,               // 관리자 여부
  message: string,
  sentAt: Timestamp,
}
```

**인덱스**:
- `repairReportId` (ASC) + `sentAt` (ASC)

#### 10. user_notifications (사용자 알림)
```javascript
{
  id: string,
  userId: string,                 // users.uid 참조
  type: 'notice' | 'chat' | 'check_in_out' | 'meal' | 'facility',
  title: string,
  content: string,
  createdAt: Timestamp,
  isRead: boolean,
}
```

#### 11. regulation_agreements (규정 동의 서명)
```javascript
{
  id: string,
  userId: string,                 // users.uid 참조
  userName: string,
  roomNumber: string,
  signatureUrl: string,           // 서명 이미지 URL
  agreedAt: Timestamp,
}
```

### Firebase Storage 구조

```
storage/
├── profile_images/
│   └── {userId}/
│       └── profile.jpg             # 사용자 프로필 사진
├── repair_images/
│   └── {reportId}/
│       └── repair.jpg              # 시설 신고 사진
├── notice_images/
│   └── {noticeId}/
│       ├── image_0.jpg             # 공지사항 이미지
│       └── image_1.jpg
├── notice_pdfs/
│   └── {noticeId}/
│       └── document.pdf            # 공지사항 PDF
├── board_posts/
│   └── {postId}/
│       ├── image_0.jpg             # 게시글 이미지 (최대 5개)
│       ├── image_1.jpg
│       └── ...
└── regulation_agreements/
    └── {userId}/
        └── signature.png           # 디지털 서명 (불변)
```

### Firestore Security Rules

**파일**: `firestore.rules`

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // 인증 확인
    function isAuthenticated() {
      return request.auth != null;
    }

    // 자신의 문서인지 확인
    function isOwner(userId) {
      return request.auth.uid == userId;
    }

    // 관리자 권한 확인
    function isAdmin() {
      return isAuthenticated() &&
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    // users 컬렉션
    match /users/{userId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() && isOwner(userId);
      allow update: if isAuthenticated() && (isOwner(userId) || isAdmin());
      allow delete: if isAdmin();
    }

    // board_posts 컬렉션
    match /board_posts/{postId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated();
      allow update: if isAuthenticated() &&
                      (isOwner(resource.data.authorId) || isAdmin());
      allow delete: if isAuthenticated() &&
                      (isOwner(resource.data.authorId) || isAdmin());
    }

    // comments 컬렉션
    match /comments/{commentId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated();
      allow update: if isAuthenticated() &&
                      (isOwner(resource.data.authorId) || isAdmin());
      allow delete: if isAuthenticated() &&
                      (isOwner(resource.data.authorId) || isAdmin());
    }

    // notices 컬렉션
    match /notices/{noticeId} {
      allow read: if isAuthenticated();
      allow create, update, delete: if isAdmin();
    }

    // meals 컬렉션
    match /meals/{mealId} {
      allow read: if isAuthenticated();
      allow create, update, delete: if isAdmin();
    }

    // repair_reports 컬렉션
    match /repair_reports/{reportId} {
      allow read: if isAuthenticated() &&
                     (isOwner(resource.data.userId) || isAdmin());
      allow create: if isAuthenticated();
      allow update: if isAdmin();
      allow delete: if isAdmin();
    }

    // check_in_out_requests 컬렉션
    match /check_in_out_requests/{requestId} {
      allow read: if isAuthenticated() &&
                     (isOwner(resource.data.userId) || isAdmin());
      allow create: if isAuthenticated();
      allow update: if isAdmin();
      allow delete: if isAdmin();
    }

    // room_assignments 컬렉션
    match /room_assignments/{assignmentId} {
      allow read: if isAuthenticated() &&
                     (isOwner(resource.data.userId) || isAdmin());
      allow create, update, delete: if isAdmin();
    }

    // chat_messages 컬렉션
    match /chat_messages/{messageId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated();
      allow update, delete: if isAdmin();
    }

    // user_notifications 컬렉션
    match /user_notifications/{notificationId} {
      allow read: if isAuthenticated() && isOwner(resource.data.userId);
      allow create: if isAdmin();
      allow update: if isAuthenticated() && isOwner(resource.data.userId);
      allow delete: if isAuthenticated() &&
                      (isOwner(resource.data.userId) || isAdmin());
    }

    // regulation_agreements 컬렉션
    match /regulation_agreements/{agreementId} {
      allow read: if isAuthenticated() &&
                     (isOwner(resource.data.userId) || isAdmin());
      allow create: if isAuthenticated();
      allow update, delete: if false; // 불변 문서
    }
  }
}
```

### Firebase Storage Security Rules

**파일**: `storage.rules`

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    // 인증된 사용자만 접근
    function isAuthenticated() {
      return request.auth != null;
    }

    // 이미지 파일 검증
    function isImage() {
      return request.resource.contentType.matches('image/.*');
    }

    // PDF 파일 검증
    function isPDF() {
      return request.resource.contentType == 'application/pdf';
    }

    // 파일 크기 제한 (10MB)
    function isValidSize() {
      return request.resource.size < 10 * 1024 * 1024;
    }

    // 프로필 이미지
    match /profile_images/{userId}/{fileName} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated() &&
                      request.auth.uid == userId &&
                      isImage() &&
                      isValidSize();
    }

    // 시설 신고 이미지
    match /repair_images/{reportId}/{fileName} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated() &&
                      isImage() &&
                      isValidSize();
    }

    // 공지사항 이미지
    match /notice_images/{noticeId}/{fileName} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated() &&
                      isImage() &&
                      isValidSize();
    }

    // 공지사항 PDF
    match /notice_pdfs/{noticeId}/{fileName} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated() &&
                      isPDF() &&
                      isValidSize();
    }

    // 게시판 이미지
    match /board_posts/{postId}/{fileName} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated() &&
                      isImage() &&
                      isValidSize();
    }

    // 규정 동의 서명 (불변)
    match /regulation_agreements/{userId}/{fileName} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() &&
                       request.auth.uid == userId &&
                       isImage() &&
                       isValidSize();
      allow update, delete: if false;
    }
  }
}
```

### Firestore 인덱스

**파일**: `firestore.indexes.json`

```json
{
  "indexes": [
    {
      "collectionGroup": "repair_reports",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "reportedAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "check_in_out_requests",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "requestDate", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "chat_messages",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "repairReportId", "order": "ASCENDING" },
        { "fieldPath": "sentAt", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "comments",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "postId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "ASCENDING" }
      ]
    }
  ]
}
```

---

## 📊 데이터 모델

### 모델 특징

모든 데이터 모델은 다음을 포함합니다:

1. **직렬화 메서드**:
   - `toMap()`: Dart 객체 → Map (Firestore에 저장)
   - `fromMap()`: Map → Dart 객체 (Firestore에서 읽기)

2. **Timestamp 처리**:
   - Firestore Timestamp ↔ Dart DateTime 자동 변환

3. **Null Safety**:
   - Null 가능한 필드는 `?` 표시
   - 기본값 제공

4. **리스트 처리**:
   - 빈 리스트를 기본값으로 제공
   - `List<String>.from()` 사용

### 주요 모델 예시

#### UserModel
```dart
class UserModel {
  final String uid;
  final String email;
  final String name;
  final String? nickname;
  final String studentId;
  final String phoneNumber;
  final String roomNumber;
  final String role;
  final String? college;
  final String? department;
  final String? profileImageUrl;
  final String? fcmToken;
  final DateTime createdAt;

  // 계산된 속성
  String get building {
    final lastTwoDigits = int.parse(roomNumber.substring(1));
    return lastTwoDigits <= 20 ? 'A동' : 'B동';
  }

  String get floor => '${roomNumber[0]}층';

  // 직렬화
  Map<String, dynamic> toMap();
  factory UserModel.fromMap(Map<String, dynamic> map);
}
```

#### PostModel (커뮤니티)
```dart
class PostModel {
  final String id;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final String? authorNickname;
  final String? authorProfileImageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int likeCount;
  final int commentCount;
  final int viewCount;
  final List<String> likes;
  final List<String> imageUrls;

  // 직렬화
  Map<String, dynamic> toMap();
  factory PostModel.fromMap(Map<String, dynamic> map);
}
```

#### FacilityReportModel
```dart
class FacilityReportModel {
  final String id;
  final String userId;
  final String userName;
  final String roomNumber;
  final String building;
  final String faultLocation;
  final String category;
  final String title;
  final String description;
  final String? imageUrl;
  final DateTime reportedAt;
  final String status;
  final DateTime? completedAt;
  final String? technicianNote;

  // 직렬화
  Map<String, dynamic> toMap();
  factory FacilityReportModel.fromMap(Map<String, dynamic> map);
}
```

---

## 🔄 상태 관리

### Provider 패턴

본 프로젝트는 **Provider** 패턴을 사용하여 상태를 관리합니다.

#### AuthProvider

**파일**: `lib/providers/auth_provider.dart`

```dart
class AuthProvider with ChangeNotifier {
  final AuthService _authService;
  final DatabaseService _databaseService;

  UserModel? _currentUser;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;

  // 초기화: Firebase Auth 상태 리스너
  void _initAuth() {
    _authService.authStateChanges.listen((firebaseUser) async {
      if (firebaseUser != null) {
        await refreshUser();
      } else {
        _currentUser = null;
        notifyListeners();
      }
    });
  }

  // 회원가입
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    // ... 기타 필드
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signUp(/* ... */);
      await refreshUser();
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 로그인
  Future<void> signIn(String email, String password) async {
    // ...
  }

  // 로그아웃
  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    notifyListeners();
  }

  // 사용자 정보 새로고침
  Future<void> refreshUser() async {
    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      _currentUser = await _databaseService.getUser(uid);
      notifyListeners();
    }
  }
}
```

#### Provider 등록 (main.dart)

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            authService: AuthService(),
            databaseService: DatabaseService(),
          ),
        ),
        // 필요 시 추가 Provider
      ],
      child: MyApp(),
    ),
  );
}
```

#### UI에서 Provider 사용

**Provider 읽기**:
```dart
final authProvider = Provider.of<AuthProvider>(context);
final currentUser = authProvider.currentUser;
```

**Consumer 사용** (선택적 리빌드):
```dart
Consumer<AuthProvider>(
  builder: (context, authProvider, child) {
    if (authProvider.isLoading) {
      return CircularProgressIndicator();
    }
    return Text('Welcome ${authProvider.currentUser?.name}');
  },
)
```

### StreamBuilder (실시간 데이터)

Firestore의 실시간 업데이트는 `StreamBuilder`를 사용합니다.

```dart
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection('board_posts')
      .orderBy('createdAt', descending: true)
      .snapshots(),
  builder: (context, snapshot) {
    if (snapshot.hasError) {
      return Text('오류: ${snapshot.error}');
    }

    if (snapshot.connectionState == ConnectionState.waiting) {
      return CircularProgressIndicator();
    }

    final posts = snapshot.data!.docs
        .map((doc) => PostModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList();

    return ListView.builder(
      itemCount: posts.length,
      itemBuilder: (context, index) => PostCard(post: posts[index]),
    );
  },
)
```

---

## 🎨 디자인 시스템

### SWU 브랜드 컬러

**파일**: `lib/utils/constants.dart`

```dart
class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF9E1A20);      // 버건디/퍼플
  static const Color secondary = Color(0xFF101077);    // 딥 네이비
  static const Color accent = Color(0xFFFFB300);       // 골드/옐로우

  // Neutral Colors
  static const Color background = Color(0xFFF8F8F8);   // 라이트 그레이
  static const Color surface = Color(0xFFFFFFFF);      // 화이트
  static const Color textPrimary = Color(0xFF212121);  // 다크 그레이
  static const Color textSecondary = Color(0xFF757575);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
}
```

### 타이포그래피

```dart
class AppTextStyles {
  // Headings
  static const TextStyle headingLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // Body
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    color: AppColors.textPrimary,
  );

  // Caption
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );
}
```

### 간격 시스템

```dart
class AppSpacing {
  static const double xs = 4.0;    // Extra Small
  static const double sm = 8.0;    // Small
  static const double md = 16.0;   // Medium
  static const double lg = 24.0;   // Large
  static const double xl = 32.0;   // Extra Large
}
```

### UI 컴포넌트 스타일

**버튼**:
```dart
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    padding: EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
  ),
  onPressed: () {},
  child: Text('버튼'),
)
```

**카드**:
```dart
Card(
  elevation: 2,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
  child: Padding(
    padding: EdgeInsets.all(AppSpacing.md),
    child: /* content */,
  ),
)
```

### 특수 UI 요소

#### 인터랙티브 로고
홈 화면의 SWU 로고는 탭하여 색상을 전환할 수 있습니다 (빨강 ↔ 파랑).

#### 배지 시스템
```dart
Badge(
  label: Text('5'),
  child: Icon(Icons.notifications),
)
```

#### 진동 패턴
```dart
// 알림 수신 시
Vibration.vibrate(pattern: [0, 200, 100, 200]);
```

---

## 💻 개발 가이드

### 새로운 기능 추가하기

#### 1. 모델 생성

```dart
// lib/models/new_feature_model.dart
class NewFeatureModel {
  final String id;
  final String title;
  final DateTime createdAt;

  NewFeatureModel({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory NewFeatureModel.fromMap(Map<String, dynamic> map) {
    return NewFeatureModel(
      id: map['id'] as String,
      title: map['title'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}
```

#### 2. Service 메서드 추가

```dart
// lib/services/database_service.dart에 추가
Future<void> createNewFeature(NewFeatureModel feature) async {
  await _firestore
      .collection('new_features')
      .doc(feature.id)
      .set(feature.toMap());
}

Stream<List<NewFeatureModel>> getNewFeatures() {
  return _firestore
      .collection('new_features')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => NewFeatureModel.fromMap(doc.data()))
          .toList());
}
```

#### 3. UI 화면 작성

```dart
// lib/screens/new_feature/new_feature_screen.dart
class NewFeatureScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final databaseService = DatabaseService();

    return Scaffold(
      appBar: AppBar(title: Text('New Feature')),
      body: StreamBuilder<List<NewFeatureModel>>(
        stream: databaseService.getNewFeatures(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('오류: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final features = snapshot.data!;

          return ListView.builder(
            itemCount: features.length,
            itemBuilder: (context, index) {
              final feature = features[index];
              return ListTile(
                title: Text(feature.title),
                subtitle: Text(feature.createdAt.toString()),
              );
            },
          );
        },
      ),
    );
  }
}
```

#### 4. Firestore 보안 규칙 추가

```javascript
match /new_features/{featureId} {
  allow read: if isAuthenticated();
  allow create: if isAuthenticated();
  allow update, delete: if isAdmin();
}
```

### 에러 처리

```dart
try {
  await databaseService.createPost(post);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('게시글이 작성되었습니다')),
  );
} on FirebaseException catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('오류: ${e.message}')),
  );
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('알 수 없는 오류가 발생했습니다')),
  );
}
```

### 이미지 업로드

```dart
// 이미지 선택
final ImagePicker picker = ImagePicker();
final XFile? image = await picker.pickImage(source: ImageSource.gallery);

if (image != null) {
  // 업로드
  final storageService = StorageService();
  final imageUrl = await storageService.uploadImage(
    File(image.path),
    'board_posts/${postId}/image_0.jpg',
  );

  // URL 저장
  await databaseService.updatePost(postId, {'imageUrl': imageUrl});
}
```

---

## 🚀 빌드 및 배포

### Android 빌드

#### Debug APK
```bash
flutter build apk --debug
```

#### Release APK
```bash
flutter build apk --release
```

APK 파일 위치: `build/app/outputs/flutter-apk/app-release.apk`

#### App Bundle (Google Play Store)
```bash
flutter build appbundle --release
```

App Bundle 위치: `build/app/outputs/bundle/release/app-release.aab`

#### 서명 설정

1. 키스토어 생성:
```bash
keytool -genkey -v -keystore ~/swu-dormi-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias swu-dormi
```

2. `android/key.properties` 생성:
```properties
storePassword=<비밀번호>
keyPassword=<키 비밀번호>
keyAlias=swu-dormi
storeFile=<키스토어 절대 경로>
```

3. `android/app/build.gradle`에서 서명 설정 확인

### iOS 빌드

#### Debug
```bash
flutter build ios --debug
```

#### Release
```bash
flutter build ios --release
```

#### App Store 배포
1. Xcode에서 프로젝트 열기:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. Signing & Capabilities에서 팀 선택
3. Archive 생성
4. App Store Connect 업로드

### 앱 아이콘 및 스플래시 스크린

#### 앱 아이콘 생성
```bash
flutter pub run flutter_launcher_icons
```

설정 (`pubspec.yaml`):
```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/images/logo.jpg"
  adaptive_icon_background: "#FFFFFF"
```

#### 스플래시 스크린 생성
```bash
flutter pub run flutter_native_splash:create
```

설정 (`pubspec.yaml`):
```yaml
flutter_native_splash:
  color: "#FFFFFF"
  image: assets/images/logo.jpg
  android_12:
    color: "#FFFFFF"
    image: assets/images/logo.jpg
```

---

## 🔧 문제 해결

### 일반적인 문제

#### 1. Firebase 초기화 오류
```
[core/no-app] No Firebase App '[DEFAULT]' has been created
```

**해결 방법**:
- `main.dart`에서 `Firebase.initializeApp()` 호출 확인
- `flutterfire configure` 재실행
- `firebase_options.dart` 파일 존재 확인

#### 2. Android 빌드 오류
```
FAILURE: Build failed with an exception
```

**해결 방법**:
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk
```

#### 3. iOS 빌드 오류 (Cocoapods)
```
pod install 실패
```

**해결 방법**:
```bash
cd ios
pod deintegrate
pod install
cd ..
flutter clean
flutter pub get
```

#### 4. 이미지 업로드 실패
```
FirebaseException: [storage/unauthorized]
```

**해결 방법**:
- Firebase Storage 규칙 확인
- 파일 크기 10MB 이하 확인
- 파일 타입 확인 (이미지: image/*, PDF: application/pdf)

#### 5. Firestore 권한 오류
```
FirebaseException: [permission-denied]
```

**해결 방법**:
- Firestore 보안 규칙 확인
- 사용자 인증 상태 확인
- 관리자 권한이 필요한 작업인지 확인

#### 6. FCM 알림이 수신되지 않음

**해결 방법**:
- FCM 토큰이 Firestore에 저장되었는지 확인
- Android: `google-services.json` 파일 확인
- iOS: APNs 인증서 설정 확인
- 앱이 백그라운드/종료 상태일 때 테스트

#### 7. Windows에서 심볼릭 링크 오류

**해결 방법**:
1. 설정 > 업데이트 및 보안 > 개발자용
2. "개발자 모드" 켜기

---

## 📚 관련 문서

- [Flutter 공식 문서](https://flutter.dev/docs)
- [Firebase Flutter 문서](https://firebase.google.com/docs/flutter/setup)
- [Provider 패턴 가이드](https://pub.dev/packages/provider)
- [Material Design 3](https://m3.material.io/)
- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)

---

## 🔗 관련 프로젝트

- **swu_dormi_admin_w**: 기숙사 관리자용 Windows 데스크톱 앱
- **swu_global**: 외국인 학생용 모바일 앱
- **swu_global_admin**: 외국인 학생 관리자용 웹 시스템

---

## 📄 라이선스

이 프로젝트는 서울여자대학교의 소유입니다.

---

## 📞 문의

문제가 발생하거나 문의사항이 있으시면 GitHub Issues를 통해 알려주세요.

---

## 🙏 기여

프로젝트 기여를 환영합니다!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📝 업데이트 로그

### Version 1.0.0
- ✅ 기본 인증 시스템 (이메일/비밀번호)
- ✅ 공지사항 게시판
- ✅ 커뮤니티 게시판 (게시글, 댓글, 좋아요)
- ✅ 시설 고장 신고 및 채팅
- ✅ 입퇴사 신청 시스템
- ✅ 식단표 조회
- ✅ FCM 푸시 알림
- ✅ 디지털 서명 시스템
- ✅ 호실 정보 조회

---

**Made with ❤️ by SWU Development Team**
