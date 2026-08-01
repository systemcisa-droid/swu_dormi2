@echo off
echo =====================================
echo Flutter 설치 상태 확인
echo =====================================
echo.

echo [1] Flutter 명령어 확인 중...
where flutter >nul 2>&1
if %errorlevel% equ 0 (
    echo ✓ Flutter가 PATH에 등록되어 있습니다
    echo.
    echo Flutter 버전:
    flutter --version
    echo.
    echo Flutter Doctor 실행:
    flutter doctor
) else (
    echo ✗ Flutter가 PATH에 등록되어 있지 않습니다
    echo.
    echo Flutter SDK 설치 위치를 확인해주세요:
    echo.
    echo 일반적인 설치 위치:
    echo   - C:\flutter
    echo   - C:\src\flutter
    echo   - %USERPROFILE%\flutter
    echo.
    echo Flutter SDK 폴더를 찾으셨다면:
    echo 1. 제어판 열기
    echo 2. 시스템 및 보안 ^> 시스템
    echo 3. 고급 시스템 설정 ^> 환경 변수
    echo 4. 사용자 변수의 Path 편집
    echo 5. 새로 만들기 클릭
    echo 6. Flutter SDK의 bin 폴더 경로 입력 (예: C:\flutter\bin)
    echo 7. 확인 클릭
    echo 8. 모든 터미널 창 닫고 다시 열기
    echo.
    echo Flutter SDK가 설치되지 않았다면:
    echo https://docs.flutter.dev/get-started/install/windows
)

echo.
echo =====================================
pause
