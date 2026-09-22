@echo off
echo =====================================
echo SWU 샬롬하우스 관리자 앱 자동 재빌드
echo =====================================
echo.
echo 자동으로 빌드 캐시를 삭제하고 재빌드합니다.
echo.

echo =====================================
echo [1/5] 빌드 캐시 삭제 중...
echo =====================================
echo.

REM build 폴더 삭제
if exist "build" (
    echo build 폴더 삭제 중...
    rd /s /q build
    echo ✓ build 폴더 삭제 완료
) else (
    echo build 폴더 없음 (정상)
)

REM .dart_tool 폴더 삭제
if exist ".dart_tool" (
    echo .dart_tool 폴더 삭제 중...
    rd /s /q .dart_tool
    echo ✓ .dart_tool 폴더 삭제 완료
) else (
    echo .dart_tool 폴더 없음 (정상)
)

echo.
echo =====================================
echo [2/5] Flutter clean 실행 중...
echo =====================================
echo.

flutter clean

echo.
echo =====================================
echo [3/5] 패키지 의존성 설치 중...
echo =====================================
echo.

call flutter pub get
if %errorlevel% neq 0 (
    echo 오류: 패키지 설치 실패
    pause
    exit /b 1
)

echo.
echo =====================================
echo [4/5] 초기 빌드 시도...
echo =====================================
echo.

REM 첫 빌드로 Firebase SDK 다운로드
flutter build windows --debug

echo.
echo =====================================
echo [5/5] CMake 수정 및 최종 빌드...
echo =====================================
echo.

REM Firebase CMake 파일 수정
set FIREBASE_CMAKE=build\windows\x64\extracted\firebase_cpp_sdk_windows\CMakeLists.txt

if exist "%FIREBASE_CMAKE%" (
    echo Firebase CMake 파일 수정 중...
    powershell -Command "(Get-Content '%FIREBASE_CMAKE%') -replace 'cmake_minimum_required\(VERSION 3\.1\)', 'cmake_minimum_required(VERSION 3.5)' | Set-Content '%FIREBASE_CMAKE%'"
    echo ✓ CMake 파일 수정 완료
    echo.
)

REM 최종 빌드
echo 최종 빌드 중...
flutter build windows --debug

echo.
echo =====================================
echo 빌드 완료 확인...
echo =====================================
echo.

set EXE_PATH=build\windows\x64\runner\Debug\swu_dormi_admin.exe

if exist "%EXE_PATH%" (
    echo.
    echo ✓✓✓ 빌드 성공! ✓✓✓
    echo.
    echo 실행 파일 위치:
    echo %EXE_PATH%
    echo.
    echo 앱을 실행합니다...
    start "" "%EXE_PATH%"
    echo.
    echo ✓ 앱이 실행되었습니다!
) else (
    echo.
    echo ✗ 빌드 실패
    echo.
    echo TROUBLESHOOTING.md 파일을 참조하세요.
)

echo.
echo =====================================
pause
