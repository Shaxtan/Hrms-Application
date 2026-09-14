import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MODEL
// ═══════════════════════════════════════════════════════════════════════════════
class ApprovalItem {
  final int id;
  final String subject, type, status, action, submitted;
  final String? reason, employmentType, branch, client;

  const ApprovalItem({
    required this.id, required this.subject, required this.type,
    required this.status, required this.action, required this.submitted,
    this.reason, this.employmentType, this.branch, this.client,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONTROLLER
// ═══════════════════════════════════════════════════════════════════════════════
class ApprovalsController extends GetxController {
  final statusFilter = 'ALL'.obs;
  final typeFilter   = 'ALL'.obs;

  final _items = <ApprovalItem>[
    const ApprovalItem(id:1, subject:'Demo 1',       type:'Onboarding', status:'PENDING',  action:'Submitted', submitted:'06 Sep 2026', employmentType:'CONTRACT', branch:'Mumbai HQ',    client:'Acme Corp'),
    const ApprovalItem(id:2, subject:'Employee 1',   type:'Onboarding', status:'PENDING',  action:'Submitted', submitted:'03 Sep 2026', employmentType:'NAPS',     branch:'Pune Branch',  client:'Globex'),
    const ApprovalItem(id:3, subject:'Priya Sharma', type:'Onboarding', status:'APPROVED', action:'Approved',  submitted:'28 Aug 2026', employmentType:'FULL_TIME',branch:'Mumbai HQ',    client:'Acme Corp'),
    const ApprovalItem(id:4, subject:'Rahul Nair',   type:'Onboarding', status:'REJECTED', action:'Rejected',  submitted:'25 Aug 2026', reason:'Incomplete documents', employmentType:'CONTRACT', branch:'Pune Branch', client:'Globex'),
    const ApprovalItem(id:5, subject:'Anita Joshi',  type:'Onboarding', status:'APPROVED', action:'Approved',  submitted:'20 Aug 2026', employmentType:'INTERN',   branch:'Nashik Office',client:'Acme Corp'),
    const ApprovalItem(id:6, subject:'Deepak Kumar', type:'Onboarding', status:'PENDING',  action:'Submitted', submitted:'18 Aug 2026', employmentType:'NAPS',     branch:'Mumbai HQ',    client:'Globex'),
    const ApprovalItem(id:7, subject:'Sneha Patil',  type:'Onboarding', status:'REJECTED', action:'Rejected',  submitted:'15 Aug 2026', reason:'PAN verification failed', employmentType:'FULL_TIME', branch:'Pune Branch', client:'Acme Corp'),
  ].obs;

  List<ApprovalItem> get filtered => _items.where((i) {
    final okStatus = statusFilter.value == 'ALL' || i.status == statusFilter.value;
    final okType   = typeFilter.value   == 'ALL' || i.type   == typeFilter.value;
    return okStatus && okType;
  }).toList();

  int get pendingCount => _items.where((i) => i.status == 'PENDING').length;

  void approve(int id) {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    final old = _items[idx];
    _items[idx] = ApprovalItem(
        id: old.id, subject: old.subject, type: old.type,
        status: 'APPROVED', action: 'Approved',
        submitted: old.submitted, employmentType: old.employmentType,
        branch: old.branch, client: old.client);
    Get.snackbar('Approved', '${old.subject} approved.',
        backgroundColor: AppColors.success, colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(16));
  }

  void reject(int id, String reason) {
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    final old = _items[idx];
    _items[idx] = ApprovalItem(
        id: old.id, subject: old.subject, type: old.type,
        status: 'REJECTED', action: 'Rejected',
        submitted: old.submitted,
        reason: reason.trim().isEmpty ? 'No reason provided' : reason.trim(),
        employmentType: old.employmentType,
        branch: old.branch, client: old.client);
    Get.snackbar('Rejected', '${old.subject} rejected.',
        backgroundColor: AppColors.danger, colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(16));
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(AppRadius.full)),
                    child: Text('${ctrl.pendingCount} pending',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600)))
                : const SizedBox.shrink()),
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
            _SChip(ctrl: ctrl, t: t, value: 'ALL',      label: 'All statuses', color: null),
            const SizedBox(width: 8),
            _SChip(ctrl: ctrl, t: t, value: 'PENDING',  label: 'Pending',      color: AppColors.warning),
            const SizedBox(width: 8),
            _SChip(ctrl: ctrl, t: t, value: 'APPROVED', label: 'Approved',     color: AppColors.success),
            const SizedBox(width: 8),
            _SChip(ctrl: ctrl, t: t, value: 'REJECTED', label: 'Rejected',     color: AppColors.danger),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          _TChip(ctrl: ctrl, t: t, value: 'ALL',        label: 'All types'),
          const SizedBox(width: 8),
          _TChip(ctrl: ctrl, t: t, value: 'Onboarding', label: 'Onboarding'),
        ]),
      ]),
    );
  }
}

