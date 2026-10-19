import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../data/employee_api.dart';
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
  // Three-state model mirroring the web portal's CheckInOutPage:
  //   NOT_CHECKED_IN -> CHECKED_IN -> CHECKED_OUT
  // `isCheckedIn` is kept in sync so existing widgets keep working.
  static const String statusNotIn = 'NOT_CHECKED_IN';
  static const String statusIn = 'CHECKED_IN';
  static const String statusOut = 'CHECKED_OUT';

  final attendanceStatus = statusNotIn.obs;
  final isCheckedIn = false.obs;
  final checkInTime = Rxn<DateTime>();
  final checkOutTime = Rxn<DateTime>();
  final currentTime = DateTime.now().obs;
  final elapsedSecs = 0.obs;
  final isPunching = false.obs;
  final isLoadingStatus = false.obs;
  final employeeId = Rxn<int>();
  Timer? _clockTimer;
  Timer? _elapsedTimer;

  // Punch source. 'WEB' is the only value proven against this backend — it is
  // exactly what the working web portal sends. Change to 'MOBILE' only if the
  // backend PunchSource enum accepts it.
  static const String _punchSource = 'WEB';

  final Dio _dio = ApiClient.instance;
  static const _storage = FlutterSecureStorage();

  bool get hasCheckedOut => attendanceStatus.value == statusOut;

  @override
  void onInit() {
    super.onInit();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      currentTime.value = DateTime.now();
    });
    fetchTodayStatus();
  }

  @override
  void onClose() {
    _clockTimer?.cancel();
    _elapsedTimer?.cancel();
    super.onClose();
  }

  // ── Employee id resolution ────────────────────────────────────────────────
  // punch-in / punch-out and the ledger all need the logged-in employee's id.
  // Order: cached -> secure storage (written at login) -> JWT claim ->
  // first row of /employees/list (that row is the logged-in user).
  /// Public wrapper so MyAttendanceController can reuse the same resolution
  /// cascade instead of duplicating it.
  Future<int?> resolveEmployeeId() => _resolveEmployeeId();

  Future<int?> _resolveEmployeeId() async {
    if (employeeId.value != null) return employeeId.value;

    final stored = await _storage.read(key: 'employee_id');
    final fromStore = int.tryParse(stored ?? '');
    if (fromStore != null) {
      employeeId.value = fromStore;
      return fromStore;
    }

    final token = await _storage.read(key: 'auth_token');
    final fromJwt = ApiClient.getEmployeeIdFromToken(token);
    if (fromJwt != null) {
      employeeId.value = fromJwt;
      return fromJwt;
    }

    try {
      // sortBy MUST be 'firstName' — 'fullName' makes this endpoint 500.
      final res = await _dio.post('/api/v1/employees/list', data: {
        'page': 0,
        'size': 1,
        'sortBy': 'firstName',
        'sortDir': 'ASC',
        'filters': {},
      });
      final list = res.data?['data'] as List?;
      if (list != null && list.isNotEmpty) {
        final raw = (list.first as Map)['employeeId'];
        final parsed = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
        employeeId.value = parsed;
        return parsed;
      }
    } catch (_) {}
    return null;
  }

  // ── Today's status ────────────────────────────────────────────────────────
  // Primary source is POST /attendance/list (the exact call the web portal
  // makes — the backend auto-scopes it to the JWT owner). If that comes back
  // empty we fall back to GET /attendance/ledger, which returns the full day
  // object under `day` when `recorded` is true.
  Future<void> fetchTodayStatus() async {
    isLoadingStatus.value = true;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    Map<String, dynamic>? record;

    try {
      final res = await _dio.post('/api/v1/attendance/list', data: {
        'page': 0,
        'size': 1,
        'sortBy': 'attendanceDate',
        'sortDir': 'DESC',
        'filters': {'dateFrom': today, 'dateTo': today},
      });
      final list = res.data?['data'] as List?;
      if (list != null && list.isNotEmpty) {
        record = Map<String, dynamic>.from(list.first as Map);
      }
    } catch (_) {}

    if (record == null) {
      final empId = await _resolveEmployeeId();
      if (empId != null) {
        try {
          final res = await _dio.get('/api/v1/attendance/ledger',
              queryParameters: {
                'employeeId': empId,
                'from': today,
                'to': today
              });
          final list = res.data?['data'] as List?;
          if (list != null && list.isNotEmpty) {
            final entry = Map<String, dynamic>.from(list.first as Map);
            if (entry['recorded'] == true && entry['day'] is Map) {
              record = Map<String, dynamic>.from(entry['day'] as Map);
            }
          }
        } catch (_) {}
      }
    }

    _applyRecord(record);
    isLoadingStatus.value = false;
  }

  /// Single place that derives UI state from an attendance record.
  /// Passing null resets to NOT_CHECKED_IN (the old code returned early and
  /// left stale state behind).
  void _applyRecord(Map<String, dynamic>? record) {
    _elapsedTimer?.cancel();

    final inRaw = record?['punchInTime'] ?? record?['punchInTimeIST'];
    final outRaw = record?['punchOutTime'] ?? record?['punchOutTimeIST'];

    // toLocal() matters: the API returns UTC ("…T03:37:00.226Z"). Without it
    // a 09:07 AM IST punch rendered as 03:37 AM.
    final pin =
        inRaw == null ? null : DateTime.tryParse(inRaw.toString())?.toLocal();
    final pout =
        outRaw == null ? null : DateTime.tryParse(outRaw.toString())?.toLocal();

    checkInTime.value = pin;
    checkOutTime.value = pout;

    if (pin == null) {
      attendanceStatus.value = statusNotIn;
      isCheckedIn.value = false;
      elapsedSecs.value = 0;
    } else if (pout == null) {
      attendanceStatus.value = statusIn;
      isCheckedIn.value = true;
      elapsedSecs.value =
          DateTime.now().difference(pin).inSeconds.clamp(0, 86400).toInt();
      _elapsedTimer = Timer.periodic(
          const Duration(seconds: 1), (_) => elapsedSecs.value++);
    } else {
      attendanceStatus.value = statusOut;
      isCheckedIn.value = false;
      elapsedSecs.value =
          pout.difference(pin).inSeconds.clamp(0, 86400).toInt();
    }
  }

  Map<String, dynamic> _punchPayload(int? empId) => {
        'employeeId': empId,
        'punchTime': DateTime.now().toUtc().toIso8601String(),
        'punchSource': _punchSource,
        'latitude': null,
        'longitude': null,
      };

  Future<void> checkIn() async {
    if (isPunching.value) return;
    isPunching.value = true;
    try {
      final empId = await _resolveEmployeeId();
      // The old code posted an empty body — no employeeId, no punchTime — so
      // the backend had nothing to record. This is the real fix.
      await _dio.post('/api/v1/attendance/punch-in',
          data: _punchPayload(empId));
      // Re-read from the server so the displayed times are authoritative.
      await fetchTodayStatus();
      Get.snackbar('Checked In', 'Attendance recorded at $checkInDisplay.',
          backgroundColor: AppColors.success,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16));
    } on DioException catch (e) {
      Get.snackbar('Check-in failed', ApiFailure.fromDioException(e).message,
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
      final empId = await _resolveEmployeeId();
      await _dio.post('/api/v1/attendance/punch-out',
          data: _punchPayload(empId));
      await fetchTodayStatus();
      Get.snackbar('Checked Out', 'Attendance recorded at $checkOutDisplay.',
          backgroundColor: AppColors.info,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16));
    } on DioException catch (e) {
      Get.snackbar('Check-out failed', ApiFailure.fromDioException(e).message,
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
      // Pull-to-refresh: re-fetches the dashboard summary. The other tabs
      // (Employees, Approvals) already have this — the main screen was the
      // only one without a way to refresh short of restarting the app.
      body: RefreshIndicator(
        onRefresh: ctrl.load,
        color: AppColors.accent,
        child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: [
              _DashboardSliverAppBar(),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverList(
                    delegate: SliverChildListDelegate([
                  const SizedBox(height: 16),
                  // ── Workforce Stats Cards (shimmer skeleton on first load) ──
                  Obx(() {
                    if (ctrl.workforce.value != null) {
                      return _WorkforceStatsGrid(ctrl: ctrl);
                    }
                    return ctrl.loading.value
                        ? const _DashboardSkeleton()
                        : const SizedBox.shrink();
                  }),
                  const SizedBox(height: 16),
                  // ── Secondary KPI Row ──────────────────────────────────────
                  Obx(() => ctrl.workforce.value != null
                      ? _SecondaryKpiRow(ctrl: ctrl)
                      : const SizedBox.shrink()),
                  const SizedBox(height: 16),
                  // ── Supervisor Pipeline (if available) ─────────────────────
                  Obx(() => ctrl.supervisorMetrics.value != null
                      ? _HeroCards(ctrl: ctrl)
                      : const SizedBox.shrink()),
                  const SizedBox(height: 16),
                  // ── Employee List ──────────────────────────────────────────
                  _EmployeeQuickList(t: t),
                  const SizedBox(height: 16),
                  // ── Recent Onboarding ──────────────────────────────────────
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
      ),
    );
  }
}

// ── Dashboard loading skeleton — shimmer placeholders matching the stat grid ──
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.to;
    Widget box(double h, {double? w, double r = AppRadius.lg}) => Container(
        height: h,
        width: w,
        decoration: BoxDecoration(
            color: t.surface, borderRadius: BorderRadius.circular(r)));
    return Shimmer.fromColors(
      baseColor: t.surface,
      highlightColor: t.surfaceVar,
      child: Column(children: [
        Row(children: [
          Expanded(child: box(96)),
          const SizedBox(width: 10),
          Expanded(child: box(96)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: box(96)),
          const SizedBox(width: 10),
          Expanded(child: box(96)),
        ]),
        const SizedBox(height: 16),
        box(64),
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
    // Entrance animation: cards fade in and rise slightly when the data
    // arrives — runs once per build of the grid, no controller needed.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
          opacity: v,
          child: Transform.translate(
              offset: Offset(0, 12 * (1 - v)), child: child)),
      child: Container(
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
      ),
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
// ═══════════════════════════════════════════════════════════════════════════════
// MY ATTENDANCE — month ledger + monthly summary
// Mirrors the web portal's AttendanceCalendarPage: month nav (12 months of
// history, no future months), a Sun–Sat grid coloured by status, and a
// summary row driven by /monthly-summary.
// ═══════════════════════════════════════════════════════════════════════════════

/// One normalised calendar day from GET /attendance/ledger.
class LedgerDay {
  final DateTime date;
  final bool recorded;

  /// PRESENT | ABSENT | LATE | HALF_DAY | ON_LEAVE | HOLIDAY
  /// | WEEK_OFF | FUTURE | NO_RECORD
  final String status;

  /// Raw attendance record — present only when [recorded] is true.
  final Map<String, dynamic>? day;

  const LedgerDay({
    required this.date,
    required this.recorded,
    required this.status,
    this.day,
  });

  factory LedgerDay.fromJson(Map<String, dynamic> j) {
    final parsed = DateTime.tryParse((j['date'] ?? '').toString());
    final rec = j['recorded'] == true;
    final raw = j['day'];
    final dayMap = raw is Map ? Map<String, dynamic>.from(raw) : null;
    return LedgerDay(
      date: parsed ?? DateTime.now(),
      recorded: rec,
      status: _derive(rec, dayMap, j['derivedStatus']),
      day: dayMap,
    );
  }

  // When a record exists the real status wins, but isHalfDay / isLate are
  // surfaced as their own states (the backend keeps status = PRESENT and
  // flags them separately, exactly like the web's summary counts them).
  static String _derive(
      bool recorded, Map<String, dynamic>? day, dynamic derived) {
    if (recorded && day != null) {
      if (day['isHalfDay'] == true) return 'HALF_DAY';
      if (day['isLate'] == true) return 'LATE';
      final s = (day['status'] ?? '').toString();
      return s.isNotEmpty ? s : 'PRESENT';
    }
    final d = (derived ?? '').toString();
    return d.isNotEmpty ? d : 'NO_RECORD';
  }

  // ── Derived display helpers ─────────────────────────────────────────────
  String? get punchInIst =>
      day?['punchInTimeIST']?.toString() ?? day?['punchInTime']?.toString();
  String? get punchOutIst =>
      day?['punchOutTimeIST']?.toString() ?? day?['punchOutTime']?.toString();
  int get workingMinutes => (day?['workingMinutes'] as num?)?.toInt() ?? 0;
  int get overtimeMinutes => (day?['overtimeMinutes'] as num?)?.toInt() ?? 0;
}

class MyAttendanceController extends GetxController {
  final _api = EmployeeApi();

  final loading = false.obs;
  final summaryLoading = false.obs;
  final error = ''.obs;
  final ledger = <LedgerDay>[].obs;
  final summary = Rxn<Map<String, dynamic>>();

  /// First day of the month currently being viewed.
  final activeMonth = DateTime(DateTime.now().year, DateTime.now().month).obs;

  /// Matches the web's MAX_HISTORY_MONTHS.
  static const int maxHistoryMonths = 12;

  int get year => activeMonth.value.year;
  int get month => activeMonth.value.month;

  DateTime get _thisMonth =>
      DateTime(DateTime.now().year, DateTime.now().month);

  bool get canGoNext => activeMonth.value.isBefore(_thisMonth);
  bool get canGoPrev {
    final earliest =
        DateTime(_thisMonth.year, _thisMonth.month - maxHistoryMonths);
    final prev = DateTime(year, month - 1);
    return !prev.isBefore(earliest);
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }

  void nextMonth() {
    if (!canGoNext) return;
    activeMonth.value = DateTime(year, month + 1);
    load();
  }

  void prevMonth() {
    if (!canGoPrev) return;
    activeMonth.value = DateTime(year, month - 1);
    load();
  }

  Future<void> load() async {
    loading.value = true;
    summaryLoading.value = true;
    error.value = '';

    // Reuse the punch controller's proven employee-id cascade
    // (storage -> JWT claim -> first row of /employees/list).
    int? empId;
    if (Get.isRegistered<AttendanceController>()) {
      empId = await Get.find<AttendanceController>().resolveEmployeeId();
    }
    if (empId == null) {
      error.value = 'Could not identify the logged-in employee.';
      ledger.clear();
      summary.value = null;
      loading.value = false;
      summaryLoading.value = false;
      return;
    }

    final first = DateTime(year, month, 1);
    final last = DateTime(year, month + 1, 0); // day 0 of next month
    final from = DateFormat('yyyy-MM-dd').format(first);
    final to = DateFormat('yyyy-MM-dd').format(last);

    try {
      final rows =
          await _api.getAttendanceLedger(employeeId: empId, from: from, to: to);
      ledger.assignAll(rows
          .whereType<Map>()
          .map((e) => LedgerDay.fromJson(Map<String, dynamic>.from(e)))
          .toList());
    } on DioException catch (e) {
      error.value = ApiFailure.fromDioException(e).message;
      ledger.clear();
    } catch (e) {
      error.value = 'Failed to load attendance: $e';
      ledger.clear();
    } finally {
      loading.value = false;
    }

    // Summary is best-effort — the grid stays usable if it fails.
    try {
      summary.value = await _api.getMonthlySummary(empId, month, year);
    } catch (_) {
      summary.value = null;
    } finally {
      summaryLoading.value = false;
    }
  }

  /// Counts for the summary row. Prefers /monthly-summary (what the web
  /// shows) and falls back to counting the ledger when it isn't available.
  Map<String, int> get counts {
    final s = summary.value;
    if (s != null) {
      int n(String k) => (s[k] as num?)?.toInt() ?? 0;
      return {
        'present': n('presentDays'),
        'absent': n('absentDays'),
        'late': n('lateDays'),
        'leave': n('leavesTaken'),
        'halfDay': n('halfDays'),
      };
    }
    final c = {'present': 0, 'absent': 0, 'late': 0, 'leave': 0, 'halfDay': 0};
    for (final d in ledger) {
      switch (d.status) {
        case 'PRESENT':
          c['present'] = c['present']! + 1;
          break;
        case 'ABSENT':
          c['absent'] = c['absent']! + 1;
          break;
        case 'LATE':
          c['late'] = c['late']! + 1;
          break;
        case 'ON_LEAVE':
        case 'LEAVE':
          c['leave'] = c['leave']! + 1;
          break;
        case 'HALF_DAY':
          c['halfDay'] = c['halfDay']! + 1;
          break;
      }
    }
    return c;
  }

  String summaryText(String key) {
    final v = summary.value?[key];
    if (v == null) return '—';
    return v.toString();
  }
}

// ── Status -> colour / label, shared by the grid, legend and detail sheet ──
class AttendanceStatusStyle {
  final Color color;
  final String label;
  const AttendanceStatusStyle(this.color, this.label);

  static AttendanceStatusStyle of(String status) {
    switch (status) {
      case 'PRESENT':
        return const AttendanceStatusStyle(AppColors.success, 'Present');
      case 'ABSENT':
        return const AttendanceStatusStyle(AppColors.danger, 'Absent');
      case 'LATE':
        return const AttendanceStatusStyle(AppColors.warning, 'Late');
      case 'HALF_DAY':
        return const AttendanceStatusStyle(AppColors.info, 'Half Day');
      case 'ON_LEAVE':
      case 'LEAVE':
        return const AttendanceStatusStyle(AppColors.accent, 'On Leave');
      case 'HOLIDAY':
        return const AttendanceStatusStyle(Color(0xFF7C3AED), 'Holiday');
      case 'WEEK_OFF':
      case 'WEEKEND':
        return const AttendanceStatusStyle(AppColors.textTertiary, 'Week Off');
      case 'FUTURE':
        return const AttendanceStatusStyle(AppColors.textTertiary, '—');
      default: // NO_RECORD
        return const AttendanceStatusStyle(AppColors.textTertiary, 'No Record');
    }
  }
}

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
    // Two sections, as separate tabs: My Attendance (month ledger) and
    // Check In / Out (the existing punch flow, unchanged).
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: t.bg,
        appBar: SharedAppBar(
          title: 'Attendance',
          subtitle: _buildSubtitle(ctrl),
          bottom: TabBar(
            labelColor: AppColors.accent,
            unselectedLabelColor: t.textSec,
            indicatorColor: AppColors.accent,
            indicatorWeight: 2.5,
            labelStyle: AppTextStyles.buttonMedium,
            unselectedLabelStyle: AppTextStyles.buttonMedium,
            tabs: const [
              Tab(text: 'My Attendance'),
              Tab(text: 'Check In / Out'),
            ],
          ),
        ),
        body: TabBarView(children: [
          const _MyAttendanceTab(),
          _CheckInOutTab(ctrl: ctrl, days: _days, months: _months),
        ]),
      ),
    );
  }

  String _buildSubtitle(AttendanceController ctrl) {
    final now = ctrl.currentTime.value;
    return '${_days[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]} ${now.year}';
  }
}

// ── Check In / Out tab — the existing punch flow, moved verbatim ─────────────
class _CheckInOutTab extends StatelessWidget {
  final AttendanceController ctrl;
  final List<String> days;
  final List<String> months;
  const _CheckInOutTab(
      {required this.ctrl, required this.days, required this.months});

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.to;
    // Pull-to-refresh re-reads today's punch state from the server.
    return RefreshIndicator(
      onRefresh: ctrl.fetchTodayStatus,
      color: AppColors.accent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _ClockCard(ctrl: ctrl, days: days, months: months),
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
      final done = ctrl.hasCheckedOut;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: BoxDecoration(
          gradient: chk
              ? const LinearGradient(
                  colors: [Color(0xFF065F46), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)
              : done
                  ? const LinearGradient(
                      colors: [Color(0xFF1E3A5F), Color(0xFF0E7490)],
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
                          : done
                              ? const Color(0xFF67E8F9)
                              : const Color(0xFF94A3B8),
                      shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(
                  chk
                      ? 'Checked In'
                      : done
                          ? 'Checked Out'
                          : 'Not Checked In',
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
      final done = ctrl.hasCheckedOut;
      final punching = ctrl.isPunching.value;

      // Once the day is closed the button is disabled — previously it flipped
      // back to "Check In", which let the user punch in twice in one day.
      final VoidCallback? action =
          (punching || done) ? null : (chk ? ctrl.checkOut : ctrl.checkIn);

      final LinearGradient gradient = done
          ? const LinearGradient(colors: [Color(0xFF94A3B8), Color(0xFF64748B)])
          : chk
              ? const LinearGradient(
                  colors: [Color(0xFFDC2626), Color(0xFFB91C1C)])
              : const LinearGradient(
                  colors: [Color(0xFF059669), Color(0xFF047857)]);

      final Color glow = done
          ? AppColors.textTertiary
          : chk
              ? AppColors.danger
              : AppColors.success;

      final IconData icon = done
          ? Icons.check_circle_rounded
          : chk
              ? Icons.logout_rounded
              : Icons.login_rounded;

      final String label =
          done ? 'Checked Out' : (chk ? 'Check Out' : 'Check In');

      return GestureDetector(
        onTap: action,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: glow.withOpacity(done ? 0.18 : 0.35),
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
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text(label,
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
// MY ATTENDANCE TAB — month nav + calendar grid + legend + monthly summary
// ═══════════════════════════════════════════════════════════════════════════════
class _MyAttendanceTab extends StatelessWidget {
  const _MyAttendanceTab();

  static const _monthNames = [
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
    // isRegistered guard: TabBarView rebuilds this widget, and a bare
    // Get.put would replace the controller and re-run onInit (refetching)
    // every time the tab is rebuilt.
    final ctrl = Get.isRegistered<MyAttendanceController>()
        ? Get.find<MyAttendanceController>()
        : Get.put(MyAttendanceController());
    final t = ThemeController.to;

    return RefreshIndicator(
      onRefresh: ctrl.load,
      color: AppColors.accent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Month navigation ──────────────────────────────────────────
          Obx(() => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: t.border),
                    boxShadow: t.cardShadow),
                child: Row(children: [
                  _navBtn(
                      icon: Icons.chevron_left_rounded,
                      enabled: ctrl.canGoPrev,
                      onTap: ctrl.prevMonth,
                      t: t),
                  Expanded(
                    child: Text(
                      '${_monthNames[ctrl.month - 1]} ${ctrl.year}',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headingSmall
                          .copyWith(color: t.textPrimary),
                    ),
                  ),
                  _navBtn(
                      icon: Icons.chevron_right_rounded,
                      enabled: ctrl.canGoNext,
                      onTap: ctrl.nextMonth,
                      t: t),
                ]),
              )),
          const SizedBox(height: 14),

          // ── Calendar grid ─────────────────────────────────────────────
          Obx(() {
            if (ctrl.loading.value) {
              return _calendarSkeleton(t);
            }
            if (ctrl.error.value.isNotEmpty && ctrl.ledger.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: t.border)),
                child: Column(children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.danger, size: 40),
                  const SizedBox(height: 10),
                  Text(ctrl.error.value,
                      textAlign: TextAlign.center,
                      style:
                          AppTextStyles.bodySmall.copyWith(color: t.textSec)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                      onPressed: ctrl.load, child: const Text('Retry')),
                ]),
              );
            }
            return _AttendanceCalendarGrid(
                ctrl: ctrl, year: ctrl.year, month: ctrl.month, t: t);
          }),
          const SizedBox(height: 14),

          // ── Legend ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: t.border)),
            child: Wrap(spacing: 14, runSpacing: 8, children: const [
              _LegendDot(status: 'PRESENT'),
              _LegendDot(status: 'ABSENT'),
              _LegendDot(status: 'LATE'),
              _LegendDot(status: 'HALF_DAY'),
              _LegendDot(status: 'ON_LEAVE'),
              _LegendDot(status: 'HOLIDAY'),
              _LegendDot(status: 'WEEK_OFF'),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Monthly summary ───────────────────────────────────────────
          Obx(() {
            final c = ctrl.counts;
            final busy = ctrl.summaryLoading.value;
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
                    Text('Monthly Summary',
                        style: AppTextStyles.headingSmall
                            .copyWith(color: t.textPrimary)),
                    const SizedBox(height: 14),
                    // Primary five — same metrics the web portal shows.
                    Row(children: [
                      _SummaryStat(
                          label: 'Present',
                          value: busy ? '—' : '${c['present']}',
                          color: AppColors.success,
                          t: t),
                      _SummaryStat(
                          label: 'Absent',
                          value: busy ? '—' : '${c['absent']}',
                          color: AppColors.danger,
                          t: t),
                      _SummaryStat(
                          label: 'Late',
                          value: busy ? '—' : '${c['late']}',
                          color: AppColors.warning,
                          t: t),
                      _SummaryStat(
                          label: 'Leave',
                          value: busy ? '—' : '${c['leave']}',
                          color: AppColors.accent,
                          t: t),
                      _SummaryStat(
                          label: 'Half Day',
                          value: busy ? '—' : '${c['halfDay']}',
                          color: AppColors.info,
                          t: t),
                    ]),
                    const SizedBox(height: 14),
                    Divider(color: t.border, height: 1),
                    const SizedBox(height: 14),
                    // Secondary strip — the rest of the monthly-summary payload.
                    Row(children: [
                      _SummaryStat(
                          label: 'Working Days',
                          value:
                              busy ? '—' : ctrl.summaryText('totalWorkingDays'),
                          color: t.textPrimary,
                          t: t),
                      _SummaryStat(
                          label: 'Paid Days',
                          value: busy ? '—' : ctrl.summaryText('paidDays'),
                          color: t.textPrimary,
                          t: t),
                      _SummaryStat(
                          label: 'Payable',
                          value: busy ? '—' : ctrl.summaryText('payableDays'),
                          color: t.textPrimary,
                          t: t),
                      _SummaryStat(
                          label: 'OT Hours',
                          value: busy ? '—' : ctrl.summaryText('overtimeHours'),
                          color: t.textPrimary,
                          t: t),
                      _SummaryStat(
                          label: 'LOP',
                          value: busy ? '—' : ctrl.summaryText('lopDays'),
                          color: t.textPrimary,
                          t: t),
                    ]),
                  ]),
            );
          }),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _navBtn(
      {required IconData icon,
      required bool enabled,
      required VoidCallback onTap,
      required ThemeController t}) {
    return IconButton(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon,
          size: 26,
          color: enabled ? t.textPrimary : t.textTert.withOpacity(0.4)),
      splashRadius: 22,
    );
  }

  Widget _calendarSkeleton(ThemeController t) => Shimmer.fromColors(
        baseColor: t.surface,
        highlightColor: t.surfaceVar,
        child: Container(
          height: 320,
          decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg)),
        ),
      );
}

