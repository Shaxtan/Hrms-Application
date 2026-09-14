import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// LIGHT PALETTE
// ═══════════════════════════════════════════════════════════════════════════════
class AppColors {
  AppColors._();
  static const Color primary       = Color(0xFF1E293B);
  static const Color primaryLight  = Color(0xFF334155);
  static const Color accent        = Color(0xFF4F46E5);
  static const Color accentLight   = Color(0xFFEEF2FF);
  static const Color accentMid     = Color(0xFF818CF8);
  static const Color success       = Color(0xFF059669);
  static const Color successLight  = Color(0xFFD1FAE5);
  static const Color warning       = Color(0xFFD97706);
  static const Color warningLight  = Color(0xFFFEF3C7);
  static const Color danger        = Color(0xFFDC2626);
  static const Color dangerLight   = Color(0xFFFEE2E2);
  static const Color info          = Color(0xFF0284C7);
  static const Color infoLight     = Color(0xFFE0F2FE);
  static const Color pending       = Color(0xFFF59E0B);
  static const Color background    = Color(0xFFF8FAFC);
  static const Color surface       = Color(0xFFFFFFFF);
  static const Color surfaceVariant= Color(0xFFF1F5F9);
  static const Color border        = Color(0xFFE2E8F0);
  static const Color borderFocus   = Color(0xFF4F46E5);
  static const Color textPrimary   = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary  = Color(0xFF94A3B8);
  static const Color textOnDark    = Color(0xFFFFFFFF);
  static const Color textOnAccent  = Color(0xFFFFFFFF);
  static const Color pipelineApproved = Color(0xFF059669);
  static const Color pipelinePending  = Color(0xFFF59E0B);
  static const Color pipelineRejected = Color(0xFFDC2626);
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF334155)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// DARK PALETTE
// ═══════════════════════════════════════════════════════════════════════════════
class DarkColors {
  DarkColors._();
  static const Color background    = Color(0xFF0F172A);
  static const Color surface       = Color(0xFF1E293B);
  static const Color surfaceVariant= Color(0xFF263348);
  static const Color border        = Color(0xFF334155);
  static const Color textPrimary   = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textTertiary  = Color(0xFF64748B);
}

// ═══════════════════════════════════════════════════════════════════════════════
// THEME CONTROLLER — GetX reactive so ALL widgets rebuild on toggle
// ═══════════════════════════════════════════════════════════════════════════════
class ThemeController extends GetxController {
  static ThemeController get to => Get.find<ThemeController>();

  final _isDark = false.obs;
  bool get isDark => _isDark.value;

  void toggle() {
    _isDark.value = !_isDark.value;
    Get.changeThemeMode(_isDark.value ? ThemeMode.dark : ThemeMode.light);
    SystemChrome.setSystemUIOverlayStyle(
      _isDark.value ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );
    update(); // Notify GetBuilder listeners (e.g. ThemeToggleButton)
  }

  // ── Dynamic tokens — always call inside Obx or build() ───────────────────
  Color get bg         => _isDark.value ? DarkColors.background    : AppColors.background;
  Color get surface    => _isDark.value ? DarkColors.surface       : AppColors.surface;
  Color get surfaceVar => _isDark.value ? DarkColors.surfaceVariant: AppColors.surfaceVariant;
  Color get border     => _isDark.value ? DarkColors.border        : AppColors.border;
  Color get textPrimary=> _isDark.value ? DarkColors.textPrimary   : AppColors.textPrimary;
  Color get textSec    => _isDark.value ? DarkColors.textSecondary : AppColors.textSecondary;
  Color get textTert   => _isDark.value ? DarkColors.textTertiary  : AppColors.textTertiary;

  List<BoxShadow> get cardShadow => _isDark.value
      ? [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 2))]
      : AppShadows.card;
}

// ═══════════════════════════════════════════════════════════════════════════════
// THEMED SCAFFOLD — wraps every page so bg reacts to theme
// ═══════════════════════════════════════════════════════════════════════════════
class ThemedScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;

  const ThemedScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final t = ThemeController.to;
      return Scaffold(
        backgroundColor: t.bg,
        appBar: appBar,
        body: body,
        bottomNavigationBar: bottomNavigationBar,
        floatingActionButton: floatingActionButton,
      );
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TEXT STYLES
// ═══════════════════════════════════════════════════════════════════════════════
class AppTextStyles {
  AppTextStyles._();
  static TextStyle get displayLarge  => GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.2);
  static TextStyle get displayMedium => GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.3, height: 1.25);
  static TextStyle get headingLarge  => GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.2, height: 1.3);
  static TextStyle get headingMedium => GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.1, height: 1.35);
  static TextStyle get headingSmall  => GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, height: 1.4);
  static TextStyle get bodyLarge     => GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400, height: 1.5);
  static TextStyle get bodyMedium    => GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5);
  static TextStyle get bodySmall     => GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w400, height: 1.45);
  static TextStyle get caption       => GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, height: 1.4);
  static TextStyle get label         => GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.1, height: 1.4);
  static TextStyle get buttonLarge   => GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600);
  static TextStyle get buttonMedium  => GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600);
  static TextStyle get numericLarge  => GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.1);
  static TextStyle get numericMedium => GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3, height: 1.15);
}

class AppSpacing {
  AppSpacing._();
  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 12;
  static const double base = 16;
  static const double lg   = 20;
  static const double xl   = 24;
  static const double xxl  = 32;
  static const double xxxl = 48;
}

class AppRadius {
  AppRadius._();
  static const double sm   = 6;
  static const double md   = 10;
  static const double lg   = 14;
  static const double xl   = 18;
  static const double xxl  = 24;
  static const double full = 100;
}

class AppShadows {
  AppShadows._();
  static List<BoxShadow> get card => [
    BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 2)),
    BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1)),
  ];
  static List<BoxShadow> get elevated => [
    BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 4)),
    BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2)),
  ];
}

// ═══════════════════════════════════════════════════════════════════════════════
// THEME DATA BUILDERS
// ═══════════════════════════════════════════════════════════════════════════════
ThemeData buildLightTheme() => _build(Brightness.light);
ThemeData buildDarkTheme()  => _build(Brightness.dark);

ThemeData _build(Brightness brightness) {
  final dark    = brightness == Brightness.dark;
  final bg      = dark ? DarkColors.background    : AppColors.background;
  final surface = dark ? DarkColors.surface       : AppColors.surface;
  final border  = dark ? DarkColors.border        : AppColors.border;
  final text    = dark ? DarkColors.textPrimary   : AppColors.textPrimary;
  final textSec = dark ? DarkColors.textSecondary : AppColors.textSecondary;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: brightness,
      background: bg,
      surface: surface,
      primary: AppColors.accent,
      error: AppColors.danger,
    ),
    scaffoldBackgroundColor: bg,
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: text,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: border,
      systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      titleTextStyle: AppTextStyles.headingMedium.copyWith(color: text),
      iconTheme: IconThemeData(color: textSec, size: 22),
    ),
    cardTheme: CardThemeData(
      color: surface, elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: border),
      ),
    ),
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 0),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? DarkColors.surfaceVariant : AppColors.surfaceVariant,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.danger)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: AppTextStyles.bodyMedium.copyWith(color: dark ? DarkColors.textTertiary : AppColors.textTertiary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent, foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
        minimumSize: const Size(0, 48),
      ),
    ),
    textTheme: GoogleFonts.interTextTheme().apply(bodyColor: text, displayColor: text),
  );
}