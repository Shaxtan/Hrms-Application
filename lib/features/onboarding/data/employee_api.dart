import 'dart:io';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../domain/employee_models.dart';

class EmployeeApi {
  final Dio _dio = ApiClient.instance;

  // ── Employee list ─────────────────────────────────────────────────────────
  Future<ApiResponse<List<EmployeeSummary>>> getEmployees(
    Map<String, dynamic> filterRequest,
  ) async {
    final res = await _dio.post('/api/v1/employees/list', data: filterRequest);
    final json = res.data as Map<String, dynamic>;
    final list = (json['data'] as List?)
            ?.map((e) => EmployeeSummary.fromJson(e))
            .toList() ??
        [];
    return ApiResponse<List<EmployeeSummary>>(
      data: list,
      message: json['message'],
      totalRecords: json['totalRecords'],
      page: json['page'],
      totalPages: json['totalPages'],
    );
  }

  // ── Create employee (provisional) ────────────────────────────────────────
  Future<Map<String, dynamic>> createEmployee(
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.post('/api/v1/employees', data: payload);
    return res.data as Map<String, dynamic>;
  }

  // ── Finalize employee creation ────────────────────────────────────────────
  Future<Map<String, dynamic>> finalizeEmployeeCreation(
    int employeeId,
  ) async {
    final res =
        await _dio.post('/api/v1/employees/$employeeId/finalize-creation');
    return res.data as Map<String, dynamic>;
  }

  // ── Discard provisional employee ─────────────────────────────────────────
  Future<void> discardEmployeeCreation(int employeeId) async {
    await _dio.post('/api/v1/employees/$employeeId/discard-creation');
  }

