import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import 'login_page.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CHANGE PASSWORD — POST /api/v1/auth/password/change
//
// Mirrors the web portal's ChangePasswordPage:
//   • same payload  — currentPassword + newPassword + confirmPassword
//   • same policy   — min 8, upper, lower, digit, special (@$!%*?&)
//   • same rule     — the new password must differ from the current one
//
// Two modes:
//   FORCED  (mustChangePwd true after login) — this screen is the whole app
//           until the password is replaced. No back, no tabs, no dashboard.
//           The temporary password is pre-filled, because the user was handed
//           it minutes ago and should not have to transcribe it again.
//   NORMAL  (opened by choice) — behaves like an ordinary page with a back
//           button, and clears the fields on success.
// ═══════════════════════════════════════════════════════════════════════════════
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  final _newFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  // Per-field messages, surfaced only after the first submit so the form
  // doesn't shout at the user while they are still typing.
  String? _currentErr;
  String? _newErr;
  String? _confirmErr;
  bool _submitted = false;

  // The backend's policy, stated up front. Kept word-for-word in step with the
  // portal's hint so the two screens can't drift apart.
  static const _policyHint =
      'Choose a strong password with at least 8 characters, one uppercase '
      'letter, one lowercase letter, one number, and one special character '
      r'(@$!%*?&).';

  AuthController get _auth => AuthController.to;

  @override
  void initState() {
    super.initState();
    // Pre-fill the temporary password used moments ago at login. It never
    // touched disk — it is held in memory on the controller for exactly this.
    final temp = _auth.lastUsedPassword;
    if (_auth.mustChangePwd.value && temp != null && temp.isNotEmpty) {
      _currentCtrl.text = temp;
    }
  }

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  // ── Validation — the Dart twin of the portal's Yup schema ─────────────────
  String? _validateCurrent(String v) =>
      v.isEmpty ? 'Current password is required' : null;

  String? _validateNew(String v) {
    if (v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(v)) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(v)) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(v)) {
      return 'Password must contain at least one number';
    }
    // The special-character set is fixed by the backend regex — anything else
    // passes here and comes back as a 422 on submit, so the two stay identical.
    if (!RegExp(r'[@$!%*?&]').hasMatch(v)) {
      return r'Password must contain at least one special character (@$!%*?&)';
    }
    if (v == _currentCtrl.text) {
      return 'New password must differ from current password';
    }
    return null;
  }

  String? _validateConfirm(String v) {
    if (v.isEmpty) return 'Please confirm your new password';
    if (v != _newCtrl.text) return 'Passwords do not match';
    return null;
  }

  void _revalidate() {
    if (!_submitted) return;
    setState(() {
      _currentErr = _validateCurrent(_currentCtrl.text);
      _newErr = _validateNew(_newCtrl.text);
      _confirmErr = _validateConfirm(_confirmCtrl.text);
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _submitted = true;
      _currentErr = _validateCurrent(_currentCtrl.text);
      _newErr = _validateNew(_newCtrl.text);
      _confirmErr = _validateConfirm(_confirmCtrl.text);
    });
    if (_currentErr != null || _newErr != null || _confirmErr != null) return;

    final wasForced = _auth.mustChangePwd.value;
    final ok = await _auth.changePassword(
      currentPassword: _currentCtrl.text,
      newPassword: _newCtrl.text,
      confirmPassword: _confirmCtrl.text,
    );
    if (!mounted) return;

    if (!ok) {
      // A rejected current password belongs on that field, as on the portal.
      if (_auth.changePwdError.value.toLowerCase().contains('current')) {
        setState(() => _currentErr = _auth.changePwdError.value);
      }
      return;
    }

    Get.snackbar(
      'Password updated',
      'You stay signed in here; other devices were signed out.',
      backgroundColor: AppColors.success,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
    );

    if (wasForced) {
      // Land where login would have taken them.
      Get.offAllNamed('/home');
    } else {
      setState(() {
        _submitted = false;
        _currentErr = _newErr = _confirmErr = null;
      });
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
    }
  }

  Future<void> _confirmSignOut() async {
    final leave = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
            'Your password has not been changed yet. You will need your '
            'temporary password to sign in again.'),
        actions: [
          TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Stay')),
          TextButton(
              onPressed: () => Get.back(result: true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (leave == true) await _auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final t = ThemeController.to;
      final forced = _auth.mustChangePwd.value;

      return PopScope(
        // Forced mode owns the back button: there is nowhere behind this
        // screen to go, and swiping back must not reveal the app.
        canPop: !forced,
        child: Scaffold(
          backgroundColor: t.bg,
          appBar: AppBar(
            backgroundColor: t.surface,
            elevation: 0,
            scrolledUnderElevation: 0.5,
            automaticallyImplyLeading: !forced,
            title: Text('Change Password',
                style:
                    AppTextStyles.headingMedium.copyWith(color: t.textPrimary)),
            actions: [
              if (forced)
                TextButton(
                  onPressed: _auth.isChangingPwd.value ? null : _confirmSignOut,
                  child: Text('Sign out',
                      style: AppTextStyles.buttonMedium
                          .copyWith(color: AppColors.textSecondary)),
                ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (forced) _ForcedBanner(name: _auth.userName.value),
                      if (forced) const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: t.surface,
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          border: Border.all(color: t.border),
                          boxShadow: t.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(_policyHint,
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: t.textSec)),
                            const SizedBox(height: 20),
                            AppTextField(
                              label: 'Current password',
                              controller: _currentCtrl,
                              hint: 'Enter your current password',
                              required: true,
                              obscureText: !_showCurrent,
                              errorText: _currentErr,
                              enabled: !_auth.isChangingPwd.value,
                              onChanged: (_) => _revalidate(),
                              suffix: _EyeButton(
                                shown: _showCurrent,
                                onTap: () => setState(
                                    () => _showCurrent = !_showCurrent),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Divider(color: t.border, height: 1),
                            const SizedBox(height: 16),
                            AppTextField(
                              label: 'New password',
                              controller: _newCtrl,
                              hint: 'New password',
                              required: true,
                              obscureText: !_showNew,
                              errorText: _newErr,
                              enabled: !_auth.isChangingPwd.value,
                              focusNode: _newFocus,
                              onChanged: (_) => _revalidate(),
                              suffix: _EyeButton(
                                shown: _showNew,
                                onTap: () =>
                                    setState(() => _showNew = !_showNew),
                              ),
                            ),
                            const SizedBox(height: 16),
                            AppTextField(
                              label: 'Confirm new password',
                              controller: _confirmCtrl,
                              hint: 'Re-enter new password',
                              required: true,
                              obscureText: !_showConfirm,
                              errorText: _confirmErr,
                              enabled: !_auth.isChangingPwd.value,
                              focusNode: _confirmFocus,
                              textInputAction: TextInputAction.done,
                              onChanged: (_) => _revalidate(),
                              onSubmitted: (_) => _submit(),
                              suffix: _EyeButton(
                                shown: _showConfirm,
                                onTap: () => setState(
                                    () => _showConfirm = !_showConfirm),
                              ),
                            ),
                            // Server-side failures that aren't a field problem.
                            if (_auth.changePwdError.value.isNotEmpty &&
                                _currentErr == null) ...[
                              const SizedBox(height: 16),
                              _ErrorBanner(message: _auth.changePwdError.value),
                            ],
                            const SizedBox(height: 24),
                            AppButton(
                              label: 'Update password',
                              fullWidth: true,
                              loading: _auth.isChangingPwd.value,
                              onPressed:
                                  _auth.isChangingPwd.value ? null : _submit,
                            ),
                          ],
                        ),
                      ),
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

/// Explains why the user is here and why there is no way around it.
class _ForcedBanner extends StatelessWidget {
  final String name;
  const _ForcedBanner({required this.name});

  @override
  Widget build(BuildContext context) {
    final greeting =
        name.trim().isEmpty ? '' : ', ${name.trim().split(' ').first}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.accent.withOpacity(0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.lock_reset_rounded, size: 22, color: AppColors.accent),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Set your own password$greeting',
                style: AppTextStyles.headingSmall
                    .copyWith(color: AppColors.accent)),
            const SizedBox(height: 4),
            Text(
                'You signed in with a temporary password. Choose one of your '
                'own to carry on — it only takes a moment.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
          ]),
        ),
      ]),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.danger.withOpacity(0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.error_outline_rounded,
            size: 18, color: AppColors.danger),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.danger, fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}

/// Show / hide toggle, matching the eye affordance on the portal's fields.
class _EyeButton extends StatelessWidget {
  final bool shown;
  final VoidCallback onTap;
  const _EyeButton({required this.shown, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      splashRadius: 20,
      // Without these the default 48×48 tap target stretches the field.
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 40),
      icon: Icon(
        shown ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 20,
        color: AppColors.textTertiary,
      ),
      tooltip: shown ? 'Hide password' : 'Show password',
    );
  }
}
