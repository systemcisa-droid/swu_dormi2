# SWU 샬롬하우스 관리자 앱

서울여자대학교 기숙사 관리를 위한 관리자용 Flutter 애플리케이션입니다.

## 주요 기능

### 1. 대시보드
- 실시간 통계 확인 (입퇴사 대기, 외박 대기, 시설 신고, 총 학생 수)
- 각 관리 화면으로 빠른 이동

### 2. 공지사항 관리
- 공지사항 목록 조회
- 공지사항 작성 (PDF 첨부 가능)
- 공지사항 수정 및 삭제
- 중요 공지사항 고정 기능

### 3. 입퇴사 신청 관리
- 입사/퇴사 신청 목록 조회
- 신청 승인/거부 처리
- 상태별 필터링 (전체/대기중/승인/거부)

### 4. 외박 신청 관리
- 외박 신청 목록 조회
- 신청 승인/거부 처리
- 상태별 필터링
- 외박 기간 및 사유 확인

### 5. 식단표 관리
- 식단표 등록 및 조회
- 날짜별 조식/중식/석식 관리
- 식단표 수정 및 삭제

### 6. 시설 신고 관리 (준비 중)
- 시설 고장 신고 접수
- 처리 상태 관리

### 7. 학생 관리 (준비 중)
- 학생 정보 조회 및 관리
- 호실 배정 관리

## 설치 방법

### 1. 패키지 설치
```bash
cd swu_dormi_admin
flutter pub get
```

### 2. Firebase 설정

#### 2-1. Firebase 프로젝트 생성
1. [Firebase Console](https://console.firebase.google.com/)에 접속
2. 새 프로젝트 생성 또는 기존 프로젝트 선택
3. 프로젝트 이름: "SWU Dormi" (또는 원하는 이름)

#### 2-2. Firebase 앱 등록
1. Firebase 프로젝트에서 Android/iOS/Web 앱 추가
2. 패키지 이름: `com.example.swu_dormi_admin`

#### 2-3. FlutterFire CLI 설치 및 설정
```bash
# FlutterFire CLI 설치
dart pub global activate flutterfire_cli

# Firebase 프로젝트 설정
flutterfire configure
```

위 명령어를 실행하면 자동으로 `lib/firebase_options.dart` 파일이 생성됩니다.

#### 2-4. Firestore 보안 규칙 설정
Firebase Console > Firestore Database > 규칙 탭에서 다음 규칙 적용:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 관리자만 접근 가능
    function isAdmin() {
      return request.auth != null &&
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    // users 컬렉션
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if isAdmin();
    }

    // notices 컬렉션
    match /notices/{noticeId} {
      allow read: if request.auth != null;
      allow write: if isAdmin();
    }

    // check_in_out_requests 컬렉션
    match /check_in_out_requests/{requestId} {
      allow read: if request.auth != null;
      allow write: if isAdmin();
    }

    // overnight_requests 컬렉션
    match /overnight_requests/{requestId} {
      allow read: if request.auth != null;
      allow write: if isAdmin();
    }

    // facilities 컬렉션
    match /facilities/{facilityId} {
      allow read: if request.auth != null;
      allow write: if isAdmin();
    }

    // meals 컬렉션
    match /meals/{mealId} {
      allow read: if request.auth != null;
      allow write: if isAdmin();
    }

    // chats 컬렉션
    match /chats/{chatId} {
      allow read: if request.auth != null;
      allow write: if isAdmin();
    }
  }
}
```

#### 2-5. Storage 보안 규칙 설정
Firebase Console > Storage > 규칙 탭에서 다음 규칙 적용:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // 관리자만 업로드 가능
    match /{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null &&
                      firestore.get(/databases/(default)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

### 3. 관리자 계정 생성

#### 방법 1: Firebase Console에서 수동 생성
1. Firebase Console > Authentication > Users
2. "사용자 추가" 클릭
3. 이메일과 비밀번호 입력
4. Firestore Database > users 컬렉션에 문서 추가:
   ```json
   {
     "email": "admin@example.com",
     "name": "관리자",
     "role": "admin",
     "createdAt": [현재 시간]
   }
   ```

#### 방법 2: 코드로 생성 (개발 환경에서만)
앱에서 일시적으로 계정 생성 기능을 활성화하여 관리자 계정 생성 후 해당 기능 제거

### 4. 앱 실행
```bash
flutter run
```

## 프로젝트 구조

```
lib/
├── models/              # 데이터 모델
│   ├── admin_model.dart
│   ├── notice_model.dart
│   ├── check_in_out_model.dart
│   ├── overnight_model.dart
│   ├── facility_model.dart
│   ├── meal_model.dart
│   └── student_model.dart
├── screens/             # 화면
│   ├── auth/            # 인증 관련
│   │   └── login_screen.dart
│   ├── dashboard/       # 대시보드
│   │   └── dashboard_screen.dart
│   ├── notices/         # 공지사항 관리
│   │   └── notices_management_screen.dart
│   ├── check_in_out/    # 입퇴사 관리
│   │   └── check_in_out_management_screen.dart
│   ├── overnight/       # 외박 관리
│   │   └── overnight_management_screen.dart
│   ├── meals/           # 식단표 관리
│   │   └── meals_management_screen.dart
│   ├── facilities/      # 시설 관리 (준비 중)
│   └── students/        # 학생 관리 (준비 중)
├── services/            # 서비스 (비즈니스 로직)
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   └── storage_service.dart
├── widgets/             # 공통 위젯
├── firebase_options.dart # Firebase 설정
└── main.dart            # 앱 진입점
```

## 사용된 패키지

- **firebase_core**: Firebase 초기화
- **firebase_auth**: 사용자 인증
- **cloud_firestore**: 데이터베이스
- **firebase_storage**: 파일 저장소
- **provider**: 상태 관리
- **intl**: 날짜/시간 포맷팅
- **image_picker**: 이미지 선택
- **file_picker**: 파일 선택
- **webview_flutter**: PDF 뷰어
- **fl_chart**: 차트 (통계용)

## 학생용 앱과의 연동

이 관리자 앱은 학생용 앱(SWU_Dormi)과 동일한 Firebase 프로젝트를 사용합니다.

### Firebase 프로젝트 공유 방법
1. 두 앱 모두 같은 Firebase 프로젝트에 등록
2. 각 앱에 대한 플랫폼별 설정 파일 생성
3. Firestore와 Storage의 보안 규칙에서 role 기반 접근 제어

### 데이터베이스 구조
```
users/
  {userId}/
    - email
    - name
    - studentId (학생만)
    - roomNumber (학생만)
    - role: "admin" | "student"
    - createdAt

