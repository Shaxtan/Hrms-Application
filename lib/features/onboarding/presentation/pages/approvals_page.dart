import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/widgets/shared_widgets.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════════════════════════
class ApprovalItem {
  final int id;
  final String subject, type, status, action, submitted;
  final String? reason, employmentType, branch, client;

  const ApprovalItem({
    required this.id,
    required this.subject,
    required this.type,
    required this.status,
    required this.action,
    required this.submitted,
    this.reason,
    this.employmentType,
    this.branch,
    this.client,
  });

  /// Parse a pending onboarding record from the API.
  factory ApprovalItem.fromOnboardingJson(Map<String, dynamic> j) {
    final name = j['fullName'] ??
        '${j['firstName'] ?? ''} ${j['lastName'] ?? ''}'.trim();
    return ApprovalItem(
      id: j['employeeId'] ?? j['id'] ?? 0,
      subject: name.isNotEmpty ? name : 'Employee #${j['id']}',
      type: 'Onboarding',
      status: _mapStatus(j['status']),
      action: _mapAction(j['status']),
      submitted: j['joiningDate'] ?? j['createdAt'] ?? '',
      employmentType: j['employmentType'],
      branch: j['branch'],
      client: j['client'],
      reason: j['rejectionReason'] ?? j['reason'],
    );
  }

  /// Parse a leave approval record.
  factory ApprovalItem.fromLeaveJson(Map<String, dynamic> j) {
    final empName = j['employeeName'] ?? j['fullName'] ?? 'Employee';
    final leaveType = j['leaveTypeName'] ?? j['leaveType'] ?? 'Leave';
    return ApprovalItem(
      id: j['id'] ?? j['requestId'] ?? 0,
      subject: empName,
      type: 'Leave ($leaveType)',
      status: _mapStatus(j['status']),
      action: _mapAction(j['status']),
      submitted: j['startDate'] ?? j['appliedOn'] ?? j['createdAt'] ?? '',
      reason: j['remarks'] ?? j['reason'],
      branch: j['branch'],
      client: j['client'],
    );
  }

  /// Parse an attendance regularisation record.
  factory ApprovalItem.fromRegularisationJson(Map<String, dynamic> j) {
    final empName = j['employeeName'] ?? j['fullName'] ?? 'Employee';
    return ApprovalItem(
      id: j['id'] ?? 0,
      subject: empName,
      type: 'Regularisation',
      status: _mapStatus(j['status']),
      action: _mapAction(j['status']),
      submitted: j['attendanceDate'] ?? j['createdAt'] ?? '',
      reason: j['remarks'] ?? j['reason'],
    );
  }

  /// Parse an approval history record (from payroll cross-flow history).
  factory ApprovalItem.fromHistoryJson(Map<String, dynamic> j) {
    return ApprovalItem(
      id: j['id'] ?? j['requestId'] ?? 0,
      subject: j['employeeName'] ?? j['subject'] ?? '',
      type: j['flowType'] ?? j['type'] ?? 'Request',
      status: _mapStatus(j['status']),
      action: j['action'] ?? _mapAction(j['status']),
      submitted: j['submittedAt'] ?? j['createdAt'] ?? '',
      reason: j['remarks'] ?? j['reason'],
      branch: j['branch'],
      client: j['client'],
      employmentType: j['employmentType'],
    );
  }

  static String _mapStatus(String? s) {
    if (s == null) return 'PENDING';
    final upper = s.toUpperCase();
    if (upper.contains('APPROVED') || upper == 'ACTIVE') return 'APPROVED';
    if (upper.contains('REJECTED')) return 'REJECTED';
    if (upper.contains('CANCELLED')) return 'CANCELLED';
    return 'PENDING';
  }

