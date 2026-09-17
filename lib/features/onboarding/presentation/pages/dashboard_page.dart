import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../controllers/dashboard_controller.dart';
import 'add_employee_page.dart';
import 'approvals_page.dart';
import 'login_page.dart';
import 'employee_list_page.dart';
import 'employee_controller.dart';
import 'employee_edit_page.dart';
import 'profile_page.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ATTENDANCE CONTROLLER — real API: punch-in/out + today status
// ═══════════════════════════════════════════════════════════════════════════════
class AttendanceController extends GetxController {
  final isCheckedIn = false.obs;
  final checkInTime = Rxn<DateTime>();
  final checkOutTime = Rxn<DateTime>();
  final currentTime = DateTime.now().obs;
  final elapsedSecs = 0.obs;
  final isPunching = false.obs;
  Timer? _clockTimer;
  Timer? _elapsedTimer;

  final Dio _dio = ApiClient.instance;

  @override
  void onInit() {
    super.onInit();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      currentTime.value = DateTime.now();
    });
    _fetchTodayStatus();
  }

  @override
  void onClose() {
    _clockTimer?.cancel();
    _elapsedTimer?.cancel();
    super.onClose();
  }

  Future<void> _fetchTodayStatus() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final res = await _dio.post('/api/v1/attendance/list', data: {
        'page': 0,
        'size': 1,
        'sortBy': 'attendanceDate',
        'sortDir': 'DESC',
        'filters': {'dateFrom': today, 'dateTo': today},
      });
      final record = (res.data?['data'] as List?)?.isNotEmpty == true
          ? res.data['data'][0] as Map<String, dynamic>
          : null;
      if (record == null) return;

      final punchIn = record['punchInTime'] ?? record['punchInTimeIST'];
      final punchOut = record['punchOutTime'] ?? record['punchOutTimeIST'];
      if (punchIn != null)
        checkInTime.value = DateTime.tryParse(punchIn.toString());
      if (punchOut != null)
        checkOutTime.value = DateTime.tryParse(punchOut.toString());

      if (checkInTime.value != null && checkOutTime.value == null) {
        isCheckedIn.value = true;
        elapsedSecs.value =
            DateTime.now().difference(checkInTime.value!).inSeconds;
        _elapsedTimer?.cancel();
        _elapsedTimer = Timer.periodic(
            const Duration(seconds: 1), (_) => elapsedSecs.value++);
      } else if (checkOutTime.value != null) {
        isCheckedIn.value = false;
        elapsedSecs.value =
            checkOutTime.value!.difference(checkInTime.value!).inSeconds;
      }
    } catch (_) {}
  }

  Future<void> checkIn() async {
    if (isPunching.value) return;
    isPunching.value = true;
    try {
      await _dio.post('/api/v1/attendance/punch-in', data: {});
      checkInTime.value = DateTime.now();
      checkOutTime.value = null;
      isCheckedIn.value = true;
      elapsedSecs.value = 0;
      _elapsedTimer?.cancel();
      _elapsedTimer = Timer.periodic(
          const Duration(seconds: 1), (_) => elapsedSecs.value++);
      Get.snackbar('Checked In', 'Attendance recorded.',
          backgroundColor: AppColors.success,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16));
    } on DioException catch (e) {
      Get.snackbar('Failed', ApiFailure.fromDioException(e).message,
          backgroundColor: AppColors.danger,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16));
    } finally {
      isPunching.value = false;
    }
  }

  Future<void> checkOut() async {
    if (isPunching.value) return;
    isPunching.value = true;
    try {
      await _dio.post('/api/v1/attendance/punch-out', data: {});
      checkOutTime.value = DateTime.now();
      isCheckedIn.value = false;
      _elapsedTimer?.cancel();
      Get.snackbar('Checked Out', 'Attendance recorded.',
          backgroundColor: AppColors.info,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16));
    } on DioException catch (e) {
      Get.snackbar('Failed', ApiFailure.fromDioException(e).message,
          backgroundColor: AppColors.danger,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16));
    } finally {
      isPunching.value = false;
    }
  }

  String get elapsedFormatted {
    final h = (elapsedSecs.value ~/ 3600).toString().padLeft(2, '0');
    final m = ((elapsedSecs.value % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (elapsedSecs.value % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '--:--';
    final h12 =
        (dt.hour % 12 == 0 ? 12 : dt.hour % 12).toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h12:$min $ampm';
  }

  String get checkInDisplay => _fmt(checkInTime.value);
  String get checkOutDisplay => _fmt(checkOutTime.value);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN SHELL
// ═══════════════════════════════════════════════════════════════════════════════
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  bool _sidebarOpen = false;

  void openSidebar() => setState(() => _sidebarOpen = true);

  static const _navItems = [
    (Icons.dashboard_rounded, Icons.dashboard_outlined, 'Dashboard'),
    (Icons.people_rounded, Icons.people_outline_rounded, 'Employees'),
    (Icons.person_add_rounded, Icons.person_add_outlined, 'Add'),
    (Icons.approval_rounded, Icons.approval_outlined, 'Approvals'),
    (Icons.access_time_rounded, Icons.access_time_outlined, 'Attendance'),
  ];

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    SidebarOpener.register(openSidebar);
    TabSwitcher.register((i) => setState(() => _selectedIndex = i));
    Get.put(AttendanceController(), permanent: true);
    Get.put(EmployeeController(), permanent: true);
    _pages = [
      const DashboardPage(),
      const EmployeeListPage(),
      const AddEmployeePage(),
      const ApprovalsPage(),
      const AttendancePage(),
    ];
  }

  @override
  void dispose() {
    SidebarOpener.unregister();
    TabSwitcher.unregister();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Read theme once — no Obx here; Scaffold bg is static per build
    final t = ThemeController.to;
    return Scaffold(
      backgroundColor: t.bg,
      body: Stack(children: [
        Column(children: [
          Expanded(
              child: IndexedStack(index: _selectedIndex, children: _pages)),
          _BottomNav(
            selectedIndex: _selectedIndex,
            items: _navItems,
            onTap: (i) => setState(() => _selectedIndex = i),
          ),
        ]),
        if (_sidebarOpen) ...[
          GestureDetector(
            onTap: () => setState(() => _sidebarOpen = false),
            child: Container(color: Colors.black54),
          ),
          _Sidebar(
            onClose: () => setState(() => _sidebarOpen = false),
            onNav: (i) => setState(() {
              _selectedIndex = i;
              _sidebarOpen = false;
            }),
            onProfile: () {
              setState(() => _sidebarOpen = false);
              Get.to(() => const ProfilePage(),
                  transition: Transition.cupertino);
            },
          ),
        ],
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BOTTOM NAV
// ═══════════════════════════════════════════════════════════════════════════════
class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final List<(IconData, IconData, String)> items;
  final void Function(int) onTap;
  const _BottomNav({
    required this.selectedIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Obx only here so border/bg update on theme toggle
    return Obx(() {
      final t = ThemeController.to;
      return Container(
        decoration: BoxDecoration(
          color: t.surface,
          border: Border(top: BorderSide(color: t.border)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, -2))
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
                children: List.generate(items.length, (i) {
              final item = items[i];
              final sel = selectedIndex == i;
              if (i == 2) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(i),
                    behavior: HitTestBehavior.opaque,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.accent
                                    .withOpacity(sel ? 0.45 : 0.25),
                                blurRadius: sel ? 14 : 8,
                                offset: const Offset(0, 4))
                          ],
                        ),
                        child: Icon(sel ? item.$1 : item.$2,
                            color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                );
              }
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                            color: sel
                                ? AppColors.accentLight
                                : Colors.transparent,
                            borderRadius:
                                BorderRadius.circular(AppRadius.full)),
                        child: Icon(sel ? item.$1 : item.$2,
                            color: sel ? AppColors.accent : t.textTert,
                            size: 21),
                      ),
                      const SizedBox(height: 2),
                      Text(item.$3,
                          style: AppTextStyles.caption.copyWith(
                              fontSize: 9.5,
                              color: sel ? AppColors.accent : t.textTert,
                              fontWeight:
                                  sel ? FontWeight.w600 : FontWeight.w400)),
                    ],
                  ),
                ),
              );
            })),
          ),
        ),
      );
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIDEBAR — no Obx wrapper; reads t/auth directly in build()
// ═══════════════════════════════════════════════════════════════════════════════
class _Sidebar extends StatelessWidget {
  final VoidCallback onClose;
  final void Function(int) onNav;
  final VoidCallback onProfile;
  const _Sidebar({
    required this.onClose,
    required this.onNav,
    required this.onProfile,
  });

