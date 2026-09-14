import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/employment_requirements.dart';
import '../../../../shared/widgets/shared_widgets.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CONTROLLER — self-contained, no API calls
// ═══════════════════════════════════════════════════════════════════════════════
class AddEmployeeController extends GetxController {
  final formKey = GlobalKey<FormState>();

  final expandedSections    = <int>{0, 1}.obs;
  final employmentType      = 'CONTRACT'.obs;
  final aadhaarConsentGiven = false.obs;
  final genderValue         = ''.obs;
  final maritalStatusValue  = ''.obs;
  final bankNameValue        = ''.obs;
  final profilePicture      = Rxn<File>();
  final documents           = <String, File>{}.obs;
  final submitting          = false.obs;
  final missingFields       = <String>[].obs;
  final missingDocs         = <String>[].obs;

  // Text controllers
  final aadhaarController           = TextEditingController();
  final fullNameController          = TextEditingController();
  final fatherHusbandNameController = TextEditingController();
  final motherNameController        = TextEditingController();
  final emailController             = TextEditingController();
  final phoneController             = TextEditingController();
  final secondaryPhoneController    = TextEditingController();
  final dobController               = TextEditingController();
  final bloodGroupController        = TextEditingController();
  final casteController             = TextEditingController();
  final permanentAddressController  = TextEditingController();
  final currentAddressController    = TextEditingController();
  final joiningDateController       = TextEditingController();
  final confirmationDateController  = TextEditingController();
  final clientController            = TextEditingController();
  final branchController            = TextEditingController();
  final departmentController        = TextEditingController();
  final designationController       = TextEditingController();
  final bankAccountController       = TextEditingController();
  final ifscController              = TextEditingController();
  final panController               = TextEditingController();
  final uanController               = TextEditingController();
  final pfController                = TextEditingController();
  final esicController              = TextEditingController();

  bool _currentAddressTouched = false;
  bool _confirmationTouched   = false;

