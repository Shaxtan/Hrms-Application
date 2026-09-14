import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../../data/employee_api.dart';
import '../../domain/employee_models.dart';
import '../../../../core/constants/employment_requirements.dart';

class AddEmployeeController extends GetxController {
  final EmployeeApi _api = EmployeeApi();

  final formKey = GlobalKey<FormState>();

  // ── Sections ──────────────────────────────────────────────────────────────
  final expandedSections = <int>{0, 1}.obs;

  // ── Employment type ───────────────────────────────────────────────────────
  final employmentType = 'CONTRACT'.obs;

  // ── Identity ──────────────────────────────────────────────────────────────
  final aadhaarController = TextEditingController();
  final aadhaarConsentGiven = false.obs;
  final aadhaarCheckState = 'IDLE'.obs;
  final aadhaarCheckResult = Rxn<Map<String, dynamic>>();
  Timer? _aadhaarDebounce;

  // ── Personal Info ─────────────────────────────────────────────────────────
  final fullNameController        = TextEditingController();
  final fatherHusbandNameController = TextEditingController();
  final motherNameController      = TextEditingController();
  final emailController           = TextEditingController();
  final phoneController           = TextEditingController();
  final secondaryPhoneController  = TextEditingController();
  final dobController             = TextEditingController();
  final genderValue               = ''.obs;
  final maritalStatusValue        = ''.obs;
  final bloodGroupController      = TextEditingController();
  final casteController           = TextEditingController();
  final permanentAddressController = TextEditingController();
  final currentAddressController  = TextEditingController();
  final customCodeController      = TextEditingController();

  bool _currentAddressTouched = false;

  // ── Job Details ───────────────────────────────────────────────────────────
  final joiningDateController      = TextEditingController();
  final confirmationDateController = TextEditingController();
  bool _confirmationTouched = false;

  final selectedClientId      = Rxn<int>();
  final selectedBranchId      = Rxn<int>();
  final selectedDepartmentId  = Rxn<int>();
  final selectedDesignationId = Rxn<int>();

  // ── Bank & Tax ────────────────────────────────────────────────────────────
  final bankAccountController = TextEditingController();
  final bankNameValue         = ''.obs;
  final ifscController        = TextEditingController();
  final panController         = TextEditingController();
  final uanController         = TextEditingController();
  final pfController          = TextEditingController();
  final esicController        = TextEditingController();

  // ── Files ─────────────────────────────────────────────────────────────────
  final profilePicture = Rxn<File>();
  final documents      = <String, File>{}.obs;

  // ── Dropdown data ──────────────────────────────────────────────────────────
  final clients          = <ClientCompany>[].obs;
  final branches         = <Branch>[].obs;
  final departments      = <Department>[].obs;
  final designations     = <Designation>[].obs;
  final loadingDropdowns = false.obs;

  // ── Submission ────────────────────────────────────────────────────────────
  final submitting         = false.obs;
  final stepResults        = <String, StepResult>{}.obs;
  final provisionalEmpId   = Rxn<int>();
  final createdEmpId       = Rxn<int>();
  final createdEmployee    = Rxn<Map<String, dynamic>>();
  final requiredDocFailures = <String>[].obs;
  final discarding         = false.obs;
  final showSuccessModal   = false.obs;

  // ── Live validation ───────────────────────────────────────────────────────
  final missingFields = <String>[].obs;
  final missingDocs   = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    _loadDropdowns();

    ever(employmentType, (_) => recomputeMissing());
    ever(selectedClientId, (_) {
      selectedBranchId.value    = null;
      selectedDepartmentId.value = null;
      recomputeMissing();
    });
    ever(documents,     (_) => recomputeMissing());
    ever(profilePicture, (_) => recomputeMissing());

    // Permanent → current address mirror
    permanentAddressController.addListener(() {
      if (!_currentAddressTouched) {
        currentAddressController.text = permanentAddressController.text;
      }
    });

    // Joining → confirmation (+6 months) auto-fill
    joiningDateController.addListener(() {
      if (_confirmationTouched) return;
      final raw = joiningDateController.text;
      if (raw.isEmpty) return;
      final joining = DateTime.tryParse(raw);
      if (joining == null) return;
      final confirm = DateTime(joining.year, joining.month + 6, joining.day);
      confirmationDateController.text =
          '${confirm.year}-'
          '${confirm.month.toString().padLeft(2, '0')}-'
          '${confirm.day.toString().padLeft(2, '0')}';
    });

