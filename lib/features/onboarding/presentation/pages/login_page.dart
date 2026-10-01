import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
// LOGIN PAGE — industry-standard redesign
// Layout  : dark gradient background + white floating form card
// GetX    : GetBuilder<AuthController> for reactive sections — NO Obx anywhere,
//           avoids the nested-Obx red screen entirely
// Animation: 900 ms fade + slide-up entry
// ═══════════════════════════════════════════════════════════════════════════════
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _formKey   = GlobalKey<FormState>();
  final _emailFocus = FocusNode();
  final _passFocus  = FocusNode();

  bool _obscure      = true;
  bool _emailFocused = false;
  bool _passFocused  = false;

  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    _emailFocus.addListener(
        () => setState(() => _emailFocused = _emailFocus.hasFocus));
    _passFocus.addListener(
        () => setState(() => _passFocused = _passFocus.hasFocus));

    WidgetsBinding.instance.addPostFrameCallback((_) => _animCtrl.forward());
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    Get.find<AuthController>().login(_emailCtrl.text.trim(), _passCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final size   = MediaQuery.of(context).size;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        resizeToAvoidBottomInset: true,
        body: Stack(children: [
          // ── Background ──────────────────────────────────────────────────
          _Background(size: size),

          // ── Content ─────────────────────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.only(bottom: bottom + 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: size.height
                      - MediaQuery.of(context).padding.top
                      - MediaQuery.of(context).padding.bottom,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 48),

                      // Brand header
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: const _BrandHeader(),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Form card
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: _FormCard(
                            formKey:         _formKey,
                            emailCtrl:       _emailCtrl,
                            passCtrl:        _passCtrl,
                            emailFocus:      _emailFocus,
                            passFocus:       _passFocus,
                            emailFocused:    _emailFocused,
                            passFocused:     _passFocused,
                            obscure:         _obscure,
                            onToggleObscure: () =>
                                setState(() => _obscure = !_obscure),
                            onSubmit: _submit,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Footer
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: const _Footer(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Background ─────────────────────────────────────────────────────────────────
class _Background extends StatelessWidget {
  final Size size;
  const _Background({required this.size});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      // Base gradient
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
      // Top-right glow
      Positioned(
        top: -100, right: -100,
        child: Container(
          width: 320, height: 320,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              const Color(0xFF4F46E5).withOpacity(0.28),
              Colors.transparent,
            ]),
          ),
        ),
      ),
      // Bottom-left glow
      Positioned(
        bottom: -80, left: -80,
        child: Container(
          width: 260, height: 260,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              const Color(0xFF7C3AED).withOpacity(0.22),
              Colors.transparent,
            ]),
          ),
        ),
      ),
      // Subtle grid overlay
      Positioned.fill(child: CustomPaint(painter: _GridPainter())),
    ]);
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = Colors.white.withOpacity(0.03)
      ..strokeWidth = 0.8;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y < size.height; y += step)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Brand header ───────────────────────────────────────────────────────────────
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Logo tile
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withOpacity(0.5),
              blurRadius: 22, offset: const Offset(0, 8)),
          ],
        ),
        child: const Icon(Icons.business_rounded, color: Colors.white, size: 26),
      ),
      const SizedBox(height: 20),
      // Wordmark
      RichText(
        text: const TextSpan(
          children: [
            TextSpan(
              text: 'HR',
              style: TextStyle(
                  fontSize: 34, fontWeight: FontWeight.w800,
                  color: Colors.white, letterSpacing: -1.0),
            ),
            TextSpan(
              text: 'MS',
              style: TextStyle(
                  fontSize: 34, fontWeight: FontWeight.w800,
                  color: Color(0xFF818CF8), letterSpacing: -1.0),
            ),
          ],
        ),
      ),
      const SizedBox(height: 5),
      const Text(
        'Employee Onboarding Platform',
        style: TextStyle(
            fontSize: 13, color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w400, letterSpacing: 0.1),
      ),
    ]);
  }
}

// ── Form card ──────────────────────────────────────────────────────────────────
class _FormCard extends StatelessWidget {
  final GlobalKey<FormState>  formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final FocusNode             emailFocus;
  final FocusNode             passFocus;
  final bool emailFocused;
  final bool passFocused;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;

