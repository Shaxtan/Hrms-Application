import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// AUTH CONTROLLER
// ═══════════════════════════════════════════════════════════════════════════════
class AuthController extends GetxController {
  static AuthController get to => Get.find();

  final isLoggedIn   = false.obs;
  final isLoading    = false.obs;
  final errorMessage = ''.obs;
  final userName     = ''.obs;
  final userRole     = ''.obs;
  final userInitials = ''.obs;
  final companyName  = ''.obs;

  static const _mockUsers = [
    {
      'email':    'supervisor@hrms.demo',
      'password': 'Super@123',
      'name':     'Demo Supervisor',
      'role':     'SUPERVISOR',
      'company':  'Demo Company',
      'initials': 'DS',
    },
    {
      'email':    'admin@hrms.demo',
      'password': 'Admin@123',
      'name':     'Priya Sharma',
      'role':     'TENANT_ADMIN',
      'company':  'Demo Company',
      'initials': 'PS',
    },
    {
      'email':    'hr@hrms.demo',
      'password': 'Hr@123456',
      'name':     'Rahul Verma',
      'role':     'TENANT_USER',
      'company':  'Demo Company',
      'initials': 'RV',
    },
  ];

  Future<void> login(String email, String password) async {
    errorMessage.value = '';
    isLoading.value    = true;
    await Future.delayed(const Duration(milliseconds: 1400));

    final match = _mockUsers.cast<Map<String, String>?>().firstWhere(
      (u) =>
          u!['email']!.toLowerCase() == email.trim().toLowerCase() &&
          u['password'] == password,
      orElse: () => null,
    );

    if (match != null) {
      userName.value     = match['name']!;
      userRole.value     = match['role']!;
      userInitials.value = match['initials']!;
      companyName.value  = match['company']!;
      isLoggedIn.value   = true;
    } else {
      errorMessage.value = 'Incorrect email or password.';
    }
    isLoading.value = false;
  }

  void logout() {
    isLoggedIn.value   = false;
    userName.value     = '';
    userRole.value     = '';
    userInitials.value = '';
    companyName.value  = '';
    errorMessage.value = '';
    Get.offAllNamed('/login');
  }

  String get roleDisplay {
    const map = {
      'SUPERVISOR':   'Supervisor',
      'TENANT_ADMIN': 'Company Admin',
      'TENANT_USER':  'HR Manager',
    };
    return map[userRole.value] ?? userRole.value;
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
    with TickerProviderStateMixin {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();
  bool  _obscure      = true;
  bool  _showHints    = false;
  bool  _emailFocused = false;
  bool  _passFocused  = false;

  late final AnimationController _entryCtrl;
  late final AnimationController _logoCtrl;
  late final Animation<double>   _logoScale;
  late final Animation<double>   _cardFade;
  late final Animation<Offset>   _cardSlide;

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _logoScale = CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut);

    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _cardFade  = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _cardSlide = Tween<Offset>(
            begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));

    Future.delayed(const Duration(milliseconds: 100), () {
      _logoCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 350), () {
      _entryCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _logoCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final ctrl = Get.find<AuthController>();
    await ctrl.login(_emailCtrl.text, _passwordCtrl.text);
    if (ctrl.isLoggedIn.value) Get.offAllNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    final size   = MediaQuery.of(context).size;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A), // dark slate base
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            // ── Decorative background ──────────────────────────────────────
            _Background(size: size),

            // ── Scrollable content ─────────────────────────────────────────
            SafeArea(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.only(bottom: bottom),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 48),

                        // Logo + brand
                        _LogoBrand(scaleAnim: _logoScale),

                        const SizedBox(height: 40),

                        // Card
                        FadeTransition(
                          opacity: _cardFade,
                          child: SlideTransition(
                            position: _cardSlide,
                            child: _FormCard(
                              formKey:      _formKey,
                              emailCtrl:    _emailCtrl,
                              passwordCtrl: _passwordCtrl,
                              obscure:      _obscure,
                              showHints:    _showHints,
                              emailFocused: _emailFocused,
                              passFocused:  _passFocused,
                              onToggleObscure: () =>
                                  setState(() => _obscure = !_obscure),
                              onToggleHints: () =>
                                  setState(() => _showHints = !_showHints),
                              onEmailFocus: (v) =>
                                  setState(() => _emailFocused = v),
                              onPassFocus: (v) =>
                                  setState(() => _passFocused = v),
                              onFillCredentials: (e, p) {
                                _emailCtrl.text    = e;
                                _passwordCtrl.text = p;
                                setState(() => _showHints = false);
                              },
                              onSubmit: _submit,
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Decorative background ──────────────────────────────────────────────────────
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
        top: -80, right: -80,
        child: Container(
          width: 280, height: 280,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              const Color(0xFF4F46E5).withOpacity(0.35),
              Colors.transparent,
            ]),
          ),
        ),
      ),
      // Bottom-left glow
      Positioned(
        bottom: -60, left: -60,
        child: Container(
          width: 240, height: 240,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              const Color(0xFF7C3AED).withOpacity(0.25),
              Colors.transparent,
            ]),
          ),
        ),
      ),
      // Subtle grid pattern overlay
      Positioned.fill(
        child: CustomPaint(painter: _GridPainter()),
      ),
    ]);
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..strokeWidth = 0.5;
    const step = 36.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Logo + brand ───────────────────────────────────────────────────────────────
