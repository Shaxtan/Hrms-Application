import 'package:get/get.dart';

// ── Models ────────────────────────────────────────────────────────────────────
class SupervisorMetrics {
  final int supervisorEmployeeId;
  final int onboarded;
  final int approved;
  final int rejected;
  final double approvalRate;
  final int managedWorkforce;
  final List<String> clientNames;
  final List<String> branchNames;

  SupervisorMetrics({
    required this.supervisorEmployeeId,
    required this.onboarded,
    required this.approved,
    required this.rejected,
    required this.approvalRate,
    required this.managedWorkforce,
    this.clientNames = const [],
    this.branchNames = const [],
  });

  int get pending => (onboarded - approved - rejected).clamp(0, onboarded);
}

class WorkforceStats {
  final int working;
  final int deployed;
  final int bench;
  final double benchRatio;

  WorkforceStats({
    required this.working,
    required this.deployed,
    required this.bench,
    required this.benchRatio,
  });
}

class RecentOnboardingRow {
  final int employeeId;
  final String fullName;
  final String status;
  final String? employmentType;
  final String? joiningDate;
  final String? branch;
  final String? client;

  RecentOnboardingRow({
    required this.employeeId,
    required this.fullName,
    required this.status,
    this.employmentType,
    this.joiningDate,
    this.branch,
    this.client,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONTROLLER — pure mock, zero API calls
// ═══════════════════════════════════════════════════════════════════════════════
class DashboardController extends GetxController {
  final loading           = false.obs;
  final error             = ''.obs;
  final supervisorMetrics = Rxn<SupervisorMetrics>();
  final workforceStats    = Rxn<WorkforceStats>();
  final recentOnboarding  = <RecentOnboardingRow>[].obs;
  final pendingApprovals  = <dynamic>[].obs;

  @override
  void onInit() {
    super.onInit();
    _loadMockData();
  }

  void _loadMockData() {
    supervisorMetrics.value = SupervisorMetrics(
      supervisorEmployeeId: 1,
      onboarded:        47,
      approved:         38,
      rejected:          4,
      approvalRate:      0.809,
      managedWorkforce: 83,
      clientNames: ['Acme Corp', 'Globex'],
      branchNames: ['Mumbai HQ', 'Pune Branch'],
    );

    workforceStats.value = WorkforceStats(
      working:    83,
      deployed:   71,
      bench:      12,
      benchRatio: 0.145,
    );

    recentOnboarding.value = [
      RecentOnboardingRow(
        employeeId: 101, fullName: 'Priya Sharma',
        status: 'PENDING_APPROVAL', employmentType: 'CONTRACT',
        joiningDate: '2026-09-01', branch: 'Mumbai HQ', client: 'Acme Corp',
      ),
      RecentOnboardingRow(
        employeeId: 102, fullName: 'Rahul Verma',
        status: 'ACTIVE', employmentType: 'FULL_TIME',
        joiningDate: '2026-08-15', branch: 'Pune Branch', client: 'Globex',
      ),
      RecentOnboardingRow(
        employeeId: 103, fullName: 'Anita Joshi',
        status: 'PENDING_APPROVAL', employmentType: 'NAPS',
        joiningDate: '2026-09-05', branch: 'Mumbai HQ', client: 'Acme Corp',
      ),
      RecentOnboardingRow(
        employeeId: 104, fullName: 'Deepak Kumar',
        status: 'ACTIVE', employmentType: 'CONTRACT',
        joiningDate: '2026-08-20', branch: 'Pune Branch', client: 'Globex',
      ),
      RecentOnboardingRow(
        employeeId: 105, fullName: 'Sneha Patil',
        status: 'ACTIVE', employmentType: 'INTERN',
        joiningDate: '2026-08-10', branch: 'Nashik Office', client: 'Acme Corp',
      ),
    ];

    // 3 pending approvals for the pending tile count
    pendingApprovals.value = [1, 2, 3];
  }

  // Called by retry button — just reload mock
  Future<void> load() async {
    loading.value = true;
    await Future.delayed(const Duration(milliseconds: 500));
    _loadMockData();
    loading.value = false;
  }
}