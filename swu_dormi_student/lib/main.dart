import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/locale_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/privacy_consent_screen.dart';
import 'screens/auth/google_student_id_screen.dart';
import 'screens/home/home_screen.dart';
import 'utils/constants.dart';

// 백그라운드 메시지 핸들러 — Flutter 플러그인 사용 불가, Firebase만 초기화
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // 시스템이 자동으로 알림을 표시하므로 별도 처리 불필요
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // App Check 초기화
  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
  );

  // 한국어 날짜 포맷 초기화
  await initializeDateFormatting('ko');

  // 백그라운드 메시지 핸들러 등록
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()..load()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          final clamped = MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.of(context).textScaler.clamp(
              minScaleFactor: 0.8,
              maxScaleFactor: 1.2,
            ),
          );
          return MediaQuery(
            data: clamped,
            child: SafeArea(
              top: false,
              child: child!,
            ),
          );
        },
        theme: ThemeData(
          // 색상 스킴 - SWU Identity Colors
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppConstants.primaryColor,
            primary: AppConstants.primaryColor,
            secondary: AppConstants.secondaryColor,
            surface: AppConstants.surfaceColor,
            error: AppConstants.errorColor,
            brightness: Brightness.light,
          ),
          useMaterial3: true,

          // 기본 색상
          primaryColor: AppConstants.primaryColor,
          scaffoldBackgroundColor: AppConstants.backgroundColor,

          // AppBar 테마
          appBarTheme: AppBarTheme(
            centerTitle: true,
            elevation: AppConstants.elevationNone,
            backgroundColor: AppConstants.surfaceColor,
            foregroundColor: AppConstants.secondaryColor,
            titleTextStyle: AppConstants.headingSmallStyle,
            iconTheme: const IconThemeData(
              color: AppConstants.secondaryColor,
            ),
          ),

          // Card 테마
          cardTheme: CardThemeData(
            color: AppConstants.surfaceColor,
            elevation: AppConstants.elevationMedium,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadiusLarge),
            ),
          ),

          // Input 테마
          inputDecorationTheme: AppConstants.inputDecorationTheme,

          // Button 테마
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: AppConstants.primaryButtonStyle,
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: AppConstants.secondaryButtonStyle,
          ),

          // FloatingActionButton 테마
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: AppConstants.accentColor,
            foregroundColor: AppConstants.surfaceColor,
          ),

          // BottomNavigationBar 테마
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: AppConstants.surfaceColor,
            selectedItemColor: AppConstants.primaryColor,
            unselectedItemColor: AppConstants.textDisabledColor,
            type: BottomNavigationBarType.fixed,
            elevation: 8,
          ),

          // Text 테마
          textTheme: const TextTheme(
            headlineLarge: AppConstants.headingLargeStyle,
            headlineMedium: AppConstants.headingMediumStyle,
            headlineSmall: AppConstants.headingSmallStyle,
            titleLarge: AppConstants.subheadingStyle,
            bodyLarge: AppConstants.bodyLargeStyle,
            bodyMedium: AppConstants.bodyMediumStyle,
            bodySmall: AppConstants.bodySmallStyle,
            labelLarge: AppConstants.buttonTextStyle,
          ),

          // Icon 테마
          iconTheme: const IconThemeData(
            color: AppConstants.primaryColor,
            size: AppConstants.iconSizeMedium,
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _privacyAgreed = false;
  bool _checkingPrivacy = true;

  @override
  void initState() {
    super.initState();
    _checkPrivacyAgreement();
  }

  Future<void> _checkPrivacyAgreement() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _privacyAgreed = prefs.getBool('privacy_policy_agreed') ?? false;
      _checkingPrivacy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingPrivacy) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_privacyAgreed) {
      return PrivacyConsentScreen(
        onAgreed: () {
          setState(() {
            _privacyAgreed = true;
          });
        },
      );
    }

    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authProvider.isAuthenticated) {
          return const HomeScreen();
        } else if (authProvider.pendingGoogleUid != null) {
          return const GoogleStudentIdScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
