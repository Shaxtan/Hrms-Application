// ═══════════════════════════════════════════════════════════════════════════════
// EMPLOYEE MODEL + MOCK DATA
// ═══════════════════════════════════════════════════════════════════════════════
class Employee {
  final int id;
  final String employeeCode;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String status;
  final String employmentType;
  final String? designation;
  final String? department;
  final String? branch;
  final String? client;
  final String? joiningDate;
  final String? profilePhotoUrl;
  final String? bloodGroup;
  final String? gender;
  final String? maritalStatus;
  final String? permanentAddress;
  final String? currentAddress;
  final String? pan;
  final String? uan;
  final String? bankName;
  final String? bankAccount;
  final String? ifsc;
  final String? fatherName;
  final String? profileInitials;

  Employee({
    required this.id,
    required this.employeeCode,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    required this.status,
    required this.employmentType,
    this.designation,
    this.department,
    this.branch,
    this.client,
    this.joiningDate,
    this.profilePhotoUrl,
    this.bloodGroup,
    this.gender,
    this.maritalStatus,
    this.permanentAddress,
    this.currentAddress,
    this.pan,
    this.uan,
    this.bankName,
    this.bankAccount,
    this.ifsc,
    this.fatherName,
    this.profileInitials,
  });

  String get fullName => '$firstName $lastName'.trim();
  String get initials =>
      profileInitials ??
      '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
          .toUpperCase();

  Employee copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? status,
    String? designation,
    String? department,
    String? branch,
    String? joiningDate,
    String? bloodGroup,
    String? gender,
    String? maritalStatus,
    String? permanentAddress,
    String? currentAddress,
    String? pan,
    String? uan,
    String? bankName,
    String? bankAccount,
    String? ifsc,
    String? fatherName,
  }) {
    return Employee(
      id: id,
      employeeCode: employeeCode,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      employmentType: employmentType,
      designation: designation ?? this.designation,
      department: department ?? this.department,
      branch: branch ?? this.branch,
      client: client,
      joiningDate: joiningDate ?? this.joiningDate,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      gender: gender ?? this.gender,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      permanentAddress: permanentAddress ?? this.permanentAddress,
      currentAddress: currentAddress ?? this.currentAddress,
      pan: pan ?? this.pan,
      uan: uan ?? this.uan,
      bankName: bankName ?? this.bankName,
      bankAccount: bankAccount ?? this.bankAccount,
      ifsc: ifsc ?? this.ifsc,
      fatherName: fatherName ?? this.fatherName,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
    );
  }
}

// No mock data — employees are fetched from the API.
