import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:firebase_core/firebase_core.dart';
import 'package:window_manager/window_manager.dart';
import 'package:media_kit/media_kit.dart';
import 'package:swu_dormi_admin/firebase_options.dart';
import 'package:swu_dormi_admin/services/auth_service.dart';
import 'package:swu_dormi_admin/screens/windows/windows_navigation_shell.dart';
import 'package:swu_dormi_admin/screens/windows/windows_login_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // Windows 전용 설정
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1400, 900),
    minimumSize: Size(1200, 700),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // 한국어 locale 초기화
    await initializeDateFormatting('ko_KR', null);
  } catch (e) {
    // Firebase 초기화 실패 시 에러 처리
    debugPrint('Firebase 초기화 오류: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return fluent.FluentApp(
      title: 'SWU 샬롬하우스 관리자',
      debugShowCheckedModeBanner: false,
      theme: fluent.FluentThemeData(
        brightness: fluent.Brightness.light,
        accentColor: fluent.Colors.blue,
        visualDensity: fluent.VisualDensity.standard,
        scaffoldBackgroundColor: const Color(0xFFF3F3F3),
        cardColor: Colors.white,
        fontFamily: 'Segoe UI',
        typography: const fluent.Typography.raw(
          body: TextStyle(fontSize: 14, color: Colors.black87),
          bodyLarge: TextStyle(fontSize: 16, color: Colors.black87),
          bodyStrong: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
          title: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: Colors.black),
          titleLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w600, color: Colors.black),
          subtitle: TextStyle(fontSize: 20, fontWeight: FontWeight.w400, color: Colors.black87),
          caption: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ),
      darkTheme: fluent.FluentThemeData(
        brightness: fluent.Brightness.dark,
        accentColor: fluent.Colors.blue,
        visualDensity: fluent.VisualDensity.standard,
        scaffoldBackgroundColor: const Color(0xFF202020),
      ),
      home: const WindowsAuthWrapper(),
    );
  }
}

// Windows용 인증 래퍼
class WindowsAuthWrapper extends StatelessWidget {
  const WindowsAuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const fluent.ScaffoldPage(
            content: Center(
              child: fluent.ProgressRing(),
            ),
          );
        }

        if (snapshot.hasData) {
          return const WindowsNavigationShell();
        }

        return const WindowsLoginScreen();
      },
    );
  }
}