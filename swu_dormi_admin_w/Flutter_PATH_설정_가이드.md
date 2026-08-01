# Flutter PATH 설정 가이드

Android Studio나 명령 프롬프트에서 `flutter` 명령어가 작동하지 않는다면 Flutter SDK가 시스템 PATH에 등록되지 않은 것입니다.

## 🔍 1단계: Flutter SDK 설치 여부 확인

### 방법 1: 자동 확인 스크립트 실행
```
flutter_설치_확인.bat (더블클릭)
```

### 방법 2: 수동 확인
다음 위치에 Flutter 폴더가 있는지 확인:
- `C:\flutter`
- `C:\src\flutter`
- `C:\Users\[사용자이름]\flutter`

Flutter 폴더 안에 `bin` 폴더가 있어야 합니다.

---

## 📦 2단계: Flutter SDK 설치 (없는 경우만)

### Flutter SDK 다운로드 및 설치

1. **다운로드**
   - https://docs.flutter.dev/get-started/install/windows
   - "flutter_windows_3.x.x-stable.zip" 다운로드

2. **압축 해제**
   - 다운로드한 zip 파일을 `C:\` 드라이브에 압축 해제
   - 최종 경로: `C:\flutter`

3. **설치 확인**
   - `C:\flutter\bin` 폴더가 있는지 확인
   - 폴더 안에 `flutter.bat` 파일이 있어야 함

---

## ⚙️ 3단계: 시스템 PATH에 Flutter 등록

### Windows 10/11 설정 방법

1. **시스템 설정 열기**
   - `Windows 키` + `Pause/Break` 키
   - 또는: 제어판 > 시스템 및 보안 > 시스템

2. **고급 시스템 설정 클릭**
   - 왼쪽 메뉴에서 "고급 시스템 설정" 클릭

3. **환경 변수 클릭**
   - "고급" 탭에서 "환경 변수" 버튼 클릭

4. **사용자 변수의 Path 편집**
   - 상단 "사용자 변수" 섹션에서 `Path` 선택
   - "편집" 버튼 클릭

5. **Flutter bin 경로 추가**
   - "새로 만들기" 클릭
   - Flutter bin 폴더 경로 입력:
     ```
     C:\flutter\bin
     ```
   - (Flutter를 다른 위치에 설치했다면 해당 경로 입력)

6. **저장**
   - "확인" 버튼 3번 클릭하여 모든 창 닫기

7. **터미널 재시작**
   - **중요!** 모든 명령 프롬프트, PowerShell, Android Studio 창을 닫고 다시 열기
   - 환경 변수 변경사항이 적용되려면 재시작 필요

---

## ✅ 4단계: 설치 확인

### 새 명령 프롬프트 열고 실행:

```bash
flutter --version
```

정상적으로 설치되었다면 다음과 같은 출력이 나옵니다:
```
Flutter 3.x.x • channel stable • https://github.com/flutter/flutter.git
Framework • revision xxxxx
Engine • revision xxxxx
Tools • Dart 3.x.x
```

### Flutter Doctor 실행:

```bash
flutter doctor
```

결과 예시:
```
[✓] Flutter (Channel stable, 3.x.x)
[✓] Windows Version (Installed version of Windows is version 10 or higher)
[!] Android toolchain - develop for Android devices
[✓] Visual Studio - develop Windows apps
[✓] Android Studio (version 2024.x)
[✓] VS Code (version 1.x.x)
```

---

## 🔧 Android Studio 전용 설정

### Android Studio에서 Flutter SDK 경로 설정

1. **Android Studio 열기**

2. **Settings 열기**
   - File > Settings (또는 `Ctrl + Alt + S`)

3. **Flutter 플러그인 설정**
   - Languages & Frameworks > Flutter

4. **Flutter SDK path 설정**
   - "Flutter SDK path" 입력란에 Flutter 설치 경로 입력:
     ```
     C:\flutter
     ```

5. **Apply 및 OK 클릭**

6. **Android Studio 재시작**

---

## 🚨 문제 해결

### 여전히 flutter 명령어가 작동하지 않는 경우

1. **터미널을 완전히 재시작했는지 확인**
   - Android Studio 완전 종료 후 재실행
   - 또는 시스템 재부팅

2. **PATH 등록 확인**
   ```bash
   echo %PATH%
   ```
   출력에 `C:\flutter\bin`이 포함되어 있어야 함

3. **직접 실행 시도**
   ```bash
   C:\flutter\bin\flutter.bat --version
   ```
   이 명령어가 작동하면 PATH 문제임

4. **시스템 변수에도 추가** (사용자 변수에 추가했는데 안 되는 경우)
   - 환경 변수 창에서 하단 "시스템 변수" 섹션의 Path에도 동일하게 추가

---

## 💡 빠른 해결: 직접 경로로 실행

PATH 설정이 복잡하다면 임시로 다음과 같이 사용:

```bash
C:\flutter\bin\flutter doctor
C:\flutter\bin\flutter pub get
C:\flutter\bin\flutter run -d windows
```

하지만 개발 편의를 위해 PATH 설정을 권장합니다.

---

## 📱 Android Studio 터미널에서 바로 테스트

PATH 설정 후 Android Studio 하단의 Terminal 탭에서:

```bash
flutter --version
flutter doctor
```

정상 작동하면 설정 완료!

---

## 🎯 요약

1. Flutter SDK 다운로드 및 압축 해제 (`C:\flutter`)
2. 환경 변수 Path에 `C:\flutter\bin` 추가
3. 모든 터미널/Android Studio 재시작
4. `flutter --version` 명령어로 확인

PATH 설정만 제대로 되면 모든 터미널에서 Flutter 명령어를 사용할 수 있습니다!
