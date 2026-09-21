import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../../shared/widgets/auth_image.dart';
import '../../data/employee_api.dart';
import 'employee_controller.dart';

class EmployeeEditPage extends StatefulWidget {
  final int employeeId;
  const EmployeeEditPage({super.key, required this.employeeId});
  @override
  State<EmployeeEditPage> createState() => _EmployeeEditPageState();
}

class _EmployeeEditPageState extends State<EmployeeEditPage> {
  final _api = EmployeeApi();
  bool _loading = true, _saving = false, _editing = false;
  String? _error;
  Map<String, dynamic> _data = {};
  List<dynamic> _family = [], _emergency = [], _bank = [], _documents = [];
  String? _photoPath;
  final _expanded = <int>{0};
  final _scrollCtrl = ScrollController();
  final _sectionKeys = List.generate(6, (_) => GlobalKey());

  // Controllers
  late final TextEditingController _firstNameCtrl,
      _lastNameCtrl,
      _emailCtrl,
      _phoneCtrl;
  late final TextEditingController _designationCtrl,
      _departmentCtrl,
      _branchCtrl,
      _joiningDateCtrl;
  late final TextEditingController _bloodGroupCtrl,
      _fatherNameCtrl,
      _motherNameCtrl;
  late final TextEditingController _permanentAddrCtrl, _currentAddrCtrl;
  late final TextEditingController _panCtrl,
      _uanCtrl,
      _pfCtrl,
      _esicCtrl,
      _dobCtrl;
  String? _gender, _maritalStatus, _employmentType;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController();
    _lastNameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _designationCtrl = TextEditingController();
    _departmentCtrl = TextEditingController();
    _branchCtrl = TextEditingController();
    _joiningDateCtrl = TextEditingController();
    _bloodGroupCtrl = TextEditingController();
    _fatherNameCtrl = TextEditingController();
    _motherNameCtrl = TextEditingController();
    _permanentAddrCtrl = TextEditingController();
    _currentAddrCtrl = TextEditingController();
    _panCtrl = TextEditingController();
    _uanCtrl = TextEditingController();
    _pfCtrl = TextEditingController();
    _esicCtrl = TextEditingController();
    _dobCtrl = TextEditingController();
    _scrollCtrl.addListener(_onScroll);
    _fetchAll();
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    for (final c in [
      _firstNameCtrl,
      _lastNameCtrl,
      _emailCtrl,
      _phoneCtrl,
      _designationCtrl,
      _departmentCtrl,
      _branchCtrl,
      _joiningDateCtrl,
      _bloodGroupCtrl,
      _fatherNameCtrl,
      _motherNameCtrl,
      _permanentAddrCtrl,
      _currentAddrCtrl,
      _panCtrl,
      _uanCtrl,
      _pfCtrl,
      _esicCtrl,
      _dobCtrl
    ]) c.dispose();
    super.dispose();
  }

  /// Auto-expand the section closest to the top of the visible area.
  void _onScroll() {
    if (!mounted) return;
    int? closest;
    double closestDist = double.infinity;
    for (int i = 0; i < _sectionKeys.length; i++) {
      final ctx = _sectionKeys[i].currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      // Position relative to screen top
      final screenY = box.localToGlobal(Offset.zero).dy;
      // We want the section whose top is closest to ~180px from screen top
      final dist = (screenY - 180).abs();
      if (screenY > -box.size.height && dist < closestDist) {
        closestDist = dist;
        closest = i;
      }
    }
    if (closest != null && !_expanded.contains(closest)) {
      setState(() {
        _expanded.clear();
        _expanded.add(closest!);
      });
    }
  }

  ThemeController get t => ThemeController.to;

  Future<void> _fetchAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.getEmployeeById(widget.employeeId);
      _data = (res['data'] ?? res) as Map<String, dynamic>;
      _populateFields();
      final pUrl = _data['profilePhotoUrl'] ?? _data['profilePictureUrl'];
      _photoPath = (pUrl != null && pUrl.toString().isNotEmpty)
          ? pUrl.toString()
          : '/api/v1/employees/${widget.employeeId}/photo';
      try {
        _family = (_data['familyMembers'] as List?) ??
            await _api.getFamilyMembers(widget.employeeId);
      } catch (_) {}
      try {
        _emergency = (_data['emergencyContacts'] as List?) ??
            await _api.getEmergencyContacts(widget.employeeId);
      } catch (_) {}
      try {
        _bank = (_data['bankAccounts'] as List?) ??
            await _api.getBankAccounts(widget.employeeId);
      } catch (_) {}
      try {
        _documents = await _api.getEmployeeDocuments(widget.employeeId);
      } catch (_) {}
      setState(() => _loading = false);
    } on DioException catch (e) {
      setState(() {
        _error = ApiFailure.fromDioException(e).message;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load: $e';
        _loading = false;
      });
    }
  }

  void _populateFields() {
    final d = _data;
    String fn = (d['firstName'] ?? '').toString(),
        ln = (d['lastName'] ?? '').toString();
    if (fn.isEmpty && ln.isEmpty) {
      final parts = (d['fullName'] ?? '')
          .toString()
          .trim()
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .toList();
      fn = parts.isNotEmpty ? parts.first : '';
      ln = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }
    _firstNameCtrl.text = fn;
    _lastNameCtrl.text = ln;
    _emailCtrl.text = (d['email'] ?? '').toString();
    _phoneCtrl.text = (d['phone'] ?? d['mobileNumber'] ?? '').toString();
    _designationCtrl.text =
        (d['designationName'] ?? d['designation'] ?? '').toString();
    _departmentCtrl.text =
        (d['departmentName'] ?? d['department'] ?? '').toString();
    _branchCtrl.text = (d['branchName'] ?? d['branch'] ?? '').toString();
    _joiningDateCtrl.text = (d['joiningDate'] ?? '').toString();
    _dobCtrl.text = (d['dateOfBirth'] ?? '').toString();
    _bloodGroupCtrl.text = (d['bloodGroup'] ?? '').toString();
    _fatherNameCtrl.text =
        (d['fatherHusbandName'] ?? d['fatherName'] ?? '').toString();
    _motherNameCtrl.text = (d['motherName'] ?? '').toString();
    _permanentAddrCtrl.text = (d['permanentAddress'] ?? '').toString();
    _currentAddrCtrl.text = (d['currentAddress'] ?? '').toString();
    _panCtrl.text = (d['pan'] ?? '').toString();
    _uanCtrl.text = (d['uan'] ?? '').toString();
    _pfCtrl.text = (d['pfAccountNumber'] ?? '').toString();
    _esicCtrl.text = (d['esicNumber'] ?? '').toString();
    _gender = d['gender'];
    _maritalStatus = d['maritalStatus'];
    _employmentType = d['employmentType'];
  }

  String get _fullName => '${_firstNameCtrl.text} ${_lastNameCtrl.text}'.trim();
  String get _initials {
    final p = _fullName.split(' ').where((w) => w.isNotEmpty).toList();
    return p.length >= 2
        ? '${p[0][0]}${p[1][0]}'.toUpperCase()
        : (p.isNotEmpty ? p[0][0].toUpperCase() : '?');
  }

  String get _empCode => (_data['employeeCode'] ?? '').toString();
  String get _status => (_data['status'] ?? '').toString();

  void _toggle(int i) => setState(() {
        if (_expanded.contains(i))
          _expanded.remove(i);
        else
          _expanded.add(i);
      });

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _api.patchEmployee(widget.employeeId, {
        'firstName': _firstNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'email':
            _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
        'phone':
            _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
        'dateOfBirth':
            _dobCtrl.text.trim().isNotEmpty ? _dobCtrl.text.trim() : null,
        'gender': _gender,
        'bloodGroup': _bloodGroupCtrl.text.trim().isNotEmpty
            ? _bloodGroupCtrl.text.trim()
            : null,
        'maritalStatus': _maritalStatus,
        'fatherHusbandName': _fatherNameCtrl.text.trim().isNotEmpty
            ? _fatherNameCtrl.text.trim()
            : null,
        'motherName': _motherNameCtrl.text.trim().isNotEmpty
            ? _motherNameCtrl.text.trim()
            : null,
        'permanentAddress': _permanentAddrCtrl.text.trim().isNotEmpty
            ? _permanentAddrCtrl.text.trim()
            : null,
        'currentAddress': _currentAddrCtrl.text.trim().isNotEmpty
            ? _currentAddrCtrl.text.trim()
            : null,
        'pan': _panCtrl.text.trim().isNotEmpty ? _panCtrl.text.trim() : null,
        'uan': _uanCtrl.text.trim().isNotEmpty ? _uanCtrl.text.trim() : null,
      });
      setState(() {
        _saving = false;
        _editing = false;
      });
      if (Get.isRegistered<EmployeeController>())
        Get.find<EmployeeController>().fetchEmployees();
      Get.snackbar('Saved', '$_fullName updated.',
          backgroundColor: AppColors.success,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16));
    } on DioException catch (e) {
      setState(() => _saving = false);
      Get.snackbar('Error', ApiFailure.fromDioException(e).message,
          backgroundColor: AppColors.danger,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return Scaffold(
          backgroundColor: t.bg,
          appBar: AppBar(backgroundColor: t.surface, elevation: 0),
          body: const Center(child: CircularProgressIndicator()));
    if (_error != null)
      return Scaffold(
          backgroundColor: t.bg,
          appBar: AppBar(backgroundColor: t.surface, elevation: 0),
          body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
            const SizedBox(height: 12),
            Text(_error!,
                style: AppTextStyles.bodySmall.copyWith(color: t.textSec)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _fetchAll, child: const Text('Retry'))
          ])));

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.surface,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_editing ? 'Edit Employee' : 'Employee Details',
              style:
                  AppTextStyles.headingMedium.copyWith(color: t.textPrimary)),
          if (_empCode.isNotEmpty)
            Text(_empCode,
                style: AppTextStyles.caption
                    .copyWith(color: t.textTert, fontFamily: 'monospace')),
        ]),
        actions: [
          if (_editing) ...[
            TextButton(
                onPressed: () => setState(() {
                      _editing = false;
                      _populateFields();
                    }),
                child: Text('Cancel',
                    style:
                        AppTextStyles.buttonMedium.copyWith(color: t.textSec))),
            _saving
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                : TextButton(
                    onPressed: _save,
                    child: Text('Save',
                        style: AppTextStyles.buttonMedium
                            .copyWith(color: AppColors.accent))),
          ] else
            IconButton(
                icon: const Icon(Icons.edit_rounded,
                    color: AppColors.accent, size: 20),
                onPressed: () => setState(() => _editing = true)),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            // ── Header card with photo ──
            _headerCard(),
            const SizedBox(height: 12),

            // ── Section 0: Personal Info ──
            _accordion(0, 'Personal Information', Icons.person_outline_rounded,
                AppColors.accent, [
              _fieldRow('First Name', _firstNameCtrl, required: true),
              _fieldRow('Last Name', _lastNameCtrl),
              _fieldRow('Date of Birth', _dobCtrl),
              _ddRow(
                  'Gender',
                  _gender,
                  ['MALE', 'FEMALE', 'OTHER', 'PREFER_NOT_TO_SAY'],
                  (v) => setState(() => _gender = v)),
              _fieldRow('Blood Group', _bloodGroupCtrl),
              _ddRow(
                  'Marital Status',
                  _maritalStatus,
                  ['SINGLE', 'MARRIED', 'DIVORCED', 'WIDOWED'],
                  (v) => setState(() => _maritalStatus = v)),
              _fieldRow('Phone', _phoneCtrl, keyboard: TextInputType.phone),
              _fieldRow('Email', _emailCtrl,
                  keyboard: TextInputType.emailAddress),
              _fieldRow("Father/Husband Name", _fatherNameCtrl),
              _fieldRow("Mother's Name", _motherNameCtrl),
              _fieldRow('Permanent Address', _permanentAddrCtrl, maxLines: 2),
              _fieldRow('Current Address', _currentAddrCtrl, maxLines: 2),
            ]),
            const SizedBox(height: 10),

            // ── Section 1: Job Details ──
            _accordion(1, 'Job Details', Icons.work_outline_rounded,
                AppColors.success, [
              _infoRow('Employment Type', _employmentType ?? '—'),
              _infoRow('Status', _status),
              _fieldRow('Designation', _designationCtrl),
              _fieldRow('Department', _departmentCtrl),
              _fieldRow('Branch', _branchCtrl),
              _fieldRow('Joining Date', _joiningDateCtrl),
              _infoRow(
                  'Aadhaar',
                  (_data['aadhaarLast4'] ?? _data['aadhaarNumber'] ?? '—')
                      .toString()),
            ]),
            const SizedBox(height: 10),

            // ── Section 2: Bank & Tax ──
            _accordion(2, 'Bank & Tax', Icons.account_balance_outlined,
                AppColors.warning, [
              _fieldRow('PAN', _panCtrl),
              _fieldRow('UAN', _uanCtrl),
              _fieldRow('PF Account', _pfCtrl),
              _fieldRow('ESIC', _esicCtrl),
              if (_bank.isNotEmpty) ...[
                const SizedBox(height: 12),
                ..._bank.map((b) {
                  final m = b as Map<String, dynamic>;
                  return _bankCard(m);
                }),
              ] else
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('No bank accounts on file.',
                        style:
                            AppTextStyles.caption.copyWith(color: t.textTert))),
            ]),
            const SizedBox(height: 10),

            // ── Section 3: Family Members ──
            _accordion(
                3,
                'Family Members',
                Icons.family_restroom_rounded,
                const Color(0xFF7C3AED),
                _family.isEmpty
                    ? [_emptyMsg('No family members on file.')]
                    : _family
                        .map((f) => _familyCard(f as Map<String, dynamic>))
                        .toList()),
            const SizedBox(height: 10),

            // ── Section 4: Emergency Contacts ──
            _accordion(
                4,
                'Emergency Contacts',
                Icons.emergency_rounded,
                AppColors.danger,
                _emergency.isEmpty
                    ? [_emptyMsg('No emergency contacts on file.')]
                    : _emergency
                        .map((c) => _emergencyCard(c as Map<String, dynamic>))
                        .toList()),
            const SizedBox(height: 10),

            // ── Section 5: Documents ──
            _accordion(
                5,
                'Documents',
                Icons.description_outlined,
                AppColors.info,
                _documents.isEmpty
                    ? [_emptyMsg('No documents on file.')]
                    : _documents
                        .map((d) => _documentCard(d as Map<String, dynamic>))
                        .toList()),

            if (_editing) ...[
              const SizedBox(height: 20),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md)),
                          elevation: 0),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text('Save Changes',
                              style: AppTextStyles.buttonLarge
                                  .copyWith(color: Colors.white)))),
            ],
            const SizedBox(height: 32),
          ])),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: t.border),
          boxShadow: t.cardShadow),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 64,
            height: 64,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18)),
            child: AuthImage(
                url: _photoPath ??
                    '/api/v1/employees/${widget.employeeId}/photo',
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorWidget: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
                        borderRadius: BorderRadius.circular(18)),
                    child: Center(
                        child: Text(_initials,
                            style: AppTextStyles.headingLarge.copyWith(
                                color: Colors.white, fontSize: 20)))))),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_fullName.isNotEmpty ? _fullName : 'Employee',
              style: AppTextStyles.headingMedium.copyWith(color: t.textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(_empCode,
              style: AppTextStyles.caption.copyWith(
                  color: t.textTert, fontFamily: 'monospace', fontSize: 12)),
          if (_emailCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(_emailCtrl.text,
                style: AppTextStyles.caption
                    .copyWith(color: t.textSec, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis)
          ],
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 4, children: [
            StatusBadge(status: _status),
            if (_employmentType != null)
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: BorderRadius.circular(AppRadius.full)),
                  child: Text(_employmentType!,
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w600))),
          ]),
        ])),
      ]),
    );
  }

  Widget _accordion(int index, String title, IconData icon, Color color,
      List<Widget> children) {
    final isOpen = _expanded.contains(index);
    return AnimatedContainer(
        key: _sectionKeys[index],
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border:
                Border.all(color: isOpen ? color.withOpacity(0.4) : t.border),
            boxShadow: t.cardShadow),
        child: Column(children: [
          // Header
          InkWell(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              onTap: () => _toggle(index),
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                      color:
                          isOpen ? color.withOpacity(0.06) : Colors.transparent,
                      borderRadius: isOpen
                          ? const BorderRadius.only(
                              topLeft: Radius.circular(AppRadius.lg - 1),
                              topRight: Radius.circular(AppRadius.lg - 1))
                          : BorderRadius.circular(AppRadius.lg - 1)),
                  child: Row(children: [
                    Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: Icon(icon, color: color, size: 18)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(title,
                            style: AppTextStyles.headingSmall.copyWith(
                                color: isOpen ? color : t.textPrimary))),
                    AnimatedRotation(
                        turns: isOpen ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.keyboard_arrow_down_rounded,
                            color: t.textTert, size: 22)),
                  ]))),
          // Body
          AnimatedCrossFade(
              firstChild: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(color: t.border, height: 1),
                        const SizedBox(height: 14),
                        ...children,
                      ])),
              secondChild: const SizedBox(width: double.infinity),
              crossFadeState:
                  isOpen ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 200)),
        ]));
  }

  Widget _infoRow(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 140,
            child: Text(label,
                style: AppTextStyles.caption
                    .copyWith(color: t.textTert, fontSize: 12))),
        Expanded(
            child: Text(value.isNotEmpty ? value : '—',
                style: AppTextStyles.bodySmall.copyWith(
                    color: t.textPrimary, fontWeight: FontWeight.w500)))
      ]));

  Widget _fieldRow(String label, TextEditingController ctrl,
      {bool required = false, TextInputType? keyboard, int maxLines = 1}) {
    if (!_editing) return _infoRow(label, ctrl.text);
    return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label, style: AppTextStyles.label.copyWith(color: t.textSec)),
            if (required)
              const Text(' *',
                  style: TextStyle(color: AppColors.danger, fontSize: 12))
          ]),
          const SizedBox(height: 6),
          TextField(
              controller: ctrl,
              keyboardType: keyboard,
              maxLines: maxLines,
              style: AppTextStyles.bodyMedium.copyWith(color: t.textPrimary),
              decoration: InputDecoration(
                  filled: true,
                  fillColor: t.surfaceVar,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: t.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: t.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide:
                          const BorderSide(color: AppColors.accent, width: 2)),
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 12, vertical: maxLines > 1 ? 12 : 10)))
        ]));
  }

  Widget _ddRow(String label, String? value, List<String> options,
      void Function(String?) onChanged) {
    if (!_editing) return _infoRow(label, value ?? '—');
    return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppTextStyles.label.copyWith(color: t.textSec)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
              value: value,
              items: options
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: onChanged,
              style: AppTextStyles.bodyMedium.copyWith(color: t.textPrimary),
              dropdownColor: t.surface,
              decoration: InputDecoration(
                  filled: true,
                  fillColor: t.surfaceVar,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: t.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: t.border)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10)))
        ]));
  }

  Widget _emptyMsg(String msg) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child:
          Text(msg, style: AppTextStyles.caption.copyWith(color: t.textTert)));

  Widget _meta(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(children: [
        Icon(icon, size: 13, color: t.textTert),
        const SizedBox(width: 6),
        Expanded(
            child: Text(text,
                style: AppTextStyles.caption
                    .copyWith(color: t.textSec, fontSize: 11)))
      ]));

  Widget _bankCard(Map<String, dynamic> m) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: t.bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: t.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(m['bankName'] ?? 'Bank',
                  style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600, color: t.textPrimary))),
          if (m['isPrimary'] == true)
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(AppRadius.full)),
                child: Text('Primary',
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.success,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)))
        ]),
        const SizedBox(height: 6),
        _meta(Icons.account_balance_outlined,
            'A/c: ${m['accountNumber'] ?? '—'}'),
        _meta(Icons.code_rounded, 'IFSC: ${m['ifscCode'] ?? '—'}'),
        _meta(Icons.person_outline, 'Holder: ${m['accountHolderName'] ?? '—'}'),
        _meta(Icons.credit_card_outlined, 'Type: ${m['accountType'] ?? '—'}'),
      ]));

  Widget _familyCard(Map<String, dynamic> m) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: t.bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: t.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(m['fullName'] ?? '',
                  style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600, color: t.textPrimary))),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(AppRadius.full)),
              child: Text(m['relationship'] ?? '',
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 10)))
        ]),
        const SizedBox(height: 4),
        if (m['dateOfBirth'] != null)
          _meta(Icons.cake_outlined, 'DOB: ${m['dateOfBirth']}'),
        if (m['phone'] != null && m['phone'].toString().isNotEmpty)
          _meta(Icons.phone_outlined, m['phone'].toString()),
        if (m['gender'] != null)
          _meta(Icons.person_outline, m['gender'].toString()),
        if (m['isNominee'] == true)
          _meta(Icons.star_outline_rounded,
              'Nominee — ${m['nomineeSharePercent'] ?? 0}% share'),
        if (m['isDependent'] == true)
          _meta(Icons.family_restroom_rounded, 'Dependent'),
        if (m['isEmergencyContact'] == true)
          _meta(Icons.emergency_rounded, 'Emergency Contact'),
      ]));

  Widget _emergencyCard(Map<String, dynamic> m) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: t.bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: t.border)),
      child: Row(children: [
        Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.emergency_rounded,
                color: AppColors.danger, size: 18)),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m['contactName'] ?? '',
              style: AppTextStyles.bodySmall
                  .copyWith(fontWeight: FontWeight.w600, color: t.textPrimary)),
          Text(
              '${m['relationship'] ?? ''} ${m['isPrimary'] == true ? '· Primary' : ''}',
              style: AppTextStyles.caption.copyWith(color: t.textSec)),
          if (m['phone'] != null)
            Text(m['phone'].toString(),
                style: AppTextStyles.caption.copyWith(color: t.textTert)),
          if (m['email'] != null)
            Text(m['email'].toString(),
                style: AppTextStyles.caption.copyWith(color: t.textTert)),
        ])),
      ]));

  Color _docColor(String type) {
    if (type.contains('AADHAAR')) return AppColors.info;
    if (type.contains('BANK')) return AppColors.success;
    if (type.contains('PAN')) return AppColors.warning;
    return AppColors.accent;
  }

  IconData _docIcon(String type) {
    if (type.contains('AADHAAR')) return Icons.badge_outlined;
    if (type.contains('BANK')) return Icons.account_balance_outlined;
    if (type.contains('PAN')) return Icons.credit_card_outlined;
    return Icons.description_outlined;
  }

  Widget _documentCard(Map<String, dynamic> m) {
    final docType = (m['documentType'] ?? m['type'] ?? '').toString();
    final category = (m['documentCategory'] ?? m['category'] ?? '').toString();
    final fileName =
        (m['originalFilename'] ?? m['fileName'] ?? docType).toString();
    final uploadedAt = (m['createdAt'] ?? m['uploadedAt'] ?? '').toString();
    final docId = m['id'] ?? m['documentId'];
    return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: t.bg,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: t.border)),
        child: Row(children: [
          Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: _docColor(docType).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child:
                  Icon(_docIcon(docType), color: _docColor(docType), size: 20)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(docType,
                    style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600, color: t.textPrimary)),
                Text('$category · $fileName',
                    style: AppTextStyles.caption
                        .copyWith(color: t.textSec, fontSize: 10)),
                if (uploadedAt.length >= 10)
                  Text('Uploaded: ${uploadedAt.substring(0, 10)}',
                      style: AppTextStyles.caption
                          .copyWith(color: t.textTert, fontSize: 10)),
              ])),
          if (docId != null)
            IconButton(
                icon:
                    Icon(Icons.visibility_outlined, color: t.textSec, size: 18),
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (_) => Dialog(
                          child: Container(
                              constraints: const BoxConstraints(
                                  maxWidth: 500, maxHeight: 500),
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12)),
                              child: AuthImage(
                                  url: '/api/v1/documents/$docId/download',
                                  fit: BoxFit.contain,
                                  errorWidget: const Center(
                                      child: Padding(
                                          padding: EdgeInsets.all(32),
                                          child: Text(
                                              'Cannot preview this file type.')))))));
                }),
        ]));
  }
}
