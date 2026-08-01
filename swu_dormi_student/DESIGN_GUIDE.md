# 서울여자대학교 기숙사 모바일 앱 디자인 가이드

## 1. 디자인 목표 및 컨셉 ✨

**핵심 컨셉**: 모던하고 우아한 기숙사 관리 플랫폼 (Modern & Elegant Dormitory Platform)

**디자인 톤앤매너**: 고급스러움, 신뢰감, 전문성, 정돈된 느낌을 강조하여 프리미엄 기숙사 앱의 품격을 표현합니다.

**레이아웃 특징**: **여백(Whitespace)**을 충분히 활용하여 콘텐츠의 가독성을 극대화하며, 모든 UI 요소는 미니멀하고 깨끗하게 처리합니다.

## 2. 핵심 컬러 팔레트 (SWU Identity Color Palette) 🎨

서울여자대학교의 공식 UI(University Identity) 색상을 기반으로 정의하며, Flutter/Dart 환경에서 `Color(0xFF...)` 형식으로 사용합니다.

| 분류 | 용도 (예시) | HEX 코드 | Flutter Color | 색상 설명 |
|------|------------|----------|---------------|-----------|
| **Primary (메인)** | 버튼, 활성화된 아이콘, 주요 헤더, 브랜드 강조 | `#9E1A20` | `Color(0xFF9E1A20)` | SWU 퍼플/딥 버건디 (품격, 주된 행동 유도) |
| **Secondary (보조)** | 배경 악센트, 서브 헤더, 보조 버튼 테두리 | `#101077` | `Color(0xFF101077)` | SWU 블루/딥 네이비 (안정감, 신뢰감) |
| **Accent (강조)** | 새로운 알림 배지, 하이라이트 아이콘, 주요 알림 | `#FFB300` | `Color(0xFFFFB300)` | SWU 옐로우/골드 (밝고 진취적인 악센트) |
| **Background** | 일반적인 화면 배경, 카드 외부 | `#F8F8F8` | `Color(0xFFF8F8F8)` | 부드러운 화이트 톤 (모던함) |
| **Surface** | 카드 컴포넌트, 모달창 등 콘텐츠 영역 | `#FFFFFF` | `Color(0xFFFFFFFF)` | 깨끗한 백색 (정보의 명료성) |

## 3. 주요 UI 컴포넌트 및 스타일 (Flutter 구현) 💻

### A. 내비게이션 및 헤더

#### AppBar (상단 바)
- 배경색은 `#FFFFFF` (Surface)
- 아이콘 및 텍스트 색상은 `#101077` (Secondary) 또는 검은색을 사용
- 좌측에는 **SWU 심볼 마크 (Primary Color 적용)**를 배치하여 정체성을 강조

#### BottomNavigationBar
- 아이콘은 5개 내외 (예: 홈, 소식/공지, 이벤트/행사, 커뮤니티, 마이페이지)
- 활성화된(Active) 아이콘은 `#9E1A20` (Primary Color)
- 비활성화된(Inactive) 아이콘은 `#A0A0A0` (Soft Gray) 처리

### B. 버튼 및 인터랙션

#### Primary Button (주 행동 버튼)
- 배경색: `#9E1A20` (Primary)
- 텍스트 색상: `#FFFFFF` (White)
- 모서리 둥글기: `BorderRadius.circular(10.0)` 정도를 적용하여 모던한 느낌을 줌

```dart
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: Color(0xFF9E1A20),
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10.0),
    ),
  ),
  onPressed: () {},
  child: Text('버튼 텍스트'),
)
```

#### Secondary Button (보조 버튼)
- 배경색: `#FFFFFF`
- 테두리(Border): `#101077` (Secondary) 색상으로 1px~2px 두께로 처리
- 텍스트 색상: Secondary Color

```dart
OutlinedButton(
  style: OutlinedButton.styleFrom(
    foregroundColor: Color(0xFF101077),
    side: BorderSide(color: Color(0xFF101077), width: 1.5),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10.0),
    ),
  ),
  onPressed: () {},
  child: Text('보조 버튼'),
)
```

#### Floating Action Button (FAB)
- 배경색: `#FFB300` (Accent)를 사용하여 화면에서 눈에 띄게 배치

```dart
FloatingActionButton(
  backgroundColor: Color(0xFFFFB300),
  onPressed: () {},
  child: Icon(Icons.add),
)
```

### C. 콘텐츠 리스트 (Cards & List Tiles)

