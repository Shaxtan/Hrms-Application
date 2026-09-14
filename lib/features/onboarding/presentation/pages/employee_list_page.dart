import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import 'employee_controller.dart';
import 'employee_models.dart';
import 'employee_edit_page.dart';

class EmployeeListPage extends StatelessWidget {
  const EmployeeListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<EmployeeController>();
    return Obx(() {
      final t = ThemeController.to;
      return Scaffold(
        backgroundColor: t.bg,
        appBar: SharedAppBar(
          title: 'Employees',
          subtitle: '${ctrl.filtered.length} records',
        ),
        body: Column(children: [
          _SearchBar(ctrl: ctrl, t: t),
          Expanded(child: _EmployeeList(ctrl: ctrl, t: t)),
        ]),
      );
    });
  }
}

class _SearchBar extends StatelessWidget {
  final EmployeeController ctrl;
  final ThemeController t;
  const _SearchBar({required this.ctrl, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: t.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(children: [
        TextField(
          onChanged: (v) => ctrl.searchQuery.value = v,
          style: AppTextStyles.bodyMedium.copyWith(color: t.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search name, code, branch…',
            hintStyle: AppTextStyles.bodyMedium.copyWith(color: t.textTert),
            prefixIcon: Icon(Icons.search_rounded, color: t.textTert, size: 20),
            filled: true,
            fillColor: t.surfaceVar,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: t.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: t.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.accent, width: 2)),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _Chip(ctrl: ctrl, t: t, type: 'status', value: 'ALL',                  label: 'All'),
            _Chip(ctrl: ctrl, t: t, type: 'status', value: 'ACTIVE',               label: 'Active',       color: AppColors.success),
            _Chip(ctrl: ctrl, t: t, type: 'status', value: 'PENDING_SALARY_SETUP', label: 'Pending',      color: AppColors.info),
            _Chip(ctrl: ctrl, t: t, type: 'status', value: 'UNASSIGNED',           label: 'Unassigned',   color: AppColors.warning),
            const SizedBox(width: 12),
            Container(width: 1, height: 20, color: t.border),
            const SizedBox(width: 12),
            _Chip(ctrl: ctrl, t: t, type: 'type', value: 'ALL',       label: 'All Types'),
            _Chip(ctrl: ctrl, t: t, type: 'type', value: 'FULL_TIME', label: 'Staff',    color: AppColors.success),
            _Chip(ctrl: ctrl, t: t, type: 'type', value: 'CONTRACT',  label: 'Contract', color: AppColors.accent),
            _Chip(ctrl: ctrl, t: t, type: 'type', value: 'NAPS',      label: 'NAPS',     color: AppColors.info),
            _Chip(ctrl: ctrl, t: t, type: 'type', value: 'INTERN',    label: 'Intern',   color: AppColors.warning),
          ]),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final EmployeeController ctrl;
  final ThemeController t;
  final String type, value, label;
  final Color? color;
  const _Chip({required this.ctrl, required this.t,
      required this.type, required this.value,
      required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final sel         = type == 'status'
          ? ctrl.statusFilter.value == value
          : ctrl.typeFilter.value == value;
      final activeColor = color ?? AppColors.accent;
      return GestureDetector(
        onTap: () {
          if (type == 'status') ctrl.statusFilter.value = value;
          else ctrl.typeFilter.value = value;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

class _EmployeeList extends StatelessWidget {
  final EmployeeController ctrl;
  final ThemeController t;
  const _EmployeeList({required this.ctrl, required this.t});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final items = ctrl.filtered;
      if (items.isEmpty) {
        return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.people_outline_rounded, color: t.textTert, size: 52),
          const SizedBox(height: 12),
          Text('No employees found',
              style: AppTextStyles.headingSmall.copyWith(color: t.textPrimary)),
          const SizedBox(height: 6),
          Text('Try adjusting your search or filters',
              style: AppTextStyles.bodySmall.copyWith(color: t.textSec)),
        ]));
      }
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _EmployeeCard(emp: items[i], t: t),
      );
    });
  }
}

class _EmployeeCard extends StatelessWidget {
  final Employee emp;
  final ThemeController t;
  const _EmployeeCard({required this.emp, required this.t});

  static const _typeMap = <String, (Color, Color, String)>{
    'CONTRACT':  (AppColors.accentLight,  AppColors.accent,  'Contractual'),
    'NAPS':      (AppColors.infoLight,    AppColors.info,    'NAPS'),
    'FULL_TIME': (AppColors.successLight, AppColors.success, 'Staff'),
    'INTERN':    (AppColors.warningLight, AppColors.warning, 'Intern'),
  };

  @override
  Widget build(BuildContext context) {
    final tc = _typeMap[emp.employmentType] ??
        (t.surfaceVar, t.textSec, emp.employmentType);
    return Container(
      decoration: BoxDecoration(color: t.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: t.border), boxShadow: t.cardShadow),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => Get.to(() => EmployeeEditPage(employeeId: emp.id),
              transition: Transition.cupertino),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(width: 48, height: 48,
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(14)),
                  child: Center(child: Text(emp.initials,
                      style: AppTextStyles.headingSmall
                          .copyWith(color: Colors.white, fontSize: 14)))),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(emp.fullName,
                      style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600, color: t.textPrimary))),
                  StatusBadge(status: emp.status),
                ]),
                const SizedBox(height: 4),
                Text(emp.employeeCode,
                    style: AppTextStyles.caption.copyWith(
                        color: t.textTert, fontFamily: 'monospace')),
                const SizedBox(height: 6),
                Row(children: [
                  if (emp.designation != null) ...[
                    Icon(Icons.work_outline_rounded, size: 11, color: t.textTert),
                    const SizedBox(width: 3),
                    Flexible(child: Text(emp.designation!,
                        style: AppTextStyles.caption
                            .copyWith(color: t.textSec, fontSize: 11),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: tc.$1,
                        borderRadius: BorderRadius.circular(AppRadius.full)),
                    child: Text(tc.$3, style: AppTextStyles.caption.copyWith(
                        color: tc.$2, fontSize: 10,
                        fontWeight: FontWeight.w600)),
                  ),
                ]),
                if (emp.branch != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.location_on_outlined, size: 11, color: t.textTert),
                    const SizedBox(width: 3),
                    Text(
                        '${emp.branch}${emp.client != null ? ' · ${emp.client}' : ''}',
                        style: AppTextStyles.caption
                            .copyWith(color: t.textTert, fontSize: 11)),
                  ]),
                ],
              ])),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: t.textTert, size: 18),
            ]),
          ),
        ),
      ),
    );
  }
}