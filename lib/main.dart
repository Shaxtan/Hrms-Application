import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'core/theme/app_theme.dart';
import 'core/network/api_client.dart';
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
      return GetMaterialApp(
        title: 'HRMS',
        debugShowCheckedModeBanner: false,
        theme:     buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: t.isDark ? ThemeMode.dark : ThemeMode.light,
        initialRoute: '/login',
        getPages: [
          GetPage(name: '/login', page: () => const LoginPage()),
          GetPage(name: '/home',  page: () => const MainShell()),
        ],
        defaultTransition: Transition.cupertino,
        transitionDuration: const Duration(milliseconds: 280),
      );
    });
  }
}