#### Card (리스트 항목 컨테이너)
- 배경색: `#FFFFFF` (Surface)
- 그림자: Soft Shadow (`Elevation 2.0~4.0`)를 적용하여 콘텐츠에 입체감과 집중도를 부여

```dart
Card(
  color: Color(0xFFFFFFFF),
  elevation: 3.0,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12.0),
  ),
  child: Padding(
    padding: EdgeInsets.all(16.0),
    child: // 콘텐츠
  ),
)
```

#### List Title (제목/본문)
- **제목**: `TextStyle(fontWeight: FontWeight.bold)` 및 진한 색상 (Black 또는 Secondary)
- **내용**: 일반 폰트와 부드러운 회색 (`#606060`)으로 처리하여 정보 계층을 명확하게 구분

```dart
ListTile(
  title: Text(
    '제목',
    style: TextStyle(
      fontWeight: FontWeight.bold,
      color: Colors.black,
    ),
  ),
  subtitle: Text(
    '내용',
    style: TextStyle(
      color: Color(0xFF606060),
    ),
  ),
)
```

#### Tag / Badge
- "D-day" 또는 "New"와 같은 정보 태그는 `#FFB300` (Accent) 색상의 작은 뱃지 형태로 처리하여 가독성을 높임

```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(
    color: Color(0xFFFFB300),
    borderRadius: BorderRadius.circular(4),
  ),
  child: Text(
    'NEW',
    style: TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.bold,
    ),
  ),
)
```

## 4. 폰트 및 타이포그래피

### 폰트 (Font Family)
산세리프(San-serif) 계열의 깔끔하고 모던하며 가독성이 높은 폰트를 사용합니다.
- 권장: 시스템 기본 폰트 또는 **Noto Sans KR**, **Pretendard** 등

### 텍스트 크기
- **Body**: 14pt~16pt (모바일 환경에 최적화)
- **제목 (Headline)**과 **본문 (Body)** 간의 크기 및 굵기 차이를 명확하게 두어 정보 구조를 직관적으로 파악할 수 있도록 함

### 정렬
- 대부분의 텍스트는 **좌측 정렬(Left Aligned)**을 기본으로 함

### 예시 코드

```dart
// 큰 제목
Text(
  '큰 제목',
  style: TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Color(0xFF9E1A20),
  ),
)

// 부제목
Text(
  '부제목',
  style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Color(0xFF101077),
  ),
)

// 본문
Text(
  '본문 텍스트',
  style: TextStyle(
    fontSize: 14,
    color: Color(0xFF606060),
  ),
)
```

## 5. 여백 및 간격 (Spacing)

### 기본 여백 가이드
- **Extra Small**: 4px
- **Small**: 8px
- **Medium**: 16px
- **Large**: 24px
- **Extra Large**: 32px

### 적용 예시
```dart
// 섹션 간 여백
SizedBox(height: 24)

// 카드 내부 패딩
Padding(padding: EdgeInsets.all(16))

// 리스트 아이템 간 간격
SizedBox(height: 8)
```

## 6. 아이콘 스타일

- **Material Icons** 사용 권장
- 활성화 상태: Primary Color (`#9E1A20`)
- 비활성화 상태: Gray (`#A0A0A0`)
- 강조 아이콘: Accent Color (`#FFB300`)

## 7. 사용 예시

### constants.dart 파일 참조
모든 색상, 스타일, 간격은 `lib/utils/constants.dart` 파일에 정의되어 있습니다.

```dart
import 'package:swu_dormi/utils/constants.dart';

// Primary Button 사용
ElevatedButton(
  style: AppConstants.primaryButtonStyle,
  onPressed: () {},
  child: Text('로그인'),
)

// Card 스타일 적용
Container(
  decoration: AppConstants.cardDecoration,
  child: Padding(
    padding: EdgeInsets.all(AppConstants.paddingMedium),
    child: Text(
      '카드 내용',
      style: AppConstants.bodyMediumStyle,
    ),
  ),
)

// Badge 적용
Container(
  padding: EdgeInsets.symmetric(
    horizontal: AppConstants.paddingSmall,
    vertical: AppConstants.paddingExtraSmall,
  ),
  decoration: AppConstants.badgeDecoration,
  child: Text(
    'NEW',
    style: AppConstants.badgeTextStyle,
  ),
)
```

---

**문서 버전**: 1.0
**최종 수정일**: 2025년
**적용 프로젝트**: SWU Dormi (서울여자대학교 기숙사 앱)
