import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/employee_models.dart';
import '../../data/employee_api.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CONTROLLER — real API calls to GET /api/v1/dashboard/summary +
//              GET /api/v1/employees/my-submissions +
//              GET /api/v1/employees/onboarding/pending
// ═══════════════════════════════════════════════════════════════════════════════
class DashboardController extends GetxController {
  final loading = false.obs;
  final error = ''.obs;
  final supervisorMetrics = Rxn<SupervisorMetrics>();
  final workforceStats = Rxn<WorkforceStats>();
  final recentOnboarding = <RecentOnboardingRow>[].obs;
  final pendingApprovals = <dynamic>[].obs;

  final _api = EmployeeApi();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  /// Fetch all dashboard data from real APIs.
  Future<void> load() async {
    loading.value = true;
    error.value = '';

    try {
      // 1) Dashboard summary — GET /api/v1/dashboard/summary (→ core :8081)
      //    Response shape: ApiResponse { data: DashboardSummaryResponse }
      //    The DashboardSummaryResponse contains:
      //      supervisorMetrics, workforceStats, and more — all optional blocks.
      final summaryData = await _api.getDashboardSummary();
      final payload = summaryData['data'] ?? summaryData;

      // Parse supervisor metrics block (if present)
      if (payload['supervisorMetrics'] != null) {
        supervisorMetrics.value = SupervisorMetrics.fromJson(
          payload['supervisorMetrics'] as Map<String, dynamic>,
        );
      }

      // Parse workforce stats block (if present)
      if (payload['workforceStats'] != null) {
        workforceStats.value = WorkforceStats.fromJson(
          payload['workforceStats'] as Map<String, dynamic>,
        );
      }

      // 2) Recent onboarding (my submissions) — GET /api/v1/employees/my-submissions
      try {
        final submissions = await _api.getMySubmissions();
        recentOnboarding.value = submissions
            .map((e) => RecentOnboardingRow.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        // Non-critical — dashboard still shows other data
        recentOnboarding.clear();
      }

      // 3) Pending approvals count — GET /api/v1/employees/onboarding/pending
      try {
        final pending = await _api.getPendingOnboarding();
        pendingApprovals.value = pending;
      } catch (_) {
        pendingApprovals.clear();
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data as Map)['message'] ?? e.message
          : e.message ?? 'Failed to load dashboard';
      error.value = msg.toString();
    } catch (e) {
      error.value = 'Failed to load dashboard: $e';
    } finally {
      loading.value = false;
    }
  }
}
