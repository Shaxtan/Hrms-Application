// ── Employee summary (list view) ─────────────────────────────────────────────
class EmployeeSummary {
  final int id;
  final String employeeCode;
  final String? customCode;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String status;
  final String? employmentType;
  final String? profilePhotoUrl;
  final String? department;
  final String? branch;
  final String? designation;

  EmployeeSummary({
    required this.id,
    required this.employeeCode,
    this.customCode,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    required this.status,
    this.employmentType,
    this.profilePhotoUrl,
    this.department,
    this.branch,
    this.designation,
  });

  String get fullName => '$firstName $lastName'.trim();
  String get displayCode => customCode ?? employeeCode;

  factory EmployeeSummary.fromJson(Map<String, dynamic> j) {
    // API returns fullName as one field; split into first/last for compatibility
    String rawFirst = (j['firstName'] ?? '').toString().trim();
    String rawLast = (j['lastName'] ?? '').toString().trim();
    if (rawFirst.isEmpty && rawLast.isEmpty) {
      final full = (j['fullName'] ?? '').toString().trim();
      final parts =
          full.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
      rawFirst = parts.isNotEmpty ? parts.first : '';
      rawLast = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }
    return EmployeeSummary(
      id: j['employeeId'] ?? j['id'] ?? 0,
      employeeCode: j['employeeCode'] ?? '',
      customCode: j['customCode'],
      firstName: rawFirst,
      lastName: rawLast,
      email: j['email'],
      phone: j['phone'] ?? j['mobileNumber'],
      status: j['status'] ?? 'ACTIVE',
      employmentType: j['employmentType'],
      profilePhotoUrl: j['profilePhotoUrl'],
      department: j['department'],
      branch: j['branchName'] ?? j['branch'],
      designation: j['designation'],
    );
  }
}

// ── Pipeline metrics (supervisor dashboard) ───────────────────────────────────
class SupervisorMetrics {
  final int supervisorEmployeeId;
  final int onboarded;
  final int approved;
  final int rejected;
  final double approvalRate;
  final int managedWorkforce;
  final List<String> clientNames;
  final List<String> branchNames;

  SupervisorMetrics({
    required this.supervisorEmployeeId,
    required this.onboarded,
    required this.approved,
    required this.rejected,
    required this.approvalRate,
    required this.managedWorkforce,
    this.clientNames = const [],
    this.branchNames = const [],
  });

  // Derived: pending = onboarded - approved - rejected (clamped ≥ 0)
  int get pending => (onboarded - approved - rejected).clamp(0, onboarded);

  factory SupervisorMetrics.fromJson(Map<String, dynamic> j) =>
      SupervisorMetrics(
        supervisorEmployeeId: j['supervisorEmployeeId'] ?? 0,
        onboarded: j['onboarded'] ?? 0,
        approved: j['approved'] ?? 0,
        rejected: j['rejected'] ?? 0,
        approvalRate: (j['approvalRate'] ?? 0).toDouble(),
        managedWorkforce: j['managedWorkforce'] ?? 0,
        clientNames: List<String>.from(j['clientNames'] ?? []),
        branchNames: List<String>.from(j['branchNames'] ?? []),
      );
}

// ── Workforce KPIs ────────────────────────────────────────────────────────────
class WorkforceStats {
  final int working;
  final int deployed;
  final int bench;
  final double benchRatio;

  WorkforceStats({
    required this.working,
    required this.deployed,
    required this.bench,
    required this.benchRatio,
  });

  factory WorkforceStats.fromJson(Map<String, dynamic> j) => WorkforceStats(
        working: j['working'] ?? 0,
        deployed: j['deployed'] ?? 0,
        bench: j['bench'] ?? 0,
        benchRatio: (j['benchRatio'] ?? 0).toDouble(),
      );
}

// ── Recent onboarding row ─────────────────────────────────────────────────────
class RecentOnboardingRow {
  final int employeeId;
  final String fullName;
  final String status;
  final String? employmentType;
  final String? joiningDate;
  final String? branch;
  final String? client;

  RecentOnboardingRow({
    required this.employeeId,
    required this.fullName,
    required this.status,
    this.employmentType,
    this.joiningDate,
    this.branch,
    this.client,
  });

