import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// AUTH CONTROLLER — real API: POST /api/v1/auth/login
//
// Login response shape (from the web's LoginPage.jsx → acceptAuthenticatedResponse):
//   { data: { accessToken, employee: { employeeId, fullName, firstName, lastName, email, ... },
//             company: { tenantId, tenantName, logoUrl, ... },
//             accessibleCompanies: [...] } }
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
  final userEmail = ''.obs;

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

  Future<void> _tryRestoreSession() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) return;

    userName.value = await _storage.read(key: 'user_name') ?? '';
    userRole.value = await _storage.read(key: 'user_role') ?? '';
    companyName.value = await _storage.read(key: 'company_name') ?? '';
    userInitials.value = await _storage.read(key: 'user_initials') ?? '';
    userEmail.value = await _storage.read(key: 'user_email') ?? '';
    isLoggedIn.value = true;

    // If name is empty, try decoding from JWT
    if (userName.value.isEmpty) {
      final claims = ApiClient.decodeJwtPayload(token);
      final sub = claims['sub']?.toString() ?? '';
      if (sub.contains('@')) {
        userName.value = sub.split('@').first;
        userInitials.value =
            userName.value.isNotEmpty ? userName.value[0].toUpperCase() : 'U';
      }
    }

    // Fetch company name if not stored
    if (companyName.value.isEmpty) _fetchCompanyName();
    // Fetch real name if not stored
    if (userName.value.isEmpty || userName.value == 'User') _fetchMyProfile();

    if (Get.currentRoute == '/login') Get.offAllNamed('/home');
  }

  Future<void> login(String email, String password) async {
    errorMessage.value = '';
    isLoading.value = true;

    try {
      final res = await ApiClient.instance.post('/api/v1/auth/login', data: {
        'email': email.trim(),
        'password': password,
      });

      final body = res.data as Map<String, dynamic>;

      // Unwrap: body itself or body['data']
      final Map<String, dynamic> data = body['data'] is Map<String, dynamic>
          ? body['data'] as Map<String, dynamic>
          : body;

      // Token
      final token = (data['accessToken'] ??
          data['token'] ??
          body['accessToken']) as String?;
      if (token == null || token.isEmpty) {
        errorMessage.value = body['message'] ?? 'No token received.';
        isLoading.value = false;
        return;
      }

      // Decode JWT for authoritative claims
      final jwt = ApiClient.decodeJwtPayload(token);
      debugPrint('JWT CLAIMS: $jwt');

      // Employee object (may be absent for PLATFORM_ADMIN)
      final emp = data['employee'] as Map<String, dynamic>? ?? {};
      // Company object
      final company = data['company'] as Map<String, dynamic>? ?? {};

      // Name: prefer employee fields, fall back to JWT sub
      String name = '${emp['firstName'] ?? ''} ${emp['lastName'] ?? ''}'.trim();
      if (name.isEmpty) name = (emp['fullName'] ?? '').toString().trim();
      if (name.isEmpty) {
        // Fall back to JWT 'sub' (usually email) or 'name' claim
        final sub = jwt['sub']?.toString() ?? '';
        name = jwt['name']?.toString() ??
            (sub.contains('@') ? sub.split('@').first : sub);
      }

      // Role: from JWT (authoritative), fall back to employee/data
      final roles = ApiClient.getRolesFromToken(token);
      final role = roles.isNotEmpty
          ? roles.first
          : (emp['role'] ?? data['role'] ?? '').toString();

      // Tenant ID: from company object, fall back to JWT
      final tenantId =
          (company['tenantId'] ?? company['id'] ?? data['tenantId'])
                  ?.toString() ??
              ApiClient.getTenantIdFromToken(token);

      // Branch ID: from JWT
      final branchId = ApiClient.getBranchIdFromToken(token);

      // Employee ID
      final empId =
          (emp['employeeId'] ?? emp['id'] ?? data['employeeId'])?.toString() ??
              ApiClient.getEmployeeIdFromToken(token)?.toString();

      // Company name
      final companyStr = (company['tenantName'] ??
              company['companyName'] ??
              data['tenantName'] ??
              '')
          .toString();

      // Email
      final emailStr = (emp['email'] ?? jwt['sub'] ?? email).toString();

      // Initials
      final parts = name.split(' ').where((w) => w.isNotEmpty).toList();
      final initials = parts.length >= 2
          ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
          : (parts.isNotEmpty ? parts[0][0].toUpperCase() : 'U');

      // Persist
      await _storage.write(key: 'auth_token', value: token);
      if (tenantId != null)
        await _storage.write(key: 'tenant_id', value: tenantId);
      if (branchId != null)
        await _storage.write(key: 'branch_id', value: branchId);
      if (empId != null) await _storage.write(key: 'employee_id', value: empId);
      await _storage.write(key: 'user_name', value: name);
      await _storage.write(key: 'user_role', value: role);
      await _storage.write(key: 'user_initials', value: initials);
      await _storage.write(key: 'company_name', value: companyStr);
      await _storage.write(key: 'user_email', value: emailStr);

      userName.value = name;
      userRole.value = role;
      userInitials.value = initials;
      companyName.value = companyStr;
      userEmail.value = emailStr;
      isLoggedIn.value = true;
      isLoading.value = false;

      Get.offAllNamed('/home');

      // Fetch company name from API if not in login response
      if (companyName.value.isEmpty) _fetchCompanyName();
      // Fetch real user name if login response didn't include it
      if (userName.value.isEmpty || userName.value == 'User') _fetchMyProfile();
    } on DioException catch (e) {
      final d = e.response?.data;
      if (d is Map && d['message'] != null) {
        errorMessage.value = d['message'];
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage.value = 'Cannot reach server. Check your connection.';
      } else {
        errorMessage.value = e.message ?? 'Login failed.';
      }
      isLoading.value = false;
    } catch (e) {
      errorMessage.value = 'An unexpected error occurred.';
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    try {
      await ApiClient.instance.post('/api/v1/auth/logout');
    } catch (_) {}
    await _storage.deleteAll();
    isLoggedIn.value = false;
    userName.value = '';
    userRole.value = '';
    userInitials.value = '';
    companyName.value = '';
    userEmail.value = '';
    errorMessage.value = '';
    Get.offAllNamed('/login');
  }

  /// Fetch company name from POST /api/v1/client-companies/list (platform module)
  Future<void> _fetchCompanyName() async {
    try {
      final res =
          await ApiClient.instance.post('/api/v1/client-companies/list', data: {
        'page': 0,
        'size': 1,
        'sortBy': 'clientName',
        'sortDir': 'ASC',
        'filters': {},
      });
      final list = res.data?['data'] as List?;
      if (list != null && list.isNotEmpty) {
        final name = (list.first['clientName'] ?? '').toString();
        if (name.isNotEmpty) {
          companyName.value = name;
          await _storage.write(key: 'company_name', value: name);
        }
      }
    } catch (_) {}
  }

  /// Fetch the logged-in user's profile from GET /api/v1/employees/me
  /// to get the real name when the login response didn't include it.
  Future<void> _fetchMyProfile() async {
    try {
      final res = await ApiClient.instance.get('/api/v1/employees/me');
      final d = (res.data?['data'] ?? res.data) as Map<String, dynamic>?;
      if (d == null) return;

      String name = (d['fullName'] ?? '').toString().trim();
      if (name.isEmpty)
        name = '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}'.trim();

      if (name.isNotEmpty) {
        final parts = name.split(' ').where((w) => w.isNotEmpty).toList();
        final initials = parts.length >= 2
            ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
            : (parts.isNotEmpty ? parts[0][0].toUpperCase() : 'U');

        userName.value = name;
        userInitials.value = initials;
        await _storage.write(key: 'user_name', value: name);
        await _storage.write(key: 'user_initials', value: initials);
      }

      final email = (d['email'] ?? '').toString();
      if (email.isNotEmpty && userEmail.value.isEmpty) {
        userEmail.value = email;
        await _storage.write(key: 'user_email', value: email);
      }
    } catch (_) {}
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOGIN PAGE
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
    Get.find<AuthController>().login(_emailCtrl.text, _passCtrl.text);
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
                              ]),
                          child: const Icon(Icons.business_rounded,
                              color: Colors.white, size: 36)),
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
                                    color: AppColors.danger.withOpacity(0.3))),
                            child: Row(children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: AppColors.danger, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(err,
                                      style: AppTextStyles.bodySmall
                                          .copyWith(color: AppColors.danger))),
                            ]));
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
                                      color: AppColors.accent, width: 2))),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Email is required'
                              : null),
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
                                  onTap: () =>
                                      setState(() => _obscure = !_obscure),
                                  child: Icon(
                                      _obscure
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: t.textTert,
                                      size: 20)),
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
                                      color: AppColors.accent, width: 2))),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Password is required'
                              : null),
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
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    elevation: 0),
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
                                            .copyWith(color: Colors.white))));
                      }),
                      const SizedBox(height: 24),
                    ],
                  ))),
        ))),
      );
    });
  }
}