  static String _mapAction(String? s) {
    final mapped = _mapStatus(s);
    switch (mapped) {
      case 'APPROVED':
        return 'Approved';
      case 'REJECTED':
        return 'Rejected';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return 'Submitted';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONTROLLER — real API
// ═══════════════════════════════════════════════════════════════════════════════
class ApprovalsController extends GetxController {
  final statusFilter = 'ALL'.obs;
  final typeFilter = 'ALL'.obs;
  final isLoading = false.obs;
  final errorMsg = ''.obs;
  final _items = <ApprovalItem>[].obs;

  final Dio _dio = ApiClient.instance;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  List<ApprovalItem> get filtered => _items.where((i) {
        final okStatus =
            statusFilter.value == 'ALL' || i.status == statusFilter.value;
        final okType =
            typeFilter.value == 'ALL' || i.type.contains(typeFilter.value);
        return okStatus && okType;
      }).toList();

  int get pendingCount => _items.where((i) => i.status == 'PENDING').length;

  /// Available type filter values (derived from loaded data).
  List<String> get availableTypes {
    final types = _items
        .map((i) {
          if (i.type.startsWith('Leave')) return 'Leave';
          return i.type;
        })
        .toSet()
        .toList()
      ..sort();
    return ['ALL', ...types];
  }

  /// Load all approval data from real APIs.
  Future<void> load() async {
    isLoading.value = true;
    errorMsg.value = '';
    final allItems = <ApprovalItem>[];

    try {
      // 1) Pending onboarding — GET /api/v1/employees/onboarding/pending (→ core)
      try {
        final res = await _dio.get('/api/v1/employees/onboarding/pending');
        final list = (res.data?['data'] as List?) ?? [];
        allItems.addAll(list.map(
            (e) => ApprovalItem.fromOnboardingJson(e as Map<String, dynamic>)));
      } catch (_) {}

      // 2) Pending leave approvals — GET /api/v1/leave-requests/pending-approvals (→ payroll)
      try {
        final res = await _dio.get('/api/v1/leave-requests/pending-approvals');
        final list = (res.data?['data'] as List?) ?? [];
        allItems.addAll(list
            .map((e) => ApprovalItem.fromLeaveJson(e as Map<String, dynamic>)));
      } catch (_) {}

      // 3) Pending regularisations — GET /api/v1/attendance/regularisation/pending-approvals (→ payroll)
      try {
        final res = await _dio
            .get('/api/v1/attendance/regularisation/pending-approvals');
        final list = (res.data?['data'] as List?) ?? [];
        allItems.addAll(list.map((e) =>
            ApprovalItem.fromRegularisationJson(e as Map<String, dynamic>)));
      } catch (_) {}

      // 4) Approval history (cross-flow) — GET /api/v1/approvals/my-history (→ payroll)
      try {
        final res = await _dio.get('/api/v1/approvals/my-history');
        final list = (res.data?['data'] as List?) ?? [];
        allItems.addAll(list.map(
            (e) => ApprovalItem.fromHistoryJson(e as Map<String, dynamic>)));
      } catch (_) {}

      // 5) My onboarding submissions — GET /api/v1/employees/my-submissions (→ core)
      try {
        final res = await _dio.get('/api/v1/employees/my-submissions');
        final list = (res.data?['data'] as List?) ?? [];
        // Only add submissions that aren't already in the list (by id+type)
        final existingOnboardingIds = allItems
            .where((i) => i.type == 'Onboarding')
            .map((i) => i.id)
            .toSet();
        for (final e in list) {
          final parsed =
              ApprovalItem.fromOnboardingJson(e as Map<String, dynamic>);
          if (!existingOnboardingIds.contains(parsed.id)) {
            allItems.add(parsed);
          }
        }
      } catch (_) {}

      _items.value = allItems;
    } on DioException catch (e) {
      errorMsg.value = ApiFailure.fromDioException(e).message;
    } catch (e) {
      errorMsg.value = 'Failed to load approvals: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// Approve an onboarding hire — POST /api/v1/employees/{id}/approve
  Future<void> approve(int id) async {
    try {
      await _dio.post('/api/v1/employees/$id/approve', data: {});
      // Update local state
      final idx =
          _items.indexWhere((i) => i.id == id && i.type == 'Onboarding');
      if (idx != -1) {
        final old = _items[idx];
        _items[idx] = ApprovalItem(
          id: old.id,
          subject: old.subject,
          type: old.type,
          status: 'APPROVED',
          action: 'Approved',
          submitted: old.submitted,
          employmentType: old.employmentType,
          branch: old.branch,
          client: old.client,
        );
      }
      Get.snackbar('Approved', 'Onboarding approved successfully.',
          backgroundColor: AppColors.success,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16));
    } on DioException catch (e) {
      Get.snackbar('Error', ApiFailure.fromDioException(e).message,
          backgroundColor: AppColors.danger,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16));
    }
  }

  /// Reject an onboarding hire — POST /api/v1/employees/{id}/reject
  Future<void> reject(int id, String reason) async {
    try {
      await _dio.post('/api/v1/employees/$id/reject',
          data: {'reason': reason.trim().isEmpty ? null : reason.trim()});
      final idx =
          _items.indexWhere((i) => i.id == id && i.type == 'Onboarding');
      if (idx != -1) {
        final old = _items[idx];
        _items[idx] = ApprovalItem(
          id: old.id,
          subject: old.subject,
          type: old.type,
          status: 'REJECTED',
          action: 'Rejected',
          submitted: old.submitted,
          reason: reason.trim().isEmpty ? 'No reason provided' : reason.trim(),
          employmentType: old.employmentType,
          branch: old.branch,
          client: old.client,
        );
      }
      Get.snackbar('Rejected', 'Onboarding rejected.',
          backgroundColor: AppColors.danger,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16));
    } on DioException catch (e) {
      Get.snackbar('Error', ApiFailure.fromDioException(e).message,
          backgroundColor: AppColors.danger,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16));
    }
  }

  /// Approve a leave request — POST /api/v1/leave-requests/{id}/approve
  Future<void> approveLeave(int id) async {
    try {
      await _dio
          .post('/api/v1/leave-requests/$id/approve', data: {'remarks': ''});
      final idx =
          _items.indexWhere((i) => i.id == id && i.type.contains('Leave'));
      if (idx != -1) {
        final old = _items[idx];
        _items[idx] = ApprovalItem(
          id: old.id,
          subject: old.subject,
          type: old.type,
          status: 'APPROVED',
          action: 'Approved',
          submitted: old.submitted,
          branch: old.branch,
          client: old.client,
        );
      }
      Get.snackbar('Approved', 'Leave request approved.',
          backgroundColor: AppColors.success,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16));
    } on DioException catch (e) {
      Get.snackbar('Error', ApiFailure.fromDioException(e).message,
          backgroundColor: AppColors.danger,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16));
    }
  }

  /// Reject a leave request — POST /api/v1/leave-requests/{id}/reject
  Future<void> rejectLeave(int id, String remarks) async {
    try {
      await _dio.post('/api/v1/leave-requests/$id/reject',
          data: {'remarks': remarks});
      final idx =
          _items.indexWhere((i) => i.id == id && i.type.contains('Leave'));
      if (idx != -1) {
        final old = _items[idx];
        _items[idx] = ApprovalItem(
          id: old.id,
          subject: old.subject,
          type: old.type,
          status: 'REJECTED',
          action: 'Rejected',
          submitted: old.submitted,
          reason: remarks,
          branch: old.branch,
          client: old.client,
        );
      }
      Get.snackbar('Rejected', 'Leave request rejected.',
          backgroundColor: AppColors.danger,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16));
    } on DioException catch (e) {
      Get.snackbar('Error', ApiFailure.fromDioException(e).message,
          backgroundColor: AppColors.danger,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16));
    }
  }

  /// Approve a regularisation — POST /api/v1/attendance/regularisation/{id}/approve
  Future<void> approveRegularisation(int id) async {
    try {
      await _dio.post('/api/v1/attendance/regularisation/$id/approve');
      final idx =
          _items.indexWhere((i) => i.id == id && i.type == 'Regularisation');
      if (idx != -1) {
        final old = _items[idx];
        _items[idx] = ApprovalItem(
          id: old.id,
          subject: old.subject,
          type: old.type,
          status: 'APPROVED',
          action: 'Approved',
          submitted: old.submitted,
        );
      }
      Get.snackbar('Approved', 'Regularisation approved.',
          backgroundColor: AppColors.success,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16));
    } on DioException catch (e) {
      Get.snackbar('Error', ApiFailure.fromDioException(e).message,
          backgroundColor: AppColors.danger,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16));
    }
  }

  /// Reject a regularisation — POST /api/v1/attendance/regularisation/{id}/reject
  Future<void> rejectRegularisation(int id, String remarks) async {
    try {
      await _dio.post('/api/v1/attendance/regularisation/$id/reject',
          data: {},
          queryParameters: remarks.isNotEmpty ? {'remarks': remarks} : null);
      final idx =
          _items.indexWhere((i) => i.id == id && i.type == 'Regularisation');
      if (idx != -1) {
        final old = _items[idx];
        _items[idx] = ApprovalItem(
          id: old.id,
          subject: old.subject,
          type: old.type,
          status: 'REJECTED',
          action: 'Rejected',
          submitted: old.submitted,
          reason: remarks,
        );
      }
      Get.snackbar('Rejected', 'Regularisation rejected.',
          backgroundColor: AppColors.danger,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16));
    } on DioException catch (e) {
      Get.snackbar('Error', ApiFailure.fromDioException(e).message,
          backgroundColor: AppColors.danger,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16));
    }
  }

  /// Dispatch approve to the right API based on approval type
  void approveItem(ApprovalItem item) {
    if (item.type == 'Onboarding') {
      approve(item.id);
    } else if (item.type.contains('Leave')) {
      approveLeave(item.id);
    } else if (item.type == 'Regularisation') {
      approveRegularisation(item.id);
    }
  }

  /// Dispatch reject to the right API based on approval type
  void rejectItem(ApprovalItem item, String reason) {
    if (item.type == 'Onboarding') {
      reject(item.id, reason);
    } else if (item.type.contains('Leave')) {
      rejectLeave(item.id, reason);
    } else if (item.type == 'Regularisation') {
      rejectRegularisation(item.id, reason);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAGE
// ═══════════════════════════════════════════════════════════════════════════════
class ApprovalsPage extends StatelessWidget {
  const ApprovalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(ApprovalsController(), tag: 'approvals');
    return Obx(() {
      final t = ThemeController.to;
      return Scaffold(
        backgroundColor: t.bg,
        appBar: SharedAppBar(
          title: 'Approvals',
          subtitle: 'History',
          extraActions: [
            Obx(() => ctrl.pendingCount > 0
                ? Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(AppRadius.full)),
                    child: Text('${ctrl.pendingCount} pending',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600)))
                : const SizedBox.shrink()),
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: t.textSec, size: 20),
              onPressed: () => ctrl.load(),
            ),
          ],
        ),
        body: Column(children: [
          _FilterBar(ctrl: ctrl, t: t),
          Expanded(child: _ItemList(ctrl: ctrl, t: t)),
        ]),
      );
    });
  }
}

