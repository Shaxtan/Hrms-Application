import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/employment_requirements.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../data/employee_api.dart';
import '../../domain/employee_models.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CONTROLLER — real API: multi-step create + side-steps
// ═══════════════════════════════════════════════════════════════════════════════
class AddEmployeeController extends GetxController {
  final formKey = GlobalKey<FormState>();

  final expandedSections = <int>{0, 1}.obs;
  final employmentType = 'CONTRACT'.obs;
  final aadhaarConsentGiven = false.obs;
  final genderValue = ''.obs;
  final maritalStatusValue = ''.obs;
  final bankNameValue = ''.obs;
  final profilePicture = Rxn<File>();
  final profilePictureBytes = Rxn<List<int>>(); // web-safe raw bytes
  final profilePictureName = ''.obs;
  final documents = <String, File>{}.obs;
  final documentBytes = <String, List<int>>{}.obs; // web-safe raw bytes
  final documentNames = <String, String>{}.obs;
  final submitting = false.obs;
  final missingFields = <String>[].obs;
  final missingDocs = <String>[].obs;

  // Family members (staged locally until submit)
  final familyMembers = <Map<String, dynamic>>[].obs;
  // Emergency contacts (staged locally until submit)
  final emergencyContacts = <Map<String, dynamic>>[].obs;
  // Step results for progress display
  final stepResults = <String, Map<String, dynamic>>{}.obs;
  final createdEmployeeId = Rxn<int>();
  final createdEmployee = Rxn<Map<String, dynamic>>();

  final _api = EmployeeApi();

  // Text controllers
  // ── Job Details dropdowns (API-driven) ────────────────────────────────────
  final clients = <ClientCompany>[].obs;
  final branches = <Branch>[].obs;
  final departments = <Department>[].obs;
  final designations = <Designation>[].obs;
  final loadingDropdowns = false.obs;
  final loadingBranchDepts = false.obs;
  final selectedClientId = Rxn<int>();
  final selectedBranchId = Rxn<int>();
  final selectedDepartmentId = Rxn<int>();
  final selectedDesignationId = Rxn<int>();

  final aadhaarController = TextEditingController();
  final fullNameController = TextEditingController();
  final fatherHusbandNameController = TextEditingController();
  final motherNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final secondaryPhoneController = TextEditingController();
  final dobController = TextEditingController();
  final bloodGroupController = TextEditingController();
  final casteController = TextEditingController();
  final permanentAddressController = TextEditingController();
  final currentAddressController = TextEditingController();
  final joiningDateController = TextEditingController();
  final confirmationDateController = TextEditingController();
  final clientController = TextEditingController();
  final branchController = TextEditingController();
  final departmentController = TextEditingController();
  final designationController = TextEditingController();
  final bankAccountController = TextEditingController();
  final ifscController = TextEditingController();
  final panController = TextEditingController();
  final uanController = TextEditingController();
  final pfController = TextEditingController();
  final esicController = TextEditingController();

  bool _currentAddressTouched = false;
  bool _confirmationTouched = false;

  @override
  void onInit() {
    super.onInit();
    ever(employmentType, (_) => recomputeMissing());
    ever(documents, (_) => recomputeMissing());
    ever(profilePicture, (_) => recomputeMissing());
    ever(genderValue, (_) => recomputeMissing());
    ever(maritalStatusValue, (_) => recomputeMissing());
    ever(bankNameValue, (_) => recomputeMissing());
    ever(aadhaarConsentGiven, (_) => recomputeMissing());

    // ── Job Details reactive wiring ────────────────────────────────────────
    _loadDropdowns();
    ever<int?>(selectedClientId, (id) {
      // Client changed → clear dependent selections
      selectedBranchId.value = null;
      selectedDepartmentId.value = null;
      departments.clear();
      clientController.text = _lookupClientName(id);
      recomputeMissing();
    });
    ever<int?>(selectedBranchId, (id) {
      selectedDepartmentId.value = null;
      departments.clear();
      branchController.text = _lookupBranchName(id);
      if (id != null) _loadEffectiveDepartments(id);
      recomputeMissing();
    });
    ever<int?>(selectedDepartmentId, (id) {
      departmentController.text = _lookupDepartmentName(id);
      recomputeMissing();
    });
    ever<int?>(selectedDesignationId, (id) {
      designationController.text = _lookupDesignationName(id);
      recomputeMissing();
    });

    permanentAddressController.addListener(() {
      if (!_currentAddressTouched) {
        currentAddressController.text = permanentAddressController.text;
      }
    });

    joiningDateController.addListener(() {
      if (_confirmationTouched) return;
      final joining = DateTime.tryParse(joiningDateController.text);
      if (joining == null) return;
      final confirm = DateTime(joining.year, joining.month + 6, joining.day);
      confirmationDateController.text =
          '${confirm.year}-${confirm.month.toString().padLeft(2, '0')}-'
          '${confirm.day.toString().padLeft(2, '0')}';
    });
  }

  @override
  void onClose() {
    for (final c in [
      aadhaarController,
      fullNameController,
      fatherHusbandNameController,
      motherNameController,
      emailController,
      phoneController,
      secondaryPhoneController,
      dobController,
      bloodGroupController,
      casteController,
      permanentAddressController,
      currentAddressController,
      joiningDateController,
      confirmationDateController,
      clientController,
      branchController,
      departmentController,
      designationController,
      bankAccountController,
      ifscController,
      panController,
      uanController,
      pfController,
      esicController,
    ]) {
      c.dispose();
    }
    super.onClose();
  }

  void toggleSection(int i) {
    if (expandedSections.contains(i)) {
      expandedSections.remove(i);
    } else {
      expandedSections.add(i);
    }
  }

  // ── Dropdown loaders ──────────────────────────────────────────────────────
  Future<void> _loadDropdowns() async {
    loadingDropdowns.value = true;
    try {
      final results = await Future.wait([
        _api.getClientCompanies(),
        _api.getBranches(),
        _api.getDesignations(),
      ]);
      clients.assignAll(results[0] as List<ClientCompany>);
      branches.assignAll(results[1] as List<Branch>);
      designations.assignAll(results[2] as List<Designation>);
    } catch (_) {
      // Non-fatal — dropdowns just stay empty and user gets an empty menu
    } finally {
      loadingDropdowns.value = false;
    }
  }

  Future<void> _loadEffectiveDepartments(int branchId) async {
    loadingBranchDepts.value = true;
    try {
      departments.assignAll(await _api.getEffectiveDepartments(branchId));
    } catch (_) {
      departments.clear();
    } finally {
      loadingBranchDepts.value = false;
    }
  }

  // Filter branches by the selected client company
  List<Branch> get filteredBranches {
    final cid = selectedClientId.value;
    if (cid == null) return const [];
    return branches.where((b) => b.clientCompanyId == cid).toList();
  }

  // Global designations + those scoped to selected client
  List<Designation> get filteredDesignations {
    final cid = selectedClientId.value;
    return designations
        .where((d) => d.clientCompanyId == null || d.clientCompanyId == cid)
        .toList();
  }

  // ── Lookup helpers (avoid package:collection dependency) ──────────────────
  String _lookupClientName(int? id) {
    if (id == null) return '';
    for (final c in clients) {
      if (c.id == id) return c.clientName;
    }
    return '';
  }

  String _lookupBranchName(int? id) {
    if (id == null) return '';
    for (final b in branches) {
      if (b.id == id) return b.branchName;
    }
    return '';
  }

  String _lookupDepartmentName(int? id) {
    if (id == null) return '';
    for (final d in departments) {
      if (d.id == id) return d.departmentName;
    }
    return '';
  }

  String _lookupDesignationName(int? id) {
    if (id == null) return '';
    for (final d in designations) {
      if (d.id == id) return d.designationName;
    }
    return '';
  }