// ── Legend chip ──────────────────────────────────────────────────────────────
class _LegendDot extends StatelessWidget {
  final String status;
  const _LegendDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.to;
    final s = AttendanceStatusStyle.of(status);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: s.color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 5),
      Text(s.label,
          style:
              AppTextStyles.caption.copyWith(color: t.textSec, fontSize: 11)),
    ]);
  }
}

// ── Calendar grid (Sun–Sat, leading empties) ─────────────────────────────────
class _AttendanceCalendarGrid extends StatelessWidget {
  final MyAttendanceController ctrl;
  final int year, month;
  final ThemeController t;
  const _AttendanceCalendarGrid(
      {required this.ctrl,
      required this.year,
      required this.month,
      required this.t});

  static const _headers = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  Widget build(BuildContext context) {
    // O(1) lookup by day-of-month, same approach as the web grid.
    final byDay = <int, LedgerDay>{};
    for (final d in ctrl.ledger) {
      byDay[d.date.day] = d;
    }

    final daysInMonth = DateTime(year, month + 1, 0).day;
    // weekday: Mon=1..Sun=7 -> Sun=0..Sat=6 for a Sunday-first grid.
    final leading = DateTime(year, month, 1).weekday % 7;

    final now = DateTime.now();
    final cells = <Widget>[];
    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final isToday = now.year == year && now.month == month && now.day == d;
      cells.add(
          _AttendanceDayCell(day: d, entry: byDay[d], isToday: isToday, t: t));
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: t.border),
          boxShadow: t.cardShadow),
      child: Column(children: [
        Row(
            children: _headers
                .map((h) => Expanded(
                      child: Center(
                        child: Text(h,
                            style: AppTextStyles.caption.copyWith(
                                color: t.textTert,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                    ))
                .toList()),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: cells,
        ),
      ]),
    );
  }
}