// ── Filter Bar ─────────────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  final ApprovalsController ctrl;
  final ThemeController t;
  const _FilterBar({required this.ctrl, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: t.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _SChip(
                ctrl: ctrl,
                t: t,
                value: 'ALL',
                label: 'All statuses',
                color: null),
            const SizedBox(width: 8),
            _SChip(
                ctrl: ctrl,
                t: t,
                value: 'PENDING',
                label: 'Pending',
                color: AppColors.warning),
            const SizedBox(width: 8),
            _SChip(
                ctrl: ctrl,
                t: t,
                value: 'APPROVED',
                label: 'Approved',
                color: AppColors.success),
            const SizedBox(width: 8),
            _SChip(
                ctrl: ctrl,
                t: t,
                value: 'REJECTED',
                label: 'Rejected',
                color: AppColors.danger),
          ]),
        ),
        const SizedBox(height: 10),
        Obx(() => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                  children: ctrl.availableTypes
                      .map(
                        (type) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _TChip(
                              ctrl: ctrl,
                              t: t,
                              value: type,
                              label: type == 'ALL' ? 'All types' : type),
                        ),
                      )
                      .toList()),
            )),
      ]),
    );
  }
}

class _SChip extends StatelessWidget {
  final ApprovalsController ctrl;
  final ThemeController t;
  final String value, label;
  final Color? color;
  const _SChip(
      {required this.ctrl,
      required this.t,
      required this.value,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final sel = ctrl.statusFilter.value == value;
      final activeColor = color ?? AppColors.accent;
      return GestureDetector(
        onTap: () => ctrl.statusFilter.value = value,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: sel ? activeColor.withOpacity(0.12) : t.surfaceVar,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
                color: sel ? activeColor : t.border, width: sel ? 1.5 : 1),
          ),
          child: Text(label,
              style: AppTextStyles.caption.copyWith(
                  color: sel ? activeColor : t.textSec,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
        ),
      );
    });
  }
}

