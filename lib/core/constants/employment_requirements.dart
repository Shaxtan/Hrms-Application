// Mirror of employmentRequirements.js — single source of truth on mobile

enum EmploymentType {
  contract('CONTRACT', 'Contractual'),
  naps('NAPS', 'NAPS'),
  fullTime('FULL_TIME', 'Staff (Full Time)'),
  intern('INTERN', 'Intern');

  const EmploymentType(this.value, this.label);
  final String value;
  final String label;

  static EmploymentType fromValue(String v) =>
      EmploymentType.values.firstWhere((e) => e.value == v,
          orElse: () => EmploymentType.contract);
}

enum FieldRequirement { mandatory, optional }

// M = Mandatory, O = Optional
// INTERN always mirrors NAPS
const _M = FieldRequirement.mandatory;
const _O = FieldRequirement.optional;

// { contract, naps, fullTime, intern }
const Map<String, Map<String, FieldRequirement>> fieldMatrix = {
  'aadhaarNumber':     {'CONTRACT': _M, 'NAPS': _M, 'FULL_TIME': _M, 'INTERN': _M},
  'fullName':          {'CONTRACT': _M, 'NAPS': _M, 'FULL_TIME': _M, 'INTERN': _M},
  'fatherHusbandName': {'CONTRACT': _M, 'NAPS': _M, 'FULL_TIME': _M, 'INTERN': _M},
  'motherName':        {'CONTRACT': _O, 'NAPS': _M, 'FULL_TIME': _M, 'INTERN': _M},
  'email':             {'CONTRACT': _O, 'NAPS': _M, 'FULL_TIME': _M, 'INTERN': _M},
  'phone':             {'CONTRACT': _M, 'NAPS': _M, 'FULL_TIME': _M, 'INTERN': _M},
  'secondaryPhone':    {'CONTRACT': _O, 'NAPS': _M, 'FULL_TIME': _M, 'INTERN': _M},
  'dateOfBirth':       {'CONTRACT': _M, 'NAPS': _M, 'FULL_TIME': _M, 'INTERN': _M},
  'gender':            {'CONTRACT': _M, 'NAPS': _M, 'FULL_TIME': _M, 'INTERN': _M},
  'maritalStatus':     {'CONTRACT': _M, 'NAPS': _M, 'FULL_TIME': _M, 'INTERN': _M},
  'bloodGroup':        {'CONTRACT': _O, 'NAPS': _O, 'FULL_TIME': _M, 'INTERN': _O},
  'caste':             {'CONTRACT': _O, 'NAPS': _M, 'FULL_TIME': _M, 'INTERN': _M},
  'permanentAddress':  {'CONTRACT': _M, 'NAPS': _M, 'FULL_TIME': _M, 'INTERN': _M},
  'currentAddress':    {'CONTRACT': _M, 'NAPS': _M, 'FULL_TIME': _M, 'INTERN': _M},
  'joiningDate':       {'CONTRACT': _M, 'NAPS': _M, 'FULL_TIME': _M, 'INTERN': _M},
  'clientCompanyId':   {'CONTRACT': _M, 'NAPS': _M, 'FULL_TIME': _M, 'INTERN': _M},
  'branchId':          {'CONTRACT': _M, 'NAPS': _M, 'FULL_TIME': _M, 'INTERN': _M},
  'departmentId':      {'CONTRACT': _O, 'NAPS': _M, 'FULL_TIME': _M, 'INTERN': _M},
  'designationId':     {'CONTRACT': _M, 'NAPS': _M, 'FULL_TIME': _M, 'INTERN': _M},
  'bankName':          {'CONTRACT': _M, 'NAPS': _M, 'FULL_TIME': _M, 'INTERN': _M},
  'bankAccountNumber': {'CONTRACT': _M, 'NAPS': _M, 'FULL_TIME': _M, 'INTERN': _M},
  'ifscCode':          {'CONTRACT': _M, 'NAPS': _M, 'FULL_TIME': _M, 'INTERN': _M},
  'pan':               {'CONTRACT': _O, 'NAPS': _M, 'FULL_TIME': _M, 'INTERN': _M},
  'familyDetails':     {'CONTRACT': _M, 'NAPS': _O, 'FULL_TIME': _M, 'INTERN': _O},
};

