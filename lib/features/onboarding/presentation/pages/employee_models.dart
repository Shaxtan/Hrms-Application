// ═══════════════════════════════════════════════════════════════════════════════
// EMPLOYEE MODEL + MOCK DATA
// ═══════════════════════════════════════════════════════════════════════════════
class Employee {
  final int    id;
  final String employeeCode;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String  status;
  final String  employmentType;
  final String? designation;
  final String? department;
  final String? branch;
  final String? client;
  final String? joiningDate;
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
  String get initials => profileInitials ??
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
      id:               id,
      employeeCode:     employeeCode,
      firstName:        firstName        ?? this.firstName,
      lastName:         lastName         ?? this.lastName,
      email:            email            ?? this.email,
      phone:            phone            ?? this.phone,
      status:           status           ?? this.status,
      employmentType:   employmentType,
      designation:      designation      ?? this.designation,
      department:       department       ?? this.department,
      branch:           branch           ?? this.branch,
      client:           client,
      joiningDate:      joiningDate      ?? this.joiningDate,
      bloodGroup:       bloodGroup       ?? this.bloodGroup,
      gender:           gender           ?? this.gender,
      maritalStatus:    maritalStatus    ?? this.maritalStatus,
      permanentAddress: permanentAddress ?? this.permanentAddress,
      currentAddress:   currentAddress   ?? this.currentAddress,
      pan:              pan              ?? this.pan,
      uan:              uan              ?? this.uan,
      bankName:         bankName         ?? this.bankName,
      bankAccount:      bankAccount      ?? this.bankAccount,
      ifsc:             ifsc             ?? this.ifsc,
      fatherName:       fatherName       ?? this.fatherName,
    );
  }
}