// ── One day square ───────────────────────────────────────────────────────────
class _AttendanceDayCell extends StatelessWidget {
  final int day;
  final LedgerDay? entry;
  final bool isToday;
  final ThemeController t;
  const _AttendanceDayCell(
      {required this.day,
      required this.entry,
      required this.isToday,
      required this.t});

  @override
  Widget build(BuildContext context) {
    final status = entry?.status ?? 'NO_RECORD';
    final isFuture = status == 'FUTURE';
    final isBlank = status == 'NO_RECORD' || isFuture;
    final s = AttendanceStatusStyle.of(status);

    // Blank days (no record / future) get no fill — only recorded or
    // explicitly-derived states are coloured, matching the web grid.
    final bg = isBlank ? t.surfaceVar : s.color.withOpacity(0.14);
    final fg = isFuture
        ? t.textTert.withOpacity(0.5)
        : isBlank
            ? t.textSec
            : s.color;

    return GestureDetector(
      onTap:
          entry?.recorded == true ? () => _showDetail(context, entry!) : null,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isToday ? AppColors.accent : Colors.transparent,
            width: isToday ? 2 : 0,
          ),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$day',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                  color: fg)),
          if (!isBlank) ...[
            const SizedBox(height: 2),
            Container(
                width: 14,
                height: 3,
                decoration: BoxDecoration(
                    color: s.color, borderRadius: BorderRadius.circular(2))),
          ],
        ]),
      ),
    );
  }

  void _showDetail(BuildContext context, LedgerDay e) {
    final t = ThemeController.to;
    final s = AttendanceStatusStyle.of(e.status);
    String fmt(String? iso) {
      if (iso == null) return '--:--';
      final d = DateTime.tryParse(iso)?.toLocal();
      if (d == null) return '--:--';
      final h12 =
          (d.hour % 12 == 0 ? 12 : d.hour % 12).toString().padLeft(2, '0');
      return '$h12:${d.minute.toString().padLeft(2, '0')} '
          '${d.hour >= 12 ? 'PM' : 'AM'}';
    }

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            SizedBox(
                width: 120,
                child: Text(label,
                    style: AppTextStyles.caption.copyWith(color: t.textTert))),
            Expanded(
                child: Text(value,
                    style: AppTextStyles.bodySmall.copyWith(
                        color: t.textPrimary, fontWeight: FontWeight.w500))),
          ]),
        );

    Get.bottomSheet(
      Container(
        padding: EdgeInsets.fromLTRB(
            20, 14, 20, 20 + MediaQuery.of(context).viewPadding.bottom),
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
          const SizedBox(height: 18),
          Row(children: [
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: s.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full)),
                child: Text(s.label,
                    style: AppTextStyles.caption.copyWith(
                        color: s.color, fontWeight: FontWeight.w700))),
            const Spacer(),
            Text(DateFormat('EEE, d MMM yyyy').format(e.date),
                style: AppTextStyles.caption.copyWith(color: t.textSec)),
          ]),
          const SizedBox(height: 18),
          row('Check In', fmt(e.punchInIst)),
          row('Check Out', fmt(e.punchOutIst)),
          row('Working Hours',
              '${(e.workingMinutes ~/ 60)}h ${(e.workingMinutes % 60)}m'),
          if (e.overtimeMinutes > 0)
            row('Overtime',
                '${(e.overtimeMinutes ~/ 60)}h ${(e.overtimeMinutes % 60)}m'),
          if ((e.day?['punchInSource'] ?? '').toString().isNotEmpty)
            row('Source', e.day!['punchInSource'].toString()),
          if ((e.day?['remarks'] ?? '').toString().isNotEmpty)
            row('Remarks', e.day!['remarks'].toString()),
          const SizedBox(height: 4),
        ]),
      ),
    );
  }
}
