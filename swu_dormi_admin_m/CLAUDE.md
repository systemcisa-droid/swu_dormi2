## 하네스: swu_dormi_admin_m (층장 전용 모바일 앱)

**목표:** 층장(floor captain) 모바일 앱의 화면/Firestore 기능 개발을 flutter-dev + firebase-firestore 에이전트로 조율한다.

**트리거:** 이 프로젝트에서 화면 추가/수정, Firestore 연동, 층장 권한 로직, 버그 수정 등 개발 작업 요청 시 `flutter-feature-dev` 스킬을 사용하라. 단순 질문은 직접 응답 가능.

**변경 이력:**
| 날짜 | 변경 내용 | 대상 | 사유 |
|------|----------|------|------|
| 2026-07-18 | 초기 구성 (기존 architect/dev/pm/qa 커맨드 및 개별 에이전트 제거 후 재구축) | 전체 | 프로젝트별 코드베이스 탐색 기반 하네스로 재설계 |
| 2026-08-02 | 1학기 admin_m 코드베이스 전체를 통째 복사(커밋 안 된 변경 포함), Firebase는 2학기 DB(swu-dormi2) 유지 | 전체 lib/, pubspec 등 | 사용자 요청 — 기능 격차가 커서 이식보다 전체 교체가 효율적. nav shell이 3개→10개 화면 연결로 확장되어 flutter-dev.md 서술 갱신 |
