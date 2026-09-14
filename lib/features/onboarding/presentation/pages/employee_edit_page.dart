import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import 'employee_controller.dart';
import 'employee_models.dart';

class EmployeeEditPage extends StatefulWidget {
  final int employeeId;
  const EmployeeEditPage({super.key, required this.employeeId});

  @override
  State<EmployeeEditPage> createState() => _EmployeeEditPageState();
}

class _EmployeeEditPageState extends State<EmployeeEditPage> {
  late Employee _emp;
  final _ctrl = Get.find<EmployeeController>();
  final t     = ThemeController.to;

  // Controllers
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _designationCtrl;
  late final TextEditingController _departmentCtrl;
  late final TextEditingController _branchCtrl;
  late final TextEditingController _joiningDateCtrl;
  late final TextEditingController _bloodGroupCtrl;
  late final TextEditingController _fatherNameCtrl;
  late final TextEditingController _permanentAddressCtrl;
  late final TextEditingController _currentAddressCtrl;
  late final TextEditingController _panCtrl;
  late final TextEditingController _uanCtrl;
  late final TextEditingController _bankNameCtrl;

  String? _gender;
  String? _maritalStatus;
  bool _saving = false;

  static const _genders = ['MALE', 'FEMALE', 'OTHER', 'PREFER_NOT_TO_SAY'];
  static const _genderLabels = {'MALE': 'Male', 'FEMALE': 'Female', 'OTHER': 'Other', 'PREFER_NOT_TO_SAY': 'Prefer not to say'};
  static const _maritalStatuses = ['SINGLE', 'MARRIED', 'DIVORCED', 'WIDOWED'];
  static const _maritalLabels   = {'SINGLE': 'Single', 'MARRIED': 'Married', 'DIVORCED': 'Divorced', 'WIDOWED': 'Widowed'};

  @override
  void initState() {
    super.initState();
    _emp = _ctrl.findById(widget.employeeId)!;
    _firstNameCtrl        = TextEditingController(text: _emp.firstName);
    _lastNameCtrl         = TextEditingController(text: _emp.lastName);
    _emailCtrl            = TextEditingController(text: _emp.email ?? '');
    _phoneCtrl            = TextEditingController(text: _emp.phone ?? '');
    _designationCtrl      = TextEditingController(text: _emp.designation ?? '');
    _departmentCtrl       = TextEditingController(text: _emp.department ?? '');
    _branchCtrl           = TextEditingController(text: _emp.branch ?? '');
    _joiningDateCtrl      = TextEditingController(text: _emp.joiningDate ?? '');
    _bloodGroupCtrl       = TextEditingController(text: _emp.bloodGroup ?? '');
    _fatherNameCtrl       = TextEditingController(text: _emp.fatherName ?? '');
    _permanentAddressCtrl = TextEditingController(text: _emp.permanentAddress ?? '');
    _currentAddressCtrl   = TextEditingController(text: _emp.currentAddress ?? '');
    _panCtrl              = TextEditingController(text: _emp.pan ?? '');
    _uanCtrl              = TextEditingController(text: _emp.uan ?? '');
    _bankNameCtrl         = TextEditingController(text: _emp.bankName ?? '');
    _gender         = _emp.gender;
    _maritalStatus  = _emp.maritalStatus;
  }

