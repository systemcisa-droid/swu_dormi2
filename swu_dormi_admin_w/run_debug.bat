@echo off
echo =====================================
echo SWU 샬롬하우스 관리자 앱 디버그 실행
echo =====================================
echo.

echo 패키지 의존성 확인 중...
call flutter pub get

echo.
echo 앱을 디버그 모드로 실행합니다...
echo.
call flutter run -d windows

pause
