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
  final currentPage = 0.obs;
  final totalPages = 1.obs;
  final totalRecords = 0.obs;

  final _api = EmployeeApi();

  @override
  void onInit() {
    super.onInit();
    fetchEmployees();
  }

  /// Fetch employees from POST /api/v1/employees/list
  Future<void> fetchEmployees({int page = 0}) async {
    isLoading.value = true;
    errorMsg.value = '';

    try {
      // Build filter request matching the web's FilterRequest shape
      final filters = <String, dynamic>{};
      if (statusFilter.value != 'ALL') {
        filters['status'] = statusFilter.value;
      }
      if (typeFilter.value != 'ALL') {
        filters['employmentType'] = typeFilter.value;
      }
      if (searchQuery.value.isNotEmpty) {
        filters['search'] = searchQuery.value;
      }

      final filterRequest = {
        'page': page,
        'size': 50,
        'sortBy': 'firstName',
        'sortDir': 'ASC',
        'filters': filters,
      };

      final res = await _api.getEmployees(filterRequest);

      // Map domain EmployeeSummary → page-level Employee model
      final list = (res.data ?? [])
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
              ))
          .toList();

      employees.value = list;
      currentPage.value = res.page ?? 0;
      totalPages.value = res.totalPages ?? 1;
      totalRecords.value = res.totalRecords ?? list.length;
    } on DioException catch (e) {
      errorMsg.value = ApiFailure.fromDioException(e).message;
    } catch (e) {
      errorMsg.value = 'Failed to load employees: $e';
    } finally {
      isLoading.value = false;
    }
  }

  /// Filtered list (client-side quick filter on already-fetched data).
  /// For server-side filtering, call fetchEmployees() which sends filters.
  List<Employee> get filtered {
    final q = searchQuery.value.toLowerCase();
    return employees.where((e) {
      final matchSearch = q.isEmpty ||
          e.fullName.toLowerCase().contains(q) ||
          e.employeeCode.toLowerCase().contains(q) ||
          (e.designation?.toLowerCase().contains(q) ?? false) ||
          (e.branch?.toLowerCase().contains(q) ?? false);
      final matchStatus =
          statusFilter.value == 'ALL' || e.status == statusFilter.value;
      final matchType =
          typeFilter.value == 'ALL' || e.employmentType == typeFilter.value;
      return matchSearch && matchStatus && matchType;
    }).toList();
  }

  /// Re-fetch with current filters from the API
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