  factory RecentOnboardingRow.fromJson(Map<String, dynamic> j) =>
      RecentOnboardingRow(
        employeeId: j['employeeId'] ?? j['id'] ?? 0,
        fullName: j['fullName'] ??
            '${j['firstName'] ?? ''} ${j['lastName'] ?? ''}'.trim(),
        status: j['status'] ?? '',
        employmentType: j['employmentType'],
        joiningDate: j['joiningDate'],
        branch: j['branchName'] ?? j['branch'],
        client: j['client'] ?? j['clientCompanyName'],
      );
}

// ── Client company ─────────────────────────────────────────────────────────────
class ClientCompany {
  final int id;
  final String clientName;
  final String? clientCode;

  ClientCompany({required this.id, required this.clientName, this.clientCode});

  String get displayName =>
      clientCode != null ? '$clientName ($clientCode)' : clientName;

  factory ClientCompany.fromJson(Map<String, dynamic> j) => ClientCompany(
        id: j['id'],
        clientName: j['clientName'] ?? '',
        clientCode: j['clientCode'],
      );
}

// ── Branch ─────────────────────────────────────────────────────────────────────
class Branch {
  final int id;
  final String branchName;
  final String? branchCode;
  final int? clientCompanyId;

  Branch({
    required this.id,
    required this.branchName,
    this.branchCode,
    this.clientCompanyId,
  });

  String get displayName =>
      branchCode != null ? '$branchName ($branchCode)' : branchName;

  factory Branch.fromJson(Map<String, dynamic> j) => Branch(
        id: j['id'],
        branchName: j['branchName'] ?? '',
        branchCode: j['branchCode'],
        clientCompanyId: j['clientCompanyId'],
      );
}

// ── Department ────────────────────────────────────────────────────────────────
class Department {
  final int id;
  final String departmentName;
  final String? departmentCode;
  final int? clientCompanyId; // null = global

  Department({
    required this.id,
    required this.departmentName,
    this.departmentCode,
    this.clientCompanyId,
  });

  String get displayName =>
      '${departmentCode ?? departmentName}${clientCompanyId == null ? ' (global)' : ''}';

  factory Department.fromJson(Map<String, dynamic> j) => Department(
        id: j['departmentId'] ?? j['id'],
        departmentName: j['departmentName'] ?? j['departmentCode'] ?? '',
        departmentCode: j['departmentCode'],
        clientCompanyId: j['clientCompanyId'],
      );
}

// ── Designation ───────────────────────────────────────────────────────────────
class Designation {
  final int id;
  final String designationName;
  final int? clientCompanyId;

  Designation({
    required this.id,
    required this.designationName,
    this.clientCompanyId,
  });

  String get displayName =>
      '$designationName${clientCompanyId == null ? ' (global)' : ''}';

  factory Designation.fromJson(Map<String, dynamic> j) => Designation(
        id: j['id'],
        designationName: j['designationName'] ?? j['designationCode'] ?? '',
        clientCompanyId: j['clientCompanyId'],
      );
}

// ── Add Employee form state ────────────────────────────────────────────────────
class AddEmployeeFormData {
  // Employment type
  String employmentType = 'CONTRACT';

  // Identity
  String aadhaarNumber = '';
  bool aadhaarConsentGiven = false;

  // Personal
  String fullName = '';
  String fatherHusbandName = '';
  String motherName = '';
  String email = '';
  String phone = '';
  String secondaryPhone = '';
  String dateOfBirth = '';
  String gender = '';
  String maritalStatus = '';
  String bloodGroup = '';
  String caste = '';
  String permanentAddress = '';
  String currentAddress = '';

  // Job
  String joiningDate = '';
  String confirmationDate = '';
  int? clientCompanyId;
  int? branchId;
  int? departmentId;
  int? designationId;

  // Bank & Tax
  String bankAccountNumber = '';
  String bankName = '';
  String ifscCode = '';
  String pan = '';
  String uan = '';
  String pfAccountNumber = '';
  String esicNumber = '';

  AddEmployeeFormData();
}

// ── Step status for the results ledger ───────────────────────────────────────
enum StepStatus { pending, running, success, failed, skipped }

class StepResult {
  final String label;
  final StepStatus status;
  final String? error;

  const StepResult({
    required this.label,
    required this.status,
    this.error,
  });

  StepResult copyWith({StepStatus? status, String? error}) => StepResult(
        label: label,
        status: status ?? this.status,
        error: error ?? this.error,
      );
}