  // ── Upload profile photo ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> uploadProfilePicture(
    int employeeId,
    File file,
  ) async {
    final bytes = await file.readAsBytes();
    final fileName = file.path.split('/').last.split('\\').last;
    final formData = FormData.fromMap({
      'photo': MultipartFile.fromBytes(
        bytes,
        filename: fileName.isNotEmpty ? fileName : 'photo.jpg',
      ),
    });
    final res = await _dio.post(
      '/api/v1/employees/$employeeId/photo',
      data: formData,
    );
    return res.data as Map<String, dynamic>;
  }

  // ── Add bank account ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> addBankAccount(
    int employeeId,
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.post(
      '/api/v1/employees/$employeeId/bank-accounts',
      data: payload,
    );
    return res.data as Map<String, dynamic>;
  }

  // ── Add family member ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>> addFamilyMember(
    int employeeId,
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.post(
      '/api/v1/employees/$employeeId/family-members',
      data: payload,
    );
    return res.data as Map<String, dynamic>;
  }

  // ── Add emergency contact ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> addEmergencyContact(
    int employeeId,
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.post(
      '/api/v1/employees/$employeeId/emergency-contacts',
      data: payload,
    );
    return res.data as Map<String, dynamic>;
  }

  // ── Aadhaar dedup check ───────────────────────────────────────────────────
  Future<Map<String, dynamic>> checkAadhaar(String aadhaarNumber) async {
    final res = await _dio.post(
      '/api/v1/employees/check-aadhaar',
      data: {'aadhaarNumber': aadhaarNumber},
    );
    return res.data as Map<String, dynamic>;
  }

  // ── Availability check (email / phone / PAN / code) ───────────────────────
  Future<Map<String, dynamic>> checkAvailability(
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.post(
      '/api/v1/employees/check-availability',
      data: payload,
    );
    return res.data as Map<String, dynamic>;
  }

  // ── My submissions (supervisor) ───────────────────────────────────────────
  Future<List<dynamic>> getMySubmissions() async {
    final res = await _dio.get('/api/v1/employees/my-submissions');
    final data = res.data;
    return (data['data'] as List?) ?? [];
  }

  // ── Pending onboarding (approver) ─────────────────────────────────────────
  Future<List<dynamic>> getPendingOnboarding() async {
    final res = await _dio.get('/api/v1/employees/onboarding/pending');
    final data = res.data;
    return (data['data'] as List?) ?? [];
  }

  // ── Upload document ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>> uploadDocument({
    required int employeeId,
    required String documentCategory,
    required String documentType,
    required File file,
    bool replaceExisting = true,
  }) async {
    final bytes = await file.readAsBytes();
    final fileName = file.path.split('/').last.split('\\').last;
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: fileName.isNotEmpty ? fileName : 'document.jpg',
      ),
      'employeeId': employeeId.toString(),
      'documentCategory': documentCategory,
      'documentType': documentType,
      'replaceExisting': replaceExisting.toString(),
    });
    final res = await _dio.post('/api/v1/documents/upload', data: formData);
    return res.data as Map<String, dynamic>;
  }

  // ── Dashboard summary ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getDashboardSummary() async {
    final res = await _dio.get('/api/v1/dashboard/summary');
    return res.data as Map<String, dynamic>;
  }

  // ── Get single employee by ID ────────────────────────────────────────────
  Future<Map<String, dynamic>> getEmployeeById(int id) async {
    final res = await _dio.get('/api/v1/employees/$id');
    return res.data as Map<String, dynamic>;
  }

  // ── Patch (update) employee ──────────────────────────────────────────────
  Future<Map<String, dynamic>> patchEmployee(
    int employeeId,
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.patch(
      '/api/v1/employees/$employeeId',
      data: payload,
    );
    return res.data as Map<String, dynamic>;
  }

  // ── Get employee documents ───────────────────────────────────────────────
  Future<List<dynamic>> getEmployeeDocuments(int employeeId) async {
    final res = await _dio.post('/api/v1/documents/list', data: {
      'page': 0,
      'size': 50,
      'sortBy': 'createdAt',
      'sortDir': 'DESC',
      'filters': {'employeeId': employeeId},
    });
    return (res.data?['data'] as List?) ?? [];
  }

  // ── Get family members ───────────────────────────────────────────────────
  Future<List<dynamic>> getFamilyMembers(int employeeId) async {
    final res = await _dio.get('/api/v1/employees/$employeeId/family-members');
    return (res.data?['data'] as List?) ?? [];
  }

  // ── Get emergency contacts ───────────────────────────────────────────────
  Future<List<dynamic>> getEmergencyContacts(int employeeId) async {
    final res =
        await _dio.get('/api/v1/employees/$employeeId/emergency-contacts');
    return (res.data?['data'] as List?) ?? [];
  }

  // ── Get bank accounts ────────────────────────────────────────────────────
  Future<List<dynamic>> getBankAccounts(int employeeId) async {
    final res = await _dio.get('/api/v1/employees/$employeeId/bank-accounts');
    return (res.data?['data'] as List?) ?? [];
  }

  // ── Build authenticated photo URL ────────────────────────────────────────
  static String buildPhotoUrl(String? profilePhotoUrl, int employeeId) {
    if (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty) {
      if (profilePhotoUrl.startsWith('http')) return profilePhotoUrl;
      // Relative URL — prepend the core service base
      return 'http://103.139.58.189:8081$profilePhotoUrl';
    }
    return 'http://103.139.58.189:8081/api/v1/employees/$employeeId/photo';
  }

  // ── Client companies ──────────────────────────────────────────────────────
  Future<List<ClientCompany>> getClientCompanies() async {
    final res = await _dio.post(
      '/api/v1/client-companies/list',
      data: {'page': 0, 'size': 100},
    );
    final data = res.data['data'];
    final list = (data is List ? data : data['content'] as List? ?? []);
    return list.map((e) => ClientCompany.fromJson(e)).toList();
  }

  // ── Branches ──────────────────────────────────────────────────────────────
  Future<List<Branch>> getBranches() async {
    final res = await _dio.get(
      '/api/v1/branches',
      queryParameters: {'activeOnly': true},
    );
    return ((res.data['data'] as List?) ?? [])
        .map((e) => Branch.fromJson(e))
        .toList();
  }

  // ── Effective departments for a branch ────────────────────────────────────
  Future<List<Department>> getEffectiveDepartments(int branchId) async {
    final res =
        await _dio.get('/api/v1/branches/$branchId/effective-departments');
    return ((res.data['data'] as List?) ?? [])
        .map((e) => Department.fromJson(e))
        .toList();
  }

  // ── Departments ───────────────────────────────────────────────────────────
  Future<List<Department>> getDepartments() async {
    final res = await _dio.post(
      '/api/v1/departments/list',
      data: {
        'page': 0,
        'size': 200,
        'sortBy': 'departmentName',
        'sortDir': 'ASC',
        'filters': {}
      },
    );
    final data = res.data['data'];
    final list = (data is List ? data : data['content'] as List? ?? []);
    return list.map((e) => Department.fromJson(e)).toList();
  }

  // ── Designations ──────────────────────────────────────────────────────────
  Future<List<Designation>> getDesignations() async {
    final res = await _dio.post(
      '/api/v1/designations/list',
      data: {
        'page': 0,
        'size': 200,
        'sortBy': 'designationName',
        'sortDir': 'ASC',
        'filters': {}
      },
    );
    final data = res.data['data'];
    final list = (data is List ? data : data['content'] as List? ?? []);
    return list.map((e) => Designation.fromJson(e)).toList();
  }

  // ── Approve / Reject ──────────────────────────────────────────────────────
  Future<void> approveOnboarding(int id) async {
    await _dio.post('/api/v1/employees/$id/approve', data: {});
  }

  Future<void> rejectOnboarding(int id, String? reason) async {
    await _dio.post('/api/v1/employees/$id/reject', data: {'reason': reason});
  }
}
