---
name: flutter-feature-dev
description: "swu_dormi_admin_w(Windows 데스크탑 관리자 콘솔)의 기능 개발을 오케스트레이션하는 스킬. 화면 추가/수정, Firestore 연동, UI 검토, 버그 수정 등 '이 프로젝트에서 개발해줘' 류 요청 시 사용. '기능 다시 만들어줘', '이전 작업 이어서', 'UI만 검토해줘', '이 부분만 수정' 같은 후속 요청에도 사용."
---

# swu_dormi_admin_w 기능 개발 오케스트레이터

Windows 데스크탑 관리자 콘솔의 기능 개발을 `flutter-dev`, `firebase-firestore`, `ui-reviewer` 세 에이전트로 조율한다.

## Phase 0: 컨텍스트 확인
- `_workspace/`가 있으면 이전 작업 산출물을 읽고, 부분 수정 요청이면 해당 에이전트만 재호출한다.
- 없으면 신규 요청으로 처리한다.

## 실행 모드
**서브 에이전트 패턴 (생성-검증 조합).** flutter-dev/firebase-firestore가 기능을 생성하고, UI 변경이 포함되면 ui-reviewer가 검증하는 흐름. 세 에이전트가 동시에 조율할 필요는 없어 팀 모드 오버헤드가 불필요하다.

## 워크플로우

1. **분석**: 요청이 (a) Firestore 스키마/쿼리 변경, (b) UI/화면 변경, (c) 둘 다인지 판단한다.
2. **Firestore 우선 처리**: (a)가 해당되면 `firebase-firestore`를 먼저 호출한다.
3. **UI/로직 구현**: `flutter-dev`를 호출해 화면/위젯을 구현한다. fluent_ui/Material 충돌 회피 패턴을 반드시 따르도록 프롬프트에 명시한다.
4. **UI 검토**: 화면 변경이 있었다면 `ui-reviewer`를 호출해 체크리스트 기준으로 검토한다.
5. **검증**: `flutter analyze` + `flutter build windows --debug` 실행. 실행 중인 exe가 파일을 잠그면 사용자에게 종료를 요청한다(직접 프로세스 종료 금지).

## 에러 핸들링
에이전트 실행 실패 시 1회 재시도 후에도 실패하면 해당 부분 없이 진행하고 결과 보고에 누락을 명시한다.

## 테스트 시나리오
- **정상 흐름**: "학생관리 화면에 학년별 필터 추가해줘" → firebase-firestore가 쿼리 검토 → flutter-dev가 UI 구현 → ui-reviewer가 검토 → analyze+build 통과
- **에러 흐름**: 빌드 시 exe 파일 잠금 발생 → 사용자에게 실행 중인 앱 종료 요청 후 재시도
