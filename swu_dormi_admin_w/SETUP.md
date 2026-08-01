# 프로젝트 설정 가이드

Git에서 클론한 후 누락된 파일들을 복구하고 프로젝트를 실행하는 방법입니다.

## 1. Flutter 개발 환경 설정

### Flutter SDK 설치
1. [Flutter 공식 웹사이트](https://flutter.dev)에서 Windows용 Flutter SDK 다운로드
2. 압축 해제 후 원하는 위치에 저장 (예: `C:\flutter`)
3. 시스템 환경 변수 PATH에 Flutter bin 폴더 추가
   - `제어판` > `시스템` > `고급 시스템 설정` > `환경 변수`
   - 사용자 변수 또는 시스템 변수의 Path에 `C:\flutter\bin` 추가

### Visual Studio 설치 (필수!)

Windows에서 Flutter 앱을 빌드하려면 Visual Studio가 필요합니다.

1. **Visual Studio 2022 Community 다운로드**
   - https://visualstudio.microsoft.com/ko/downloads/
   - 무료 Community 버전 다운로드

2. **설치 시 필요한 워크로드 선택**
   - ✅ **"C++를 사용한 데스크톱 개발"** (필수)
   - 이 워크로드에는 다음이 포함됩니다:
     - CMake 3.x (Firebase 빌드에 필요)
     - MSBuild
     - Windows SDK
     - C++ 컴파일러

3. **설치 후 시스템 재시작 (권장)**

### 설치 확인
```bash
flutter doctor
```

이 명령어를 실행하여 필요한 도구들이 설치되어 있는지 확인합니다.

**중요:** Visual Studio 항목에 체크마크(✓)가 있어야 합니다!

예상 출력:
```
[✓] Flutter (Channel stable, 3.x.x, on Microsoft Windows)
[✓] Windows Version (Installed version of Windows is version 10 or higher)
[✓] Visual Studio - develop Windows apps (Visual Studio Community 2022 17.x.x)
```

Visual Studio 항목에 문제가 있다면 [TROUBLESHOOTING.md](TROUBLESHOOTING.md)를 참조하세요.

## 2. 프로젝트 의존성 설치

프로젝트 폴더에서 다음 명령어 실행:

```bash
flutter pub get
```

이 명령어는 `pubspec.yaml`에 정의된 모든 패키지를 다운로드합니다.

## 3. Firebase 설정

### FlutterFire CLI 설치
```bash
dart pub global activate flutterfire_cli
```

### Firebase 프로젝트 연결
```bash
flutterfire configure
```

이 명령어를 실행하면:
1. Firebase 로그인 창이 열립니다
2. 기존 Firebase 프로젝트 선택 또는 새 프로젝트 생성
3. Windows 플랫폼 선택
4. 자동으로 `lib/firebase_options.dart` 파일 생성

### Firebase 서비스 활성화

Firebase Console (https://console.firebase.google.com)에서:

1. **Authentication 활성화**
   - Authentication > Sign-in method
   - 이메일/비밀번호 활성화

2. **Firestore Database 생성**
   - Firestore Database > Create database
   - 프로덕션 모드 시작
   - 위치: asia-northeast3 (서울)

3. **Storage 활성화**
   - Storage > Get started
   - 보안 규칙 기본값으로 시작

4. **보안 규칙 설정**
   - README.md의 "Firestore 보안 규칙 설정" 섹션 참조
   - README.md의 "Storage 보안 규칙 설정" 섹션 참조

## 4. 관리자 계정 생성

### Firebase Console에서 수동 생성

1. **Authentication에 사용자 추가**
   - Firebase Console > Authentication > Users
   - "사용자 추가" 클릭
   - 이메일: `admin@swu.ac.kr` (원하는 이메일)
   - 비밀번호: 안전한 비밀번호 입력
   - UID 복사해두기

2. **Firestore에 관리자 문서 추가**
   - Firebase Console > Firestore Database
   - 컬렉션 `users` 생성 (없는 경우)
   - 문서 ID: 위에서 복사한 UID
   - 필드 추가:
     ```
     email: "admin@swu.ac.kr"
     name: "관리자"
     role: "admin"
     createdAt: [현재 타임스탬프]
     ```

## 5. 이미지 및 리소스 파일

### 앱 아이콘
프로젝트에는 기본 아이콘이 포함되어 있습니다:
- `windows/runner/resources/app_icon.ico`
- `assets/images/logo.jpg`

커스텀 아이콘을 사용하려면:
1. 아이콘 파일을 위 경로에 배치
2. ICO 파일은 256x256 크기 권장

### 추가 이미지
`assets/images/` 폴더에 필요한 이미지 추가 후 `pubspec.yaml`에 등록:
```yaml
flutter:
  assets:
    - assets/images/
```

## 6. 프로젝트 실행

### 디버그 모드 실행
```bash
flutter run -d windows
```

또는 제공된 배치 파일 실행:
```bash
run_debug.bat
```

### 릴리스 빌드 생성
```bash
flutter build windows --release
```

또는 제공된 배치 파일 실행:
```bash
build.bat
```

빌드된 파일은 `build\windows\x64\runner\Release\` 폴더에 생성됩니다.

## 7. VSCode 설정 (선택사항)

프로젝트에 `.vscode/launch.json`과 `.vscode/settings.json`이 포함되어 있습니다.

VSCode에서 프로젝트 열기:
1. VSCode 실행
2. `파일` > `폴더 열기` > 프로젝트 폴더 선택
3. Flutter 및 Dart 확장 프로그램 설치 권장
4. F5를 눌러 디버그 실행

## 8. 문제 해결

### "Flutter SDK를 찾을 수 없습니다"
- Flutter SDK가 올바르게 설치되었는지 확인
- 환경 변수 PATH에 Flutter bin 폴더가 추가되었는지 확인
- 터미널을 재시작

### "패키지를 다운로드할 수 없습니다"
```bash
flutter clean
flutter pub get
```

### "Firebase 연결 오류"
- `firebase_options.dart` 파일이 생성되었는지 확인
- Firebase 프로젝트에 앱이 등록되었는지 확인
- 인터넷 연결 확인

### "로그인할 수 없습니다"
- Firebase Authentication이 활성화되었는지 확인
- 관리자 계정이 올바르게 생성되었는지 확인
- Firestore의 users 컬렉션에 role: "admin" 필드가 있는지 확인

### Visual Studio 관련 오류 (Windows)
Windows에서 Flutter 앱을 빌드하려면 Visual Studio가 필요합니다:
```bash
flutter doctor
```
실행 후 안내에 따라 Visual Studio 설치

## 9. 추가 리소스

- [Flutter 공식 문서](https://flutter.dev/docs)
- [Firebase 공식 문서](https://firebase.google.com/docs)
- [FlutterFire 공식 문서](https://firebase.flutter.dev)
- [프로젝트 README](README.md)
- [기여 가이드](CONTRIBUTING.md)

## 10. 지원

문제가 발생하면:
1. 이 문서의 "문제 해결" 섹션 확인
2. README.md의 "문제 해결" 섹션 확인
3. GitHub Issues에 문제 보고

---

설정이 완료되면 `run_debug.bat`을 실행하여 앱을 시작할 수 있습니다!
