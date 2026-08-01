## 하네스: swu_dormi_student (학생 앱, Android + iOS)

**목표:** 학생 앱(4개 자매 프로젝트 중 최종 사용자가 직접 쓰는 핵심 앱)의 화면/Firestore 기능 개발과 디자인 톤 검증을 flutter-dev + firebase-firestore + ui-reviewer 에이전트로 조율한다.

**디자인 톤:** 20대 대학생 여성 타겟, 모던하되 과하게 귀엽지 않게 (파스텔 남발/장식 모티프/과도한 라운드 지양). iOS 사용자 비중이 크므로 iOS에서 위화감 없는 디자인/인터랙션을 함께 고려한다.

**트리거:** 이 프로젝트에서 화면 추가/수정, Firestore 연동, UI/디자인 검토, 버그 수정 등 개발 작업 요청 시 `flutter-feature-dev` 스킬을 사용하라. 단순 질문은 직접 응답 가능.

**변경 이력:**
| 날짜 | 변경 내용 | 대상 | 사유 |
|------|----------|------|------|
| 2026-07-18 | 초기 구성 (기존 architect/dev/pm/qa 커맨드 및 개별 에이전트 제거 후 재구축) | 전체 | 프로젝트별 코드베이스 탐색 기반 하네스로 재설계 |
| 2026-07-18 | ui-reviewer 에이전트 추가, 오케스트레이터에 검증 단계 반영 | agents/ui-reviewer.md, skills/flutter-feature-dev | 학생 앱이 전체 프로젝트의 핵심 화면 — 20대 여대생 타겟의 모던/절제된 디자인 톤 전담 검토 필요 |
| 2026-07-18 | "Android 전용" 전제 정정, iOS 감성 반영 원칙 추가 | agents/flutter-dev.md, agents/ui-reviewer.md, CLAUDE.md | 실제로는 Android+iOS 양쪽 실사용, iOS 사용자 비중이 커 Flutter를 선택한 이유였음 — 이전 탐색에서 iOS를 미사용으로 잘못 판단 |