class _TChip extends StatelessWidget {
  final ApprovalsController ctrl;
  final ThemeController t;
  final String value, label;
  const _TChip(
      {required this.ctrl,
      required this.t,
      required this.value,
      required this.label});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final sel = ctrl.typeFilter.value == value;
      return GestureDetector(
        onTap: () => ctrl.typeFilter.value = value,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: sel ? AppColors.accentLight : t.surfaceVar,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(
                color: sel ? AppColors.accent : t.border, width: sel ? 1.5 : 1),
          ),
          child: Text(label,
              style: AppTextStyles.caption.copyWith(
                  color: sel ? AppColors.accent : t.textSec,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
        ),
      );
    });
  }
}

// ── Item List ──────────────────────────────────────────────────────────────────
class _ItemList extends StatelessWidget {
  final ApprovalsController ctrl;
  final ThemeController t;
  const _ItemList({required this.ctrl, required this.t});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (ctrl.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (ctrl.errorMsg.value.isNotEmpty) {
        return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 48),
          const SizedBox(height: 12),
          Text(ctrl.errorMsg.value,
              style: AppTextStyles.bodySmall.copyWith(color: t.textSec),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(
              onPressed: () => ctrl.load(), child: const Text('Retry')),
        ]));
      }
      final items = ctrl.filtered;
      if (items.isEmpty) {
        return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inbox_rounded, color: t.textTert, size: 48),
          const SizedBox(height: 12),
          Text('No records found',
              style: AppTextStyles.headingSmall.copyWith(color: t.textPrimary)),
          const SizedBox(height: 6),
          Text('Try adjusting your filters',
              style: AppTextStyles.bodySmall.copyWith(color: t.textSec)),
        ]));
      }
      return RefreshIndicator(
        onRefresh: () => ctrl.load(),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) =>
              _ApprovalCard(item: items[i], ctrl: ctrl, t: t),
        ),
      );
    });
  }
}