  static const _items = [
    (Icons.dashboard_rounded, 'Dashboard', 0, AppColors.accent),
    (Icons.people_rounded, 'Employees', 1, AppColors.info),
    (Icons.person_add_rounded, 'Add Employee', 2, AppColors.success),
    (Icons.approval_rounded, 'Approvals', 3, AppColors.warning),
    (Icons.access_time_rounded, 'Attendance', 4, AppColors.primary),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final t = ThemeController.to;
    return Positioned(
      top: 0,
      left: 0,
      bottom: 0,
      width: 280,
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 24,
                offset: const Offset(4, 0))
          ],
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header — dark gradient always
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF312E81)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                ),
                child: Row(children: [
                  // Avatar uses Obx for initials only
                  Obx(() => CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: Text(
                            auth.userInitials.value.isNotEmpty
                                ? auth.userInitials.value
                                : 'U',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16)),
                      )),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Obx(() => Text(auth.userName.value,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                        Obx(() => Text(auth.roleDisplay,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 12))),
                      ])),
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 16)),
                  ),
                ]),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Obx(() => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: AppColors.accentLight,
                          borderRadius: BorderRadius.circular(AppRadius.full)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.business_rounded,
                            size: 12, color: AppColors.accent),
                        const SizedBox(width: 5),
                        Text(auth.companyName.value,
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600)),
                      ]),
                    )),
              ),

              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Divider(color: t.border),
              ),

              Expanded(
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  children: [
                    _sectionLabel('MAIN MENU', t),
                    ..._items.map((item) => _SidebarTile(
                          icon: item.$1,
                          label: item.$2,
                          color: item.$4,
                          t: t,
                          onTap: () => onNav(item.$3),
                        )),
                    const SizedBox(height: 16),
                    _sectionLabel('ACCOUNT', t),
                    _SidebarTile(
                        icon: Icons.person_outline_rounded,
                        label: 'My Profile',
                        color: t.textSec,
                        t: t,
                        onTap: onProfile),
                    _SidebarTile(
                        icon: t.isDark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        label: t.isDark ? 'Light Mode' : 'Dark Mode',
                        color: t.textSec,
                        t: t,
                        onTap: () {
                          ThemeController.to.toggle();
                          onClose();
                        }),
                    _SidebarTile(
                        icon: Icons.help_outline_rounded,
                        label: 'Help & Support',
                        color: t.textSec,
                        t: t,
                        onTap: () {}),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: () {
                    onClose();
                    Get.find<AuthController>().logout();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border:
                          Border.all(color: AppColors.danger.withOpacity(0.25)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.logout_rounded,
                          color: AppColors.danger, size: 18),
                      const SizedBox(width: 10),
                      Text('Sign out',
                          style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, ThemeController t) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Text(label,
            style: AppTextStyles.caption.copyWith(
                color: t.textTert,
                letterSpacing: 1,
                fontWeight: FontWeight.w600)),
      );
}

class _SidebarTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final ThemeController t;
  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(children: [
          Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Icon(icon, color: color, size: 17)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: AppTextStyles.bodyMedium.copyWith(
                      color: t.textPrimary, fontWeight: FontWeight.w500))),
          Icon(Icons.chevron_right_rounded, size: 16, color: t.textTert),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DASHBOARD PAGE — no outer Obx; sub-widgets handle their own reactivity
// ═══════════════════════════════════════════════════════════════════════════════
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(DashboardController());
    final t = ThemeController.to;
    return Scaffold(
      backgroundColor: t.bg,
      body: CustomScrollView(slivers: [
        _DashboardSliverAppBar(),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverList(
              delegate: SliverChildListDelegate([
            const SizedBox(height: 16),
            // ── Workforce Stats Cards ──────────────────────────────────────
            Obx(() => ctrl.workforce.value != null
                ? _WorkforceStatsGrid(ctrl: ctrl)
                : const SizedBox.shrink()),
            const SizedBox(height: 16),
            // ── Secondary KPI Row ──────────────────────────────────────────
            Obx(() => ctrl.workforce.value != null
                ? _SecondaryKpiRow(ctrl: ctrl)
                : const SizedBox.shrink()),
            const SizedBox(height: 16),
            // ── Supervisor Pipeline (if available) ─────────────────────────
            Obx(() => ctrl.supervisorMetrics.value != null
                ? _HeroCards(ctrl: ctrl)
                : const SizedBox.shrink()),
            const SizedBox(height: 16),
            // ── Employee List ──────────────────────────────────────────────
            _EmployeeQuickList(t: t),
            const SizedBox(height: 16),
            // ── Recent Onboarding ──────────────────────────────────────────
            Obx(() => ctrl.recentOnboarding.isNotEmpty
                ? _RecentOnboardingSection(ctrl: ctrl, t: t)
                : const SizedBox.shrink()),
            const SizedBox(height: 16),
            Obx(() => ctrl.pendingApprovals.isNotEmpty
                ? _PendingTile(ctrl: ctrl)
                : const SizedBox.shrink()),
            const SizedBox(height: 80),
          ])),
        ),
      ]),
    );
  }
}

