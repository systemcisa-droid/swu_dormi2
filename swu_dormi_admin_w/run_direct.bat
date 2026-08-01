@echo off
echo =====================================
echo SWU 샬롬하우스 관리자 앱 직접 실행
echo =====================================
echo.

REM 빌드된 실행 파일 경로
set EXE_PATH=build\windows\x64\runner\Debug\swu_dormi_admin.exe

REM 실행 파일이 존재하는지 확인
if exist "%EXE_PATH%" (
    echo 앱을 실행합니다...
    echo.
    start "" "%EXE_PATH%"
    echo.
    echo 앱이 실행되었습니다!
    echo 창이 열리지 않으면 Windows Defender에서 차단되었을 수 있습니다.
) else (
    echo 오류: 실행 파일을 찾을 수 없습니다.
    echo.
    echo 먼저 빌드를 시도하세요:
    echo   flutter build windows --debug
    echo.
    echo 또는:
    echo   run_with_fix.bat
)

echo.
pause
