@echo off
echo =====================================
echo 빌드 캐시 완전 삭제
echo =====================================
echo.

echo 기존 빌드 캐시를 삭제합니다...
echo.

REM build 폴더 삭제
if exist "build" (
    echo [1/3] build 폴더 삭제 중...
    rd /s /q build
    echo ✓ build 폴더 삭제 완료
) else (
    echo [1/3] build 폴더가 없습니다 (정상)
)

echo.

REM .dart_tool 폴더 삭제
if exist ".dart_tool" (
    echo [2/3] .dart_tool 폴더 삭제 중...
    rd /s /q .dart_tool
    echo ✓ .dart_tool 폴더 삭제 완료
) else (
    echo [2/3] .dart_tool 폴더가 없습니다 (정상)
)

echo.

REM Flutter clean 실행
echo [3/3] Flutter clean 실행 중...
flutter clean 2>nul
if %errorlevel% equ 0 (
    echo ✓ Flutter clean 완료
) else (
    echo ! Flutter가 설치되지 않았거나 PATH에 없습니다
    echo   수동 삭제로도 충분합니다
)

echo.
echo =====================================
echo ✓ 빌드 캐시 삭제 완료!
echo =====================================
echo.
echo 이제 다음 명령어로 새로 빌드하세요:
echo   run_with_fix.bat
echo.
echo 또는:
echo   flutter pub get
echo   flutter build windows --debug
echo.

pause
