@echo off
echo =====================================
echo SWU 샬롬하우스 관리자 앱 빌드 스크립트
echo =====================================
echo.

REM 패키지 설치 확인
echo [1/4] 패키지 의존성 확인 중...
call flutter pub get
if %errorlevel% neq 0 (
    echo 오류: 패키지 설치 실패
    pause
    exit /b 1
)

echo.
echo [2/4] 코드 분석 중...
call flutter analyze
if %errorlevel% neq 0 (
    echo 경고: 코드 분석에서 문제가 발견되었습니다
    echo 계속하시겠습니까? (Y/N)
    set /p continue=
    if /i not "%continue%"=="Y" (
        exit /b 1
    )
)

echo.
echo [3/4] Windows 릴리스 빌드 생성 중...
call flutter build windows --release
if %errorlevel% neq 0 (
    echo 오류: 빌드 실패
    pause
    exit /b 1
)

echo.
echo [4/4] 빌드 완료!
echo.
echo 빌드된 파일 위치:
echo build\windows\x64\runner\Release\
echo.
echo =====================================
echo 빌드가 성공적으로 완료되었습니다!
echo =====================================
pause