// ── Dashboard SliverAppBar ─────────────────────────────────────────────────────
class _DashboardSliverAppBar extends StatelessWidget {
  void _showProfileSheet() {
    final auth = Get.find<AuthController>();
    Get.bottomSheet(
      Builder(builder: (ctx) {
        final t = ThemeController.to;
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
          decoration: BoxDecoration(
              color: t.surface,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24), topRight: Radius.circular(24))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: t.border, borderRadius: BorderRadius.circular(100))),
            const SizedBox(height: 24),
            Obx(() => CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.accentLight,
                child: Text(auth.userInitials.value,
                    style: AppTextStyles.displayMedium
                        .copyWith(color: AppColors.accent, fontSize: 24)))),
            const SizedBox(height: 12),
            Obx(() => Text(auth.userName.value,
                style: AppTextStyles.headingMedium
                    .copyWith(color: t.textPrimary))),
            const SizedBox(height: 4),
            Obx(() => Text(auth.roleDisplay,
                style: AppTextStyles.bodySmall.copyWith(color: t.textSec))),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Get.back();
                Get.to(() => const ProfilePage());
              },
              icon: const Icon(Icons.badge_rounded, size: 16),
              label: const Text('View ID Card & Profile'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16)),
            ),
            const SizedBox(height: 10),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Get.back();
                    auth.logout();
                  },
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Sign out'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 0),
                )),
          ]),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Obx here so app bar bg/text reacts to theme toggle
    return Obx(() {
      final t = ThemeController.to;
      final auth = Get.find<AuthController>();
      return SliverAppBar(
        pinned: true,
        floating: false,
        backgroundColor: t.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 64,
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: GestureDetector(
            onTap: SidebarOpener.open,
            child: Container(
              decoration: BoxDecoration(
                  color: t.surfaceVar,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: t.border)),
              child: Icon(Icons.menu_rounded, color: t.textSec, size: 20),
            ),
          ),
        ),
        title: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
              auth.companyName.value.isNotEmpty
                  ? auth.companyName.value
                  : 'My Operations',
              style: AppTextStyles.headingMedium.copyWith(color: t.textPrimary),
              textAlign: TextAlign.center),
          Text(
              auth.roleDisplay.isNotEmpty
                  ? '${auth.roleDisplay} Dashboard'
                  : 'Supervisor Dashboard',
              style: AppTextStyles.caption.copyWith(color: t.textSec),
              textAlign: TextAlign.center),
        ]),
        centerTitle: true,
        titleSpacing: 0,
        actions: [
          const ThemeToggleButton(),
          GestureDetector(
            onTap: _showProfileSheet,
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.accentLight,
                  child: Text(
                      auth.userInitials.value.isNotEmpty
                          ? auth.userInitials.value
                          : 'U',
                      style: AppTextStyles.headingSmall
                          .copyWith(color: AppColors.accent, fontSize: 12))),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: t.border),
        ),
      );
    });
  }
}