  void markCurrentAddressTouched() => _currentAddressTouched = true;
  void markConfirmationTouched() => _confirmationTouched = true;

  void setDocument(String key, File file) => documents[key] = file;
  void setDocumentBytes(String key, List<int> bytes, String name) {
    documentBytes[key] = bytes;
    documentNames[key] = name;
  }

  void clearDocument(String key) {
    documents.remove(key);
    documentBytes.remove(key);
    documentNames.remove(key);
  }

  bool get aadhaarConsentMissing =>
      aadhaarController.text.length == 12 && !aadhaarConsentGiven.value;

  bool get canSubmit =>
      missingFields.isEmpty &&
      missingDocs.isEmpty &&
      !aadhaarConsentMissing &&
      !submitting.value;

  void recomputeMissing() {
    final type = employmentType.value;
    final hasClient = selectedClientId.value != null;

    final vals = <String, String>{
      'aadhaarNumber': aadhaarController.text,
      'fullName': fullNameController.text,
      'fatherHusbandName': fatherHusbandNameController.text,
      'motherName': motherNameController.text,
      'email': emailController.text,
      'phone': phoneController.text,
      'secondaryPhone': secondaryPhoneController.text,
      'dateOfBirth': dobController.text,
      'gender': genderValue.value,
      'maritalStatus': maritalStatusValue.value,
      'bloodGroup': bloodGroupController.text,
      'caste': casteController.text,
      'permanentAddress': permanentAddressController.text,
      'currentAddress': currentAddressController.text,
      'joiningDate': joiningDateController.text,
      'clientCompanyId': selectedClientId.value?.toString() ?? '',
      'branchId': selectedBranchId.value?.toString() ?? '',
      'departmentId': selectedDepartmentId.value?.toString() ?? '',
      'designationId': selectedDesignationId.value?.toString() ?? '',
      'bankName': bankNameValue.value,
      'bankAccountNumber': bankAccountController.text,
      'ifscCode': ifscController.text,
      'pan': panController.text,
    };

    missingFields.value = requiredFieldKeys(type, hasClient: hasClient)
        .where((k) => k != 'familyDetails' && (vals[k] ?? '').trim().isEmpty)
        .toList();

    final reqDocs = <String>{...requiredDocKeys(type)};
    if (panController.text.trim().isNotEmpty) reqDocs.add('PAN_CARD');
    missingDocs.value = reqDocs
        .where((d) => d == 'PHOTO'
            ? profilePicture.value == null
            : !documents.containsKey(d))
        .toList();
  }

