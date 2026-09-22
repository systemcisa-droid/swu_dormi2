# 문제 해결 가이드

## CMake 관련 오류

### 오류: "generator : Visual Studio XX does not match the generator used previously"

#### 증상
```
CMake Error: Error: generator : Visual Studio 17 2022
Does not match the generator used previously: Visual Studio 18 2026
Either remove the CMakeCache.txt file and CMakeFiles directory or choose a different binary directory.
Error: Unable to generate build files
```

#### 원인
- 이전에 다른 버전의 Visual Studio로 빌드한 캐시가 남아있음
- Visual Studio를 업데이트하거나 변경한 경우 발생
- CMake 캐시 파일이 충돌

#### 해결 방법: 빌드 캐시 완전 삭제 (가장 확실!)

**방법 1: 자동 스크립트 사용 (권장)**
```bash
완전재빌드.bat
```
이 스크립트는 캐시 삭제부터 재빌드까지 자동으로 처리합니다.

**방법 2: 수동으로 캐시만 삭제**
```bash
빌드캐시삭제.bat
```
그런 다음:
```bash
flutter pub get
flutter build windows --debug
```

**방법 3: 명령어로 직접 삭제**
```bash
rd /s /q build
rd /s /q .dart_tool
flutter clean
flutter pub get
flutter build windows --debug
```

### 오류: "Compatibility with CMake < 3.5 has been removed"

Firebase C++ SDK를 사용하는 Windows 빌드 시 CMake 버전 호환성 문제가 발생할 수 있습니다.

#### 해결 방법 1: Visual Studio Build Tools 설치 (권장)

Flutter Windows 앱을 빌드하려면 Visual Studio 또는 Visual Studio Build Tools가 필요합니다.

1. **Visual Studio 2022 Community 다운로드**
   - https://visualstudio.microsoft.com/ko/downloads/
   - 무료 Community 버전 다운로드

2. **설치 시 필요한 워크로드 선택**
   - "C++를 사용한 데스크톱 개발" 체크
   - 이 워크로드에는 CMake 3.x가 포함되어 있습니다

3. **설치 후 Flutter doctor 실행**
   ```bash
   flutter doctor
   ```
   Visual Studio가 제대로 인식되는지 확인

4. **프로젝트 재빌드**
   ```bash
   flutter clean
   flutter pub get
   flutter run -d windows
   ```

#### 해결 방법 2: CMake 직접 설치

Visual Studio를 설치하지 않으려면 CMake만 별도로 설치할 수 있습니다.

1. **CMake 다운로드**
   - https://cmake.org/download/
   - Windows x64 Installer 다운로드 (최신 버전 권장)

2. **설치 시 옵션**
   - "Add CMake to the system PATH for all users" 선택

3. **설치 확인**
   ```bash
   cmake --version
   ```
   CMake 3.5 이상 버전이어야 합니다

4. **프로젝트 재빌드**
   ```bash
   flutter clean
   flutter pub get
   flutter run -d windows
   ```

#### 해결 방법 3: 자동 수정 스크립트 사용 (빠른 임시 해결책)

Visual Studio를 설치할 수 없는 상황이라면, 제공된 스크립트를 사용하세요.

**방법 A: 자동 실행 스크립트**
```bash
run_with_fix.bat
```
이 스크립트는 CMake 오류를 자동으로 수정하고 앱을 실행합니다.

**방법 B: 수동 수정**
```bash
fix_cmake.bat
```
이 스크립트는 CMake 파일만 수정합니다. 수정 후:
```bash
flutter run -d windows
```

**주의:** 이 방법은 임시 해결책입니다. `flutter clean`을 실행하면 다시 수정해야 합니다.

#### 해결 방법 4: 빌드 캐시 삭제

이전 빌드 캐시가 문제를 일으킬 수 있습니다.

```bash
flutter clean
rd /s /q build
flutter pub get
flutter run -d windows
```

**참고:** 캐시 삭제 후 CMake 오류가 다시 발생하면 `run_with_fix.bat`을 사용하세요.

### 오류: "Error: Unable to generate build files"

#### 원인
- CMake가 설치되지 않음
- CMake 버전이 너무 낮음 (3.5 미만)
- Visual Studio C++ 도구가 설치되지 않음
- 빌드 캐시 손상

#### 해결 방법
1. Visual Studio Build Tools 설치 (해결 방법 1 참조)
2. CMake 버전 확인 및 업데이트
3. 빌드 캐시 삭제

## Firebase 관련 오류

### 오류: "FirebaseException: [core/no-app]"

#### 원인
Firebase가 제대로 초기화되지 않음

#### 해결 방법
1. `firebase_options.dart` 파일이 존재하는지 확인
   ```bash
   ls lib/firebase_options.dart
   ```

2. Firebase 재설정
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

3. Windows 플랫폼 선택 확인

### 오류: "Firebase 연결 실패"

#### 해결 방법
1. **인터넷 연결 확인**

2. **Firebase 프로젝트 상태 확인**
   - Firebase Console에서 프로젝트가 활성화되어 있는지 확인
   - Authentication, Firestore, Storage가 활성화되어 있는지 확인

3. **firebase_options.dart 재생성**
   ```bash
   flutterfire configure --project=swu-dormi-17962
   ```

## 패키지 관련 오류

### 오류: "pub get failed"

#### 해결 방법
1. **인터넷 연결 확인**

2. **pub cache 삭제**
   ```bash
   flutter pub cache repair
   ```

3. **패키지 재설치**
   ```bash
   flutter clean
   flutter pub get
   ```

### 오류: "version solving failed"

