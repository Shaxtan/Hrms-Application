import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// AUTH CONTROLLER — real API login via POST /api/v1/auth/login
// ═══════════════════════════════════════════════════════════════════════════════
class AuthController extends GetxController {
  static AuthController get to => Get.find();
  static const _storage = FlutterSecureStorage();

  final isLoggedIn = false.obs;
  final isLoading = false.obs;
  final errorMessage = ''.obs;
  final userName = ''.obs;
  final userRole = ''.obs;
  final userInitials = ''.obs;
  final companyName = ''.obs;

  // Stored IDs for header injection
  String? _tenantId;
  String? _branchId;
  int? _employeeId;

  int? get employeeId => _employeeId;

  String get roleDisplay {
    switch (userRole.value) {
      case 'PLATFORM_ADMIN':
        return 'Platform Admin';
      case 'TENANT_ADMIN':
        return 'Admin';
      case 'SUPERVISOR':
        return 'Supervisor';
      case 'TENANT_USER':
        return 'HR';
      case 'EMPLOYEE':
        return 'Employee';
      default:
        return userRole.value;
    }
  }

  @override
  void onInit() {
    super.onInit();
    _tryRestoreSession();
  }

  /// Try to restore a previous session from secure storage.
  Future<void> _tryRestoreSession() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return;

    final name = await _storage.read(key: 'user_name') ?? '';
    final role = await _storage.read(key: 'user_role') ?? '';
    final company = await _storage.read(key: 'company_name') ?? '';
    final initials = await _storage.read(key: 'user_initials') ?? '';
    _tenantId = await _storage.read(key: 'tenant_id');
    _branchId = await _storage.read(key: 'branch_id');
    final empIdStr = await _storage.read(key: 'employee_id');
    _employeeId = empIdStr != null ? int.tryParse(empIdStr) : null;

    userName.value = name;
    userRole.value = role;
    userInitials.value = initials;
    companyName.value = company;
    isLoggedIn.value = true;

    // Navigate to home if currently on login
    if (Get.currentRoute == '/login') {
      Get.offAllNamed('/home');
    }
  }

  /// Real login: POST /api/v1/auth/login
  Future<void> login(String email, String password) async {
    errorMessage.value = '';
    isLoading.value = true;

    try {
      final dio = ApiClient.instance;
      final res = await dio.post('/api/v1/auth/login', data: {
        'email': email.trim(),
        'password': password,
      });

      final body = res.data as Map<String, dynamic>;
      final success = body['success'] ?? false;

      if (!success) {
        errorMessage.value = body['message'] ?? 'Login failed.';
        isLoading.value = false;
        return;
      }

      final data = body['data'] as Map<String, dynamic>? ?? {};

      final token = data['accessToken'] as String?;
      final user = data['user'] as Map<String, dynamic>? ?? {};
      final name =
          '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
      final role = (user['role'] ?? user['roles']?[0] ?? '') as String;
      final tenantId = (user['tenantId'] ?? data['tenantId'])?.toString();
      final branchId = (user['branchId'] ?? data['branchId'])?.toString();
      final empId = user['employeeId']?.toString();
      final company =
          (user['companyName'] ?? user['tenantName'] ?? '') as String;

      if (token == null || token.isEmpty) {
        errorMessage.value = 'Login succeeded but no token received.';
        isLoading.value = false;
        return;
      }

      // Compute initials
      final parts = name.split(' ').where((w) => w.isNotEmpty).toList();
      final initials = parts.length >= 2
          ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
          : (parts.isNotEmpty ? parts[0][0].toUpperCase() : 'U');

      // Persist to secure storage
      await _storage.write(key: 'auth_token', value: token);
      if (tenantId != null)
        await _storage.write(key: 'tenant_id', value: tenantId);
      if (branchId != null)
        await _storage.write(key: 'branch_id', value: branchId);
      if (empId != null) await _storage.write(key: 'employee_id', value: empId);
      await _storage.write(key: 'user_name', value: name);
      await _storage.write(key: 'user_role', value: role);
      await _storage.write(key: 'user_initials', value: initials);
      await _storage.write(key: 'company_name', value: company);

      _tenantId = tenantId;
      _branchId = branchId;
      _employeeId = empId != null ? int.tryParse(empId) : null;

      userName.value = name;
      userRole.value = role;
      userInitials.value = initials;
      companyName.value = company;
      isLoggedIn.value = true;

      isLoading.value = false;
      Get.offAllNamed('/home');
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        errorMessage.value = data['message'];
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        errorMessage.value = 'Connection timed out. Please try again.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage.value = 'Cannot reach server. Check your connection.';
      } else {
        errorMessage.value = e.message ?? 'Login failed. Please try again.';
      }
      isLoading.value = false;
    } catch (e) {
      errorMessage.value = 'An unexpected error occurred.';
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    // Best-effort server logout
    try {
      await ApiClient.instance.post('/api/v1/auth/logout');
    } catch (_) {}

    await _storage.deleteAll();
    _tenantId = null;
    _branchId = null;
    _employeeId = null;

    isLoggedIn.value = false;
    userName.value = '';
    userRole.value = '';
    userInitials.value = '';
    companyName.value = '';
    errorMessage.value = '';

    Get.offAllNamed('/login');
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOGIN PAGE (UI unchanged — just uses the updated AuthController)
// ═══════════════════════════════════════════════════════════════════════════════
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Get.find<AuthController>().login(
      _emailCtrl.text,
      _passCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final t = ThemeController.to;
      return Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo area
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: AppColors.accentGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.accent.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8))
                          ],
                        ),
                        child: const Icon(Icons.business_rounded,
                            color: Colors.white, size: 36),
                      ),
                      const SizedBox(height: 24),
                      Text('Welcome back',
                          style: AppTextStyles.displayMedium
                              .copyWith(color: t.textPrimary)),
                      const SizedBox(height: 6),
                      Text('Sign in to your HRMS account',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: t.textSec)),
                      const SizedBox(height: 36),

                      // Error
                      Obx(() {
                        final err =
                            Get.find<AuthController>().errorMessage.value;
                        if (err.isEmpty) return const SizedBox.shrink();
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.dangerLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.danger.withOpacity(0.3)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline_rounded,
                                color: AppColors.danger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(err,
                                    style: AppTextStyles.bodySmall
                                        .copyWith(color: AppColors.danger))),
                          ]),
                        );
                      }),

                      // Email
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: t.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined,
                              color: t.textTert, size: 20),
                          filled: true,
                          fillColor: t.surfaceVar,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: t.border)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: t.border)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: AppColors.accent, width: 2)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Email is required'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Password
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: t.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline_rounded,
                              color: t.textTert, size: 20),
                          suffixIcon: GestureDetector(
                            onTap: () => setState(() => _obscure = !_obscure),
                            child: Icon(
                                _obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: t.textTert,
                                size: 20),
                          ),
                          filled: true,
                          fillColor: t.surfaceVar,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: t.border)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: t.border)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: AppColors.accent, width: 2)),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Password is required'
                            : null,
                      ),
                      const SizedBox(height: 28),

                      // Submit
                      Obx(() {
                        final loading =
                            Get.find<AuthController>().isLoading.value;
                        return SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation(
                                            Colors.white)))
                                : Text('Sign in',
                                    style: AppTextStyles.buttonMedium
                                        .copyWith(color: Colors.white)),
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