  @override
  void dispose() {
    for (final c in [_firstNameCtrl, _lastNameCtrl, _emailCtrl, _phoneCtrl,
        _designationCtrl, _departmentCtrl, _branchCtrl, _joiningDateCtrl,
        _bloodGroupCtrl, _fatherNameCtrl, _permanentAddressCtrl,
        _currentAddressCtrl, _panCtrl, _uanCtrl, _bankNameCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 600));
    final updated = _emp.copyWith(
      firstName:        _firstNameCtrl.text.trim(),
      lastName:         _lastNameCtrl.text.trim(),
      email:            _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      phone:            _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      designation:      _designationCtrl.text.trim().isEmpty ? null : _designationCtrl.text.trim(),
      department:       _departmentCtrl.text.trim().isEmpty ? null : _departmentCtrl.text.trim(),
      branch:           _branchCtrl.text.trim().isEmpty ? null : _branchCtrl.text.trim(),
      joiningDate:      _joiningDateCtrl.text.trim().isEmpty ? null : _joiningDateCtrl.text.trim(),
      bloodGroup:       _bloodGroupCtrl.text.trim().isEmpty ? null : _bloodGroupCtrl.text.trim(),
      fatherName:       _fatherNameCtrl.text.trim().isEmpty ? null : _fatherNameCtrl.text.trim(),
      permanentAddress: _permanentAddressCtrl.text.trim().isEmpty ? null : _permanentAddressCtrl.text.trim(),
      currentAddress:   _currentAddressCtrl.text.trim().isEmpty ? null : _currentAddressCtrl.text.trim(),
      pan:              _panCtrl.text.trim().isEmpty ? null : _panCtrl.text.trim(),
      uan:              _uanCtrl.text.trim().isEmpty ? null : _uanCtrl.text.trim(),
      bankName:         _bankNameCtrl.text.trim().isEmpty ? null : _bankNameCtrl.text.trim(),
      gender:           _gender,
      maritalStatus:    _maritalStatus,
    );
    _ctrl.updateEmployee(updated);
    setState(() => _saving = false);
    Get.back();
    Get.snackbar('Saved', '${updated.fullName} updated successfully.',
        backgroundColor: AppColors.success, colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(16));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.surface,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Edit Employee', style: AppTextStyles.headingMedium.copyWith(color: t.textPrimary)),
          Text(_emp.employeeCode,
              style: AppTextStyles.caption.copyWith(color: t.textTert, fontFamily: 'monospace')),
        ]),
        actions: [
          _saving
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)))
              : TextButton(
                  onPressed: _save,
                  child: Text('Save', style: AppTextStyles.buttonMedium
                      .copyWith(color: AppColors.accent))),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Employee header card
          _headerCard(),
          const SizedBox(height: 16),
          _section('Personal Info', [
            _row([
              _field('First Name', _firstNameCtrl, required: true),
              _field('Last Name', _lastNameCtrl, required: true),
            ]),
            _field("Father's Name", _fatherNameCtrl),
            _field('Work Email', _emailCtrl, keyboard: TextInputType.emailAddress),
            _field('Phone', _phoneCtrl, keyboard: TextInputType.phone,
                formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)]),
            _field('Blood Group', _bloodGroupCtrl, hint: 'e.g. O+, AB-'),
            _dropdown('Gender', _gender, _genders.map((g) => DropdownMenuItem(value: g, child: Text(_genderLabels[g]!))).toList(),
                (v) => setState(() => _gender = v)),
            _dropdown('Marital Status', _maritalStatus, _maritalStatuses.map((m) => DropdownMenuItem(value: m, child: Text(_maritalLabels[m]!))).toList(),
                (v) => setState(() => _maritalStatus = v)),
            _field('Permanent Address', _permanentAddressCtrl, maxLines: 3),
            _field('Current Address', _currentAddressCtrl, maxLines: 3),
          ]),
          const SizedBox(height: 12),
          _section('Job Details', [
            _field('Designation', _designationCtrl),
            _field('Department', _departmentCtrl),
            _field('Branch / Location', _branchCtrl),
            _datePicker('Joining Date', _joiningDateCtrl),
          ]),
          const SizedBox(height: 12),
          _section('Statutory & Bank', [
            _field('PAN Number', _panCtrl,
                formatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    LengthLimitingTextInputFormatter(10), _UpperCase()]),
            _field('UAN', _uanCtrl, keyboard: TextInputType.number,
                formatters: [FilteringTextInputFormatter.digitsOnly]),
            _field('Bank Name', _bankNameCtrl),
          ]),
          const SizedBox(height: 24),
          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Save Changes',
                      style: AppTextStyles.buttonLarge.copyWith(color: Colors.white)),
            ),
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: t.border),
        boxShadow: t.cardShadow,
      ),
      child: Row(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(child: Text(_emp.initials,
              style: AppTextStyles.headingLarge.copyWith(color: Colors.white, fontSize: 18))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_emp.fullName, style: AppTextStyles.headingSmall.copyWith(color: t.textPrimary)),
          const SizedBox(height: 3),
          Text(_emp.employeeCode, style: AppTextStyles.caption.copyWith(
              color: t.textTert, fontFamily: 'monospace')),
          const SizedBox(height: 5),
          StatusBadge(status: _emp.status),
        ])),
      ]),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: t.border),
        boxShadow: t.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.06),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppRadius.lg - 1),
              topRight: Radius.circular(AppRadius.lg - 1),
            ),
            border: Border(bottom: BorderSide(color: t.border)),
          ),
          child: Row(children: [
            Container(width: 3, height: 16,
                decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text(title, style: AppTextStyles.headingSmall
                .copyWith(color: AppColors.accent)),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(16),
            child: Column(children: children)),
      ]),
    );
  }

  Widget _row(List<Widget> children) {
    return Row(children: children
        .expand((w) => [Expanded(child: w), const SizedBox(width: 12)])
        .take(children.length * 2 - 1).toList());
  }

  Widget _field(String label, TextEditingController ctrl,
      {bool required = false, String? hint, TextInputType? keyboard,
       List<TextInputFormatter>? formatters, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(label, style: AppTextStyles.label.copyWith(color: t.textSec)),
          if (required) const Text(' *', style: TextStyle(color: AppColors.danger, fontSize: 12)),
        ]),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboard,
          inputFormatters: formatters,
          maxLines: maxLines,
          style: AppTextStyles.bodyMedium.copyWith(color: t.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.bodyMedium.copyWith(color: t.textTert),
            filled: true,
            fillColor: t.surfaceVar,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: t.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: t.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: maxLines > 1 ? 12 : 10),
          ),
        ),
      ]),
    );
  }

  Widget _dropdown(String label, String? value,
      List<DropdownMenuItem<String>> items, void Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTextStyles.label.copyWith(color: t.textSec)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          style: AppTextStyles.bodyMedium.copyWith(color: t.textPrimary),
          dropdownColor: t.surface,
          decoration: InputDecoration(
            filled: true, fillColor: t.surfaceVar,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: t.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: t.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            hint: Text('Select', style: AppTextStyles.bodyMedium.copyWith(color: t.textTert)),
          ),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: t.textSec),
        ),
      ]),
    );
  }

  Widget _datePicker(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTextStyles.label.copyWith(color: t.textSec)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          readOnly: true,
          style: AppTextStyles.bodyMedium.copyWith(color: t.textPrimary),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.tryParse(ctrl.text) ?? DateTime.now(),
              firstDate: DateTime(2020), lastDate: DateTime(2035),
              builder: (ctx, child) => Theme(
                data: ThemeData(colorScheme: ColorScheme.fromSeed(
                    seedColor: AppColors.accent,
                    brightness: t.isDark ? Brightness.dark : Brightness.light)),
                child: child!,
              ),
            );
            if (picked != null) {
              ctrl.text = '${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}';
            }
          },
          decoration: InputDecoration(
            filled: true, fillColor: t.surfaceVar,
            suffixIcon: Icon(Icons.calendar_today_rounded, color: t.textTert, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: t.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: t.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.accent, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ]),
    );
  }
}

class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue n) =>
      n.copyWith(text: n.text.toUpperCase());
}