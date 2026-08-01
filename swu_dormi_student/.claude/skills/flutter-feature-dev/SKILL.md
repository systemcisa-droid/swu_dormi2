---
name: flutter-feature-dev
description: "swu_dormi_student(안드로이드 학생 앱)의 기능 개발을 오케스트레이션하는 스킬. 화면 추가/수정, Firestore 연동, UI/디자인 톤 검토, 버그 수정 등 '이 프로젝트에서 개발해줘' 류 요청 시 사용. '기능 다시 만들어줘', '이전 작업 이어서', 'UI만 검토해줘', '디자인이 이상해', '이 부분만 수정' 같은 후속 요청에도 사용."
---

# swu_dormi_student 기능 개발 오케스트레이터

안드로이드 학생 앱의 기능 개발을 `flutter-dev`, `firebase-firestore`, `ui-reviewer` 세 에이전트로 조율한다. 학생 앱은 4개 자매 프로젝트 중 최종 사용자가 직접 쓰는 "얼굴"이므로, 화면 UI가 조금이라도 관련된 작업에는 반드시 `ui-reviewer` 검증 단계를 거친다.

## Phase 0: 컨텍스트 확인
- `_workspace/`가 있으면 이전 작업 산출물을 먼저 읽고, 부분 수정 요청이면 해당 에이전트만 재호출한다.
- 없으면 신규 요청으로 처리한다.

## 실행 모드
**서브 에이전트 패턴 (생성-검증 조합).** flutter-dev/firebase-firestore가 기능을 생성하고, UI 변경이 포함되면 ui-reviewer가 디자인 톤과 일관성을 검증하는 흐름. 팀 통신 오버헤드보다 순차 호출이 이 규모 작업에 적합하다.

## 워크플로우

1. **분석**: 요청이 (a) Firestore 스키마/쿼리/보안규칙 변경, (b) UI/화면/디자인 변경, (c) 둘 다인지 판단한다.
2. **Firestore 우선 처리**: (a)가 해당되면 `firebase-firestore` 에이전트를 먼저 호출한다(필요 시 `firestore.rules` 동반 갱신).
3. **UI/로직 구현**: `flutter-dev` 에이전트를 호출해 화면/위젯을 구현한다. **ListView/TabBarView 금지 제약**과 **20대 여대생 타겟의 모던하되 과하게 귀엽지 않은 톤**을 프롬프트에 반드시 명시한다.
4. **UI 검토**: (b)에 해당하면 `ui-reviewer`를 호출해 디자인 톤/일관성/체크리스트 기준으로 검토한다. "너무 귀엽다"거나 톤이 어긋난다는 지적이 나오면 `flutter-dev`에 1회 재수정을 요청한다.
5. **검증**: `flutter analyze` 결과 확인, 이상 시 1회 재수정 요청.

## 에러 핸들링
에이전트 실행 실패 시 1회 재시도 후에도 실패하면 해당 부분 없이 진행하고 결과 보고에 누락을 명시한다.

## 테스트 시나리오
- **정상 흐름**: "게시판에 인기글 정렬 탭 추가해줘" → flutter-dev가 `_viewMode` 세그먼트 패턴으로 구현(TabBarView 금지 준수) → firebase-firestore가 정렬 쿼리 확인 → ui-reviewer가 톤/일관성 검토 → analyze 통과
- **에러 흐름**: "공지사항을 세로 ListView로 보여줘" 같이 금지 패턴과 상충하는 요청 → flutter-dev가 SingleChildScrollView+Column 대안을 제시하고 사용자 확인 후 진행
- **디자인 반려 흐름**: 새 화면에 파스텔톤 카드+동글動 아이콘을 과하게 적용 → ui-reviewer가 "귀여움" 쪽으로 치우쳤다고 지적, 절제된 톤으로 재수정 요청
