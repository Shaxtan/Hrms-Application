import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'core/theme/app_theme.dart';
import 'core/network/api_client.dart';
import 'core/security/session_manager.dart';
import 'features/onboarding/presentation/pages/change_password_page.dart';
import 'features/onboarding/presentation/pages/dashboard_page.dart';
import 'features/onboarding/presentation/pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  ApiClient.init();

  // Register as permanent GetX controllers
  Get.put(ThemeController(), permanent: true);

  // Registered BEFORE AuthController, because restoring a session calls into
  // it. Its two handlers are injected here so core/ never has to import a
  // feature page.
  final session = Get.put(SessionManager(), permanent: true);
  session.tokenReader =
      () => const FlutterSecureStorage().read(key: 'auth_token');
  session.logoutHandler = () async {
    if (Get.isRegistered<AuthController>()) {
      await Get.find<AuthController>().logout();
    }
  };

  Get.put(AuthController(), permanent: true);

  runApp(const HrmsApp());
}

class HrmsApp extends StatelessWidget {
  const HrmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Obx here ensures GetMaterialApp rebuilds when theme toggles
    return Obx(() {
      final t = ThemeController.to;
      // Every touch anywhere in the app counts as activity. Listener is used
      // rather than GestureDetector so this only OBSERVES — it never competes
      // for a gesture, so no button, scroll or text field behaves differently.
      // onPointerDown alone is enough and keeps a scroll from writing a
      // timestamp on every frame.
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => SessionManager.to.recordActivity(),
        child: GetMaterialApp(
          title: 'HRMS',
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: t.isDark ? ThemeMode.dark : ThemeMode.light,
          initialRoute: '/login',
          getPages: [
            GetPage(name: '/login', page: () => const LoginPage()),
            GetPage(name: '/home', page: () => const MainShell()),
            // Reached when the login response says mustChangePwd. The page
            // itself blocks back navigation while the flag is set.
            GetPage(
                name: '/change-password',
                page: () => const ChangePasswordPage()),
          ],
          defaultTransition: Transition.cupertino,
          transitionDuration: const Duration(milliseconds: 280),
        ),
      );
    });
  }
}