  const _FormCard({
    required this.formKey,
    required this.emailCtrl,
    required this.passCtrl,
    required this.emailFocus,
    required this.passFocus,
    required this.emailFocused,
    required this.passFocused,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  InputDecoration _fieldDeco({
    required String   hint,
    required IconData icon,
    required bool     focused,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
      prefixIcon: Padding(
        padding: const EdgeInsets.all(13),
        child: Icon(icon, size: 18,
            color: focused ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8)),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 46),
      suffixIcon: suffix,
      filled:    true,
      fillColor: focused ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 40, offset: const Offset(0, 20)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(children: [
          // Gradient accent bar at top of card
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card heading
                  const Text(
                    'Welcome back',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A), letterSpacing: -0.4),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sign in to continue to your workspace',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),

                  const SizedBox(height: 28),

                  // ── Email ────────────────────────────────────────────────
                  const _FieldLabel(label: 'Email or Phone'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller:      emailCtrl,
                    focusNode:       emailFocus,
                    keyboardType:    TextInputType.text,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => passFocus.requestFocus(),
                    style: const TextStyle(
                        fontSize: 15, color: Color(0xFF0F172A)),
                    decoration: _fieldDeco(
                      hint:    'Email or phone number',
                      icon:    Icons.person_outline_rounded,
                      focused: emailFocused,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Email / phone is required';
                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  // ── Password ─────────────────────────────────────────────
                  const _FieldLabel(label: 'Password'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller:      passCtrl,
                    focusNode:       passFocus,
                    obscureText:     obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => onSubmit(),
                    style: const TextStyle(
                        fontSize: 15, color: Color(0xFF0F172A)),
                    decoration: _fieldDeco(
                      hint:    '••••••••',
                      icon:    Icons.lock_outline_rounded,
                      focused: passFocused,
                      suffix: GestureDetector(
                        onTap: onToggleObscure,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18, color: const Color(0xFF94A3B8)),
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password is required';
                      if (v.length < 6) return 'At least 6 characters';
                      return null;
                    },
                  ),

                  const SizedBox(height: 8),

                  // Forgot password
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {},
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'Forgot password?',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF4F46E5),
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── Error banner — GetBuilder, NOT Obx ───────────────────
                  GetBuilder<AuthController>(
                    builder: (auth) {
                      if (auth.errorMessage.value.isEmpty)
                        return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 18),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  const Color(0xFFDC2626).withOpacity(0.25)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline_rounded,
                              color: Color(0xFFDC2626), size: 17),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              auth.errorMessage.value,
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFFDC2626)),
                            ),
                          ),
                        ]),
                      );
                    },
                  ),

                  // ── Sign-in button — GetBuilder, NOT Obx ─────────────────
                  GetBuilder<AuthController>(
                    builder: (auth) {
                      final loading = auth.isLoading.value;
                      return GestureDetector(
                        onTap: loading ? null : onSubmit,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width:  double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: loading
                                ? null
                                : const LinearGradient(
                                    colors: [
                                      Color(0xFF4F46E5),
                                      Color(0xFF7C3AED)
                                    ],
                                    begin: Alignment.topLeft,
                                    end:   Alignment.bottomRight,
                                  ),
                            color: loading ? const Color(0xFFE2E8F0) : null,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: loading
                                ? []
                                : [
                                    BoxShadow(
                                      color: const Color(0xFF4F46E5)
                                          .withOpacity(0.38),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6)),
                                  ],
                          ),
                          child: Center(
                            child: loading
                                ? const SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation(
                                            Color(0xFF64748B))))
                                : const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Sign in',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                            letterSpacing: 0.2),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(Icons.arrow_forward_rounded,
                                          color: Colors.white, size: 18),
                                    ],
                                  ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Divider
                  const Row(children: [
                    Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or continue with',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ),
                    Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                  ]),

                  const SizedBox(height: 16),

                  // SSO button (placeholder)
                  _SsoButton(
                    icon:  Icons.account_circle_outlined,
                    label: 'Single Sign-On (SSO)',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Field label ────────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w500,
          color: Color(0xFF475569)),
    );
  }
}

// ── SSO button ─────────────────────────────────────────────────────────────────
class _SsoButton extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;
  const _SsoButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: const Color(0xFF475569)),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500,
                color: Color(0xFF475569)),
          ),
        ]),
      ),
    );
  }
}

// ── Footer ─────────────────────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Security badges
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _badge(Icons.lock_rounded,     'End-to-end encrypted'),
        const SizedBox(width: 20),
        _badge(Icons.verified_rounded, 'SOC 2 compliant'),
      ]),
      const SizedBox(height: 18),
      const Text(
        'By signing in you agree to our Terms & Privacy Policy',
        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 6),
      const Text(
        '© 2026 Ausprey Technologies',
        style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
      ),
    ]);
  }

  Widget _badge(IconData icon, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: const Color(0xFF6EE7B7)),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(
            fontSize: 11, color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w400),
      ),
    ]);
  }
}