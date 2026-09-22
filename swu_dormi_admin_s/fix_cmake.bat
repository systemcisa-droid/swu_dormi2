@echo off
echo =====================================
echo CMake 버전 오류 자동 수정 스크립트
echo =====================================
echo.

set FIREBASE_CMAKE=build\windows\x64\extracted\firebase_cpp_sdk_windows\CMakeLists.txt

if not exist "%FIREBASE_CMAKE%" (
    echo Firebase CMake 파일을 찾을 수 없습니다.
    echo 먼저 빌드를 한 번 시도해주세요.
    echo.
    pause
    exit /b 1
)

echo Firebase CMake 파일 수정 중...
powershell -Command "(Get-Content '%FIREBASE_CMAKE%') -replace 'cmake_minimum_required\(VERSION 3\.1\)', 'cmake_minimum_required(VERSION 3.5)' | Set-Content '%FIREBASE_CMAKE%'"

if %errorlevel% equ 0 (
    echo.
    echo ✓ 수정 완료!
    echo.
    echo 이제 다시 빌드를 시도하세요:
    echo   flutter run -d windows
    echo.
) else (
    echo.
    echo ✗ 수정 실패
    echo.
)

pause
