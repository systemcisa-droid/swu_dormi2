import 'package:flutter/material.dart';

/// SWU 기숙사 앱 상수 정의
/// 디자인 가이드에 따른 색상, 스타일, 간격 등을 정의합니다.
class AppConstants {
  // ============================================
  // 1. 핵심 컬러 팔레트 (SWU Identity Color Palette)
  // ============================================

  /// Primary Color - SWU 퍼플/딥 버건디
  /// 용도: 버튼, 활성화된 아이콘, 주요 헤더, 브랜드 강조
  static const Color primaryColor = Color(0xFF9E1A20);

  /// Secondary Color - SWU 블루/딥 네이비
  /// 용도: 배경 악센트, 서브 헤더, 보조 버튼 테두리
  static const Color secondaryColor = Color(0xFF101077);

  /// Accent Color - SWU 옐로우/골드
  /// 용도: 새로운 알림 배지, 하이라이트 아이콘, 주요 알림
  static const Color accentColor = Color(0xFFFFB300);

  /// Background Color - 부드러운 화이트 톤
  /// 용도: 일반적인 화면 배경, 카드 외부
  static const Color backgroundColor = Color(0xFFF8F8F8);

  /// Surface Color - 깨끗한 백색
  /// 용도: 카드 컴포넌트, 모달창 등 콘텐츠 영역
  static const Color surfaceColor = Color(0xFFFFFFFF);

  /// Text Colors
  static const Color textPrimaryColor = Color(0xFF000000);
  static const Color textSecondaryColor = Color(0xFF606060);
  static const Color textDisabledColor = Color(0xFFA0A0A0);

  /// Status Colors
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFE53935);
  static const Color warningColor = Color(0xFFFFA726);
  static const Color infoColor = Color(0xFF29B6F6);

  // ============================================
  // 2. 여백 및 간격 (Spacing)
  // ============================================

  static const double spacingExtraSmall = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingExtraLarge = 32.0;

  // Padding
  static const double paddingExtraSmall = 4.0;
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingExtraLarge = 32.0;

  // ============================================
  // 3. Border Radius
  // ============================================

  static const double borderRadiusSmall = 4.0;
  static const double borderRadiusMedium = 8.0;
  static const double borderRadiusLarge = 12.0;
  static const double borderRadiusExtraLarge = 16.0;
  static const double borderRadiusButton = 10.0;

  // ============================================
  // 4. 타이포그래피 (Typography)
  // ============================================

  // Font Sizes
  static const double fontSizeExtraSmall = 10.0;
  static const double fontSizeSmall = 12.0;
  static const double fontSizeMedium = 14.0;
  static const double fontSizeLarge = 16.0;
  static const double fontSizeExtraLarge = 18.0;
  static const double fontSizeHeadingSmall = 20.0;
  static const double fontSizeHeadingMedium = 24.0;
  static const double fontSizeHeadingLarge = 28.0;

  // Text Styles
  static const TextStyle headingLargeStyle = TextStyle(
    fontSize: fontSizeHeadingLarge,
    fontWeight: FontWeight.bold,
    color: textPrimaryColor,
  );

  static const TextStyle headingMediumStyle = TextStyle(
    fontSize: fontSizeHeadingMedium,
    fontWeight: FontWeight.bold,
    color: primaryColor,
  );

  static const TextStyle headingSmallStyle = TextStyle(
    fontSize: fontSizeHeadingSmall,
    fontWeight: FontWeight.w600,
    color: textPrimaryColor,
  );

  static const TextStyle subheadingStyle = TextStyle(
    fontSize: fontSizeExtraLarge,
    fontWeight: FontWeight.w600,
    color: secondaryColor,
  );

  static const TextStyle bodyLargeStyle = TextStyle(
    fontSize: fontSizeLarge,
    fontWeight: FontWeight.normal,
    color: textPrimaryColor,
  );

  static const TextStyle bodyMediumStyle = TextStyle(
    fontSize: fontSizeMedium,
    fontWeight: FontWeight.normal,
    color: textSecondaryColor,
  );

  static const TextStyle bodySmallStyle = TextStyle(
    fontSize: fontSizeSmall,
    fontWeight: FontWeight.normal,
    color: textSecondaryColor,
  );

  static const TextStyle captionStyle = TextStyle(
    fontSize: fontSizeExtraSmall,
    fontWeight: FontWeight.normal,
    color: textDisabledColor,
  );

  static const TextStyle buttonTextStyle = TextStyle(
    fontSize: fontSizeLarge,
    fontWeight: FontWeight.bold,
    color: surfaceColor,
  );

  // ============================================
  // 5. Elevation (그림자)
  // ============================================

  static const double elevationNone = 0.0;
  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;

  // ============================================
  // 6. Icon Sizes
  // ============================================

  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;
  static const double iconSizeExtraLarge = 48.0;

  // ============================================
  // 7. Button Heights
  // ============================================

  static const double buttonHeightSmall = 32.0;
  static const double buttonHeightMedium = 44.0;
  static const double buttonHeightLarge = 56.0;

  // ============================================
  // 8. App Specific Constants
  // ============================================

  static const String appName = 'SWU 기숙사';
  static const String appVersion = '1.0.0';

  // ============================================
  // 9. Common Widgets Styles
  // ============================================

  /// Primary Button Style
  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: surfaceColor,
    minimumSize: const Size(double.infinity, buttonHeightMedium),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadiusButton),
    ),
    elevation: elevationLow,
  );

  /// Secondary Button Style
  static ButtonStyle secondaryButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: secondaryColor,
    minimumSize: const Size(double.infinity, buttonHeightMedium),
    side: const BorderSide(color: secondaryColor, width: 1.5),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadiusButton),
    ),
  );

  /// Card Decoration
  static BoxDecoration cardDecoration = BoxDecoration(
    color: surfaceColor,
    borderRadius: BorderRadius.circular(borderRadiusLarge),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  /// Input Decoration Theme
  static InputDecorationTheme inputDecorationTheme = InputDecorationTheme(
    filled: true,
    fillColor: surfaceColor,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: paddingMedium,
      vertical: paddingSmall,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadiusMedium),
      borderSide: BorderSide(color: textDisabledColor.withValues(alpha: 0.3)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadiusMedium),
      borderSide: BorderSide(color: textDisabledColor.withValues(alpha: 0.3)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadiusMedium),
      borderSide: const BorderSide(color: primaryColor, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadiusMedium),
      borderSide: const BorderSide(color: errorColor, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadiusMedium),
      borderSide: const BorderSide(color: errorColor, width: 2),
    ),
  );

  /// Badge Decoration (for "NEW", "D-day" etc)
  static BoxDecoration badgeDecoration = BoxDecoration(
    color: accentColor,
    borderRadius: BorderRadius.circular(borderRadiusSmall),
  );

  /// Badge Text Style
  static const TextStyle badgeTextStyle = TextStyle(
    fontSize: fontSizeSmall,
    fontWeight: FontWeight.bold,
    color: surfaceColor,
  );
}
