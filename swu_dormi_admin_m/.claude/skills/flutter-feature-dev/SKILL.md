---
name: flutter-feature-dev
description: "swu_dormi_admin_m(층장 전용 모바일 앱)의 기능 개발을 오케스트레이션하는 스킬. 화면 추가/수정, Firestore 연동, 층장 계정/권한 로직, 버그 수정 등 '이 프로젝트에서 개발해줘' 류 요청 시 사용. '기능 다시 만들어줘', '이전 작업 이어서', '이 부분만 수정' 같은 후속 요청에도 사용."
---

# swu_dormi_admin_m 기능 개발 오케스트레이터

층장 전용 모바일 앱의 기능 개발을 `flutter-dev`, `firebase-firestore` 두 에이전트로 조율한다.

## Phase 0: 컨텍스트 확인
- `_workspace/`가 있으면 이전 작업 산출물을 먼저 읽고, 부분 수정 요청이면 해당 에이전트만 재호출한다.
- 없으면 신규 요청으로 처리한다.

## 실행 모드
**서브 에이전트 패턴.** 대부분 단일 화면/기능 단위 작업이라 팀 조율 오버헤드보다 직접 호출이 효율적이다.

## 워크플로우

1. **분석**: 요청이 Firestore 스키마/쿼리 변경 또는 층장 권한 로직(`floor_captain_accounts.dart`, `assignedFloor`)을 포함하는지 판단한다.
2. **Firestore/권한 우선 처리**: 해당되면 `firebase-firestore` 에이전트를 먼저 호출한다.
3. **UI/로직 구현**: `flutter-dev` 에이전트를 호출해 화면/위젯을 구현한다. nav shell에 새 화면을 연결하는 작업은 사용자가 명시적으로 요청했는지 반드시 확인 후 진행한다(현재 cleaning/attendance/profile 3개만 연결됨).
4. **검증**: `flutter analyze` 결과 확인, 이상 시 1회 재수정 요청.

## 에러 핸들링
에이전트 실행 실패 시 1회 재시도 후에도 실패하면 해당 부분 없이 진행하고 결과 보고에 누락을 명시한다.

## 테스트 시나리오
- **정상 흐름**: "청소 점검 화면에 사진 첨부 필드 추가해줘" → firebase-firestore가 `cleaning_requests` 스키마 확인 → flutter-dev가 UI 구현 → analyze 통과
- **에러 흐름**: "시설 관리 화면을 nav에 연결해줘" 같은 범위 확장 요청 → 기존에 미연결 상태임을 사용자에게 먼저 확인