// ── Employee Quick List ────────────────────────────────────────────────────────
class _EmployeeQuickList extends StatelessWidget {
  final ThemeController t;
  const _EmployeeQuickList({required this.t});

  @override
  Widget build(BuildContext context) {
    final empCtrl = Get.find<EmployeeController>();
    return Container(
      decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: t.border),
          boxShadow: t.cardShadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('My Employees',
                      style: AppTextStyles.headingSmall
                          .copyWith(color: t.textPrimary)),
                  Obx(() => Text(
                      '${empCtrl.employees.length} total across your branches',
                      style:
                          AppTextStyles.caption.copyWith(color: t.textTert))),
                ])),
            GestureDetector(
              onTap: () => TabSwitcher.switchTo(1),
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: BorderRadius.circular(AppRadius.full)),
                  child: Text('View all',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600))),
            ),
          ]),
        ),
        Divider(height: 1, color: t.border),
        Obx(() => Column(
              children: empCtrl.employees
                  .take(4)
                  .map((emp) => _QuickEmpRow(emp: emp, t: t))
                  .toList(),
            )),
      ]),
    );
  }
}

class _QuickEmpRow extends StatelessWidget {
  final dynamic emp;
  final ThemeController t;
  const _QuickEmpRow({required this.emp, required this.t});

  static const _typeMap = <String, (Color, String)>{
    'CONTRACT': (AppColors.accent, 'Contractual'),
    'NAPS': (AppColors.info, 'NAPS'),
    'FULL_TIME': (AppColors.success, 'Staff'),
    'INTERN': (AppColors.warning, 'Intern'),
  };

  @override
  Widget build(BuildContext context) {
    final tc = _typeMap[emp.employmentType as String?] ??
        (AppColors.textSecondary, emp.employmentType as String? ?? '');
    return Column(children: [
      InkWell(
        onTap: () => Get.to(() => EmployeeEditPage(employeeId: emp.id as int),
            transition: Transition.cupertino),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12)),
              child: Center(
                  child: Text(emp.initials as String,
                      style: AppTextStyles.headingSmall
                          .copyWith(color: Colors.white, fontSize: 13))),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(emp.fullName as String,
                      style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600, color: t.textPrimary)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text(emp.employeeCode as String,
                        style: AppTextStyles.caption.copyWith(
                            color: t.textTert,
                            fontFamily: 'monospace',
                            fontSize: 10)),
                    if (emp.designation != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                          child: Text(emp.designation as String,
                              style: AppTextStyles.caption
                                  .copyWith(color: t.textSec, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                    ],
                  ]),
                ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: tc.$1.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.full)),
              child: Text(tc.$2,
                  style: AppTextStyles.caption.copyWith(
                      color: tc.$1, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 16, color: t.textTert),
          ]),
        ),
      ),
      Divider(height: 1, color: t.border),
    ]);
  }
}

// ── Hero Cards — reads t directly, no Obx wrapper ─────────────────────────────
// ── Workforce Stats Grid (matches web portal) ─────────────────────────────────
class _WorkforceStatsGrid extends StatelessWidget {
  final DashboardController ctrl;
  const _WorkforceStatsGrid({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.to;
    final w = ctrl.workforce.value!;
    return Column(children: [
      // Row 1: Total, Deployed, Unassigned, Pending Onboarding
      Row(children: [
        Expanded(
            child: _StatCard(
                title: 'Total Workforce',
                value: w.totalEmployees.toString(),
                subtitle: '${w.working} working',
                icon: Icons.people_rounded,
                color: AppColors.accent,
                borderColor: AppColors.accent,
                t: t)),
        const SizedBox(width: 10),
        Expanded(
            child: _StatCard(
                title: 'Deployed',
                value: w.deployed.toString(),
                subtitle: 'Billable',
                icon: Icons.business_center_rounded,
                color: AppColors.success,
                borderColor: AppColors.success,
                t: t)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
            child: _StatCard(
                title: 'Unassigned',
                value: w.unassigned.toString(),
                subtitle: '${w.unassignedPct.toStringAsFixed(0)}% of working',
                icon: Icons.warning_amber_rounded,
                color: AppColors.warning,
                borderColor: AppColors.warning,
                t: t)),
        const SizedBox(width: 10),
        Expanded(
            child: _StatCard(
                title: 'Pending\nOnboarding',
                value: w.pendingOnboarding.toString(),
                subtitle: 'Awaiting approval',
                icon: Icons.schedule_rounded,
                color: AppColors.info,
                borderColor: AppColors.info,
                t: t)),
      ]),
      const SizedBox(height: 10),
      // Row 2: Pending Salary, Rejected, Deactivated
      Row(children: [
        Expanded(
            child: _StatCard(
                title: 'Pending Salary\nSetup',
                value: w.pendingSalarySetup.toString(),
                subtitle: 'Awaiting compensation',
                icon: Icons.attach_money_rounded,
                color: const Color(0xFFD97706),
                borderColor: const Color(0xFFD97706),
                t: t)),
        const SizedBox(width: 10),
        Expanded(
            child: _StatCard(
                title: 'Rejected',
                value: w.rejected.toString(),
                subtitle: '',
                icon: Icons.cancel_outlined,
                color: AppColors.danger,
                borderColor: AppColors.danger,
                t: t)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
            child: _StatCard(
                title: 'Deactivated',
                value: w.deactivated.toString(),
                subtitle: '',
                icon: Icons.person_off_rounded,
                color: const Color(0xFF6B7280),
                borderColor: const Color(0xFF6B7280),
                t: t)),
        const Expanded(child: SizedBox()), // spacer
      ]),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final String title, value, subtitle;
  final IconData icon;
  final Color color, borderColor;
  final ThemeController t;
  const _StatCard(
      {required this.title,
      required this.value,
      required this.subtitle,
      required this.icon,
      required this.color,
      required this.borderColor,
      required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: t.border),
        boxShadow: t.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Top color accent bar
        Container(
            height: 3,
            width: 40,
            decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular(AppRadius.full))),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: AppTextStyles.caption.copyWith(
                        color: t.textSec,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1.3)),
                const SizedBox(height: 4),
                Text(value,
                    style: AppTextStyles.numericLarge.copyWith(
                        color: t.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w700)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: AppTextStyles.caption
                          .copyWith(color: t.textTert, fontSize: 10)),
                ],
              ])),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ]),
      ]),
    );
  }
}