notices/
  {noticeId}/
    - title
    - content
    - authorId
    - authorName
    - pdfUrl (optional)
    - pdfFileName (optional)
    - imageUrls[]
    - isPinned
    - createdAt

check_in_out_requests/
  {requestId}/
    - userId
    - userName
    - studentId
    - type: "check_in" | "check_out"
    - roomNumber
    - requestDate
    - status: "pending" | "approved" | "rejected"
    - rejectionReason (optional)
    - createdAt
    - processedAt (optional)

overnight_requests/
  {requestId}/
    - userId
    - userName
    - studentId
    - roomNumber
    - startDate
    - endDate
    - reason
    - destination
    - emergencyContact
    - status: "pending" | "approved" | "rejected"
    - rejectionReason (optional)
    - createdAt
    - processedAt (optional)

meals/
  {mealId}/
    - date
    - meals: {
        breakfast: []
        lunch: []
        dinner: []
      }
    - createdAt

facilities/
  {facilityId}/
    - userId
    - userName
    - category
    - location
    - description
    - imageUrls[]
    - status: "pending" | "in_progress" | "completed"
    - adminNote (optional)
    - createdAt
    - processedAt (optional)
```

## 개발 참고사항

### 새로운 기능 추가 시
1. 모델 생성 (`lib/models/`)
2. 서비스 메서드 추가 (`lib/services/firestore_service.dart`)
3. 화면 생성 (`lib/screens/`)
4. 대시보드에 메뉴 추가 (`lib/screens/dashboard/dashboard_screen.dart`)

### 보안 주의사항
- 관리자 권한은 Firestore의 users 컬렉션에서 role 필드로 관리
- 모든 민감한 작업은 서버 사이드에서 권한 검증
- Firebase 보안 규칙을 철저히 설정

## 문제 해결

### Firebase 연결 오류
- `firebase_options.dart` 파일이 올바르게 생성되었는지 확인
- Firebase 프로젝트에 앱이 등록되었는지 확인

### 로그인 오류
- Firebase Authentication이 활성화되어 있는지 확인
- 관리자 계정의 role이 'admin'으로 설정되어 있는지 확인

### 데이터 접근 오류
- Firestore 보안 규칙이 올바르게 설정되어 있는지 확인
- 사용자의 role이 'admin'인지 확인

## 라이선스

이 프로젝트는 서울여자대학교 기숙사 관리용으로 제작되었습니다.
