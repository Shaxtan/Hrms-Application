import 'package:get/get.dart';
import 'employee_models.dart';

class EmployeeController extends GetxController {
  final employees   = <Employee>[].obs;
  final searchQuery = ''.obs;
  final statusFilter = 'ALL'.obs;
  final typeFilter   = 'ALL'.obs;

  @override
  void onInit() {
    super.onInit();
    employees.value = List.from(mockEmployees);
  }

  List<Employee> get filtered {
    final q = searchQuery.value.toLowerCase();
    return employees.where((e) {
      final matchSearch = q.isEmpty ||
          e.fullName.toLowerCase().contains(q) ||
          e.employeeCode.toLowerCase().contains(q) ||
          (e.designation?.toLowerCase().contains(q) ?? false) ||
          (e.branch?.toLowerCase().contains(q) ?? false);
      final matchStatus = statusFilter.value == 'ALL' ||
          e.status == statusFilter.value;
      final matchType = typeFilter.value == 'ALL' ||
          e.employmentType == typeFilter.value;
      return matchSearch && matchStatus && matchType;
    }).toList();
  }

  void updateEmployee(Employee updated) {
    final idx = employees.indexWhere((e) => e.id == updated.id);
    if (idx != -1) employees[idx] = updated;
  }

  Employee? findById(int id) {
    try { return employees.firstWhere((e) => e.id == id); }
    catch (_) { return null; }
  }
}