const Map<String, Map<String, FieldRequirement>> docMatrix = {
  'AADHAAR_FRONT': {'CONTRACT': _M, 'NAPS': _M, 'FULL_TIME': _M, 'INTERN': _M},
  'AADHAAR_BACK':  {'CONTRACT': _M, 'NAPS': _M, 'FULL_TIME': _M, 'INTERN': _M},
  'BANK_PROOF':    {'CONTRACT': _M, 'NAPS': _M, 'FULL_TIME': _M, 'INTERN': _M},
  'PAN_CARD':      {'CONTRACT': _O, 'NAPS': _M, 'FULL_TIME': _M, 'INTERN': _M},
  'MARK_SHEET':    {'CONTRACT': _O, 'NAPS': _M, 'FULL_TIME': _M, 'INTERN': _M},
  'SIGNATURE':     {'CONTRACT': _O, 'NAPS': _M, 'FULL_TIME': _O, 'INTERN': _M},
  'PHOTO':         {'CONTRACT': _M, 'NAPS': _M, 'FULL_TIME': _M, 'INTERN': _M},
};

const Map<String, String> fieldLabels = {
  'aadhaarNumber': 'Aadhaar No',
  'fullName': 'Full Name',
  'fatherHusbandName': "Father's Name",
  'motherName': "Mother's Name",
  'email': 'Email ID',
  'phone': 'Mobile No',
  'secondaryPhone': 'Mobile No (2nd)',
  'dateOfBirth': 'Date of Birth',
  'gender': 'Gender',
  'maritalStatus': 'Marital Status',
  'bloodGroup': 'Blood Group',
  'caste': 'Caste / Community',
  'permanentAddress': 'Permanent Address',
  'currentAddress': 'Current Address',
  'joiningDate': 'Joining Date',
  'clientCompanyId': 'Client',
  'branchId': 'Branch / Location',
  'departmentId': 'Department',
  'designationId': 'Designation',
  'bankName': 'Bank Name',
  'bankAccountNumber': 'Account Number',
  'ifscCode': 'IFSC Code',
  'pan': 'PAN Number',
  'uan': 'UAN',
  'familyDetails': 'Family Details',
};

const Map<String, String> docLabels = {
  'AADHAAR_FRONT': 'Aadhaar (Front)',
  'AADHAAR_BACK': 'Aadhaar (Back)',
  'BANK_PROOF': 'Bank Proof',
  'PAN_CARD': 'PAN Card',
  'MARK_SHEET': 'Mark Sheet',
  'SIGNATURE': 'Signature',
  'PHOTO': 'Photo',
};

bool isFieldRequired(
  String type,
  String field, {
  bool isAdmin = false,
  bool hasClient = false,
}) {
  final placementFields = {'clientCompanyId', 'branchId', 'departmentId', 'designationId'};
  final req = fieldMatrix[field]?[type] == FieldRequirement.mandatory;
  if (!req) return false;
  if (placementFields.contains(field) && isAdmin && !hasClient) return false;
  return true;
}

bool isDocRequired(String type, String docKey) =>
    docMatrix[docKey]?[type] == FieldRequirement.mandatory;

List<String> requiredFieldKeys(String type, {bool isAdmin = false, bool hasClient = false}) =>
    fieldMatrix.keys
        .where((f) => isFieldRequired(type, f, isAdmin: isAdmin, hasClient: hasClient))
        .toList();

List<String> requiredDocKeys(String type) =>
    docMatrix.keys.where((d) => isDocRequired(type, d)).toList();

String labelForField(String field) => fieldLabels[field] ?? field;
String labelForDoc(String docKey) => docLabels[docKey] ?? docKey;