class _ApprovalCard extends StatelessWidget {
  final ApprovalItem item;
  final ApprovalsController ctrl;
  final ThemeController t;
  const _ApprovalCard(
      {required this.item, required this.ctrl, required this.t});

  static const _typeColors = <String, (Color, Color, String)>{
    'CONTRACT': (AppColors.accentLight, AppColors.accent, 'Contractual'),
    'NAPS': (AppColors.infoLight, AppColors.info, 'NAPS'),
    'FULL_TIME': (AppColors.successLight, AppColors.success, 'Staff'),
    'INTERN': (AppColors.warningLight, AppColors.warning, 'Intern'),
  };

  @override
  Widget build(BuildContext context) {
    final initials = item.subject
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0] : '')
        .join()
        .toUpperCase();
    final tc = _typeColors[item.employmentType] ??
        (t.surfaceVar, t.textSec, item.employmentType ?? '');

    return Container(
      decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: t.border),
          boxShadow: t.cardShadow),
      child: Column(children: [
        // Header
        Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.accentLight,
                  child: Text(initials,
                      style: AppTextStyles.headingSmall
                          .copyWith(color: AppColors.accent, fontSize: 13))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Expanded(
                          child: Text(item.subject,
                              style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: t.textPrimary))),
                      StatusBadge(status: item.status),
                    ]),
                    const SizedBox(height: 5),
                    Row(children: [
                      _pill(item.type, t.surfaceVar, t.textPrimary, t.border),
                      if (item.employmentType != null &&
                          item.employmentType!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _pill(tc.$3, tc.$1, tc.$2, null),
                      ],
                    ]),
                  ])),
            ])),
        // Meta
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          decoration: BoxDecoration(
              color: t.surfaceVar,
              borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppRadius.lg),
                  bottomRight: Radius.circular(AppRadius.lg))),
          child: Column(children: [
            Row(children: [
              _metaCell('YOUR ACTION', item.action, t),
              _metaCell('SUBMITTED', item.submitted, t),
              _metaCell('REASON', item.reason ?? '—', t),
            ]),
            if (item.client != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.business_outlined, size: 11, color: t.textTert),
                const SizedBox(width: 4),
                Text(item.client!,
                    style: AppTextStyles.caption
                        .copyWith(fontSize: 11, color: t.textSec)),
                if (item.branch != null) ...[
                  Text(' · ', style: AppTextStyles.caption),
                  Icon(Icons.location_on_outlined, size: 11, color: t.textTert),
                  const SizedBox(width: 2),
                  Text(item.branch!,
                      style: AppTextStyles.caption
                          .copyWith(fontSize: 11, color: t.textSec)),
                ],
              ]),
            ],
            if (item.status == 'PENDING') ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: GestureDetector(
                  onTap: () => _showRejectSheet(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                            color: AppColors.danger.withOpacity(0.3))),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.close_rounded,
                              color: AppColors.danger, size: 15),
                          const SizedBox(width: 5),
                          Text('Reject',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.w600)),
                        ]),
                  ),
                )),
                const SizedBox(width: 10),
                Expanded(
                    child: GestureDetector(
                  onTap: () => ctrl.approveItem(item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                            color: AppColors.success.withOpacity(0.3))),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_rounded,
                              color: AppColors.success, size: 15),
                          const SizedBox(width: 5),
                          Text('Approve',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600)),
                        ]),
                  ),
                )),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _pill(String label, Color bg, Color fg, Color? border) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: border != null ? Border.all(color: border) : null),
        child: Text(label,
            style: AppTextStyles.caption.copyWith(
                color: fg, fontWeight: FontWeight.w500, fontSize: 11)),
      );

  Widget _metaCell(String label, String value, ThemeController t) => Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: AppTextStyles.caption.copyWith(
                fontSize: 9,
                color: t.textTert,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value,
            style: AppTextStyles.bodySmall
                .copyWith(fontSize: 12, color: t.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ]));

  void _showRejectSheet(BuildContext context) {
    final reasonCtrl = TextEditingController();
    Get.bottomSheet(
      isScrollControlled: true,
      Obx(() {
        final t = ThemeController.to;
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            decoration: BoxDecoration(
                color: t.surface,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: t.border,
                      borderRadius: BorderRadius.circular(100))),
              const SizedBox(height: 20),
              Text('Reject ${item.type}',
                  style: AppTextStyles.headingMedium
                      .copyWith(color: t.textPrimary)),
              const SizedBox(height: 6),
              Text('Provide a reason for rejection.',
                  style: AppTextStyles.bodySmall.copyWith(color: t.textSec),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                autofocus: true,
                style: AppTextStyles.bodyMedium.copyWith(color: t.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Reason for rejection…',
                  hintStyle:
                      AppTextStyles.bodySmall.copyWith(color: t.textTert),
                  filled: true,
                  fillColor: t.surfaceVar,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: t.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: t.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.danger, width: 2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                    child: OutlinedButton(
                  onPressed: Get.back,
                  style: OutlinedButton.styleFrom(
                      side: BorderSide(color: t.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13)),
                  child: Text('Cancel',
                      style: AppTextStyles.buttonMedium
                          .copyWith(color: t.textSec)),
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: ElevatedButton(
                  onPressed: () {
                    Get.back();
                    ctrl.rejectItem(item, reasonCtrl.text);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 0),
                  child: Text('Reject',
                      style: AppTextStyles.buttonMedium
                          .copyWith(color: Colors.white)),
                )),
              ]),
            ]),
          ),
        );
      }),
    );
  }
}