class _LogoBrand extends StatelessWidget {
  final Animation<double> scaleAnim;
  const _LogoBrand({required this.scaleAnim});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Logo mark
      ScaleTransition(
        scale: scaleAnim,
        child: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.business_rounded,
              color: Colors.white, size: 28),
        ),
      ),
      const SizedBox(height: 20),
      RichText(
        text: const TextSpan(
          children: [
            TextSpan(
              text: 'HR',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            TextSpan(
              text: 'MS',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: Color(0xFF818CF8),
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'Employee Onboarding Platform',
        style: TextStyle(
          fontSize: 14,
          color: Color(0xFF94A3B8),
          fontWeight: FontWeight.w400,
          letterSpacing: 0.1,
        ),
      ),
    ]);
  }
}

// ── Form card ──────────────────────────────────────────────────────────────────
class _FormCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool obscure;
  final bool showHints;
  final bool emailFocused;
  final bool passFocused;
  final VoidCallback onToggleObscure;
  final VoidCallback onToggleHints;
  final void Function(bool) onEmailFocus;
  final void Function(bool) onPassFocus;
  final void Function(String, String) onFillCredentials;
  final VoidCallback onSubmit;

  const _FormCard({
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.obscure,
    required this.showHints,
    required this.emailFocused,
    required this.passFocused,
    required this.onToggleObscure,
    required this.onToggleHints,
    required this.onEmailFocus,
    required this.onPassFocus,
    required this.onFillCredentials,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(children: [
        // Card top accent bar
        Container(
          height: 4,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
            ),
            borderRadius: BorderRadius.only(
              topLeft:  Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Heading
                const Text('Welcome back',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    )),
                const SizedBox(height: 4),
                const Text('Sign in to continue',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    )),
                const SizedBox(height: 28),

                // Email field
                _fieldLabel('Email address'),
                const SizedBox(height: 6),
                Focus(
                  onFocusChange: onEmailFocus,
                  child: TextFormField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(
                        fontSize: 15, color: Color(0xFF0F172A)),
                    decoration: _deco(
                      hint: 'supervisor@hrms.demo',
                      focused: emailFocused,
                      icon: Icons.alternate_email_rounded,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 18),

                // Password field
                _fieldLabel('Password'),
                const SizedBox(height: 6),
                Focus(
                  onFocusChange: onPassFocus,
                  child: TextFormField(
                    controller: passwordCtrl,
                    obscureText: obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => onSubmit(),
                    style: const TextStyle(
                        fontSize: 15, color: Color(0xFF0F172A)),
                    decoration: _deco(
                      hint: '••••••••',
                      focused: passFocused,
                      icon: Icons.lock_outline_rounded,
                      suffix: GestureDetector(
                        onTap: onToggleObscure,
                        child: Icon(
                          obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Password is required';
                      }
                      if (v.length < 6) {
                        return 'At least 6 characters';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Error message
                Obx(() {
                  final err = Get.find<AuthController>().errorMessage.value;
                  if (err.isEmpty) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFDC2626).withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Color(0xFFDC2626), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(err,
                            style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFFDC2626))),
                      ),
                    ]),
                  );
                }),

                // Sign in button
                Obx(() {
                  final loading =
                      Get.find<AuthController>().isLoading.value;
                  return GestureDetector(
                    onTap: loading ? null : onSubmit,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: loading
                            ? null
                            : const LinearGradient(
                                colors: [
                                  Color(0xFF4F46E5),
                                  Color(0xFF7C3AED),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        color: loading
                            ? const Color(0xFFE2E8F0)
                            : null,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: loading
                            ? []
                            : [
                                BoxShadow(
                                  color: const Color(0xFF4F46E5)
                                      .withOpacity(0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                      ),
                      child: Center(
                        child: loading
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(0xFF64748B),
                                ))
                            : const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Text('Sign in',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          letterSpacing: 0.2)),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded,
                                      color: Colors.white, size: 18),
                                ],
                              ),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 24),

                // Divider
                Row(children: [
                  const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('demo accounts',
                        style: TextStyle(
                            fontSize: 11,
                            color: const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500)),
                  ),
                  const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                ]),

                const SizedBox(height: 16),

                // Demo credentials
                _DemoAccounts(
                  expanded: showHints,
                  onToggle: onToggleHints,
                  onFill: onFillCredentials,
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _fieldLabel(String label) {
    return Text(label,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF475569)));
  }

  InputDecoration _deco({
    required String hint,
    required bool focused,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
      prefixIcon: Padding(
        padding: const EdgeInsets.all(13),
        child: Icon(icon,
            size: 18,
            color: focused
                ? const Color(0xFF4F46E5)
                : const Color(0xFF94A3B8)),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 46),
      suffixIcon: suffix != null
          ? Padding(padding: const EdgeInsets.all(13), child: suffix)
          : null,
      filled: true,
      fillColor: focused
          ? const Color(0xFFEEF2FF)
          : const Color(0xFFF8FAFC),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
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
        borderSide:
            const BorderSide(color: Color(0xFF4F46E5), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Color(0xFFDC2626), width: 2),
      ),
    );
  }
}

