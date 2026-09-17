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
import 'employee_models.dart';

class EmployeeEditPage extends StatefulWidget {
  final int employeeId;
  const EmployeeEditPage({super.key, required this.employeeId});
  @override
  State<EmployeeEditPage> createState() => _EmployeeEditPageState();
}

class _EmployeeEditPageState extends State<EmployeeEditPage>
    with SingleTickerProviderStateMixin {
  final _api = EmployeeApi();
  final t = ThemeController.to;
  late TabController _tabCtrl;

  bool _loading = true, _saving = false, _editing = false;
  String? _error;
  Map<String, dynamic> _data = {};
  List<dynamic> _family = [], _emergency = [], _bank = [], _documents = [];
  String? _photoPath; // relative API path for AuthImage

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
    _tabCtrl = TabController(length: 6, vsync: this);
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
    _fetchAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
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

  Future<void> _fetchAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.getEmployeeById(widget.employeeId);
      _data = (res['data'] ?? res) as Map<String, dynamic>;
      _populateFields();

      // Photo path (relative, for AuthImage)
      final pUrl = _data['profilePhotoUrl'] ?? _data['profilePictureUrl'];
      _photoPath = (pUrl != null && pUrl.toString().isNotEmpty)
          ? pUrl.toString()
          : '/api/v1/employees/${widget.employeeId}/photo';

      // Sub-resources
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
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            backgroundColor: t.surface,
            pinned: true,
            expandedHeight: 210,
            elevation: 0,
            actions: [
              if (_editing) ...[
                TextButton(
                    onPressed: () => setState(() {
                          _editing = false;
                          _populateFields();
                        }),
                    child: Text('Cancel',
                        style: AppTextStyles.buttonMedium
                            .copyWith(color: t.textSec))),
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
            flexibleSpace: FlexibleSpaceBar(
                background: Container(
                    color: t.surface,
                    padding: const EdgeInsets.fromLTRB(16, 84, 16, 50),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Photo (authenticated) ──
                          Container(
                              width: 72,
                              height: 72,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20)),
                              child: AuthImage(
                                  url: _photoPath ??
                                      '/api/v1/employees/${widget.employeeId}/photo',
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  errorWidget: Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF4F46E5),
                                                Color(0xFF7C3AED)
                                              ]),
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      child: Center(
                                          child: Text(_initials,
                                              style: AppTextStyles.headingLarge
                                                  .copyWith(
                                                      color: Colors.white,
                                                      fontSize: 22)))))),
                          const SizedBox(width: 14),
                          // ── Info ──
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                Text(
                                    _fullName.isNotEmpty
                                        ? _fullName
                                        : 'Employee',
                                    style: AppTextStyles.headingMedium
                                        .copyWith(color: t.textPrimary),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text(_empCode,
                                    style: AppTextStyles.caption.copyWith(
                                        color: t.textTert,
                                        fontFamily: 'monospace',
                                        fontSize: 12)),
                                if (_emailCtrl.text.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(_emailCtrl.text,
                                      style: AppTextStyles.caption.copyWith(
                                          color: t.textSec, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ],
                                const SizedBox(height: 6),
                                Wrap(spacing: 8, runSpacing: 4, children: [
                                  StatusBadge(status: _status),
                                  if (_employmentType != null)
                                    Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: AppColors.accentLight,
                                            borderRadius: BorderRadius.circular(
                                                AppRadius.full)),
                                        child: Text(_employmentType!,
                                            style: AppTextStyles.caption
                                                .copyWith(
                                                    color: AppColors.accent,
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.w600))),
                                ]),
                              ])),
                        ]))),
            bottom: TabBar(
                controller: _tabCtrl,
                isScrollable: true,
                labelColor: AppColors.accent,
                unselectedLabelColor: t.textTert,
                indicatorColor: AppColors.accent,
                indicatorWeight: 3,
                labelStyle:
                    AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Personal'),
                  Tab(text: 'Job'),
                  Tab(text: 'Bank & Tax'),
                  Tab(text: 'Family'),
                  Tab(text: 'Emergency'),
                  Tab(text: 'Documents')
                ]),
          ),
        ],
        body: TabBarView(controller: _tabCtrl, children: [
          _personalTab(),
          _jobTab(),
          _bankTab(),
          _familyTab(),
          _emergencyTab(),
          _documentsTab(),
        ]),
      ),
    );
  }

  // ── TABS ──
  Widget _personalTab() =>
      ListView(padding: const EdgeInsets.all(16), children: [
        _sec('Personal Information', [
          _fieldRow('First Name', _firstNameCtrl.text,
              ctrl: _firstNameCtrl, required: true),
          _fieldRow('Last Name', _lastNameCtrl.text, ctrl: _lastNameCtrl),
          _fieldRow('Date of Birth', _dobCtrl.text, ctrl: _dobCtrl),
          _infoOrDd(
              'Gender',
              _gender,
              ['MALE', 'FEMALE', 'OTHER', 'PREFER_NOT_TO_SAY'],
              (v) => setState(() => _gender = v)),
          _fieldRow('Blood Group', _bloodGroupCtrl.text, ctrl: _bloodGroupCtrl),
          _infoOrDd(
              'Marital Status',
              _maritalStatus,
              ['SINGLE', 'MARRIED', 'DIVORCED', 'WIDOWED'],
              (v) => setState(() => _maritalStatus = v)),
          _fieldRow('Phone', _phoneCtrl.text,
              ctrl: _phoneCtrl, keyboard: TextInputType.phone),
          _fieldRow('Email', _emailCtrl.text,
              ctrl: _emailCtrl, keyboard: TextInputType.emailAddress),
          _fieldRow("Father/Husband Name", _fatherNameCtrl.text,
              ctrl: _fatherNameCtrl),
          _fieldRow("Mother's Name", _motherNameCtrl.text,
              ctrl: _motherNameCtrl),
          _fieldRow('Permanent Address', _permanentAddrCtrl.text,
              ctrl: _permanentAddrCtrl, maxLines: 2),
          _fieldRow('Current Address', _currentAddrCtrl.text,
              ctrl: _currentAddrCtrl, maxLines: 2),
        ]),
        if (_editing) ...[const SizedBox(height: 16), _saveBtn()],
      ]);

  Widget _jobTab() => ListView(padding: const EdgeInsets.all(16), children: [
        _sec('Job Details', [
          _infoRow('Employment Type', _employmentType ?? '—'),
          _infoRow('Status', _status),
          _fieldRow('Designation', _designationCtrl.text,
              ctrl: _designationCtrl),
          _fieldRow('Department', _departmentCtrl.text, ctrl: _departmentCtrl),
          _fieldRow('Branch', _branchCtrl.text, ctrl: _branchCtrl),
          _fieldRow('Joining Date', _joiningDateCtrl.text,
              ctrl: _joiningDateCtrl),
          _infoRow(
              'Aadhaar',
              (_data['aadhaarLast4'] ?? _data['aadhaarNumber'] ?? '—')
                  .toString()),
        ]),
      ]);

  Widget _bankTab() => ListView(padding: const EdgeInsets.all(16), children: [
        _sec('Statutory', [
          _fieldRow('PAN', _panCtrl.text, ctrl: _panCtrl),
          _fieldRow('UAN', _uanCtrl.text, ctrl: _uanCtrl),
          _fieldRow('PF Account', _pfCtrl.text, ctrl: _pfCtrl),
          _fieldRow('ESIC', _esicCtrl.text, ctrl: _esicCtrl),
        ]),
        const SizedBox(height: 12),
        if (_bank.isNotEmpty)
          _sec(
              'Bank Accounts',
              _bank.map((b) {
                final bm = b as Map<String, dynamic>;
                return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: t.bg,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: t.border)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(bm['bankName'] ?? 'Bank',
                                  style: AppTextStyles.bodySmall.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: t.textPrimary)),
                              const SizedBox(height: 4),
                              _infoRow('Account',
                                  bm['accountNumber']?.toString() ?? '—'),
                              _infoRow(
                                  'IFSC', bm['ifscCode']?.toString() ?? '—'),
                              _infoRow(
                                  'Type', bm['accountType']?.toString() ?? '—'),
                              _infoRow('Holder',
                                  bm['accountHolderName']?.toString() ?? '—'),
                              if (bm['isPrimary'] == true)
                                Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: AppColors.successLight,
                                            borderRadius: BorderRadius.circular(
                                                AppRadius.full)),
                                        child: Text('Primary',
                                            style: AppTextStyles.caption
                                                .copyWith(
                                                    color: AppColors.success,
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.w600)))),
                            ])));
              }).toList())
        else
          Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No bank accounts on file.',
                  style: AppTextStyles.bodySmall.copyWith(color: t.textTert))),
      ]);

  Widget _familyTab() => ListView(padding: const EdgeInsets.all(16), children: [
        if (_family.isEmpty)
          _emptyState('No family members on file.')
        else
          ..._family.map((f) {
            final m = f as Map<String, dynamic>;
            return _card([
              Row(children: [
                Expanded(
                    child: Text(m['fullName'] ?? '',
                        style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: t.textPrimary))),
                _pill(m['relationship'] ?? ''),
              ]),
              const SizedBox(height: 8),
              if (m['dateOfBirth'] != null)
                _meta(Icons.cake_outlined, 'DOB: ${m['dateOfBirth']}'),
              if (m['phone'] != null && m['phone'].toString().isNotEmpty)
                _meta(Icons.phone_outlined, m['phone'].toString()),
              if (m['email'] != null && m['email'].toString().isNotEmpty)
                _meta(Icons.email_outlined, m['email'].toString()),
              if (m['gender'] != null)
                _meta(Icons.person_outline, m['gender'].toString()),
              if (m['isNominee'] == true)
                _meta(Icons.star_outline_rounded,
                    'Nominee — ${m['nomineeSharePercent'] ?? 0}% share'),
              if (m['isDependent'] == true)
                _meta(Icons.family_restroom_rounded, 'Dependent'),
              if (m['isEmergencyContact'] == true)
                _meta(Icons.emergency_rounded, 'Emergency Contact'),
              if (m['aadhaarNumber'] != null)
                _meta(Icons.badge_outlined, 'Aadhaar: ${m['aadhaarNumber']}'),
            ]);
          }),
      ]);

  Widget _emergencyTab() =>
      ListView(padding: const EdgeInsets.all(16), children: [
        if (_emergency.isEmpty)
          _emptyState('No emergency contacts on file.')
        else
          ..._emergency.map((c) {
            final m = c as Map<String, dynamic>;
            return _card([
              Row(children: [
                Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.emergency_rounded,
                        color: AppColors.danger, size: 20)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(m['contactName'] ?? '',
                          style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: t.textPrimary)),
                      Text(
                          '${m['relationship'] ?? ''} ${m['isPrimary'] == true ? '· Primary' : ''}',
                          style:
                              AppTextStyles.caption.copyWith(color: t.textSec)),
                    ])),
              ]),
              if (m['phone'] != null)
                _meta(Icons.phone_outlined, m['phone'].toString()),
              if (m['email'] != null)
                _meta(Icons.email_outlined, m['email'].toString()),
            ]);
          }),
      ]);

  Widget _documentsTab() =>
      ListView(padding: const EdgeInsets.all(16), children: [
        if (_documents.isEmpty)
          _emptyState('No documents on file.')
        else
          ..._documents.map((d) {
            final m = d as Map<String, dynamic>;
            final docType = (m['documentType'] ?? m['type'] ?? '').toString();
            final category =
                (m['documentCategory'] ?? m['category'] ?? '').toString();
            final fileName =
                (m['originalFilename'] ?? m['fileName'] ?? docType).toString();
            final uploadedAt =
                (m['createdAt'] ?? m['uploadedAt'] ?? '').toString();
            final docId = m['id'] ?? m['documentId'];
            return _card([
              Row(children: [
                Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: _docColor(docType).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(_docIcon(docType),
                        color: _docColor(docType), size: 22)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(docType,
                          style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: t.textPrimary)),
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
                      icon: Icon(Icons.visibility_outlined,
                          color: t.textSec, size: 18),
                      onPressed: () {
                        showDialog(
                            context: context,
                            builder: (_) => Dialog(
                                child: Container(
                                    constraints: const BoxConstraints(
                                        maxWidth: 500, maxHeight: 500),
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: AuthImage(
                                        url:
                                            '/api/v1/documents/$docId/download',
                                        fit: BoxFit.contain,
                                        errorWidget: const Center(
                                            child: Padding(
                                                padding: EdgeInsets.all(32),
                                                child: Text(
                                                    'Cannot preview this file type.')))))));
                      }),
              ]),
            ]);
          }),
      ]);

  // ── Helpers ──
  Widget _meta(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        Icon(icon, size: 13, color: t.textTert),
        const SizedBox(width: 6),
        Expanded(
            child: Text(text,
                style: AppTextStyles.caption
                    .copyWith(color: t.textSec, fontSize: 11)))
      ]));

  Widget _pill(String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: AppColors.accentLight,
          borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Text(label,
          style: AppTextStyles.caption.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
              fontSize: 10)));

  Widget _card(List<Widget> children) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: t.border),
          boxShadow: t.cardShadow),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children));

  Widget _emptyState(String msg) => Center(
      child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(msg,
              style: AppTextStyles.bodySmall.copyWith(color: t.textTert))));

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

  Widget _saveBtn() => SizedBox(
      width: double.infinity,
      child: ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
              elevation: 0),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text('Save Changes',
                  style: AppTextStyles.buttonLarge
                      .copyWith(color: Colors.white))));

  Widget _sec(String title, List<Widget> children) => Container(
      decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: t.border),
          boxShadow: t.cardShadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.06),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.lg - 1),
                    topRight: Radius.circular(AppRadius.lg - 1)),
                border: Border(bottom: BorderSide(color: t.border))),
            child: Row(children: [
              Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text(title,
                  style: AppTextStyles.headingSmall
                      .copyWith(color: AppColors.accent))
            ])),
        Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children)),
      ]));

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

  Widget _fieldRow(String label, String displayValue,
      {TextEditingController? ctrl,
      bool required = false,
      TextInputType? keyboard,
      int maxLines = 1}) {
    if (!_editing)
      return _infoRow(label, displayValue.isNotEmpty ? displayValue : '—');
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

  Widget _infoOrDd(String label, String? value, List<String> options,
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
}