// ── Secondary KPI Row (Working / Unassigned Ratio / On Probation / New Joiners / Exits) ──
class _SecondaryKpiRow extends StatelessWidget {
  final DashboardController ctrl;
  const _SecondaryKpiRow({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.to;
    final w = ctrl.workforce.value!;
    return Container(
      decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: t.border),
          boxShadow: t.cardShadow),
      child: IntrinsicHeight(
          child: Row(children: [
        _kpiCell('${w.working}', 'Working', t),
        _divider(t),
        _kpiCell(
            '${w.unassignedPct.toStringAsFixed(0)}%', 'Unassigned Ratio', t),
        _divider(t),
        _kpiCell('${w.onProbation}', 'On Probation', t),
        _divider(t),
        _kpiCell('${w.newJoinersThisMonth}', 'New Joiners (mo)', t),
        _divider(t),
        _kpiCell('${w.exitsThisMonth}', 'Exits (mo)', t),
      ])),
    );
  }

  Widget _kpiCell(String value, String label, ThemeController t) => Expanded(
          child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(value,
              style: AppTextStyles.numericMedium.copyWith(
                  color: t.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  AppTextStyles.caption.copyWith(color: t.textSec, fontSize: 9),
              textAlign: TextAlign.center),
        ]),
      ));

  Widget _divider(ThemeController t) => Container(width: 1, color: t.border);
}

// ── Recent Onboarding Section (from real API data.recentOnboarding) ────────────
class _RecentOnboardingSection extends StatelessWidget {
  final DashboardController ctrl;
  final ThemeController t;
  const _RecentOnboardingSection({required this.ctrl, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: t.border),
          boxShadow: t.cardShadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Recent Onboarding',
              style: AppTextStyles.headingSmall.copyWith(color: t.textPrimary)),
          const Spacer(),
          Text('${ctrl.recentOnboarding.length} records',
              style: AppTextStyles.caption.copyWith(color: t.textTert)),
        ]),
        const SizedBox(height: 12),
        ...ctrl.recentOnboarding.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.accentLight,
                    child: Text(
                        e.name.isNotEmpty ? e.name[0].toUpperCase() : '?',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700))),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(e.name,
                          style: AppTextStyles.bodySmall.copyWith(
                              color: t.textPrimary,
                              fontWeight: FontWeight.w600)),
                      Text('ID: ${e.employeeId}',
                          style: AppTextStyles.caption
                              .copyWith(color: t.textTert, fontSize: 10)),
                    ])),
                StatusBadge(status: e.status),
              ]),
            )),
      ]),
    );
  }
}