// ── Demo accounts ──────────────────────────────────────────────────────────────
class _DemoAccounts extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(String, String) onFill;

  const _DemoAccounts({
    required this.expanded,
    required this.onToggle,
    required this.onFill,
  });

  static const _accounts = [
    (
      'Supervisor',
      'supervisor@hrms.demo',
      'Super@123',
      Color(0xFF4F46E5),
      Color(0xFFEEF2FF),
      Icons.supervisor_account_rounded,
    ),
    (
      'Company Admin',
      'admin@hrms.demo',
      'Admin@123',
      Color(0xFF059669),
      Color(0xFFD1FAE5),
      Icons.admin_panel_settings_rounded,
    ),
    (
      'HR Manager',
      'hr@hrms.demo',
      'Hr@123456',
      Color(0xFF0284C7),
      Color(0xFFE0F2FE),
      Icons.manage_accounts_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Toggle button
      GestureDetector(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.key_rounded,
                  size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              const Text('Try a demo account',
                  style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
      ),

      // Account rows
      AnimatedCrossFade(
        firstChild: const SizedBox(height: 0),
        secondChild: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            children: _accounts.map((a) {
              return GestureDetector(
                onTap: () => onFill(a.$2, a.$3),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: a.$5,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: a.$4.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                              color: a.$4.withOpacity(0.15),
                              blurRadius: 6)
                        ],
                      ),
                      child: Icon(a.$6, color: a.$4, size: 17),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.$1,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: a.$4)),
                          const SizedBox(height: 1),
                          Text(a.$2,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    // Password chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: a.$4.withOpacity(0.2)),
                      ),
                      child: Text(a.$3,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                              fontFamily: 'monospace')),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.north_east_rounded,
                        size: 14, color: a.$4.withOpacity(0.7)),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
        crossFadeState: expanded
            ? CrossFadeState.showSecond
            : CrossFadeState.showFirst,
        duration: const Duration(milliseconds: 220),
        sizeCurve: Curves.easeOut,
      ),
    ]);
  }
}