class _SChip extends StatelessWidget {
  final ApprovalsController ctrl;
  final ThemeController t;
  final String value, label;
  final Color? color;
  const _SChip({required this.ctrl, required this.t,
      required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final sel         = ctrl.statusFilter.value == value;
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
                color: sel ? activeColor : t.border,
                width: sel ? 1.5 : 1),
          ),
          child: Text(label, style: AppTextStyles.caption.copyWith(
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
  const _TChip({required this.ctrl, required this.t,
      required this.value, required this.label});

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
                color: sel ? AppColors.accent : t.border,
                width: sel ? 1.5 : 1),
          ),
          child: Text(label, style: AppTextStyles.caption.copyWith(
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
      final items = ctrl.filtered;
      if (items.isEmpty) {
        return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inbox_rounded, color: t.textTert, size: 48),
          const SizedBox(height: 12),
          Text('No records found',
              style: AppTextStyles.headingSmall.copyWith(color: t.textPrimary)),
          const SizedBox(height: 6),
          Text('Try adjusting your filters',
              style: AppTextStyles.bodySmall.copyWith(color: t.textSec)),
        ]));
      }
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _ApprovalCard(item: items[i], ctrl: ctrl, t: t),
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
    'CONTRACT':  (AppColors.accentLight,  AppColors.accent,  'Contractual'),
    'NAPS':      (AppColors.infoLight,    AppColors.info,    'NAPS'),
    'FULL_TIME': (AppColors.successLight, AppColors.success, 'Staff'),
    'INTERN':    (AppColors.warningLight, AppColors.warning, 'Intern'),
  };

  @override
  Widget build(BuildContext context) {
    final initials = item.subject.split(' ').take(2)
        .map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();
    final tc = _typeColors[item.employmentType] ??
        (t.surfaceVar, t.textSec, item.employmentType ?? '');

    return Container(
      decoration: BoxDecoration(color: t.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: t.border), boxShadow: t.cardShadow),
      child: Column(children: [
        // Header
        Padding(padding: const EdgeInsets.all(14),
            child: Row(children: [
          CircleAvatar(radius: 22, backgroundColor: AppColors.accentLight,
              child: Text(initials,
                  style: AppTextStyles.headingSmall.copyWith(
                      color: AppColors.accent, fontSize: 13))),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(item.subject,
                  style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600, color: t.textPrimary))),
              StatusBadge(status: item.status),
            ]),
            const SizedBox(height: 5),
            Row(children: [
              _pill(item.type, t.surfaceVar, t.textPrimary, t.border),
              if (item.employmentType != null) ...[
                const SizedBox(width: 6),
                _pill(tc.$3, tc.$1, tc.$2, null),
              ],
            ]),
          ])),
        ])),
        // Meta
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          decoration: BoxDecoration(color: t.surfaceVar,
              borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppRadius.lg),
                  bottomRight: Radius.circular(AppRadius.lg))),
          child: Column(children: [
            Row(children: [
              _metaCell('YOUR ACTION', item.action, t),
              _metaCell('SUBMITTED',   item.submitted, t),
              _metaCell('REASON',      item.reason ?? '—', t),
            ]),
            if (item.client != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.business_outlined, size: 11, color: t.textTert),
                const SizedBox(width: 4),
                Text(item.client!,
                    style: AppTextStyles.caption.copyWith(fontSize: 11, color: t.textSec)),
                if (item.branch != null) ...[
                  Text(' · ', style: AppTextStyles.caption),
                  Icon(Icons.location_on_outlined, size: 11, color: t.textTert),
                  const SizedBox(width: 2),
                  Text(item.branch!,
                      style: AppTextStyles.caption.copyWith(fontSize: 11, color: t.textSec)),
                ],
              ]),
            ],
            if (item.status == 'PENDING') ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => _showRejectSheet(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.danger.withOpacity(0.3))),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      const Icon(Icons.close_rounded,
                          color: AppColors.danger, size: 15),
                      const SizedBox(width: 5),
                      Text('Reject', style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.danger, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                )),
                const SizedBox(width: 10),
                Expanded(child: GestureDetector(
                  onTap: () => ctrl.approve(item.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.success.withOpacity(0.3))),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      const Icon(Icons.check_rounded,
                          color: AppColors.success, size: 15),
                      const SizedBox(width: 5),
                      Text('Approve', style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.success, fontWeight: FontWeight.w600)),
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

  Widget _pill(String label, Color bg, Color fg, Color? border) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: bg,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: border != null ? Border.all(color: border) : null),
        child: Text(label, style: AppTextStyles.caption.copyWith(
            color: fg, fontWeight: FontWeight.w500, fontSize: 11)),
      );

  Widget _metaCell(String label, String value, ThemeController t) =>
      Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTextStyles.caption.copyWith(
            fontSize: 9, color: t.textTert,
            letterSpacing: 0.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, style: AppTextStyles.bodySmall.copyWith(
            fontSize: 12, color: t.textPrimary),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ]));

  void _showRejectSheet(BuildContext context) {
    final reasonCtrl = TextEditingController();
    Get.bottomSheet(
      isScrollControlled: true,
      Obx(() {
        final t = ThemeController.to;
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            decoration: BoxDecoration(color: t.surface,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: t.border,
                      borderRadius: BorderRadius.circular(100))),
              const SizedBox(height: 20),
              Text('Reject Onboarding',
                  style: AppTextStyles.headingMedium
                      .copyWith(color: t.textPrimary)),
              const SizedBox(height: 6),
              Text('Provide a reason so the supervisor can resubmit.',
                  style: AppTextStyles.bodySmall.copyWith(color: t.textSec),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                autofocus: true,
                style: AppTextStyles.bodyMedium.copyWith(color: t.textPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g. Aadhaar document unclear…',
                  hintStyle: AppTextStyles.bodySmall.copyWith(color: t.textTert),
                  filled: true, fillColor: t.surfaceVar,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: t.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: t.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.danger, width: 2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: Get.back,
                  style: OutlinedButton.styleFrom(
                      side: BorderSide(color: t.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13)),
                  child: Text('Cancel', style: AppTextStyles.buttonMedium
                      .copyWith(color: t.textSec)),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  onPressed: () {
                    Get.back();
                    ctrl.reject(item.id, reasonCtrl.text);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 0),
                  child: Text('Reject', style: AppTextStyles.buttonMedium
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