class _HeroCards extends StatelessWidget {
  final DashboardController ctrl;
  const _HeroCards({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.to;
    final me = ctrl.supervisorMetrics.value!;
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: t.border),
            boxShadow: t.cardShadow),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              height: 3,
              decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(AppRadius.full))),
          const SizedBox(height: 12),
          Row(children: [
            Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: const Icon(Icons.emoji_events_rounded,
                    color: AppColors.accent, size: 16)),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('My Onboarding Pipeline',
                  style: AppTextStyles.headingSmall
                      .copyWith(color: t.textPrimary)),
              Text('Lifetime — hires you raised',
                  style: AppTextStyles.caption.copyWith(color: t.textTert)),
            ]),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            _mini(me.onboarded.toString(), 'Total Raised', t.textPrimary, t),
            _mini(
                me.pending.toString(), 'Pending', AppColors.pipelinePending, t),
            _mini(me.approved.toString(), 'Approved',
                AppColors.pipelineApproved, t),
            _mini(me.rejected.toString(), 'Rejected',
                AppColors.pipelineRejected, t),
          ]),
          const SizedBox(height: 12),
          PipelineStatusBar(
              total: me.onboarded,
              approved: me.approved,
              pending: me.pending,
              rejected: me.rejected),
          const SizedBox(height: 8),
          if (me.onboarded > 0)
            Row(children: [
              _dot(AppColors.pipelineApproved, 'Approved ${me.approved}'),
              const SizedBox(width: 12),
              _dot(AppColors.pipelinePending, 'Pending ${me.pending}'),
              const SizedBox(width: 12),
              _dot(AppColors.pipelineRejected, 'Rejected ${me.rejected}'),
            ]),
          const SizedBox(height: 12),
          Divider(height: 1, color: t.border),
          const SizedBox(height: 12),
          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${(me.approvalRate * 100).toStringAsFixed(1)}%',
                  style: AppTextStyles.numericLarge
                      .copyWith(color: AppColors.accent)),
              Text('Approval Rate',
                  style: AppTextStyles.caption.copyWith(color: t.textSec)),
            ]),
            const SizedBox(width: 12),
            Expanded(
                child: Text('Approved out of total raised; pending included.',
                    style: AppTextStyles.caption.copyWith(color: t.textTert))),
          ]),
        ]),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: t.border),
            boxShadow: t.cardShadow),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              height: 3,
              decoration: BoxDecoration(
                  color: AppColors.info,
                  borderRadius: BorderRadius.circular(AppRadius.full))),
          const SizedBox(height: 12),
          Row(children: [
            Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: AppColors.infoLight,
                    borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: const Icon(Icons.shield_outlined,
                    color: AppColors.info, size: 16)),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('My Managed Workforce',
                  style: AppTextStyles.headingSmall
                      .copyWith(color: t.textPrimary)),
              Text('Current — employees in your branches',
                  style: AppTextStyles.caption.copyWith(color: t.textTert)),
            ]),
          ]),
          const SizedBox(height: 12),
          Text(me.managedWorkforce.toString(),
              style: AppTextStyles.numericLarge
                  .copyWith(color: AppColors.info, fontSize: 36)),
          Text('Managed workforce',
              style: AppTextStyles.caption.copyWith(color: t.textSec)),
          if (me.clientNames.isNotEmpty || me.branchNames.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              ...me.clientNames.map((n) => _chip(n, t)),
              ...me.branchNames.map((n) => _chip(n, t)),
            ]),
          ],
        ]),
      ),
    ]);
  }

  Widget _mini(String v, String l, Color c, ThemeController t) => Expanded(
          child: Column(children: [
        Text(v,
            style:
                AppTextStyles.numericMedium.copyWith(color: c, fontSize: 20)),
        const SizedBox(height: 2),
        Text(l,
            style:
                AppTextStyles.caption.copyWith(color: t.textSec, fontSize: 10),
            textAlign: TextAlign.center),
      ]));

  Widget _dot(Color color, String label) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppRadius.full))),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10)),
      ]);

  Widget _chip(String l, ThemeController t) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: t.surfaceVar,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: t.border)),
      child: Text(l, style: AppTextStyles.caption.copyWith(color: t.textSec)));
}

// ── KPI Row ────────────────────────────────────────────────────────────────────
class _KpiRow extends StatelessWidget {
  final DashboardController ctrl;
  const _KpiRow({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final w = ctrl.workforceStats.value!;
    final pct = '${(w.benchRatio * 100).toStringAsFixed(1)}%';
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
            child: KpiCard(
                title: 'Working',
                value: w.working.toString(),
                icon: Icons.people_rounded,
                color: AppColors.accent)),
        const SizedBox(width: 8),
        Expanded(
            child: KpiCard(
                title: 'Deployed',
                value: w.deployed.toString(),
                subtitle: 'Billable',
                icon: Icons.work_rounded,
                color: AppColors.success)),
        const SizedBox(width: 8),
        Expanded(
            child: KpiCard(
                title: 'Unassigned',
                value: w.bench.toString(),
                subtitle: '$pct of working',
                icon: Icons.pause_circle_outline_rounded,
                color: AppColors.warning)),
      ]),
    );
  }
}

// ── Recent Onboarding — no outer Obx; t passed in ─────────────────────────────
class _RecentOnboarding extends StatelessWidget {
  final DashboardController ctrl;
  final ThemeController t;
  const _RecentOnboarding({required this.ctrl, required this.t});

  static const _typeColors = <String, (Color, Color, String)>{
    'CONTRACT': (AppColors.accentLight, AppColors.accent, 'Contractual'),
    'NAPS': (AppColors.infoLight, AppColors.info, 'NAPS'),
    'FULL_TIME': (AppColors.successLight, AppColors.success, 'Staff'),
    'INTERN': (AppColors.warningLight, AppColors.warning, 'Intern'),
  };

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (ctrl.recentOnboarding.isEmpty) return const SizedBox.shrink();
      return Container(
        decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: t.border),
            boxShadow: t.cardShadow),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('My Recent Onboarding',
                          style: AppTextStyles.headingSmall
                              .copyWith(color: t.textPrimary)),
                      Text('Your latest submissions',
                          style: AppTextStyles.caption
                              .copyWith(color: t.textTert)),
                    ])),
                TextButton(
                    onPressed: () {},
                    child: Text('View all',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.accent))),
              ])),
          Divider(height: 1, color: t.border),
          ...ctrl.recentOnboarding.map((row) {
            final initials = row.name.isNotEmpty
                ? row.name
                    .split(' ')
                    .take(2)
                    .map((w) => w.isNotEmpty ? w[0] : '')
                    .join()
                : '?';
            return Column(children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.accentLight,
                      child: Text(initials.toUpperCase(),
                          style: AppTextStyles.headingSmall.copyWith(
                              color: AppColors.accent, fontSize: 13))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Row(children: [
                          Expanded(
                              child: Text(row.name,
                                  style: AppTextStyles.bodySmall.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: t.textPrimary))),
                          StatusBadge(status: row.status),
                        ]),
                        const SizedBox(height: 3),
                        Row(children: [
                          Text('ID: ${row.employeeId}',
                              style: AppTextStyles.caption
                                  .copyWith(color: t.textSec, fontSize: 11)),
                        ]),
                      ])),
                ]),
              ),
              Divider(height: 1, color: t.border),
            ]);
          }),
        ]),
      );
    });
  }
}