    aadhaarController.addListener(_onAadhaarChanged);
  }

  @override
  void onClose() {
    _aadhaarDebounce?.cancel();
    for (final c in [
      aadhaarController, fullNameController, fatherHusbandNameController,
      motherNameController, emailController, phoneController,
      secondaryPhoneController, dobController, bloodGroupController,
      casteController, permanentAddressController, currentAddressController,
      customCodeController, joiningDateController, confirmationDateController,
      bankAccountController, ifscController, panController,
      uanController, pfController, esicController,
    ]) {
      c.dispose();
    }
    super.onClose();
  }

  // ── Dropdowns ─────────────────────────────────────────────────────────────
  Future<void> _loadDropdowns() async {
    loadingDropdowns.value = true;
    try {
      final results = await Future.wait([
        _api.getClientCompanies(),
        _api.getBranches(),
        _api.getDesignations(),
      ]);
      clients.value     = results[0] as List<ClientCompany>;
      branches.value    = results[1] as List<Branch>;
      designations.value = results[2] as List<Designation>;
    } catch (_) {
      // Non-fatal — dropdowns stay empty
    } finally {
      loadingDropdowns.value = false;
    }
  }

  Future<void> loadDepartmentsForClient(int clientId) async {
    try {
      final all = await _api.getDepartments();
      departments.value = all
          .where((d) => d.clientCompanyId == null || d.clientCompanyId == clientId)
          .toList();
    } catch (_) {
      departments.value = [];
    }
  }

  List<Branch> get filteredBranches => selectedClientId.value == null
      ? []
      : branches.where((b) => b.clientCompanyId == selectedClientId.value).toList();

  List<Designation> get filteredDesignations {
    final cid = selectedClientId.value;
    return designations
        .where((d) => d.clientCompanyId == null || d.clientCompanyId == cid)
        .toList();
  }

  // ── Aadhaar live check ────────────────────────────────────────────────────
  void _onAadhaarChanged() {
    _aadhaarDebounce?.cancel();
    aadhaarConsentGiven.value = false;
    final val = aadhaarController.text;
    if (val.length != 12 || !RegExp(r'^\d{12}$').hasMatch(val)) {
      aadhaarCheckState.value  = 'IDLE';
      aadhaarCheckResult.value = null;
      recomputeMissing();
      return;
    }
    aadhaarCheckState.value = 'CHECKING';
    _aadhaarDebounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        final res     = await _api.checkAadhaar(val);
        final payload = res['data'] as Map<String, dynamic>? ?? {};
        if (!(payload['exists'] as bool? ?? false)) {
          aadhaarCheckState.value  = 'NONE';
          aadhaarCheckResult.value = null;
        } else {
          aadhaarCheckState.value  = payload['collisionCase'] ?? 'NONE';
          aadhaarCheckResult.value = payload['existing'] as Map<String, dynamic>?;
        }
      } catch (_) {
        aadhaarCheckState.value = 'ERROR';
      }
    });
  }

  void dismissAadhaarCheck() {
    aadhaarCheckState.value  = 'IDLE';
    aadhaarCheckResult.value = null;
  }

  void clearAadhaar() {
    aadhaarController.clear();
    aadhaarCheckState.value   = 'IDLE';
    aadhaarCheckResult.value  = null;
    aadhaarConsentGiven.value = false;
  }

  // ── Missing-fields recompute (PUBLIC — called from pages) ─────────────────
  void recomputeMissing() {
    final type     = employmentType.value;
    final hasClient = selectedClientId.value != null;

    final fieldValues = <String, String>{
      'aadhaarNumber':     aadhaarController.text,
      'fullName':          fullNameController.text,
      'fatherHusbandName': fatherHusbandNameController.text,
      'motherName':        motherNameController.text,
      'email':             emailController.text,
      'phone':             phoneController.text,
      'secondaryPhone':    secondaryPhoneController.text,
      'dateOfBirth':       dobController.text,
      'gender':            genderValue.value,
      'maritalStatus':     maritalStatusValue.value,
      'bloodGroup':        bloodGroupController.text,
      'caste':             casteController.text,
      'permanentAddress':  permanentAddressController.text,
      'currentAddress':    currentAddressController.text,
      'joiningDate':       joiningDateController.text,
      'clientCompanyId':   selectedClientId.value?.toString()     ?? '',
      'branchId':          selectedBranchId.value?.toString()     ?? '',
      'departmentId':      selectedDepartmentId.value?.toString() ?? '',
      'designationId':     selectedDesignationId.value?.toString() ?? '',
      'bankName':          bankNameValue.value,
      'bankAccountNumber': bankAccountController.text,
      'ifscCode':          ifscController.text,
      'pan':               panController.text,
    };

    missingFields.value = requiredFieldKeys(type, hasClient: hasClient)
        .where((key) {
          if (key == 'familyDetails') return false;
          return (fieldValues[key] ?? '').trim().isEmpty;
        })
        .toList();

    final reqDocs = <String>{...requiredDocKeys(type)};
    if (panController.text.trim().isNotEmpty) reqDocs.add('PAN_CARD');

    missingDocs.value = reqDocs.where((docKey) {
      if (docKey == 'PHOTO') return profilePicture.value == null;
      return !documents.containsKey(docKey);
    }).toList();
  }

  bool get aadhaarConsentMissing =>
      aadhaarController.text.length == 12 && !aadhaarConsentGiven.value;

  bool get canSubmit =>
      missingFields.isEmpty &&
      missingDocs.isEmpty &&
      !aadhaarConsentMissing &&
      !submitting.value &&
      aadhaarCheckState.value != 'ACTIVE_DUPLICATE' &&
      aadhaarCheckState.value != 'PENDING_DUPLICATE';

  // ── Section toggle ────────────────────────────────────────────────────────
  void toggleSection(int index) {
    if (expandedSections.contains(index)) {
      expandedSections.remove(index);
    } else {
      expandedSections.add(index);
    }
  }

  void markCurrentAddressTouched() => _currentAddressTouched = true;
  void markConfirmationTouched()   => _confirmationTouched = true;

  void setDocument(String key, File file) {
    documents[key] = file;
    recomputeMissing();
  }

  void clearDocument(String key) {
    documents.remove(key);
    recomputeMissing();
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> submit() async {
    recomputeMissing();
    if (!canSubmit) return;

    submitting.value = true;
    stepResults.clear();
    createdEmpId.value     = null;
    provisionalEmpId.value = null;
    requiredDocFailures.value = [];

    final fullName  = fullNameController.text.trim();
    final parts     = fullName.split(' ');
    final firstName = parts.first;
    final lastName  = parts.length > 1 ? parts.skip(1).join(' ') : '';

    final placement = selectedClientId.value != null
        ? {
            'clientCompanyId': selectedClientId.value,
            'branchId':        selectedBranchId.value,
            'departmentId':    selectedDepartmentId.value,
            'startDate':       joiningDateController.text.isNotEmpty
                ? joiningDateController.text
                : null,
          }
        : null;

    final payload = <String, dynamic>{
      'firstName':          firstName,
      'lastName':           lastName,
      'customCode':         customCodeController.text.trim().isEmpty ? null : customCodeController.text.trim(),
      'email':              emailController.text.trim().isEmpty ? null : emailController.text.trim(),
      'phone':              phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
      'dateOfBirth':        dobController.text.isEmpty ? null : dobController.text,
      'gender':             genderValue.value.isEmpty ? null : genderValue.value,
      'bloodGroup':         bloodGroupController.text.isEmpty ? null : bloodGroupController.text,
      'maritalStatus':      maritalStatusValue.value.isEmpty ? null : maritalStatusValue.value,
      'fatherHusbandName':  fatherHusbandNameController.text.isEmpty ? null : fatherHusbandNameController.text,
      'motherName':         motherNameController.text.isEmpty ? null : motherNameController.text,
      'secondaryPhone':     secondaryPhoneController.text.isEmpty ? null : secondaryPhoneController.text,
      'caste':              casteController.text.isEmpty ? null : casteController.text,
      'permanentAddress':   permanentAddressController.text.isEmpty ? null : permanentAddressController.text,
      'currentAddress':     currentAddressController.text.isEmpty ? null : currentAddressController.text,
      'employmentType':     employmentType.value,
      'joiningDate':        joiningDateController.text,
      'confirmationDate':   confirmationDateController.text.isEmpty ? null : confirmationDateController.text,
      'designationId':      selectedDesignationId.value,
      'aadhaarNumber':      aadhaarController.text,
      'aadhaarConsentGiven': aadhaarConsentGiven.value,
      'aadhaarLast4':       null,
      'pan':                panController.text.isEmpty ? null : panController.text,
      'uan':                uanController.text.isEmpty ? null : uanController.text,
      'pfAccountNumber':    pfController.text.isEmpty ? null : pfController.text,
      'esicNumber':         esicController.text.isEmpty ? null : esicController.text,
      if (placement != null) 'placement': placement,
    };

    // ── Step A: Create core record ────────────────────────────────────────
    _setStep('core', 'Create employee record', StepStatus.running);
    int? newId;
    bool pendingApproval = false;

    try {
      final res  = await _api.createEmployee(payload);
      final data = res['data'] as Map<String, dynamic>? ?? {};
      newId            = (data['employeeId'] ?? data['id']) as int?;
      pendingApproval  = data['status'] == 'PENDING_APPROVAL';
      provisionalEmpId.value = newId;
      createdEmpId.value     = newId;

      createdEmployee.value = {
        'firstName':    data['firstName']    ?? firstName,
        'lastName':     data['lastName']     ?? lastName,
        'email':        payload['email'],
        'mobile':       payload['phone'],
        'employeeCode': data['employeeCode'],
        'tempPassword': data['tempPassword'],
        'status':       data['status'],
      };

      _setStep('core',
          pendingApproval ? 'Submit for approval' : 'Create employee record',
          StepStatus.success);
    } on DioException catch (e) {
      final msg = (e.response?.data as Map?)?['message'] as String? ??
          (e.response?.statusCode == 409
              ? 'Email already in use.'
              : 'Failed to create employee.');
      _setStep('core', 'Create employee record', StepStatus.failed, error: msg);
      submitting.value = false;
      Get.snackbar('Error', msg,
          backgroundColor: const Color(0xFFDC2626), colorText: Colors.white);
      return;
    }

    if (newId == null) { submitting.value = false; return; }

    // ── Step B: Bank account ──────────────────────────────────────────────
    if (bankAccountController.text.isNotEmpty) {
      await _runStep('bank', 'Add bank account', () => _api.addBankAccount(newId!, {
        'accountHolderName': fullName,
        'accountNumber':     bankAccountController.text,
        'bankName':          bankNameValue.value,
        'ifscCode':          ifscController.text,
        'accountType':       'SAVINGS',
        'isPrimary':         true,
      }));
    } else {
      _setStep('bank', 'Add bank account', StepStatus.skipped);
    }

    // ── Step C: Profile photo ─────────────────────────────────────────────
    if (profilePicture.value != null) {
      await _runStep('photo', 'Upload profile photo',
          () => _api.uploadProfilePicture(newId!, profilePicture.value!));
    } else {
      _setStep('photo', 'Upload profile photo', StepStatus.skipped);
    }

    // ── Step D: Documents ─────────────────────────────────────────────────
    final docSlotDefs = [
      {'key': 'AADHAAR_FRONT', 'category': 'IDENTITY',    'type': 'AADHAAR_FRONT', 'label': 'Aadhaar (Front)'},
      {'key': 'AADHAAR_BACK',  'category': 'IDENTITY',    'type': 'AADHAAR_BACK',  'label': 'Aadhaar (Back)'},
      {'key': 'PAN_CARD',      'category': 'IDENTITY',    'type': 'PAN_CARD',      'label': 'PAN Card'},
      {'key': 'BANK_PROOF',    'category': 'OTHER',       'type': 'BANK_PROOF',    'label': 'Bank Proof'},
      {'key': 'OFFER_LETTER',  'category': 'EMPLOYMENT',  'type': 'OFFER_LETTER',  'label': 'Offer Letter'},
      {'key': 'MARK_SHEET',    'category': 'EDUCATION',   'type': 'MARK_SHEET',    'label': 'Mark Sheet'},
      {'key': 'SIGNATURE',     'category': 'OTHER',       'type': 'SIGNATURE',     'label': 'Signature'},
    ];

    for (final slot in docSlotDefs) {
      final file     = documents[slot['key']];
      final stepKey  = 'doc_${slot['key']}';
      final stepLabel = 'Upload ${slot['label']}';
      if (file != null) {
        await _runStep(stepKey, stepLabel, () => _api.uploadDocument(
          employeeId:       newId!,
          documentCategory: slot['category']!,
          documentType:     slot['type']!,
          file:             file,
        ));
      } else {
        _setStep(stepKey, stepLabel, StepStatus.skipped);
      }
    }

    // ── Check required doc failures ───────────────────────────────────────
    final type    = employmentType.value;
    final reqDocs = <String>{...requiredDocKeys(type)};
    if (panController.text.trim().isNotEmpty) reqDocs.add('PAN_CARD');

    final failed = reqDocs.where((docKey) {
      final stepKey = docKey == 'PHOTO' ? 'photo' : 'doc_$docKey';
      return stepResults[stepKey]?.status != StepStatus.success;
    }).toList();

    if (failed.isNotEmpty) {
      requiredDocFailures.value = failed;
      submitting.value = false;
      return;
    }

    // ── Finalize ──────────────────────────────────────────────────────────
    try {
      final fin     = await _api.finalizeEmployeeCreation(newId);
      final finData = fin['data'] as Map<String, dynamic>? ?? {};
      provisionalEmpId.value    = null;
      requiredDocFailures.value = [];
      createdEmployee.update((emp) {
        if (emp == null) return;
        emp['employeeCode'] = finData['employeeCode'] ?? emp['employeeCode'];
        emp['tempPassword'] = finData['tempPassword'];
        emp['status']       = finData['status'] ?? emp['status'];
      });
    } catch (e) {
      requiredDocFailures.value = reqDocs.toList();
      submitting.value = false;
      return;
    }

    submitting.value = false;

    if (pendingApproval) {
      Get.back();
      Get.snackbar('Submitted', 'Employee submitted for approval.',
          backgroundColor: const Color(0xFF059669), colorText: Colors.white);
    } else {
      showSuccessModal.value = true;
      _showSuccessSheet();
    }
  }

  void _showSuccessSheet() {
    final emp  = createdEmployee.value;
    final name = '${emp?['firstName'] ?? ''} ${emp?['lastName'] ?? ''}'.trim();
    final code = emp?['employeeCode'] as String? ?? '—';
    final pass = emp?['tempPassword'] as String?;

    Get.bottomSheet(
      isDismissible: false,
      Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFFFF),
          borderRadius: BorderRadius.only(
            topLeft:  Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(100))),
            const SizedBox(height: 24),
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(32)),
              child: const Icon(Icons.check_rounded,
                  color: Color(0xFF059669), size: 32),
            ),
            const SizedBox(height: 16),
            Text('Employee Created!',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A))),
            const SizedBox(height: 6),
            Text(name,
                style: const TextStyle(fontSize: 16, color: Color(0xFF334155))),
            const SizedBox(height: 4),
            Text('Code: $code',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            if (pass != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.2))),
                child: Row(children: [
                  const Icon(Icons.key_rounded, color: Color(0xFF4F46E5), size: 18),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Temporary Password',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    Text(pass,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: Color(0xFF4F46E5), letterSpacing: 1)),
                  ]),
                ]),
              ),
              const SizedBox(height: 8),
              const Text('Share this password securely with the employee.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () { Get.back(); Get.back(); },
                child: const Text('Done',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runStep(
    String key, String label, Future<dynamic> Function() action) async {
    _setStep(key, label, StepStatus.running);
    try {
      await action();
      _setStep(key, label, StepStatus.success);
    } catch (e) {
      final msg = e is DioException
          ? ((e.response?.data as Map?)?['message'] as String? ?? e.message ?? 'Failed')
          : e.toString();
      _setStep(key, label, StepStatus.failed, error: msg);
    }
  }

  void _setStep(String key, String label, StepStatus status, {String? error}) {
    stepResults[key] = StepResult(label: label, status: status, error: error);
  }

  Future<void> discardAttempt() async {
    final id = provisionalEmpId.value;
    if (id == null) return;
    discarding.value = true;
    try {
      await _api.discardEmployeeCreation(id);
      provisionalEmpId.value   = null;
      createdEmpId.value        = null;
      stepResults.clear();
      requiredDocFailures.value = [];
      Get.back();
      Get.snackbar('Cancelled', 'Employee creation discarded.',
          backgroundColor: const Color(0xFF64748B), colorText: Colors.white);
    } catch (_) {
      Get.back();
    } finally {
      discarding.value = false;
    }
  }
}
