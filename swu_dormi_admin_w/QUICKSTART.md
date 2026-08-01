# 빠른 시작 가이드

프로젝트를 최대한 빠르게 실행하기 위한 간단한 가이드입니다.

## ⚡ 5분 안에 시작하기

### 1단계: 필수 도구 설치 (처음 한 번만)

#### Flutter SDK
1. https://flutter.dev/docs/get-started/install/windows 다운로드
2. 압축 해제 후 `C:\flutter`에 저장
3. 시스템 환경 변수 PATH에 `C:\flutter\bin` 추가
4. 터미널 재시작

#### Visual Studio 2022 (필수!)
1. https://visualstudio.microsoft.com/ko/downloads/ 다운로드
2. **"C++를 사용한 데스크톱 개발"** 워크로드 선택하여 설치
3. 재시작

#### 설치 확인
```bash
flutter doctor
```

모든 항목에 ✓ 표시가 있어야 합니다.

### 2단계: 프로젝트 설정

```bash
# 프로젝트 폴더로 이동
cd swu_dormi_admin_w

# 패키지 설치
flutter pub get

# Firebase CLI 설치
dart pub global activate flutterfire_cli

# Firebase 연결 (프로젝트 ID: swu-dormi-17962)
flutterfire configure --project=swu-dormi-17962
```

Firebase 로그인 창이 열리면:
1. Google 계정으로 로그인
2. 프로젝트 선택: **swu-dormi-17962**
3. 플랫폼 선택: **Windows** (스페이스바로 선택)
4. Enter 키로 확인

### 3단계: Firebase Console 설정

https://console.firebase.google.com/project/swu-dormi-17962 접속

#### Authentication 활성화
1. Authentication > Get started
2. Sign-in method > Email/Password 활성화

#### Firestore Database 생성
1. Firestore Database > Create database
2. 프로덕션 모드 시작
3. 위치: asia-northeast3 (Seoul)

#### Storage 활성화
1. Storage > Get started
2. 기본 설정으로 시작

#### 보안 규칙 설정
복사해서 붙여넣기:

**Firestore 규칙:**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isAdmin() {
      return request.auth != null &&
             get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    match /{document=**} {
      allow read: if request.auth != null;
      allow write: if isAdmin();
    }
  }
}
```

**Storage 규칙:**
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

### 4단계: 관리자 계정 생성

#### Firebase Console에서:
1. **Authentication > Users > Add user**
   - Email: `admin@swu.ac.kr` (원하는 이메일)
   - Password: 안전한 비밀번호
   - Add user 클릭
   - **UID 복사!** (예: `abc123def456`)

2. **Firestore Database > Start collection**
   - Collection ID: `users`
   - Document ID: 위에서 복사한 UID 붙여넣기
   - Fields:
     ```
     email (string): admin@swu.ac.kr
     name (string): 관리자
     role (string): admin
     createdAt (timestamp): [현재 시간]
     ```
   - Save

### 5단계: 앱 실행!

```bash
flutter run -d windows
```

또는 더블클릭:
```
run_debug.bat
```

### 6단계: 로그인

앱이 실행되면:
1. Email: `admin@swu.ac.kr` (또는 생성한 이메일)
2. Password: 생성 시 입력한 비밀번호
3. 로그인

완료! 🎉

---

## 🔧 문제 발생 시

### CMake 오류
```bash
# Visual Studio "C++를 사용한 데스크톱 개발" 워크로드가 설치되어 있는지 확인
flutter doctor -v
```

### 빌드 오류
```bash
flutter clean
flutter pub get
flutter run -d windows
```

### Firebase 연결 오류
```bash
flutterfire configure --project=swu-dormi-17962
```

### 로그인 오류
- Firebase Console에서 관리자 계정 생성 확인
- Firestore의 users 컬렉션에 `role: "admin"` 있는지 확인

### 더 자세한 도움말
- [SETUP.md](SETUP.md) - 상세한 설정 가이드
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - 문제 해결 가이드
- [README.md](README.md) - 전체 프로젝트 문서

---

## 📝 체크리스트

설정 전에 확인:
- [ ] Flutter SDK 설치됨
- [ ] Visual Studio 2022 (C++ 워크로드) 설치됨
- [ ] `flutter doctor` 모두 ✓
- [ ] Firebase 프로젝트 접근 권한 있음
- [ ] 인터넷 연결 정상

설정 후 확인:
- [ ] `flutter pub get` 성공
- [ ] `flutterfire configure` 성공
- [ ] `lib/firebase_options.dart` 파일 생성됨
- [ ] Firebase Authentication 활성화됨
- [ ] Firestore Database 생성됨
- [ ] Storage 활성화됨
- [ ] 보안 규칙 적용됨
- [ ] 관리자 계정 생성됨 (role: admin)
- [ ] 앱 실행 성공
- [ ] 로그인 성공

모든 항목 체크 완료 = 준비 완료! ✅