  Future<void> submit() async {
    recomputeMissing();
    if (!canSubmit) return;
    submitting.value = true;
    stepResults.clear();
    createdEmployeeId.value = null;

    final fullName = fullNameController.text.trim();
    final nameParts =
        fullName.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    final firstName = nameParts.isNotEmpty ? nameParts.first : fullName;
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    // ── Step 1: Check Aadhaar availability ────────────────────────────────
    if (aadhaarController.text.trim().length == 12) {
      _setStep('aadhaar_check', 'Check Aadhaar', 'RUNNING');
      try {
        await _api.checkAadhaar(aadhaarController.text.trim());
        _setStep('aadhaar_check', 'Check Aadhaar', 'SUCCESS');
      } catch (e) {
        _setStep('aadhaar_check', 'Check Aadhaar', 'FAILED', error: _errMsg(e));
        submitting.value = false;
        return;
      }
    }

    // ── Step 2: Check phone availability ──────────────────────────────────
    if (phoneController.text.trim().isNotEmpty) {
      _setStep('phone_check', 'Check phone', 'RUNNING');
      try {
        await _api.checkAvailability({'phone': phoneController.text.trim()});
        _setStep('phone_check', 'Check phone', 'SUCCESS');
      } catch (e) {
        _setStep('phone_check', 'Check phone', 'FAILED', error: _errMsg(e));
        submitting.value = false;
        return;
      }
    }

    // ── Step 3 (FATAL): Create core employee record ──────────────────────
    _setStep('core', 'Create employee record', 'RUNNING');
    int? newId;
    try {
      final payload = {
        'firstName': firstName,
        'lastName': lastName,
        'customCode': null,
        'email': emailController.text.trim().isNotEmpty
            ? emailController.text.trim()
            : null,
        'phone': phoneController.text.trim().isNotEmpty
            ? phoneController.text.trim()
            : null,
        'dateOfBirth': dobController.text.trim().isNotEmpty
            ? dobController.text.trim()
            : null,
        'gender': genderValue.value.isNotEmpty ? genderValue.value : null,
        'bloodGroup': bloodGroupController.text.trim().isNotEmpty
            ? bloodGroupController.text.trim()
            : null,
        'maritalStatus': maritalStatusValue.value.isNotEmpty
            ? maritalStatusValue.value
            : null,
        'fatherHusbandName': fatherHusbandNameController.text.trim().isNotEmpty
            ? fatherHusbandNameController.text.trim()
            : null,
        'motherName': motherNameController.text.trim().isNotEmpty
            ? motherNameController.text.trim()
            : null,
        'secondaryPhone': secondaryPhoneController.text.trim().isNotEmpty
            ? secondaryPhoneController.text.trim()
            : null,
        'caste': casteController.text.trim().isNotEmpty
            ? casteController.text.trim()
            : null,
        'permanentAddress': permanentAddressController.text.trim().isNotEmpty
            ? permanentAddressController.text.trim()
            : null,
        'currentAddress': currentAddressController.text.trim().isNotEmpty
            ? currentAddressController.text.trim()
            : null,
        'employmentType': employmentType.value,
        'joiningDate': joiningDateController.text.trim().isNotEmpty
            ? joiningDateController.text.trim()
            : null,
        'confirmationDate': confirmationDateController.text.trim().isNotEmpty
            ? confirmationDateController.text.trim()
            : null,
        'designationId': selectedDesignationId.value,
        if (selectedClientId.value != null)
          'placement': {
            'clientCompanyId': selectedClientId.value,
            'branchId': selectedBranchId.value,
            'departmentId': selectedDepartmentId.value,
            'startDate': joiningDateController.text.trim().isNotEmpty
                ? joiningDateController.text.trim()
                : null,
          },
        'pan': panController.text.trim().isNotEmpty
            ? panController.text.trim()
            : null,
        'uan': uanController.text.trim().isNotEmpty
            ? uanController.text.trim()
            : null,
        'aadhaarNumber': aadhaarController.text.trim().isNotEmpty
            ? aadhaarController.text.trim()
            : null,
        'aadhaarConsentGiven': aadhaarController.text.trim().length == 12
            ? aadhaarConsentGiven.value
            : null,
        'aadhaarLast4': null,
        'previousEmployeeId': null,
        'pfAccountNumber': pfController.text.trim().isNotEmpty
            ? pfController.text.trim()
            : null,
        'esicNumber': esicController.text.trim().isNotEmpty
            ? esicController.text.trim()
            : null,
        'initialRole': null,
      };
      final res = await _api.createEmployee(payload);
      newId = res['data']?['employeeId'] ?? res['data']?['id'];
      createdEmployeeId.value = newId;
      createdEmployee.value = {
        'firstName': firstName,
        'lastName': lastName,
        'employeeCode': res['data']?['employeeCode'],
        'email': payload['email'],
        'phone': payload['phone'],
        'status': res['data']?['status'],
      };
      _setStep('core', 'Create employee record', 'SUCCESS');
    } catch (e) {
      _setStep('core', 'Create employee record', 'FAILED', error: _errMsg(e));
      submitting.value = false;
      return; // fatal
    }

    if (newId == null) {
      submitting.value = false;
      return;
    }

    // ── Step 4: Bank account ─────────────────────────────────────────────
    if (bankAccountController.text.trim().isNotEmpty) {
      _setStep('bank', 'Add bank account', 'RUNNING');
      try {
        await _api.addBankAccount(newId, {
          'accountHolderName': fullName,
          'accountNumber': bankAccountController.text.trim(),
          'bankName': bankNameValue.value,
          'ifscCode': ifscController.text.trim(),
          'accountType': 'SAVINGS',
          'isPrimary': true,
        });
        _setStep('bank', 'Add bank account', 'SUCCESS');
      } catch (e) {
        _setStep('bank', 'Add bank account', 'FAILED', error: _errMsg(e));
      }
    }

    // ── Step 5: Profile photo ────────────────────────────────────────────
    if (profilePictureBytes.value != null &&
        profilePictureBytes.value!.isNotEmpty) {
      _setStep('photo', 'Upload profile photo', 'RUNNING');
      try {
        final formData = FormData.fromMap({
          'photo': MultipartFile.fromBytes(
            profilePictureBytes.value!,
            filename: profilePictureName.value.isNotEmpty
                ? profilePictureName.value
                : 'photo.jpg',
          ),
        });
        await ApiClient.instance.post(
          '/api/v1/employees/$newId/photo',
          data: formData,
        );
        _setStep('photo', 'Upload profile photo', 'SUCCESS');
      } catch (e) {
        _setStep('photo', 'Upload profile photo', 'FAILED', error: _errMsg(e));
      }
    } else if (profilePicture.value != null) {
      // Fallback: try File.readAsBytes (works on mobile, may fail on web)
      _setStep('photo', 'Upload profile photo', 'RUNNING');
      try {
        await _api.uploadProfilePicture(newId, profilePicture.value!);
        _setStep('photo', 'Upload profile photo', 'SUCCESS');
      } catch (e) {
        _setStep('photo', 'Upload profile photo', 'FAILED', error: _errMsg(e));
      }
    }

    // ── Step 6: Documents (use stored bytes for web compat) ────────────
    final allDocKeys = <String>{...documents.keys, ...documentBytes.keys};
    for (final key in allDocKeys) {
      final stepKey = 'doc_$key';
      _setStep(stepKey, 'Upload $key', 'RUNNING');
      try {
        String docCategory = 'IDENTITY';
        if (key == 'BANK_PROOF') docCategory = 'FINANCIAL';

        final bytes = documentBytes[key];
        final name = documentNames[key] ?? 'document.jpg';

        if (bytes != null && bytes.isNotEmpty) {
          // Use stored bytes (works on web and mobile)
          final formData = FormData.fromMap({
            'file': MultipartFile.fromBytes(bytes, filename: name),
            'employeeId': newId.toString(),
            'documentCategory': docCategory,
            'documentType': key,
            'replaceExisting': 'true',
          });
          await ApiClient.instance
              .post('/api/v1/documents/upload', data: formData);
        } else if (documents.containsKey(key)) {
          // Fallback: use File (mobile only)
          await _api.uploadDocument(
            employeeId: newId,
            documentCategory: docCategory,
            documentType: key,
            file: documents[key]!,
          );
        }
        _setStep(stepKey, 'Upload $key', 'SUCCESS');
      } catch (e) {
        _setStep(stepKey, 'Upload $key', 'FAILED', error: _errMsg(e));
      }
    }

    // ── Step 7: Emergency contacts ───────────────────────────────────────
    if (emergencyContacts.isNotEmpty) {
      _setStep('emergency',
          'Add ${emergencyContacts.length} emergency contact(s)', 'RUNNING');
      try {
        for (final contact in emergencyContacts) {
          await _api.addEmergencyContact(newId, contact);
        }
        _setStep('emergency', 'Add emergency contacts', 'SUCCESS');
      } catch (e) {
        _setStep('emergency', 'Add emergency contacts', 'FAILED',
            error: _errMsg(e));
      }
    }

    // ── Step 8: Family members ───────────────────────────────────────────
    if (familyMembers.isNotEmpty) {
      _setStep(
          'family', 'Add ${familyMembers.length} family member(s)', 'RUNNING');
      try {
        for (final member in familyMembers) {
          await _api.addFamilyMember(newId, member);
        }
        _setStep('family', 'Add family members', 'SUCCESS');
      } catch (e) {
        _setStep('family', 'Add family members', 'FAILED', error: _errMsg(e));
      }
    }

    // ── Step 9: Finalize (always attempt — backend validates) ──────────
    _setStep('finalize', 'Finalize employee creation', 'RUNNING');
    try {
      final finRes = await _api.finalizeEmployeeCreation(newId);
      createdEmployee.value = {
        ...?createdEmployee.value,
        'employeeCode': finRes['data']?['employeeCode'] ??
            createdEmployee.value?['employeeCode'],
        'tempPassword': finRes['data']?['tempPassword'],
        'status': finRes['data']?['status'] ?? createdEmployee.value?['status'],
      };
      _setStep('finalize', 'Finalize employee creation', 'SUCCESS');
    } catch (e) {
      _setStep('finalize', 'Finalize employee creation', 'FAILED',
          error: _errMsg(e));
    }

    submitting.value = false;
    _showSuccess();
  }

  void _setStep(String key, String label, String status, {String? error}) {
    stepResults[key] = {
      'label': label,
      'status': status,
      if (error != null) 'error': error
    };
  }

  String _errMsg(dynamic e) {
    if (e is DioException) return ApiFailure.fromDioException(e).message;
    return e.toString();
  }