// ── Pending Tile ───────────────────────────────────────────────────────────────
class _PendingTile extends StatelessWidget {
  final DashboardController ctrl;
  const _PendingTile({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.warningLight,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.warning.withOpacity(0.3))),
      child: Row(children: [
        const Icon(Icons.hourglass_top_rounded,
            color: AppColors.warning, size: 22),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('My Pending Approvals',
              style: AppTextStyles.headingSmall
                  .copyWith(color: AppColors.warning)),
          Text(
              '${ctrl.pendingApprovals.length} hire${ctrl.pendingApprovals.length == 1 ? '' : 's'} awaiting your action',
              style: AppTextStyles.caption),
        ])),
        Text('Review',
            style:
                AppTextStyles.buttonMedium.copyWith(color: AppColors.warning)),
        const SizedBox(width: 4),
        const Icon(Icons.arrow_forward_ios_rounded,
            size: 12, color: AppColors.warning),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ATTENDANCE PAGE
// ═══════════════════════════════════════════════════════════════════════════════
class AttendancePage extends StatelessWidget {
  const AttendancePage({super.key});

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AttendanceController>();
    final t = ThemeController.to;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: SharedAppBar(
        title: 'Attendance',
        subtitle: _buildSubtitle(ctrl),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _ClockCard(ctrl: ctrl, days: _days, months: _months),
          const SizedBox(height: 16),
          Obx(() => Row(children: [
                Expanded(
                    child: _TimeTile(
                        label: 'Check In',
                        time: ctrl.checkInDisplay,
                        icon: Icons.login_rounded,
                        color: AppColors.success,
                        active: ctrl.checkInTime.value != null,
                        t: t)),
                const SizedBox(width: 12),
                Expanded(
                    child: _TimeTile(
                        label: 'Check Out',
                        time: ctrl.checkOutDisplay,
                        icon: Icons.logout_rounded,
                        color: AppColors.danger,
                        active: ctrl.checkOutTime.value != null,
                        t: t)),
              ])),
          const SizedBox(height: 16),
          _CheckButton(ctrl: ctrl),
          const SizedBox(height: 20),
          Obx(() {
            final now = ctrl.currentTime.value;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: t.border),
                  boxShadow: t.cardShadow),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text("Today's Summary",
                          style: AppTextStyles.headingSmall
                              .copyWith(color: t.textPrimary)),
                      const Spacer(),
                      Text('${now.day}/${now.month}/${now.year}',
                          style: AppTextStyles.caption
                              .copyWith(color: t.textTert)),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      _SummaryStat(
                          label: 'Status',
                          value: ctrl.isCheckedIn.value
                              ? 'Present'
                              : ctrl.checkOutTime.value != null
                                  ? 'Completed'
                                  : 'Absent',
                          color: ctrl.isCheckedIn.value
                              ? AppColors.success
                              : ctrl.checkOutTime.value != null
                                  ? AppColors.info
                                  : t.textTert,
                          t: t),
                      _SummaryStat(
                          label: 'Check In',
                          value: ctrl.checkInDisplay,
                          color: AppColors.success,
                          t: t),
                      _SummaryStat(
                          label: 'Check Out',
                          value: ctrl.checkOutDisplay,
                          color: AppColors.danger,
                          t: t),
                      _SummaryStat(
                          label: 'Duration',
                          value: ctrl.checkInTime.value != null
                              ? ctrl.elapsedFormatted
                              : '--:--:--',
                          color: AppColors.accent,
                          t: t),
                    ]),
                  ]),
            );
          }),
          const SizedBox(height: 16),
          Obx(() {
            final now = ctrl.currentTime.value;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: t.border),
                  boxShadow: t.cardShadow),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('This Week',
                        style: AppTextStyles.headingSmall
                            .copyWith(color: t.textPrimary)),
                    const SizedBox(height: 14),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _WeekDay(day: 'Mon', status: 'present', t: t),
                          _WeekDay(day: 'Tue', status: 'present', t: t),
                          _WeekDay(day: 'Wed', status: 'present', t: t),
                          _WeekDay(day: 'Thu', status: 'present', t: t),
                          _WeekDay(
                              day: 'Fri',
                              status: ctrl.checkInTime.value != null
                                  ? 'present'
                                  : 'today',
                              t: t),
                          _WeekDay(day: 'Sat', status: 'weekend', t: t),
                          _WeekDay(day: 'Sun', status: 'weekend', t: t),
                        ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      _legend(t, AppColors.success, 'Present'),
                      const SizedBox(width: 16),
                      _legend(t, AppColors.accent, 'Today'),
                      const SizedBox(width: 16),
                      _legend(t, t.border, 'Weekend'),
                    ]),
                  ]),
            );
          }),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  String _buildSubtitle(AttendanceController ctrl) {
    final now = ctrl.currentTime.value;
    return '${_days[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]} ${now.year}';
  }

  Widget _legend(ThemeController t, Color color, String label) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label, style: AppTextStyles.caption.copyWith(color: t.textSec)),
      ]);
}

