import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import 'login_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return Obx(() {
      final t = ThemeController.to;
      return Scaffold(
        backgroundColor: t.bg,
        // Profile is pushed on top of the shell (Get.to) — replace the
        // hamburger with a back button so the user can return to whatever
        // they were on (Dashboard, Employees, …). The sidebar isn't
        // reachable while this page owns the top of the stack; popping
        // brings them back to it.
        appBar: SharedAppBar(
          title: 'My Profile',
          showMenuButton: false,
          leading: Padding(
            padding: const EdgeInsets.all(10),
            child: GestureDetector(
              onTap: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  Get.offAllNamed('/home');
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: t.surfaceVar,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: t.border),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: t.textSec,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _IdCard(auth: auth, t: t),
            const SizedBox(height: 20),
            _StatsRow(t: t),
            const SizedBox(height: 20),
            _tile(t, Icons.notifications_outlined, 'Notifications',
                'Manage push & email alerts', () {}),
            _tile(t, Icons.lock_outline_rounded, 'Change Password',
                'Update your account password', () {}),
            _tile(t, Icons.language_rounded, 'Language', 'English (India)',
                () {}),
            _tile(
              t,
              t.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              t.isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
              t.isDark
                  ? 'Currently using dark theme'
                  : 'Currently using light theme',
              () => ThemeController.to.toggle(),
            ),
            _tile(t, Icons.help_outline_rounded, 'Help & Support',
                'FAQs, contact us', () {}),
            _tile(t, Icons.info_outline_rounded, 'About HRMS', 'Version 1.0.0',
                () {}),
            const SizedBox(height: 8),
            Divider(color: t.border),
            const SizedBox(height: 8),
            // Sign out
            GestureDetector(
              onTap: auth.logout,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.danger.withOpacity(0.25)),
                ),
                child: Row(children: [
                  const Icon(Icons.logout_rounded,
                      color: AppColors.danger, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Sign out',
                            style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w600)),
                        Text('You will be returned to the login screen',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.danger.withOpacity(0.7))),
                      ])),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: AppColors.danger),
                ]),
              ),
            ),
            const SizedBox(height: 32),
          ]),
        ),
      );
    });
  }

  Widget _tile(ThemeController t, IconData icon, String title, String subtitle,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: t.border),
            boxShadow: t.cardShadow),
        child: Row(children: [
          Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: AppColors.accent, size: 18)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: t.textPrimary, fontWeight: FontWeight.w500)),
                Text(subtitle,
                    style: AppTextStyles.caption.copyWith(color: t.textSec)),
              ])),
          Icon(Icons.chevron_right_rounded, color: t.textTert, size: 18),
        ]),
      ),
    );
  }
}

// ── ID Card ────────────────────────────────────────────────────────────────────
class _IdCard extends StatelessWidget {
  final AuthController auth;
  final ThemeController t;
  const _IdCard({required this.auth, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF1E293B), Color(0xFF312E81)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF1E293B).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Stack(children: [
        Positioned(
            top: -30,
            right: -30,
            child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05)))),
        Positioned(
            bottom: -20,
            left: -20,
            child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF4F46E5).withOpacity(0.2)))),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.3), width: 2)),
                  child: Center(
                      child: Text(auth.userInitials.value,
                          style: AppTextStyles.headingLarge
                              .copyWith(color: Colors.white, fontSize: 22)))),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6)),
                        child: const Text('HRMS',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5))),
                    const SizedBox(height: 6),
                    Text(auth.userName.value,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3)),
                    const SizedBox(height: 4),
                    Text(auth.roleDisplay,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 13)),
                  ])),
              Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.business_rounded,
                      color: Colors.white, size: 18)),
            ]),
            const SizedBox(height: 20),
            Divider(color: Colors.white.withOpacity(0.15), height: 1),
            const SizedBox(height: 16),
            Row(children: [
              _idField('Company', auth.companyName.value),
              _vDivider(),
              _idField('Role', auth.roleDisplay),
              _vDivider(),
              _idField('Status', 'Active'),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.15))),
              child: Row(children: [
                const Icon(Icons.badge_rounded,
                    color: Colors.white54, size: 16),
                const SizedBox(width: 8),
                const Text('SUPERVISOR-DS-2026',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: 'monospace',
                        letterSpacing: 1.2)),
                const Spacer(),
                const Icon(Icons.verified_rounded,
                    color: Color(0xFF6EE7B7), size: 16),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _idField(String label, String value) => Expanded(
          child: Column(children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ]));

  Widget _vDivider() => Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white.withOpacity(0.15));
}

// ── Stats Row ──────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final ThemeController t;
  const _StatsRow({required this.t});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _stat(t, '47', 'Total Onboarded', AppColors.accent),
      const SizedBox(width: 10),
      _stat(t, '38', 'Approved', AppColors.success),
      const SizedBox(width: 10),
      _stat(t, '80.9%', 'Approval Rate', AppColors.info),
    ]);
  }

  Widget _stat(ThemeController t, String value, String label, Color color) =>
      Expanded(
          child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: t.border),
            boxShadow: t.cardShadow),
        child: Column(children: [
          Text(value,
              style: AppTextStyles.numericMedium
                  .copyWith(color: color, fontSize: 18)),
          const SizedBox(height: 4),
          Text(label,
              style: AppTextStyles.caption
                  .copyWith(color: t.textSec, fontSize: 10),
              textAlign: TextAlign.center),
        ]),
      ));
}
