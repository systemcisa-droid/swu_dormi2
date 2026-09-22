@echo off
echo =====================================
echo SWU 샬롬하우스 관리자 앱 실행
echo =====================================
echo.

set EXE_PATH=build\windows\x64\runner\Debug\swu_dormi_admin.exe

if exist "%EXE_PATH%" (
    echo 앱을 실행합니다...
    echo.
    start "" "%EXE_PATH%"
    echo.
    echo ✓ 앱이 실행되었습니다!
    echo.
    echo 만약 창이 열리지 않는다면:
    echo 1. Windows Defender가 차단할 수 있습니다
    echo    - "추가 정보" 클릭 후 "실행" 선택
    echo 2. 직접 파일을 실행해보세요:
    echo    %EXE_PATH%
) else (
    echo ✗ 실행 파일을 찾을 수 없습니다.
    echo.
    echo 다음 명령어로 빌드를 시도하세요:
    echo   run_with_fix.bat
)

echo.
pause