  void _showSuccess() {
    Get.bottomSheet(
      isDismissible: false,
      _SuccessSheet(
        name: fullNameController.text.trim(),
        employeeCode: createdEmployee.value?['employeeCode'] ?? '',
        tempPassword: createdEmployee.value?['tempPassword'],
        stepResults: Map.from(stepResults),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAGE
// ═══════════════════════════════════════════════════════════════════════════════
class AddEmployeePage extends StatelessWidget {
  const AddEmployeePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Put controller here — single instance for this page
    final ctrl = Get.put(AddEmployeeController());
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(ctrl),
      body: _buildBody(ctrl),
      bottomNavigationBar: _buildFooter(context, ctrl),
    );
  }

  PreferredSizeWidget _buildAppBar(AddEmployeeController ctrl) {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: AppColors.border,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        onPressed: Get.back,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add Employee', style: AppTextStyles.headingMedium),
          Text('New hire onboarding',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textTertiary)),
        ],
      ),
      titleSpacing: 0,
      actions: [
        Obx(() {
          final n = ctrl.missingFields.length + ctrl.missingDocs.length;
          if (n == 0) return const SizedBox.shrink();
          return Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text('$n missing',
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.warning, fontWeight: FontWeight.w600)),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBody(AddEmployeeController ctrl) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Form(
        key: ctrl.formKey,
        child: Column(children: [
          _ProgressStrip(ctrl: ctrl),
          const SizedBox(height: 16),
          _PhotoHeader(ctrl: ctrl),
          const SizedBox(height: 16),
          _AccordionSection(
              index: 0,
              ctrl: ctrl,
              title: 'Employment Type',
              subtitle: 'Determines required fields and documents',
              accentColor: AppColors.accent,
              child: _EmploymentTypeSection(ctrl: ctrl)),
          const SizedBox(height: 10),
          _AccordionSection(
              index: 1,
              ctrl: ctrl,
              title: 'Identity',
              subtitle: 'Aadhaar — stored encrypted, only last 4 shown',
              accentColor: AppColors.info,
              child: _IdentitySection(ctrl: ctrl)),
          const SizedBox(height: 10),
          _AccordionSection(
              index: 2,
              ctrl: ctrl,
              title: 'Personal Info',
              subtitle: 'Name, contact, date of birth',
              child: _PersonalInfoSection(ctrl: ctrl)),
          const SizedBox(height: 10),
          _AccordionSection(
              index: 3,
              ctrl: ctrl,
              title: 'Job Details',
              subtitle: 'Joining date, placement, designation',
              accentColor: AppColors.success,
              child: _JobDetailsSection(ctrl: ctrl)),
          const SizedBox(height: 10),
          _AccordionSection(
              index: 4,
              ctrl: ctrl,
              title: 'Bank & Tax',
              subtitle: 'Account, PAN, UAN, PF, ESIC',
              accentColor: AppColors.warning,
              child: _BankTaxSection(ctrl: ctrl)),
          const SizedBox(height: 10),
          _AccordionSection(
              index: 5,
              ctrl: ctrl,
              title: 'Documents',
              subtitle: 'Aadhaar, PAN, bank proof and more',
              accentColor: AppColors.info,
              child: _DocumentsSection(ctrl: ctrl)),
          const SizedBox(height: 10),
          _AccordionSection(
              index: 6,
              ctrl: ctrl,
              title: 'Family Members',
              subtitle: 'Nominee allocation, dependents',
              accentColor: const Color(0xFF7C3AED),
              child: _FamilyMembersSection(ctrl: ctrl)),
          const SizedBox(height: 10),
          _AccordionSection(
              index: 7,
              ctrl: ctrl,
              title: 'Emergency Contacts',
              subtitle: 'Non-family emergency contacts',
              accentColor: AppColors.danger,
              child: _EmergencyContactsSection(ctrl: ctrl)),
          const SizedBox(height: 16),
          _MissingPanel(ctrl: ctrl),
          const SizedBox(height: 120),
        ]),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, AddEmployeeController ctrl) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.ghost,
            onPressed: Get.back),
        const SizedBox(width: 10),
        Expanded(
          child: Obx(() => AppButton(
                label: ctrl.submitting.value ? 'Creating…' : 'Create Employee',
                loading: ctrl.submitting.value,
                onPressed: ctrl.canSubmit ? ctrl.submit : null,
                fullWidth: true,
              )),
        ),
      ]),
    );
  }
}

// ── Accordion wrapper — reads expandedSections once per card ──────────────────
class _AccordionSection extends StatelessWidget {
  final int index;
  final AddEmployeeController ctrl;
  final String title;
  final String subtitle;
  final Color? accentColor;
  final Widget child;

  const _AccordionSection({
    required this.index,
    required this.ctrl,
    required this.title,
    required this.subtitle,
    this.accentColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Each accordion independently observes expandedSections
    return Obx(() => SectionCard(
          title: title,
          subtitle: subtitle,
          isExpanded: ctrl.expandedSections.contains(index),
          onToggle: () => ctrl.toggleSection(index),
          accentColor: accentColor,
          child: child,
        ));
  }
}

// ── Missing fields panel — isolated Obx ──────────────────────────────────────
class _MissingPanel extends StatelessWidget {
  final AddEmployeeController ctrl;
  const _MissingPanel({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() => MissingFieldsPanel(
          fields: ctrl.missingFields.map(labelForField).toList(),
          docs: ctrl.missingDocs.map(labelForDoc).toList(),
          consentMissing: ctrl.aadhaarConsentMissing,
          employmentTypeLabel: EmploymentType.values
              .firstWhere((e) => e.value == ctrl.employmentType.value,
                  orElse: () => EmploymentType.contract)
              .label,
        ));
  }
}

// ── Progress Strip ────────────────────────────────────────────────────────────
class _ProgressStrip extends StatelessWidget {
  final AddEmployeeController ctrl;
  const _ProgressStrip({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final missing = ctrl.missingFields.length +
          ctrl.missingDocs.length +
          (ctrl.aadhaarConsentMissing ? 1 : 0);
      final total = fieldMatrix.length + docMatrix.length + 1;
      final done = (total - missing).clamp(0, total);
      final progress = done / total;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('$done of $total required fields done',
              style: AppTextStyles.caption),
          const Spacer(),
          Text('${(progress * 100).round()}%',
              style: AppTextStyles.caption.copyWith(
                  color: progress == 1.0 ? AppColors.success : AppColors.accent,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: AppColors.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(
                progress == 1.0 ? AppColors.success : AppColors.accent),
          ),
        ),
      ]);
    });
  }
}

// ── Photo Header ──────────────────────────────────────────────────────────────
class _PhotoHeader extends StatelessWidget {
  final AddEmployeeController ctrl;
  const _PhotoHeader({required this.ctrl});

  Future<void> _pick(BuildContext context) async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PickerSheet(title: 'Profile Photo'),
    );
    if (src == null) return;
    final img = await ImagePicker()
        .pickImage(source: src, maxWidth: 800, imageQuality: 85);
    if (img != null) {
      ctrl.profilePicture.value = File(img.path);
      ctrl.profilePictureBytes.value = await img.readAsBytes();
      ctrl.profilePictureName.value = img.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => _pick(context),
          child: Obx(() {
            final photo = ctrl.profilePicture.value;
            return Stack(children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                  image: photo != null
                      ? DecorationImage(
                          image: FileImage(photo), fit: BoxFit.cover)
                      : null,
                ),
                child: photo == null
                    ? const Icon(Icons.person_rounded,
                        color: AppColors.accent, size: 32)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: Colors.white, size: 10),
                ),
              ),
            ]);
          }),
        ),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Read fullName reactively but DON'T put a text listener — use
            // a ValueListenableBuilder so we don't trigger the GetX scope error
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: ctrl.fullNameController,
              builder: (_, val, __) => Text(
                val.text.isEmpty ? 'New Employee' : val.text,
                style: AppTextStyles.headingSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 3),
            Obx(() {
              const map = {
                'CONTRACT': 'Contractual',
                'NAPS': 'NAPS',
                'FULL_TIME': 'Staff (Full Time)',
                'INTERN': 'Intern',
              };
              return Text(map[ctrl.employmentType.value] ?? '',
                  style: AppTextStyles.caption);
            }),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => _pick(context),
              child: Text('Tap to add photo',
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.accent, fontWeight: FontWeight.w500)),
            ),
          ]),
        ),
        Obx(() => ctrl.profilePicture.value != null
            ? GestureDetector(
                onTap: () => ctrl.profilePicture.value = null,
                child: const Icon(Icons.close_rounded,
                    color: AppColors.textTertiary, size: 18),
              )
            : const SizedBox.shrink()),
      ]),
    );
  }
}

