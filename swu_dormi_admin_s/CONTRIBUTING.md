# 기여 가이드

SWU 샬롬하우스 관리자 앱 프로젝트에 기여해 주셔서 감사합니다!

## 개발 환경 설정

### 필수 요구사항
- Flutter SDK 3.9.2 이상
- Dart SDK 3.9.2 이상
- Windows 10/11 (이 프로젝트는 Windows 전용입니다)
- Visual Studio Code 또는 Android Studio
- Git

### 초기 설정
1. 저장소 클론
```bash
git clone <repository-url>
cd swu_dormi_admin_w
```

2. 패키지 설치
```bash
flutter pub get
```

3. Firebase 설정 (README.md 참조)

## 코딩 스타일

### Dart 코딩 컨벤션
- [Effective Dart](https://dart.dev/guides/language/effective-dart) 가이드를 따릅니다
- `flutter analyze` 명령어로 코드 품질을 확인합니다
- VSCode의 자동 포맷팅 기능을 사용합니다 (저장 시 자동 포맷)

### 네이밍 규칙
- **클래스**: PascalCase (예: `NoticeModel`, `AuthService`)
- **변수/함수**: camelCase (예: `userName`, `fetchNotices()`)
- **상수**: camelCase (예: `defaultPadding`, `primaryColor`)
- **private 변수/함수**: _camelCase (예: `_userId`, `_initialize()`)
- **파일명**: snake_case (예: `auth_service.dart`, `notice_model.dart`)

### 파일 구조
```
lib/
├── models/          # 데이터 모델
├── screens/         # 화면 위젯
│   └── windows/     # Windows 전용 화면
├── services/        # 비즈니스 로직
├── utils/           # 유틸리티 함수
└── widgets/         # 공통 위젯
```

## Git 워크플로우

### 브랜치 전략
- `master`: 프로덕션 코드
- `develop`: 개발 중인 코드
- `feature/*`: 새로운 기능 개발
- `bugfix/*`: 버그 수정
- `hotfix/*`: 긴급 버그 수정

### 커밋 메시지
커밋 메시지는 다음 형식을 따릅니다:

```
<타입>: <제목>

<본문>
```

#### 타입
- `feat`: 새로운 기능
- `fix`: 버그 수정
- `docs`: 문서 변경
- `style`: 코드 포맷팅, 세미콜론 누락 등
- `refactor`: 코드 리팩토링
- `test`: 테스트 추가
- `chore`: 빌드 작업, 패키지 매니저 설정 등

#### 예시
```
feat: 공지사항 첨부파일 다운로드 기능 추가

- PDF 첨부파일 다운로드 버튼 추가
- 파일명 자동 생성 기능 구현
- 다운로드 진행상태 표시
```

### Pull Request
1. 새 브랜치 생성
```bash
git checkout -b feature/new-feature
```

2. 변경사항 커밋
```bash
git add .
git commit -m "feat: 새로운 기능 추가"
```

3. 원격 저장소에 푸시
```bash
git push origin feature/new-feature
```

4. Pull Request 생성
   - 제목: 간결하고 명확하게
   - 본문: 변경사항, 이유, 테스트 방법 등 상세히 작성
   - 관련 이슈가 있다면 연결

## 코드 리뷰

### 리뷰어 체크리스트
- [ ] 코드가 프로젝트 스타일 가이드를 따르는가?
- [ ] 새로운 기능에 대한 테스트가 추가되었는가?
- [ ] 문서가 업데이트되었는가?
- [ ] 성능에 부정적인 영향이 없는가?
- [ ] 보안 취약점이 없는가?

### PR 작성자 체크리스트
- [ ] `flutter analyze` 통과
- [ ] 수동 테스트 완료
- [ ] 관련 문서 업데이트
- [ ] 커밋 메시지가 규칙을 따르는가?

## 테스트

### 단위 테스트
```bash
flutter test
```

### 위젯 테스트
각 화면에 대한 위젯 테스트를 작성합니다.

### 통합 테스트
주요 사용자 플로우에 대한 통합 테스트를 작성합니다.

## 새로운 기능 추가하기

### 1. 모델 생성
```dart
// lib/models/example_model.dart
class ExampleModel {
  final String id;
  final String name;

  ExampleModel({
    required this.id,
    required this.name,
  });

  factory ExampleModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ExampleModel(
      id: doc.id,
      name: data['name'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
    };
  }
}
```

### 2. 서비스 메서드 추가
```dart
// lib/services/firestore_service.dart
Future<List<ExampleModel>> getExamples() async {
  try {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('examples')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => ExampleModel.fromFirestore(doc))
        .toList();
  } catch (e) {
    throw Exception('Failed to fetch examples: $e');
  }
}
```

### 3. 화면 생성
```dart
// lib/screens/windows/windows_example_screen.dart
class WindowsExampleScreen extends StatefulWidget {
  const WindowsExampleScreen({super.key});

  @override
  State<WindowsExampleScreen> createState() => _WindowsExampleScreenState();
}

class _WindowsExampleScreenState extends State<WindowsExampleScreen> {
  // 구현...
}
```

## 보안 가이드라인

### Firebase 보안 규칙
- 모든 데이터 접근에 대한 권한 검증
- 관리자 권한 확인
- 입력 데이터 검증

### 민감한 정보 처리
- API 키나 비밀번호를 코드에 하드코딩하지 않기
- `.env` 파일 사용 (`.gitignore`에 추가)
- Firebase 설정 파일은 안전하게 관리

## 문의사항

질문이나 제안사항이 있으시면 이슈를 생성해 주세요.

감사합니다!
