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
          (e.branch?.toLowerCase().contains(q) ?? false);
      final matchStatus =
          statusFilter.value == 'ALL' || e.status == statusFilter.value;
      final matchType =
          typeFilter.value == 'ALL' || e.employmentType == typeFilter.value;
      return matchSearch && matchStatus && matchType;
    }).toList();
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