  @override
  void onInit() {
    super.onInit();
    ever(employmentType,  (_) => recomputeMissing());
    ever(documents,       (_) => recomputeMissing());
    ever(profilePicture,  (_) => recomputeMissing());
    ever(genderValue,     (_) => recomputeMissing());
    ever(maritalStatusValue, (_) => recomputeMissing());
    ever(bankNameValue,   (_) => recomputeMissing());
    ever(aadhaarConsentGiven, (_) => recomputeMissing());

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
      aadhaarController, fullNameController, fatherHusbandNameController,
      motherNameController, emailController, phoneController,
      secondaryPhoneController, dobController, bloodGroupController,
      casteController, permanentAddressController, currentAddressController,
      joiningDateController, confirmationDateController, clientController,
      branchController, departmentController, designationController,
      bankAccountController, ifscController, panController,
      uanController, pfController, esicController,
    ]) { c.dispose(); }
    super.onClose();
  }

  void toggleSection(int i) {
    if (expandedSections.contains(i)) {
      expandedSections.remove(i);
    } else {
      expandedSections.add(i);
    }
  }

  void markCurrentAddressTouched() => _currentAddressTouched = true;
  void markConfirmationTouched()   => _confirmationTouched   = true;

  void setDocument(String key, File file) => documents[key] = file;
  void clearDocument(String key)          => documents.remove(key);

  bool get aadhaarConsentMissing =>
      aadhaarController.text.length == 12 && !aadhaarConsentGiven.value;

  bool get canSubmit =>
      missingFields.isEmpty && missingDocs.isEmpty &&
      !aadhaarConsentMissing && !submitting.value;

  void recomputeMissing() {
    final type      = employmentType.value;
    final hasClient = clientController.text.trim().isNotEmpty;

    final vals = <String, String>{
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
      'clientCompanyId':   clientController.text,
      'branchId':          branchController.text,
      'departmentId':      departmentController.text,
      'designationId':     designationController.text,
      'bankName':          bankNameValue.value,
      'bankAccountNumber': bankAccountController.text,
      'ifscCode':          ifscController.text,
      'pan':               panController.text,
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
    await Future.delayed(const Duration(seconds: 2));
    submitting.value = false;
    _showSuccess();
  }

  void _showSuccess() {
    Get.bottomSheet(
      isDismissible: false,
      _SuccessSheet(name: fullNameController.text.trim()),
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
      appBar:              _buildAppBar(ctrl),
      body:                _buildBody(ctrl),
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
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600)),
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
          _AccordionSection(index: 0, ctrl: ctrl,
              title: 'Employment Type',
              subtitle: 'Determines required fields and documents',
              accentColor: AppColors.accent,
              child: _EmploymentTypeSection(ctrl: ctrl)),
          const SizedBox(height: 10),
          _AccordionSection(index: 1, ctrl: ctrl,
              title: 'Identity',
              subtitle: 'Aadhaar — stored encrypted, only last 4 shown',
              accentColor: AppColors.info,
              child: _IdentitySection(ctrl: ctrl)),
          const SizedBox(height: 10),
          _AccordionSection(index: 2, ctrl: ctrl,
              title: 'Personal Info',
              subtitle: 'Name, contact, date of birth',
              child: _PersonalInfoSection(ctrl: ctrl)),
          const SizedBox(height: 10),
          _AccordionSection(index: 3, ctrl: ctrl,
              title: 'Job Details',
              subtitle: 'Joining date, placement, designation',
              accentColor: AppColors.success,
              child: _JobDetailsSection(ctrl: ctrl)),
          const SizedBox(height: 10),
          _AccordionSection(index: 4, ctrl: ctrl,
              title: 'Bank & Tax',
              subtitle: 'Account, PAN, UAN, PF, ESIC',
              accentColor: AppColors.warning,
              child: _BankTaxSection(ctrl: ctrl)),
          const SizedBox(height: 10),
          _AccordionSection(index: 5, ctrl: ctrl,
              title: 'Documents',
              subtitle: 'Aadhaar, PAN, bank proof and more',
              accentColor: AppColors.info,
              child: _DocumentsSection(ctrl: ctrl)),
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
        AppButton(label: 'Cancel',
            variant: AppButtonVariant.ghost, onPressed: Get.back),
        const SizedBox(width: 10),
        Expanded(
          child: Obx(() => AppButton(
                label:     ctrl.submitting.value ? 'Creating…' : 'Create Employee',
                loading:   ctrl.submitting.value,
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
          title:       title,
          subtitle:    subtitle,
          isExpanded:  ctrl.expandedSections.contains(index),
          onToggle:    () => ctrl.toggleSection(index),
          accentColor: accentColor,
          child:       child,
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
          docs:   ctrl.missingDocs.map(labelForDoc).toList(),
          consentMissing:      ctrl.aadhaarConsentMissing,
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
      final missing  = ctrl.missingFields.length + ctrl.missingDocs.length +
          (ctrl.aadhaarConsentMissing ? 1 : 0);
      final total    = fieldMatrix.length + docMatrix.length + 1;
      final done     = (total - missing).clamp(0, total);
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
            value:           progress,
            minHeight:       5,
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
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => const _PickerSheet(title: 'Profile Photo'),
    );
    if (src == null) return;
    final img = await ImagePicker()
        .pickImage(source: src, maxWidth: 800, imageQuality: 85);
    if (img != null) ctrl.profilePicture.value = File(img.path);
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
                width: 72, height: 72,
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
                bottom: 0, right: 0,
                child: Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.accent, shape: BoxShape.circle,
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Read fullName reactively but DON'T put a text listener — use
            // a ValueListenableBuilder so we don't trigger the GetX scope error
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: ctrl.fullNameController,
              builder: (_, val, __) => Text(
                val.text.isEmpty ? 'New Employee' : val.text,
                style: AppTextStyles.headingSmall,
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 3),
            Obx(() {
              const map = {
                'CONTRACT': 'Contractual', 'NAPS': 'NAPS',
                'FULL_TIME': 'Staff (Full Time)', 'INTERN': 'Intern',
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
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(100))),
        const SizedBox(height: 20),
        Text(title, style: AppTextStyles.headingMedium),
        const SizedBox(height: 16),
        _tile(context, Icons.camera_alt_rounded,    'Camera',  ImageSource.camera),
        const SizedBox(height: 10),
        _tile(context, Icons.photo_library_rounded, 'Gallery', ImageSource.gallery),
        const SizedBox(height: 4),
      ]),
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
    ('CONTRACT',  'Contractual',       'Default — flexible, minimal doc set'),
    ('NAPS',      'NAPS',              'Apprenticeship — full doc set required'),
    ('FULL_TIME', 'Staff (Full Time)', 'Full employee — all fields mandatory'),
    ('INTERN',    'Intern',            'Same requirements as NAPS'),
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
                  width: 20, height: 20,
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
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => const _PickerSheet(title: 'Upload Document'),
    );
    if (src == null) return;
    final img =
        await ImagePicker().pickImage(source: src, imageQuality: 90);
    if (img != null) ctrl.setDocument(key, File(img.path));
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
        label: 'Aadhaar Number', controller: ctrl.aadhaarController,
        hint: '123456789012', required: true,
        keyboardType: TextInputType.number, maxLength: 12,
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
                      border: Border.all(
                          color: AppColors.info.withOpacity(0.3)),
                    ),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 20, height: 20,
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
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),

      Obx(() => DocumentSlotTile(
            label: 'Aadhaar Card (Front)', required: true,
            helperText: 'Front side — photo or image file',
            fileName: _fname(ctrl.documents['AADHAAR_FRONT']),
            onPick:  () => _pickDoc(context, 'AADHAAR_FRONT'),
            onClear: () => ctrl.clearDocument('AADHAAR_FRONT'),
          )),
      const SizedBox(height: 8),
      Obx(() => DocumentSlotTile(
            label: 'Aadhaar Card (Back)', required: true,
            helperText: 'Back side — photo or image file',
            fileName: _fname(ctrl.documents['AADHAAR_BACK']),
            onPick:  () => _pickDoc(context, 'AADHAAR_BACK'),
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
      initialDate:
          DateTime.now().subtract(const Duration(days: 365 * 22)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      builder: (ctx, child) => Theme(
        data: ThemeData(
            colorScheme:
                const ColorScheme.light(primary: AppColors.accent)),
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
          isAdmin: true,
          hasClient: ctrl.clientController.text.trim().isNotEmpty);

      return Column(children: [
        AppTextField(label: 'Full Name',
            controller: ctrl.fullNameController,
            hint: 'Amit Kumar', required: true,
            onChanged: (_) => ctrl.recomputeMissing()),
        const SizedBox(height: 12),
        AppTextField(label: "Father's / Husband's Name",
            controller: ctrl.fatherHusbandNameController,
            hint: 'As on statutory records',
            required: req('fatherHusbandName'),
            onChanged: (_) => ctrl.recomputeMissing()),
        const SizedBox(height: 12),
        AppTextField(label: "Mother's Name",
            controller: ctrl.motherNameController,
            hint: 'As on statutory records', required: req('motherName'),
            onChanged: (_) => ctrl.recomputeMissing()),
        const SizedBox(height: 12),
        AppTextField(label: 'Work Email',
            controller: ctrl.emailController,
            hint: 'amit@company.com', required: req('email'),
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => ctrl.recomputeMissing()),
        const SizedBox(height: 12),
        AppTextField(label: 'Phone Number',
            controller: ctrl.phoneController,
            hint: '9876543210', required: true,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            onChanged: (_) => ctrl.recomputeMissing()),
        const SizedBox(height: 12),
        AppTextField(label: 'Second Mobile',
            controller: ctrl.secondaryPhoneController,
            hint: '9876543210', required: req('secondaryPhone'),
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            onChanged: (_) => ctrl.recomputeMissing()),
        const SizedBox(height: 12),
        AppTextField(label: 'Date of Birth',
            controller: ctrl.dobController,
            hint: 'YYYY-MM-DD', required: true,
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
          value: ctrl.genderValue.value.isEmpty
              ? null
              : ctrl.genderValue.value,
          required: true, hint: 'Select gender',
          items: const [
            DropdownMenuItem(value: 'MALE',   child: Text('Male')),
            DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
            DropdownMenuItem(value: 'OTHER',  child: Text('Other')),
            DropdownMenuItem(
                value: 'PREFER_NOT_TO_SAY',
                child: Text('Prefer not to say')),
          ],
          onChanged: (v) => ctrl.genderValue.value = v ?? '',
        ),
        const SizedBox(height: 12),
        AppDropdown<String>(
          label: 'Marital Status',
          value: ctrl.maritalStatusValue.value.isEmpty
              ? null
              : ctrl.maritalStatusValue.value,
          required: req('maritalStatus'), hint: 'Select status',
          items: const [
            DropdownMenuItem(value: 'SINGLE',   child: Text('Single')),
            DropdownMenuItem(value: 'MARRIED',  child: Text('Married')),
            DropdownMenuItem(value: 'DIVORCED', child: Text('Divorced')),
            DropdownMenuItem(value: 'WIDOWED',  child: Text('Widowed')),
            DropdownMenuItem(
                value: 'PREFER_NOT_TO_SAY',
                child: Text('Prefer not to say')),
          ],
          onChanged: (v) => ctrl.maritalStatusValue.value = v ?? '',
        ),
        const SizedBox(height: 12),
        AppTextField(label: 'Blood Group',
            controller: ctrl.bloodGroupController,
            hint: 'e.g. O+, AB-', required: req('bloodGroup'),
            onChanged: (_) => ctrl.recomputeMissing()),
        const SizedBox(height: 12),
        AppTextField(label: 'Caste / Community',
            controller: ctrl.casteController,
            hint: 'General / OBC / SC / ST', required: req('caste'),
            onChanged: (_) => ctrl.recomputeMissing()),
        const SizedBox(height: 12),
        AppTextField(label: 'Permanent Address',
            controller: ctrl.permanentAddressController,
            hint: 'House / street / city / state / PIN',
            required: true, maxLines: 3,
            onChanged: (_) => ctrl.recomputeMissing()),
        const SizedBox(height: 12),
        AppTextField(label: 'Current Address',
            controller: ctrl.currentAddressController,
            hint: 'Leave blank if same as permanent',
            required: true, maxLines: 3,
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
      firstDate:   DateTime(2020),
      lastDate:    DateTime(2030),
      builder: (ctx, child) => Theme(
        data: ThemeData(
            colorScheme:
                const ColorScheme.light(primary: AppColors.accent)),
        child: child!,
      ),
    );
    if (picked != null) {
      c.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
      onPicked?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      AppTextField(label: 'Joining Date',
          controller: ctrl.joiningDateController,
          hint: 'YYYY-MM-DD', required: true,
          suffix: IconButton(
            icon: const Icon(Icons.calendar_today_rounded,
                color: AppColors.textSecondary, size: 18),
            onPressed: () => _pickDate(context, ctrl.joiningDateController,
                onPicked: ctrl.recomputeMissing),
          ),
          onChanged: (_) => ctrl.recomputeMissing()),
      const SizedBox(height: 12),
      AppTextField(label: 'Confirmation Date',
          controller: ctrl.confirmationDateController,
          hint: 'Auto-set to joining + 6 months',
          helperText: 'Auto-computed — adjust if needed',
          suffix: IconButton(
            icon: const Icon(Icons.calendar_today_rounded,
                color: AppColors.textSecondary, size: 18),
            onPressed: () => _pickDate(
                context, ctrl.confirmationDateController,
                onPicked: ctrl.markConfirmationTouched),
          ),
          onChanged: (_) => ctrl.markConfirmationTouched()),
      const SizedBox(height: 12),
      AppTextField(label: 'Client', controller: ctrl.clientController,
          hint: 'Client / company name', required: true,
          helperText: 'API dropdown — type for now',
          onChanged: (_) => ctrl.recomputeMissing()),
      const SizedBox(height: 12),
      AppTextField(label: 'Branch / Location',
          controller: ctrl.branchController,
          hint: 'Branch name', required: true,
          helperText: 'API dropdown — type for now',
          onChanged: (_) => ctrl.recomputeMissing()),
      const SizedBox(height: 12),
      AppTextField(label: 'Department',
          controller: ctrl.departmentController,
          hint: 'Department name',
          helperText: 'API dropdown — type for now',
          onChanged: (_) => ctrl.recomputeMissing()),
      const SizedBox(height: 12),
      AppTextField(label: 'Designation',
          controller: ctrl.designationController,
          hint: 'Job title / designation', required: true,
          helperText: 'API dropdown — type for now',
          onChanged: (_) => ctrl.recomputeMissing()),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _BankTaxSection extends StatelessWidget {
  final AddEmployeeController ctrl;
  const _BankTaxSection({required this.ctrl});

  static const _banks = [
    'State Bank of India', 'HDFC Bank', 'ICICI Bank', 'Axis Bank',
    'Kotak Mahindra Bank', 'Punjab National Bank', 'Bank of Baroda',
    'Canara Bank', 'Union Bank of India', 'IndusInd Bank',
    'Yes Bank', 'IDFC First Bank', 'Federal Bank', 'South Indian Bank',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      AppTextField(label: 'Bank Account Number',
          controller: ctrl.bankAccountController,
          hint: 'Enter account number', required: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => ctrl.recomputeMissing()),
      const SizedBox(height: 12),
      Obx(() => AppDropdown<String>(
            label: 'Bank Name',
            value: ctrl.bankNameValue.value.isEmpty
                ? null
                : ctrl.bankNameValue.value,
            hint: 'Select bank', required: true,
            items: _banks
                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                .toList(),
            onChanged: (v) => ctrl.bankNameValue.value = v ?? '',
          )),
      const SizedBox(height: 12),
      AppTextField(label: 'IFSC Code', controller: ctrl.ifscController,
          hint: 'SBIN0001234', required: true,
          helperText: 'Format: SBIN0001234',
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            LengthLimitingTextInputFormatter(11),
            _UpperCaseFormatter(),
          ],
          onChanged: (_) => ctrl.recomputeMissing()),
      const SizedBox(height: 12),
      Obx(() => AppTextField(
            label: 'PAN Number', controller: ctrl.panController,
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
      AppTextField(label: 'UAN (PF Account)',
          controller: ctrl.uanController,
          hint: '100123456789', keyboardType: TextInputType.number,
          helperText: 'Optional'),
      const SizedBox(height: 12),
      AppTextField(label: 'PF Account Number',
          controller: ctrl.pfController,
          hint: 'DL/CPM/1234567/000/0000123', helperText: 'Optional'),
      const SizedBox(height: 12),
      AppTextField(label: 'ESIC Number', controller: ctrl.esicController,
          hint: '3112345678', keyboardType: TextInputType.number,
          helperText: 'Optional'),
    ]);
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
          TextEditingValue o, TextEditingValue n) =>
      n.copyWith(text: n.text.toUpperCase());
}

// ─────────────────────────────────────────────────────────────────────────────
class _DocumentsSection extends StatelessWidget {
  final AddEmployeeController ctrl;
  const _DocumentsSection({required this.ctrl});

  Future<void> _pick(BuildContext context, String key) async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => const _PickerSheet(title: 'Upload Document'),
    );
    if (src == null) return;
    final img =
        await ImagePicker().pickImage(source: src, imageQuality: 90);
    if (img != null) ctrl.setDocument(key, File(img.path));
  }

  String? _fname(File? f) {
    if (f == null) return null;
    final p = f.path;
    return p.contains('\\') ? p.split('\\').last : p.split('/').last;
  }

  static const _slots = [
    ('PAN_CARD',     'PAN Card',          'Required when PAN number is entered'),
    ('BANK_PROOF',   'Bank Account Copy', 'Cancelled cheque or passbook'),
    ('MARK_SHEET',   'Mark Sheet',        'Latest qualifying mark sheet'),
    ('SIGNATURE',    'Signature',         'Specimen signature image'),
    ('OFFER_LETTER', 'Offer Letter',      'Optional'),
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
            child: Text(
                'Aadhaar documents are in the Identity section above.',
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.info)),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      ..._slots.map((slot) => Obx(() {
            final required = isDocRequired(ctrl.employmentType.value, slot.$1) ||
                (slot.$1 == 'PAN_CARD' &&
                    ctrl.panController.text.trim().isNotEmpty);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DocumentSlotTile(
                label:      slot.$2,
                helperText: slot.$3,
                required:   required,
                fileName:   _fname(ctrl.documents[slot.$1]),
                onPick:     () => _pick(context, slot.$1),
                onClear:    () => ctrl.clearDocument(slot.$1),
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
  const _SuccessSheet({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4,
            decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(100))),
        const SizedBox(height: 24),
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
              color: AppColors.successLight,
              borderRadius: BorderRadius.circular(32)),
          child: const Icon(Icons.check_rounded,
              color: AppColors.success, size: 36),
        ),
        const SizedBox(height: 16),
        Text('Employee Created!', style: AppTextStyles.headingLarge),
        const SizedBox(height: 6),
        Text(name.isEmpty ? 'New Employee' : name,
            style: AppTextStyles.bodyLarge
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Text('(API not wired yet — UI preview only)',
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textTertiary)),
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
            onPressed: () { Get.back(); Get.back(); },
            child: Text('Done',
                style: AppTextStyles.buttonLarge
                    .copyWith(color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}