// ── Mock employee list ─────────────────────────────────────────────────────────
final List<Employee> mockEmployees = [
  Employee(
    id: 101, employeeCode: 'EMP-0101',
    firstName: 'Priya',    lastName: 'Sharma',
    email: 'priya.sharma@acmecorp.com', phone: '9876543201',
    status: 'ACTIVE', employmentType: 'FULL_TIME',
    designation: 'Senior Engineer', department: 'Engineering',
    branch: 'Mumbai HQ', client: 'Acme Corp',
    joiningDate: '2026-08-15', bloodGroup: 'B+',
    gender: 'FEMALE', maritalStatus: 'MARRIED',
    permanentAddress: '12, Rose Garden, Andheri West, Mumbai – 400058',
    fatherName: 'Ramesh Sharma',
    pan: 'ABCPS1234F', uan: '100123456001',
    bankName: 'HDFC Bank', bankAccount: '****1234', ifsc: 'HDFC0001234',
  ),
  Employee(
    id: 102, employeeCode: 'EMP-0102',
    firstName: 'Rahul',    lastName: 'Verma',
    email: 'rahul.verma@globex.com', phone: '9876543202',
    status: 'ACTIVE', employmentType: 'FULL_TIME',
    designation: 'Project Manager', department: 'Operations',
    branch: 'Pune Branch', client: 'Globex',
    joiningDate: '2026-07-01', bloodGroup: 'O+',
    gender: 'MALE', maritalStatus: 'SINGLE',
    permanentAddress: '45, Koregaon Park, Pune – 411001',
    fatherName: 'Suresh Verma',
    pan: 'ABCPV5678G', uan: '100123456002',
    bankName: 'SBI', bankAccount: '****5678', ifsc: 'SBIN0001234',
  ),
  Employee(
    id: 103, employeeCode: 'EMP-0103',
    firstName: 'Anita',    lastName: 'Joshi',
    email: 'anita.joshi@acmecorp.com', phone: '9876543203',
    status: 'ACTIVE', employmentType: 'INTERN',
    designation: 'Intern – Design', department: 'Design',
    branch: 'Nashik Office', client: 'Acme Corp',
    joiningDate: '2026-09-01', bloodGroup: 'A+',
    gender: 'FEMALE', maritalStatus: 'SINGLE',
    permanentAddress: '7, Sharanpur Road, Nashik – 422002',
    fatherName: 'Vijay Joshi',
    bankName: 'ICICI Bank', bankAccount: '****9012', ifsc: 'ICIC0001234',
  ),
  Employee(
    id: 104, employeeCode: 'EMP-0104',
    firstName: 'Deepak',   lastName: 'Kumar',
    email: 'deepak.kumar@globex.com', phone: '9876543204',
    status: 'ACTIVE', employmentType: 'CONTRACT',
    designation: 'Site Supervisor', department: 'Field Ops',
    branch: 'Pune Branch', client: 'Globex',
    joiningDate: '2026-08-20', bloodGroup: 'AB+',
    gender: 'MALE', maritalStatus: 'MARRIED',
    permanentAddress: '22, Camp Area, Pune – 411001',
    fatherName: 'Mohan Kumar',
    pan: 'ABCDK9012H', bankName: 'Axis Bank', bankAccount: '****3456', ifsc: 'UTIB0001234',
  ),
  Employee(
    id: 105, employeeCode: 'EMP-0105',
    firstName: 'Sneha',    lastName: 'Patil',
    email: 'sneha.patil@acmecorp.com', phone: '9876543205',
    status: 'ACTIVE', employmentType: 'NAPS',
    designation: 'Apprentice – Production', department: 'Production',
    branch: 'Mumbai HQ', client: 'Acme Corp',
    joiningDate: '2026-08-10', bloodGroup: 'O-',
    gender: 'FEMALE', maritalStatus: 'SINGLE',
    permanentAddress: '88, Chembur Colony, Mumbai – 400071',
    fatherName: 'Ganesh Patil',
    pan: 'ABCSP3456I', bankName: 'Kotak Mahindra Bank', bankAccount: '****7890', ifsc: 'KKBK0001234',
  ),
  Employee(
    id: 106, employeeCode: 'EMP-0106',
    firstName: 'Mohammed', lastName: 'Raza',
    email: 'raza@globex.com', phone: '9876543206',
    status: 'PENDING_SALARY_SETUP', employmentType: 'CONTRACT',
    designation: 'Welder – Grade B', department: 'Production',
    branch: 'Mumbai HQ', client: 'Globex',
    joiningDate: '2026-09-05', bloodGroup: 'B-',
    gender: 'MALE', maritalStatus: 'MARRIED',
    permanentAddress: '15, Govandi East, Mumbai – 400088',
    fatherName: 'Abdul Raza',
    bankName: 'Yes Bank', bankAccount: '****2345', ifsc: 'YESB0001234',
  ),
  Employee(
    id: 107, employeeCode: 'EMP-0107',
    firstName: 'Kavita',   lastName: 'Nair',
    email: 'kavita.nair@acmecorp.com', phone: '9876543207',
    status: 'ACTIVE', employmentType: 'FULL_TIME',
    designation: 'HR Executive', department: 'Human Resources',
    branch: 'Nashik Office', client: 'Acme Corp',
    joiningDate: '2026-06-15', bloodGroup: 'A-',
    gender: 'FEMALE', maritalStatus: 'MARRIED',
    permanentAddress: '33, Gangapur Road, Nashik – 422013',
    fatherName: 'Sasi Nair',
    pan: 'ABCKN7890J', uan: '100123456007',
    bankName: 'Federal Bank', bankAccount: '****6789', ifsc: 'FDRL0001234',
  ),
  Employee(
    id: 108, employeeCode: 'EMP-0108',
    firstName: 'Arjun',    lastName: 'Singh',
    email: 'arjun.singh@globex.com', phone: '9876543208',
    status: 'UNASSIGNED', employmentType: 'CONTRACT',
    designation: 'Electrician – Grade A', department: 'Maintenance',
    branch: 'Pune Branch', client: 'Globex',
    joiningDate: '2026-07-20', bloodGroup: 'O+',
    gender: 'MALE', maritalStatus: 'SINGLE',
    permanentAddress: '56, Kothrud, Pune – 411038',
    fatherName: 'Harpal Singh',
    bankName: 'Punjab National Bank', bankAccount: '****1122', ifsc: 'PUNB0001234',
  ),
];