// ── Image source picker sheet ─────────────────────────────────────────────────
class _PickerSheet extends StatelessWidget {
  final String title;
  const _PickerSheet({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(100))),
        const SizedBox(height: 20),
        Text(title, style: AppTextStyles.headingMedium),
        const SizedBox(height: 16),
        _tile(context, Icons.camera_alt_rounded, 'Camera', ImageSource.camera),
        const SizedBox(height: 10),
        _tile(context, Icons.photo_library_rounded, 'Gallery',
            ImageSource.gallery),
        const SizedBox(height: 24),
      ])),
    );
  }

  Widget _tile(BuildContext ctx, IconData icon, String label, ImageSource src) {
    return GestureDetector(
      onTap: () => Navigator.pop(ctx, src),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(children: [
          Icon(icon, color: AppColors.accent),
          const SizedBox(width: 14),
          Text(label, style: AppTextStyles.bodyMedium),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION CONTENT WIDGETS
// These are plain StatelessWidgets — they contain Obx only where needed,
// never nested inside another Obx at the call site.
// ═══════════════════════════════════════════════════════════════════════════════

class _EmploymentTypeSection extends StatelessWidget {
  final AddEmployeeController ctrl;
  const _EmploymentTypeSection({required this.ctrl});

  static const _types = [
    ('CONTRACT', 'Contractual', 'Default — flexible, minimal doc set'),
    ('NAPS', 'NAPS', 'Apprenticeship — full doc set required'),
    ('FULL_TIME', 'Staff (Full Time)', 'Full employee — all fields mandatory'),
    ('INTERN', 'Intern', 'Same requirements as NAPS'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _types.map((t) {
        return Obx(() {
          final sel = ctrl.employmentType.value == t.$1;
          return GestureDetector(
            onTap: () => ctrl.employmentType.value = t.$1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: sel ? AppColors.accentLight : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                    color: sel ? AppColors.accent : AppColors.border,
                    width: sel ? 2 : 1),
              ),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: sel ? AppColors.accent : Colors.transparent,
                    border: Border.all(
                        color: sel ? AppColors.accent : AppColors.border,
                        width: 2),
                  ),
                  child: sel
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 12)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.$2,
                          style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight:
                                  sel ? FontWeight.w600 : FontWeight.w400,
                              color: sel
                                  ? AppColors.accent
                                  : AppColors.textPrimary)),
                      Text(t.$3, style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ]),
            ),
          );
        });
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _IdentitySection extends StatelessWidget {
  final AddEmployeeController ctrl;
  const _IdentitySection({required this.ctrl});

  Future<void> _pickDoc(BuildContext context, String key) async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PickerSheet(title: 'Upload Document'),
    );
    if (src == null) return;
    final img = await ImagePicker().pickImage(source: src, imageQuality: 90);
    if (img != null) {
      ctrl.setDocument(key, File(img.path));
      final bytes = await img.readAsBytes();
      ctrl.setDocumentBytes(key, bytes, img.name);
    }
  }

  String? _fname(File? f) {
    if (f == null) return null;
    final p = f.path;
    return p.contains('\\') ? p.split('\\').last : p.split('/').last;
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AppTextField(
        label: 'Aadhaar Number',
        controller: ctrl.aadhaarController,
        hint: '123456789012',
        required: true,
        keyboardType: TextInputType.number,
        maxLength: 12,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        helperText: '12 digits — encrypted; only last 4 shown after save',
        onChanged: (_) => ctrl.recomputeMissing(),
      ),
      const SizedBox(height: 12),

      // Consent — only shown when 12 digits entered
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: ctrl.aadhaarController,
        builder: (_, val, __) {
          if (val.text.length != 12) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Obx(() => GestureDetector(
                  onTap: () => ctrl.aadhaarConsentGiven.value =
                      !ctrl.aadhaarConsentGiven.value,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.infoLight,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border:
                          Border.all(color: AppColors.info.withOpacity(0.3)),
                    ),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: ctrl.aadhaarConsentGiven.value
                                  ? AppColors.accent
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: ctrl.aadhaarConsentGiven.value
                                    ? AppColors.accent
                                    : AppColors.textSecondary,
                                width: 1.5,
                              ),
                            ),
                            child: ctrl.aadhaarConsentGiven.value
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 13)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                  style: AppTextStyles.bodySmall,
                                  children: [
                                    TextSpan(
                                      text: 'Consent under DPDP Act  ',
                                      style: AppTextStyles.bodySmall.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.info),
                                    ),
                                    const TextSpan(
                                      text: '*',
                                      style: TextStyle(
                                          color: AppColors.danger,
                                          fontWeight: FontWeight.w700),
                                    ),
                                    const TextSpan(
                                      text:
                                          '\nEmployee has consented to recording their Aadhaar for compliance.',
                                    ),
                                  ]),
                            ),
                          ),
                        ]),
                  ),
                )),
          );
        },
      ),

      Text('Aadhaar Documents',
          style: AppTextStyles.label.copyWith(
              color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),

      Obx(() => DocumentSlotTile(
            label: 'Aadhaar Card (Front)',
            required: true,
            helperText: 'Front side — photo or image file',
            fileName: _fname(ctrl.documents['AADHAAR_FRONT']),
            onPick: () => _pickDoc(context, 'AADHAAR_FRONT'),
            onClear: () => ctrl.clearDocument('AADHAAR_FRONT'),
          )),
      const SizedBox(height: 8),
      Obx(() => DocumentSlotTile(
            label: 'Aadhaar Card (Back)',
            required: true,
            helperText: 'Back side — photo or image file',
            fileName: _fname(ctrl.documents['AADHAAR_BACK']),
            onPick: () => _pickDoc(context, 'AADHAAR_BACK'),
            onClear: () => ctrl.clearDocument('AADHAAR_BACK'),
          )),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _PersonalInfoSection extends StatelessWidget {
  final AddEmployeeController ctrl;
  const _PersonalInfoSection({required this.ctrl});

  Future<void> _pickDob(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 22)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      builder: (ctx, child) => Theme(
        data: ThemeData(
            colorScheme: const ColorScheme.light(primary: AppColors.accent)),
        child: child!,
      ),
    );
    if (picked != null) {
      ctrl.dobController.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
      ctrl.recomputeMissing();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Read employmentType once via Obx at the top level of this section
    return Obx(() {
      final type = ctrl.employmentType.value;
      bool req(String f) => isFieldRequired(type, f,
          isAdmin: true, hasClient: ctrl.selectedClientId.value != null);

      return Column(children: [
        AppTextField(
            label: 'Full Name',
            controller: ctrl.fullNameController,
            hint: 'Amit Kumar',
            required: true,
            onChanged: (_) => ctrl.recomputeMissing()),
        const SizedBox(height: 12),
        AppTextField(
            label: "Father's / Husband's Name",
            controller: ctrl.fatherHusbandNameController,
            hint: 'As on statutory records',
            required: req('fatherHusbandName'),
            onChanged: (_) => ctrl.recomputeMissing()),
        const SizedBox(height: 12),
        AppTextField(
            label: "Mother's Name",
            controller: ctrl.motherNameController,
            hint: 'As on statutory records',
            required: req('motherName'),
            onChanged: (_) => ctrl.recomputeMissing()),
        const SizedBox(height: 12),
        AppTextField(
            label: 'Work Email',
            controller: ctrl.emailController,
            hint: 'amit@company.com',
            required: req('email'),
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => ctrl.recomputeMissing()),
        const SizedBox(height: 12),
        AppTextField(
            label: 'Phone Number',
            controller: ctrl.phoneController,
            hint: '9876543210',
            required: true,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            onChanged: (_) => ctrl.recomputeMissing()),
        const SizedBox(height: 12),
        AppTextField(
            label: 'Second Mobile',
            controller: ctrl.secondaryPhoneController,
            hint: '9876543210',
            required: req('secondaryPhone'),
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            onChanged: (_) => ctrl.recomputeMissing()),
        const SizedBox(height: 12),
        AppTextField(
            label: 'Date of Birth',
            controller: ctrl.dobController,
            hint: 'YYYY-MM-DD',
            required: true,
            helperText: 'Must be 18 years or older',
            suffix: IconButton(
              icon: const Icon(Icons.calendar_today_rounded,
                  color: AppColors.textSecondary, size: 18),
              onPressed: () => _pickDob(context),
            ),
            onChanged: (_) => ctrl.recomputeMissing()),
        const SizedBox(height: 12),
        AppDropdown<String>(
          label: 'Gender',
          value: ctrl.genderValue.value.isEmpty ? null : ctrl.genderValue.value,
          required: true,
          hint: 'Select gender',
          items: const [
            DropdownMenuItem(value: 'MALE', child: Text('Male')),
            DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
            DropdownMenuItem(value: 'OTHER', child: Text('Other')),
            DropdownMenuItem(
                value: 'PREFER_NOT_TO_SAY', child: Text('Prefer not to say')),
          ],
          onChanged: (v) => ctrl.genderValue.value = v ?? '',
        ),
        const SizedBox(height: 12),
        AppDropdown<String>(
          label: 'Marital Status',
          value: ctrl.maritalStatusValue.value.isEmpty
              ? null
              : ctrl.maritalStatusValue.value,
          required: req('maritalStatus'),
          hint: 'Select status',
          items: const [
            DropdownMenuItem(value: 'SINGLE', child: Text('Single')),
            DropdownMenuItem(value: 'MARRIED', child: Text('Married')),
            DropdownMenuItem(value: 'DIVORCED', child: Text('Divorced')),
            DropdownMenuItem(value: 'WIDOWED', child: Text('Widowed')),
            DropdownMenuItem(
                value: 'PREFER_NOT_TO_SAY', child: Text('Prefer not to say')),
          ],
          onChanged: (v) => ctrl.maritalStatusValue.value = v ?? '',
        ),
        const SizedBox(height: 12),
        AppTextField(
            label: 'Blood Group',
            controller: ctrl.bloodGroupController,
            hint: 'e.g. O+, AB-',
            required: req('bloodGroup'),
            onChanged: (_) => ctrl.recomputeMissing()),
        const SizedBox(height: 12),
        AppTextField(
            label: 'Caste / Community',
            controller: ctrl.casteController,
            hint: 'General / OBC / SC / ST',
            required: req('caste'),
            onChanged: (_) => ctrl.recomputeMissing()),
        const SizedBox(height: 12),
        AppTextField(
            label: 'Permanent Address',
            controller: ctrl.permanentAddressController,
            hint: 'House / street / city / state / PIN',
            required: true,
            maxLines: 3,
            onChanged: (_) => ctrl.recomputeMissing()),
        const SizedBox(height: 12),
        AppTextField(
            label: 'Current Address',
            controller: ctrl.currentAddressController,
            hint: 'Leave blank if same as permanent',
            required: true,
            maxLines: 3,
            onChanged: (_) {
              ctrl.markCurrentAddressTouched();
              ctrl.recomputeMissing();
            }),
      ]);
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _JobDetailsSection extends StatelessWidget {
  final AddEmployeeController ctrl;
  const _JobDetailsSection({required this.ctrl});

  Future<void> _pickDate(BuildContext context, TextEditingController c,
      {VoidCallback? onPicked}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: ThemeData(
            colorScheme: const ColorScheme.light(primary: AppColors.accent)),
        child: child!,
      ),
    );
    if (picked != null) {
      c.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
      onPicked?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      AppTextField(
          label: 'Joining Date',
          controller: ctrl.joiningDateController,
          hint: 'YYYY-MM-DD',
          required: true,
          suffix: IconButton(
            icon: const Icon(Icons.calendar_today_rounded,
                color: AppColors.textSecondary, size: 18),
            onPressed: () => _pickDate(context, ctrl.joiningDateController,
                onPicked: ctrl.recomputeMissing),
          ),
          onChanged: (_) => ctrl.recomputeMissing()),
      const SizedBox(height: 12),
      AppTextField(
          label: 'Confirmation Date',
          controller: ctrl.confirmationDateController,
          hint: 'Auto-set to joining + 6 months',
          helperText: 'Auto-computed — adjust if needed',
          suffix: IconButton(
            icon: const Icon(Icons.calendar_today_rounded,
                color: AppColors.textSecondary, size: 18),
            onPressed: () => _pickDate(context, ctrl.confirmationDateController,
                onPicked: ctrl.markConfirmationTouched),
          ),
          onChanged: (_) => ctrl.markConfirmationTouched()),
      const SizedBox(height: 12),

      // ── Client ── (API: POST /api/v1/client-companies/list) ──────────────
      Obx(() {
        final loading = ctrl.loadingDropdowns.value;
        final items = ctrl.clients;
        return AppDropdown<int>(
          label: 'Client',
          value: ctrl.selectedClientId.value,
          required: true,
          enabled: !loading && items.isNotEmpty,
          hint: loading
              ? 'Loading clients…'
              : (items.isEmpty ? 'No clients available' : 'Select client'),
          helperText: loading ? null : null,
          items: items
              .map((c) => DropdownMenuItem<int>(
                    value: c.id,
                    child: Text(
                      c.clientCode != null && c.clientCode!.isNotEmpty
                          ? '${c.clientName} (${c.clientCode})'
                          : c.clientName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: (v) => ctrl.selectedClientId.value = v,
        );
      }),
      const SizedBox(height: 12),

      // ── Branch / Location ── (API: GET /api/v1/branches?activeOnly=true) ─
      Obx(() {
        final loading = ctrl.loadingDropdowns.value;
        final clientPicked = ctrl.selectedClientId.value != null;
        final items = ctrl.filteredBranches;
        return AppDropdown<int>(
          label: 'Branch / Location',
          value: ctrl.selectedBranchId.value,
          required: true,
          enabled: clientPicked && !loading,
          hint: !clientPicked
              ? 'Select client first'
              : (loading
                  ? 'Loading branches…'
                  : (items.isEmpty
                      ? 'No branches for this client'
                      : 'Select branch')),
          items: items
              .map((b) => DropdownMenuItem<int>(
                    value: b.id,
                    child: Text(
                      b.branchCode != null && b.branchCode!.isNotEmpty
                          ? '${b.branchName} (${b.branchCode})'
                          : b.branchName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: (v) => ctrl.selectedBranchId.value = v,
        );
      }),
      const SizedBox(height: 12),

      // ── Department ── (API: GET /api/v1/branches/{id}/effective-depts) ───
      Obx(() {
        final branchPicked = ctrl.selectedBranchId.value != null;
        final loading = ctrl.loadingBranchDepts.value;
        final items = ctrl.departments;
        return AppDropdown<int>(
          label: 'Department',
          value: ctrl.selectedDepartmentId.value,
          required: true,
          enabled: branchPicked && !loading,
          hint: !branchPicked
              ? 'Select branch first'
              : (loading
                  ? 'Loading departments…'
                  : (items.isEmpty
                      ? 'No departments for this branch'
                      : 'Select department')),
          items: items
              .map((d) => DropdownMenuItem<int>(
                    value: d.id,
                    child: Text(
                      d.departmentName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: (v) => ctrl.selectedDepartmentId.value = v,
        );
      }),
      const SizedBox(height: 12),

      // ── Designation ── (API: POST /api/v1/designations/list) ─────────────
      Obx(() {
        final loading = ctrl.loadingDropdowns.value;
        final items = ctrl.filteredDesignations;
        return AppDropdown<int>(
          label: 'Designation',
          value: ctrl.selectedDesignationId.value,
          required: true,
          enabled: !loading && items.isNotEmpty,
          hint: loading
              ? 'Loading designations…'
              : (items.isEmpty
                  ? 'No designations available'
                  : 'Select designation'),
          items: items
              .map((d) => DropdownMenuItem<int>(
                    value: d.id,
                    child: Text(
                      d.designationName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: (v) => ctrl.selectedDesignationId.value = v,
        );
      }),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _BankTaxSection extends StatelessWidget {
  final AddEmployeeController ctrl;
  const _BankTaxSection({required this.ctrl});

  static const _banks = [
    'State Bank of India',
    'HDFC Bank',
    'ICICI Bank',
    'Axis Bank',
    'Kotak Mahindra Bank',
    'Punjab National Bank',
    'Bank of Baroda',
    'Canara Bank',
    'Union Bank of India',
    'IndusInd Bank',
    'Yes Bank',
    'IDFC First Bank',
    'Federal Bank',
    'South Indian Bank',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      AppTextField(
          label: 'Bank Account Number',
          controller: ctrl.bankAccountController,
          hint: 'Enter account number',
          required: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => ctrl.recomputeMissing()),
      const SizedBox(height: 12),
      Obx(() => AppDropdown<String>(
            label: 'Bank Name',
            value: ctrl.bankNameValue.value.isEmpty
                ? null
                : ctrl.bankNameValue.value,
            hint: 'Select bank',
            required: true,
            items: _banks
                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                .toList(),
            onChanged: (v) => ctrl.bankNameValue.value = v ?? '',
          )),
      const SizedBox(height: 12),
      AppTextField(
          label: 'IFSC Code',
          controller: ctrl.ifscController,
          hint: 'SBIN0001234',
          required: true,
          helperText: 'Format: SBIN0001234',
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            LengthLimitingTextInputFormatter(11),
            _UpperCaseFormatter(),
          ],
          onChanged: (_) => ctrl.recomputeMissing()),
      const SizedBox(height: 12),
      Obx(() => AppTextField(
            label: 'PAN Number',
            controller: ctrl.panController,
            hint: 'ABCDE1234F',
            required: isFieldRequired(ctrl.employmentType.value, 'pan'),
            helperText: 'Format: ABCDE1234F',
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(10),
              _UpperCaseFormatter(),
            ],
            onChanged: (_) => ctrl.recomputeMissing(),
          )),
      const SizedBox(height: 12),
      AppTextField(
          label: 'UAN (PF Account)',
          controller: ctrl.uanController,
          hint: '100123456789',
          keyboardType: TextInputType.number,
          helperText: 'Optional'),
      const SizedBox(height: 12),
      AppTextField(
          label: 'PF Account Number',
          controller: ctrl.pfController,
          hint: 'DL/CPM/1234567/000/0000123',
          helperText: 'Optional'),
      const SizedBox(height: 12),
      AppTextField(
          label: 'ESIC Number',
          controller: ctrl.esicController,
          hint: '3112345678',
          keyboardType: TextInputType.number,
          helperText: 'Optional'),
    ]);
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue n) =>
      n.copyWith(text: n.text.toUpperCase());
}

// ─────────────────────────────────────────────────────────────────────────────
class _DocumentsSection extends StatelessWidget {
  final AddEmployeeController ctrl;
  const _DocumentsSection({required this.ctrl});

  Future<void> _pick(BuildContext context, String key) async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PickerSheet(title: 'Upload Document'),
    );
    if (src == null) return;
    final img = await ImagePicker().pickImage(source: src, imageQuality: 90);
    if (img != null) {
      ctrl.setDocument(key, File(img.path));
      final bytes = await img.readAsBytes();
      ctrl.setDocumentBytes(key, bytes, img.name);
    }
  }

  String? _fname(File? f) {
    if (f == null) return null;
    final p = f.path;
    return p.contains('\\') ? p.split('\\').last : p.split('/').last;
  }

  static const _slots = [
    ('PAN_CARD', 'PAN Card', 'Required when PAN number is entered'),
    ('BANK_PROOF', 'Bank Account Copy', 'Cancelled cheque or passbook'),
    ('MARK_SHEET', 'Mark Sheet', 'Latest qualifying mark sheet'),
    ('SIGNATURE', 'Signature', 'Specimen signature image'),
    ('OFFER_LETTER', 'Offer Letter', 'Optional'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.infoLight,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.info, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Aadhaar documents are in the Identity section above.',
                style: AppTextStyles.caption.copyWith(color: AppColors.info)),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      ..._slots.map((slot) => Obx(() {
            final required =
                isDocRequired(ctrl.employmentType.value, slot.$1) ||
                    (slot.$1 == 'PAN_CARD' &&
                        ctrl.panController.text.trim().isNotEmpty);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DocumentSlotTile(
                label: slot.$2,
                helperText: slot.$3,
                required: required,
                fileName: _fname(ctrl.documents[slot.$1]),
                onPick: () => _pick(context, slot.$1),
                onClear: () => ctrl.clearDocument(slot.$1),
              ),
            );
          })),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SUCCESS SHEET
// ═══════════════════════════════════════════════════════════════════════════════
class _SuccessSheet extends StatelessWidget {
  final String name;
  final String employeeCode;
  final String? tempPassword;
  final Map<String, Map<String, dynamic>> stepResults;
  const _SuccessSheet(
      {required this.name,
      required this.employeeCode,
      this.tempPassword,
      required this.stepResults});

  @override
  Widget build(BuildContext context) {
    final anyFailed = stepResults.values.any((s) => s['status'] == 'FAILED');
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(100))),
        const SizedBox(height: 24),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
              color:
                  anyFailed ? AppColors.warningLight : AppColors.successLight,
              borderRadius: BorderRadius.circular(32)),
          child: Icon(
              anyFailed ? Icons.warning_amber_rounded : Icons.check_rounded,
              color: anyFailed ? AppColors.warning : AppColors.success,
              size: 36),
        ),
        const SizedBox(height: 16),
        Text(anyFailed ? 'Created with warnings' : 'Employee Created!',
            style: AppTextStyles.headingLarge),
        const SizedBox(height: 6),
        Text(name.isEmpty ? 'New Employee' : name,
            style: AppTextStyles.bodyLarge
                .copyWith(color: AppColors.textSecondary)),
        if (employeeCode.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Code: $employeeCode',
              style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace')),
        ],
        if (tempPassword != null && tempPassword!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.info.withOpacity(0.3))),
            child: Row(children: [
              const Icon(Icons.key_rounded, color: AppColors.info, size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Temporary Password',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.info)),
                    Text(tempPassword!,
                        style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            color: AppColors.textPrimary)),
                  ])),
              IconButton(
                  icon: const Icon(Icons.copy_rounded,
                      size: 18, color: AppColors.info),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: tempPassword!));
                    Get.snackbar('Copied', 'Password copied to clipboard',
                        snackPosition: SnackPosition.BOTTOM,
                        margin: const EdgeInsets.all(16));
                  }),
            ]),
          ),
        ],
        // Step results
        if (stepResults.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
                child: Column(
              children: stepResults.entries.map((e) {
                final s = e.value;
                final isOk = s['status'] == 'SUCCESS';
                final isFail = s['status'] == 'FAILED';
                return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      Icon(
                          isOk
                              ? Icons.check_circle_rounded
                              : isFail
                                  ? Icons.cancel_rounded
                                  : Icons.remove_circle_outline_rounded,
                          color: isOk
                              ? AppColors.success
                              : isFail
                                  ? AppColors.danger
                                  : AppColors.textTertiary,
                          size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(s['label'] ?? e.key,
                              style: AppTextStyles.caption.copyWith(
                                  color: isFail
                                      ? AppColors.danger
                                      : AppColors.textSecondary))),
                    ]));
              }).toList(),
            )),
          ),
        ],
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () {
              Get.back();
              Get.back();
            },
            child: Text('Done',
                style: AppTextStyles.buttonLarge.copyWith(color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FAMILY MEMBERS SECTION
// ═══════════════════════════════════════════════════════════════════════════════
class _FamilyMembersSection extends StatelessWidget {
  final AddEmployeeController ctrl;
  const _FamilyMembersSection({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Obx(() => Column(children: [
            ...ctrl.familyMembers.asMap().entries.map((e) {
              final i = e.key;
              final m = e.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(m['fullName'] ?? '',
                            style: AppTextStyles.bodySmall
                                .copyWith(fontWeight: FontWeight.w600)),
                        Text(
                            '${m['relationship'] ?? ''} ${m['isNominee'] == true ? '· Nominee ${m['nomineeSharePercent'] ?? 0}%' : ''}',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textSecondary)),
                        if (m['phone'] != null &&
                            m['phone'].toString().isNotEmpty)
                          Text(m['phone'],
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.textTertiary)),
                      ])),
                  IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.danger, size: 18),
                      onPressed: () => ctrl.familyMembers.removeAt(i)),
                ]),
              );
            }),
          ])),
      const SizedBox(height: 8),
      SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('Add Family Member'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.accent),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () => _showAddFamilySheet(context),
          )),
    ]);
  }

  void _showAddFamilySheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final dobCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final aadhaarCtrl = TextEditingController();
    final shareCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final relationship = ''.obs;
    final gender = ''.obs;
    final isNominee = false.obs;
    final isDependent = false.obs;
    final isEmergency = false.obs;

    Get.bottomSheet(
      isScrollControlled: true,
      Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24), topRight: Radius.circular(24))),
        child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(100))),
          const SizedBox(height: 16),
          Text('Add Family Member', style: AppTextStyles.headingMedium),
          const SizedBox(height: 16),
          Obx(() => DropdownButtonFormField<String>(
                value: relationship.value.isEmpty ? null : relationship.value,
                decoration: const InputDecoration(
                    labelText: 'Relationship *', border: OutlineInputBorder()),
                items: [
                  'FATHER',
                  'MOTHER',
                  'SPOUSE',
                  'SON',
                  'DAUGHTER',
                  'BROTHER',
                  'SISTER',
                  'OTHER'
                ]
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => relationship.value = v ?? '',
              )),
          const SizedBox(height: 12),
          TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Full Name *', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
              controller: dobCtrl,
              decoration: const InputDecoration(
                  labelText: 'Date of Birth (YYYY-MM-DD)',
                  border: OutlineInputBorder()),
              keyboardType: TextInputType.datetime),
          const SizedBox(height: 12),
          Obx(() => DropdownButtonFormField<String>(
                value: gender.value.isEmpty ? null : gender.value,
                decoration: const InputDecoration(
                    labelText: 'Gender', border: OutlineInputBorder()),
                items: ['MALE', 'FEMALE', 'OTHER']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => gender.value = v ?? '',
              )),
          const SizedBox(height: 12),
          TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(
                  labelText: 'Phone', border: OutlineInputBorder()),
              keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                  labelText: 'Email', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          TextField(
              controller: aadhaarCtrl,
              decoration: const InputDecoration(
                  labelText: 'Aadhaar Number', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              maxLength: 12),
          const SizedBox(height: 8),
          Obx(() => CheckboxListTile(
              title: const Text('Is Dependent'),
              value: isDependent.value,
              onChanged: (v) => isDependent.value = v ?? false,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true)),
          Obx(() => CheckboxListTile(
              title: const Text('Is Emergency Contact'),
              value: isEmergency.value,
              onChanged: (v) => isEmergency.value = v ?? false,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true)),
          Obx(() => CheckboxListTile(
              title: const Text('Is Nominee'),
              value: isNominee.value,
              onChanged: (v) => isNominee.value = v ?? false,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true)),
          Obx(() => isNominee.value
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextField(
                      controller: shareCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Nominee Share %',
                          border: OutlineInputBorder()),
                      keyboardType: TextInputType.number))
              : const SizedBox.shrink()),
          const SizedBox(height: 12),
          TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                  labelText: 'Notes', border: OutlineInputBorder()),
              maxLines: 2),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed: Get.back, child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(
                child: ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty ||
                    relationship.value.isEmpty) {
                  Get.snackbar('Missing', 'Name and relationship are required',
                      backgroundColor: AppColors.warning,
                      colorText: Colors.white,
                      snackPosition: SnackPosition.BOTTOM,
                      margin: const EdgeInsets.all(16));
                  return;
                }
                ctrl.familyMembers.add({
                  'relationship': relationship.value,
                  'fullName': nameCtrl.text.trim(),
                  'dateOfBirth': dobCtrl.text.trim().isNotEmpty
                      ? dobCtrl.text.trim()
                      : null,
                  'gender': gender.value.isNotEmpty ? gender.value : null,
                  'occupation': null,
                  'phone': phoneCtrl.text.trim().isNotEmpty
                      ? phoneCtrl.text.trim()
                      : null,
                  'email': emailCtrl.text.trim().isNotEmpty
                      ? emailCtrl.text.trim()
                      : null,
                  'isDependent': isDependent.value,
                  'isEmergencyContact': isEmergency.value,
                  'aadhaarNumber': aadhaarCtrl.text.trim().isNotEmpty
                      ? aadhaarCtrl.text.trim()
                      : null,
                  'isNominee': isNominee.value,
                  'nomineeSharePercent': isNominee.value
                      ? (int.tryParse(shareCtrl.text.trim()) ?? 0)
                      : null,
                  'notes': notesCtrl.text.trim().isNotEmpty
                      ? notesCtrl.text.trim()
                      : null,
                });
                Get.back();
              },
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            )),
          ]),
          const SizedBox(height: 8),
        ])),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EMERGENCY CONTACTS SECTION