class _ClockCard extends StatelessWidget {
  final AttendanceController ctrl;
  final List<String> days;
  final List<String> months;
  _ClockCard({required this.ctrl, required this.days, required this.months});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final now = ctrl.currentTime.value;
      final h12 =
          (now.hour % 12 == 0 ? 12 : now.hour % 12).toString().padLeft(2, '0');
      final min = now.minute.toString().padLeft(2, '0');
      final sec = now.second.toString().padLeft(2, '0');
      final ampm = now.hour >= 12 ? 'PM' : 'AM';
      final chk = ctrl.isCheckedIn.value;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: BoxDecoration(
          gradient: chk
              ? const LinearGradient(
                  colors: [Color(0xFF065F46), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)
              : const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF312E81)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: (chk ? AppColors.success : AppColors.primary)
                    .withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppRadius.full)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                      color: chk
                          ? const Color(0xFF6EE7B7)
                          : const Color(0xFF94A3B8),
                      shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(chk ? 'Checked In' : 'Not Checked In',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ]),
          ),
          const SizedBox(height: 24),
          Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$h12:$min',
                    style: const TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -2,
                        height: 1)),
                const SizedBox(width: 4),
                Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sec,
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.6),
                                  letterSpacing: -0.5)),
                          Text(ampm,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white60)),
                        ])),
              ]),
          const SizedBox(height: 8),
          Text('${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6), fontSize: 13)),
          if (chk) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: Text('Working: ${ctrl.elapsedFormatted}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      letterSpacing: 2)),
            ),
          ],
        ]),
      );
    });
  }
}

class _CheckButton extends StatelessWidget {
  final AttendanceController ctrl;
  const _CheckButton({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final chk = ctrl.isCheckedIn.value;
      final punching = ctrl.isPunching.value;
      return GestureDetector(
        onTap: punching ? null : (chk ? ctrl.checkOut : ctrl.checkIn),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            gradient: chk
                ? const LinearGradient(
                    colors: [Color(0xFFDC2626), Color(0xFFB91C1C)])
                : const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF047857)]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: (chk ? AppColors.danger : AppColors.success)
                      .withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6))
            ],
          ),
          child: punching
              ? const Center(
                  child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(Colors.white))))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(chk ? Icons.logout_rounded : Icons.login_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text(chk ? 'Check Out' : 'Check In',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3)),
                ]),
        ),
      );
    });
  }
}

class _TimeTile extends StatelessWidget {
  final String label, time;
  final IconData icon;
  final Color color;
  final bool active;
  final ThemeController t;
  const _TimeTile(
      {required this.label,
      required this.time,
      required this.icon,
      required this.color,
      required this.active,
      required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: active ? color.withOpacity(0.06) : t.surfaceVar,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border:
              Border.all(color: active ? color.withOpacity(0.25) : t.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: active ? color : t.textTert, size: 16),
          const SizedBox(width: 6),
          Text(label,
              style: AppTextStyles.caption
                  .copyWith(color: active ? color : t.textTert)),
        ]),
        const SizedBox(height: 8),
        Text(time,
            style: AppTextStyles.numericMedium
                .copyWith(color: active ? color : t.textTert, fontSize: 18)),
      ]),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label, value;
  final Color color;
  final ThemeController t;
  const _SummaryStat(
      {required this.label,
      required this.value,
      required this.color,
      required this.t});

  @override
  Widget build(BuildContext context) => Expanded(
          child: Column(children: [
        Text(value,
            style: AppTextStyles.bodySmall.copyWith(
                color: color, fontWeight: FontWeight.w700, fontSize: 13),
            textAlign: TextAlign.center),
        const SizedBox(height: 3),
        Text(label,
            style:
                AppTextStyles.caption.copyWith(color: t.textSec, fontSize: 10),
            textAlign: TextAlign.center),
      ]));
}

class _WeekDay extends StatelessWidget {
  final String day, status;
  final ThemeController t;
  const _WeekDay({required this.day, required this.status, required this.t});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    switch (status) {
      case 'present':
        bg = AppColors.successLight;
        fg = AppColors.success;
        break;
      case 'today':
        bg = AppColors.accentLight;
        fg = AppColors.accent;
        break;
      case 'absent':
        bg = AppColors.dangerLight;
        fg = AppColors.danger;
        break;
      default:
        bg = t.surfaceVar;
        fg = t.textTert;
    }
    return Column(children: [
      Container(
          width: 36,
          height: 36,
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Icon(
              status == 'present'
                  ? Icons.check_rounded
                  : status == 'today'
                      ? Icons.today_rounded
                      : status == 'absent'
                          ? Icons.close_rounded
                          : Icons.remove_rounded,
              color: fg,
              size: 16)),
      const SizedBox(height: 5),
      Text(day, style: AppTextStyles.caption.copyWith(fontSize: 10, color: fg)),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MY REQUESTS PLACEHOLDER
// ═══════════════════════════════════════════════════════════════════════════════
class _SubmissionsPage extends StatelessWidget {
  const _SubmissionsPage();

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.to;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: SharedAppBar(title: 'My Requests'),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(AppRadius.xl)),
            child: const Icon(Icons.assignment_outlined,
                color: AppColors.accent, size: 32),
          ),
          const SizedBox(height: 16),
          Text('My Submissions',
              style:
                  AppTextStyles.headingMedium.copyWith(color: t.textPrimary)),
          const SizedBox(height: 8),
          Text('Hires you raised and their approval status.',
              style: AppTextStyles.bodySmall.copyWith(color: t.textSec),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