#### 해결 방법
1. **Flutter 버전 확인**
   ```bash
   flutter --version
   ```
   Flutter 3.9.2 이상이어야 합니다

2. **Flutter 업그레이드**
   ```bash
   flutter upgrade
   ```

3. **pubspec.yaml 검증**
   - 패키지 버전이 서로 호환되는지 확인

## 로그인 관련 오류

### 오류: "로그인할 수 없습니다" / "잘못된 비밀번호"

#### 해결 방법
1. **Firebase Authentication 확인**
   - Firebase Console > Authentication
   - 이메일/비밀번호 인증이 활성화되어 있는지 확인

2. **관리자 계정 확인**
   - Firebase Console > Authentication > Users
   - 해당 이메일 계정이 존재하는지 확인

3. **Firestore 관리자 역할 확인**
   - Firebase Console > Firestore Database
   - users 컬렉션에서 해당 사용자 문서 확인
   - `role: "admin"` 필드가 있는지 확인

### 오류: "권한이 없습니다"

#### 해결 방법
1. **Firestore 보안 규칙 확인**
   - README.md의 보안 규칙을 Firebase Console에 적용했는지 확인

2. **사용자 role 확인**
   ```
   Firestore > users > [userId] > role: "admin"
   ```

## 빌드 관련 오류

### 오류: "MSB3073: 명령이 종료되었습니다(코드: 1)" / "Build process failed"

#### 증상
빌드가 거의 완료되었지만 마지막 INSTALL 단계에서 MSBuild 오류가 발생합니다.

#### 중요: 이 오류는 무시해도 됩니다!
실행 파일(`swu_dormi_admin.exe`)은 이미 정상적으로 생성되었습니다. INSTALL 단계의 오류는 앱 실행에 영향을 주지 않습니다.

#### 해결 방법 1: 직접 실행
```bash
run_direct.bat
```
또는
```bash
build\windows\x64\runner\Debug\swu_dormi_admin.exe
```

#### 해결 방법 2: 자동 실행 스크립트 사용
```bash
run_with_fix.bat
```
이 스크립트는 MSBuild 오류를 무시하고 생성된 실행 파일을 자동으로 실행합니다.

#### 해결 방법 3: 릴리스 빌드 시도
디버그 빌드 대신 릴리스 빌드를 시도하면 오류가 발생하지 않을 수 있습니다.
```bash
flutter build windows --release
build\windows\x64\runner\Release\swu_dormi_admin.exe
```

### 오류: "Flutter SDK를 찾을 수 없습니다"

#### 해결 방법
1. **Flutter 설치 확인**
   ```bash
   where flutter
   ```

2. **환경 변수 PATH 설정**
   - 제어판 > 시스템 > 고급 시스템 설정 > 환경 변수
   - Path에 Flutter bin 폴더 추가 (예: `C:\flutter\bin`)

3. **터미널 재시작**

### 오류: "Gradle build failed" (Android 관련)

이 프로젝트는 Windows 전용이므로 Android 빌드는 지원하지 않습니다.

```bash
flutter run -d windows
```

## 실행 관련 오류

### 오류: "App crashes on startup"

#### 해결 방법
1. **로그 확인**
   ```bash
   flutter run -d windows --verbose
   ```

2. **Firebase 초기화 오류 확인**
   - main.dart의 Firebase 초기화 코드 확인

3. **빌드 재시도**
   ```bash
   flutter clean
   flutter pub get
   flutter run -d windows
   ```

### 오류: "화면이 비어있음 / 위젯이 표시되지 않음"

#### 해결 방법
1. **핫 리로드 시도**
   - 실행 중인 앱에서 `r` 키 입력

2. **핫 리스타트 시도**
   - 실행 중인 앱에서 `R` 키 입력

3. **완전 재빌드**
   ```bash
   flutter clean
   flutter run -d windows
   ```

## Windows 특정 오류

### 오류: "win32_window.cpp 컴파일 오류"

#### 해결 방법
1. **Visual Studio C++ 도구 확인**
   ```bash
   flutter doctor -v
   ```
   Visual Studio 섹션에 체크마크가 있어야 함

2. **Visual Studio 재설치**
   - "C++를 사용한 데스크톱 개발" 워크로드 포함

### 오류: "MSBuild 오류"

#### 해결 방법
1. **Visual Studio 버전 확인**
   - Visual Studio 2019 또는 2022 권장

2. **Windows SDK 설치**
   - Visual Studio Installer에서 Windows SDK 설치

## 성능 관련 문제

### 문제: "앱이 느림"

#### 해결 방법
1. **릴리스 모드로 빌드**
   ```bash
   flutter build windows --release
   ```

2. **디버그 콘솔 메시지 확인**
   - 불필요한 빌드나 재렌더링이 있는지 확인

### 문제: "메모리 사용량이 높음"

#### 해결 방법
1. **이미지 최적화**
   - 큰 이미지는 압축하여 사용

2. **불필요한 위젯 제거**
   - const 생성자 사용

## 추가 도움말

### Flutter Doctor 실행
```bash
flutter doctor -v
```

모든 체크마크가 녹색이어야 합니다.

### 로그 확인
```bash
flutter run -d windows --verbose
```

상세한 오류 로그를 확인할 수 있습니다.

### 캐시 완전 삭제
```bash
flutter clean
rd /s /q build
rd /s /q .dart_tool
flutter pub get
```

---

위의 방법으로 해결되지 않는 문제가 있다면 GitHub Issues에 다음 정보와 함께 보고해주세요:
- 오류 메시지 전체
- `flutter doctor -v` 출력
- `flutter --version` 출력
- 실행한 명령어