// ═══════════════════════════════════════════════════════════════════════════════
class _EmergencyContactsSection extends StatelessWidget {
  final AddEmployeeController ctrl;
  const _EmergencyContactsSection({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Obx(() => Column(children: [
            ...ctrl.emergencyContacts.asMap().entries.map((e) {
              final i = e.key;
              final c = e.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(c['contactName'] ?? '',
                            style: AppTextStyles.bodySmall
                                .copyWith(fontWeight: FontWeight.w600)),
                        Text(
                            '${c['relationship'] ?? ''} ${c['isPrimary'] == true ? '· Primary' : ''}',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textSecondary)),
                        Text(c['phone'] ?? '',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textTertiary)),
                      ])),
                  IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.danger, size: 18),
                      onPressed: () => ctrl.emergencyContacts.removeAt(i)),
                ]),
              );
            }),
          ])),
      const SizedBox(height: 8),
      SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.emergency_rounded, size: 18),
            label: const Text('Add Emergency Contact'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.danger),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () => _showAddContactSheet(context),
          )),
    ]);
  }

  void _showAddContactSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final relCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final isPrimary = false.obs;

    Get.bottomSheet(
      isScrollControlled: true,
      Container(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24), topRight: Radius.circular(24))),
        child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(100))),
          const SizedBox(height: 16),
          Text('Add Emergency Contact', style: AppTextStyles.headingMedium),
          const SizedBox(height: 16),
          TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Contact Name *', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
              controller: relCtrl,
              decoration: const InputDecoration(
                  labelText: 'Relationship *',
                  hintText: 'e.g. friend, neighbor',
                  border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(
                  labelText: 'Phone *', border: OutlineInputBorder()),
              keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                  labelText: 'Email', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 8),
          Obx(() => CheckboxListTile(
              title: const Text('Primary contact'),
              value: isPrimary.value,
              onChanged: (v) => isPrimary.value = v ?? false,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed: Get.back, child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(
                child: ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty ||
                    relCtrl.text.trim().isEmpty ||
                    phoneCtrl.text.trim().isEmpty) {
                  Get.snackbar(
                      'Missing', 'Name, relationship and phone are required',
                      backgroundColor: AppColors.warning,
                      colorText: Colors.white,
                      snackPosition: SnackPosition.BOTTOM,
                      margin: const EdgeInsets.all(16));
                  return;
                }
                ctrl.emergencyContacts.add({
                  'contactName': nameCtrl.text.trim(),
                  'relationship': relCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'email': emailCtrl.text.trim().isNotEmpty
                      ? emailCtrl.text.trim()
                      : null,
                  'isPrimary': isPrimary.value,
                });
                Get.back();
              },
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            )),
          ]),
          const SizedBox(height: 8),
        ])),
      ),
    );
  }
}
