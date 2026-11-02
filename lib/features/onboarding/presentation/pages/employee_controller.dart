import 'package:get/get.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import 'employee_models.dart';
import '../../data/employee_api.dart';

class EmployeeController extends GetxController {
  final employees = <Employee>[].obs;
  final searchQuery = ''.obs;
  final statusFilter = 'ALL'.obs;
  final typeFilter = 'ALL'.obs;
  final isLoading = false.obs;
  final errorMsg = ''.obs;
  final totalRecords = 0.obs;

  final _api = EmployeeApi();

  @override
  void onInit() {
    super.onInit();
    fetchEmployees();
  }

  Future<void> fetchEmployees({int page = 0}) async {
    isLoading.value = true;
    errorMsg.value = '';
    try {
      final filters = <String, dynamic>{};
      if (statusFilter.value != 'ALL') filters['status'] = statusFilter.value;
      if (typeFilter.value != 'ALL')
        filters['employmentType'] = typeFilter.value;
      if (searchQuery.value.isNotEmpty) filters['search'] = searchQuery.value;

      final res = await _api.getEmployees({
        'page': page,
        'size': 50,
        'sortBy': 'firstName',
        'sortDir': 'ASC',
        'filters': filters,
      });

      employees.value = (res.data ?? [])
          .map((s) => Employee(
                id: s.id,
                employeeCode: s.employeeCode,
                firstName: s.firstName,
                lastName: s.lastName,
                email: s.email,
                phone: s.phone,
                status: s.status,
                employmentType: s.employmentType ?? 'CONTRACT',
                designation: s.designation,
                department: s.department,
                branch: s.branch,
                profilePhotoUrl: s.profilePhotoUrl,
              ))
          .toList();
      totalRecords.value = res.totalRecords ?? employees.length;

      // ── Mobile-number search fallback ──────────────────────────────────
      // If the search box holds a number and the server's search returned
      // nothing, load the same list WITHOUT the search term (same endpoint,
      // same request otherwise) and let `filtered` match the phone number
      // on the device.
      if (employees.isEmpty && _isNumberQuery(searchQuery.value)) {
        final all = await _api.getEmployees({
          'page': page,
          'size': 50,
          'sortBy': 'firstName',
          'sortDir': 'ASC',
          'filters': Map<String, dynamic>.from(filters)..remove('search'),
        });

        employees.value = (all.data ?? [])
            .map((s) => Employee(
                  id: s.id,
                  employeeCode: s.employeeCode,
                  firstName: s.firstName,
                  lastName: s.lastName,
                  email: s.email,
                  phone: s.phone,
                  status: s.status,
                  employmentType: s.employmentType ?? 'CONTRACT',
                  designation: s.designation,
                  department: s.department,
                  branch: s.branch,
                  profilePhotoUrl: s.profilePhotoUrl,
                ))
            .toList();
        // Show the number of matches, not the size of the whole list.
        totalRecords.value = filtered.length;
      }
    } on DioException catch (e) {
      errorMsg.value = ApiFailure.fromDioException(e).message;
    } catch (e) {
      errorMsg.value = 'Failed to load employees: $e';
    } finally {
      isLoading.value = false;
    }
  }

  List<Employee> get filtered {
    final q = searchQuery.value.toLowerCase();
    return employees.where((e) {
      final matchSearch = q.isEmpty ||
          e.fullName.toLowerCase().contains(q) ||
          e.employeeCode.toLowerCase().contains(q) ||
          (e.designation?.toLowerCase().contains(q) ?? false) ||
          (e.branch?.toLowerCase().contains(q) ?? false) ||
          _phoneMatches(e, q); // search by mobile number
      final matchStatus =
          statusFilter.value == 'ALL' || e.status == statusFilter.value;
      final matchType =
          typeFilter.value == 'ALL' || e.employmentType == typeFilter.value;
      return matchSearch && matchStatus && matchType;
    }).toList();
  }

  /// True when the search text is a number — digits, with optional
  /// spaces, '+' or '-' (e.g. "9876543210", "98765 43210", "+91 98765...").
  static bool _isNumberQuery(String q) {
    final t = q.trim();
    return t.isNotEmpty &&
        RegExp(r'^[\d\s+\-]+$').hasMatch(t) &&
        t.replaceAll(RegExp(r'\D'), '').isNotEmpty;
  }

  /// Mobile-number match on digits only, so spaces / dashes don't matter
  /// and a pasted "+91 9876543210" still finds 9876543210.
  static bool _phoneMatches(Employee e, String q) {
    if (!_isNumberQuery(q)) return false;
    var digits = q.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2); // drop +91 country code
    }
    final String? phone = e.phone;
    final phoneDigits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
    return phoneDigits.isNotEmpty && phoneDigits.contains(digits);
  }

  void applyFilters() => fetchEmployees();

  void updateEmployee(Employee updated) {
    final idx = employees.indexWhere((e) => e.id == updated.id);
    if (idx != -1) employees[idx] = updated;
  }

  Employee? findById(int id) {
    try {
      return employees.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }
}