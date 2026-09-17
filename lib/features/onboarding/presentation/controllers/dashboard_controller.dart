import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/employee_models.dart';
import '../../data/employee_api.dart';

/// Workforce stats parsed from `data.workforce` in the dashboard summary API.
class WorkforceSummary {
  final int totalEmployees, working, deployed, bench;
  final double benchRatio;
  final int pendingOnboarding, rejected, deactivated, pendingSalarySetup;
  final int onProbation, newJoinersThisMonth, exitsThisMonth;

  WorkforceSummary({
    required this.totalEmployees,
    required this.working,
    required this.deployed,
    required this.bench,
    required this.benchRatio,
    required this.pendingOnboarding,
    required this.rejected,
    required this.deactivated,
    required this.pendingSalarySetup,
    required this.onProbation,
    required this.newJoinersThisMonth,
    required this.exitsThisMonth,
  });

  int get unassigned => bench;
  double get unassignedPct =>
      totalEmployees > 0 ? (bench / totalEmployees * 100) : 0;

  factory WorkforceSummary.fromJson(Map<String, dynamic> j) => WorkforceSummary(
        totalEmployees: j['totalEmployees'] ?? 0,
        working: j['working'] ?? 0,
        deployed: j['deployed'] ?? 0,
        bench: j['bench'] ?? 0,
        benchRatio: (j['benchRatio'] ?? 0).toDouble(),
        pendingOnboarding: j['pendingOnboarding'] ?? 0,
        rejected: j['rejected'] ?? 0,
        deactivated: j['deactivated'] ?? 0,
        pendingSalarySetup: j['pendingSalarySetup'] ?? 0,
        onProbation: j['onProbation'] ?? 0,
        newJoinersThisMonth: j['newJoinersThisMonth'] ?? 0,
        exitsThisMonth: j['exitsThisMonth'] ?? 0,
      );
}

/// Recent onboarding entry from `data.recentOnboarding`.
class RecentOnboardingEntry {
  final int employeeId;
  final String name, status;
  final String? createdAt, rejectionReason;

  RecentOnboardingEntry(
      {required this.employeeId,
      required this.name,
      required this.status,
      this.createdAt,
      this.rejectionReason});

  factory RecentOnboardingEntry.fromJson(Map<String, dynamic> j) =>
      RecentOnboardingEntry(
        employeeId: j['employeeId'] ?? 0,
        name: j['name'] ?? j['fullName'] ?? '',
        status: j['status'] ?? '',
        createdAt: j['createdAt'],
        rejectionReason: j['rejectionReason'],
      );
}

class DashboardController extends GetxController {
  final loading = false.obs;
  final error = ''.obs;
  final workforce = Rxn<WorkforceSummary>();
  final recentOnboarding = <RecentOnboardingEntry>[].obs;
  final pendingCount = 0.obs;
  final supervisorMetrics = Rxn<SupervisorMetrics>();
  final workforceStats = Rxn<WorkforceStats>();
  final pendingApprovals = <dynamic>[].obs;

  final _api = EmployeeApi();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    loading.value = true;
    error.value = '';
    try {
      final summaryData = await _api.getDashboardSummary();
      final payload = summaryData['data'] ?? summaryData;
      if (payload is Map<String, dynamic>) {
        // Workforce
        if (payload['workforce'] != null) {
          workforce.value = WorkforceSummary.fromJson(payload['workforce']);
          final w = payload['workforce'];
          workforceStats.value = WorkforceStats(
              working: w['working'] ?? 0,
              deployed: w['deployed'] ?? 0,
              bench: w['bench'] ?? 0,
              benchRatio: (w['benchRatio'] ?? 0).toDouble());
        }
        // Supervisor metrics (array in real API)
        if (payload['supervisorMetrics'] is List) {
          final list = payload['supervisorMetrics'] as List;
          if (list.isNotEmpty)
            supervisorMetrics.value = SupervisorMetrics.fromJson(list.first);
        } else if (payload['supervisorMetrics'] is Map) {
          supervisorMetrics.value =
              SupervisorMetrics.fromJson(payload['supervisorMetrics']);
        }
        // Pending approvals
        if (payload['pendingApprovals'] is Map) {
          final c = (payload['pendingApprovals'] as Map)['count'] ?? 0;
          pendingCount.value = c;
          pendingApprovals.value = List.filled(c, 1);
        }
        // Recent onboarding
        if (payload['recentOnboarding'] is List) {
          recentOnboarding.value = (payload['recentOnboarding'] as List)
              .map((e) => RecentOnboardingEntry.fromJson(e))
              .toList();
        }
      }
    } on DioException catch (e) {
      error.value = ApiFailure.fromDioException(e).message;
    } catch (e) {
      error.value = 'Failed to load dashboard: $e';
    } finally {
      loading.value = false;
    }
  }
}
