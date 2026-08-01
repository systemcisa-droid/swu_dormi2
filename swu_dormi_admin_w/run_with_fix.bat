@echo off
echo =====================================
echo SWU 샬롬하우스 관리자 앱 실행
echo (CMake 오류 자동 수정 포함)
echo =====================================
echo.

echo [1/3] 패키지 의존성 확인 중...
call flutter pub get
if %errorlevel% neq 0 (
    echo 오류: 패키지 설치 실패
    pause
    exit /b 1
)

echo.
echo [2/3] CMake 버전 문제 확인 및 수정 중...

REM 첫 빌드 시도 (Firebase SDK 다운로드용)
echo 초기 빌드 시도 중... (Firebase SDK 다운로드)
flutter build windows --debug 2>nul

REM Firebase CMake 파일 수정
set FIREBASE_CMAKE=build\windows\x64\extracted\firebase_cpp_sdk_windows\CMakeLists.txt

if exist "%FIREBASE_CMAKE%" (
    echo Firebase CMake 파일 수정 중...
    powershell -Command "(Get-Content '%FIREBASE_CMAKE%') -replace 'cmake_minimum_required\(VERSION 3\.1\)', 'cmake_minimum_required(VERSION 3.5)' | Set-Content '%FIREBASE_CMAKE%'" >nul 2>&1
    echo ✓ CMake 파일 수정 완료
) else (
    echo ! Firebase CMake 파일을 찾을 수 없습니다 (정상일 수 있음)
)

echo.
echo [3/3] 앱 빌드 및 실행 중...
echo.

REM Flutter 빌드 시도 (오류가 발생해도 계속 진행)
flutter build windows --debug 2>nul

REM 실행 파일 확인
set EXE_PATH=build\windows\x64\runner\Debug\swu_dormi_admin.exe

if exist "%EXE_PATH%" (
    echo.
    echo ✓ 빌드 성공! 앱을 실행합니다...
    echo.
    start "" "%EXE_PATH%"
    echo.
    echo 앱이 실행되었습니다!
    echo.
    echo 참고: MSBuild INSTALL 오류는 무시해도 됩니다.
    echo       실행 파일은 정상적으로 생성되었습니다.
) else (
    echo.
    echo ! 실행 파일을 찾을 수 없습니다.
    echo   Flutter run을 시도합니다...
    echo.
    flutter run -d windows
)

pause
