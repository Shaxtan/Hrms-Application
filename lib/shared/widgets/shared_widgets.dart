import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// THEME TOGGLE BUTTON — public, reactive, works anywhere
// ═══════════════════════════════════════════════════════════════════════════════
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    // GetBuilder rebuilds when ThemeController.update() is called
    // No Obx here — safe to place anywhere including inside other Obx
    return GetBuilder<ThemeController>(
      builder: (t) => IconButton(
        onPressed: t.toggle,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => RotationTransition(
              turns: anim, child: FadeTransition(opacity: anim, child: child)),
          child: Icon(
            t.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            key: ValueKey(t.isDark),
            size: 22,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED APP BAR — used by all pages for consistent look + hamburger + toggle
// ═══════════════════════════════════════════════════════════════════════════════
class SharedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget> extraActions;
  final bool showMenuButton;
  final VoidCallback? onMenuTap;
  // Optional custom leading widget — takes priority over the hamburger.
  // Pass a back button on pushed routes so the user can pop the page.
  final Widget? leading;

  const SharedAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.extraActions = const [],
    this.showMenuButton = true,
    this.onMenuTap,
    this.leading,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    // No Obx here — ThemeToggleButton is a StatefulWidget listener
    // so it rebuilds itself; reading t directly avoids nested Obx
    final t = ThemeController.to;
    return AppBar(
      backgroundColor: t.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      centerTitle: true,
      leading: leading ??
          (showMenuButton ? _MenuButton(t: t, onTap: onMenuTap) : null),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              style: AppTextStyles.headingMedium.copyWith(color: t.textPrimary),
              textAlign: TextAlign.center),
          if (subtitle != null)
            Text(subtitle!,
                style: AppTextStyles.caption.copyWith(color: t.textTert),
                textAlign: TextAlign.center),
        ],
      ),
      actions: [
        ...extraActions,
        const ThemeToggleButton(),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: t.border),
      ),
    );
  }
}

// Internal hamburger button used by SharedAppBar
class _MenuButton extends StatelessWidget {
  final ThemeController t;
  final VoidCallback? onTap;
  const _MenuButton({required this.t, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: GestureDetector(
        onTap: onTap ?? SidebarOpener.open,
        child: Container(
          decoration: BoxDecoration(
            color: t.surfaceVar,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: t.border),
          ),
          child: Icon(Icons.menu_rounded, color: t.textSec, size: 20),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// APP BUTTON
// ═══════════════════════════════════════════════════════════════════════════════
enum AppButtonVariant { primary, secondary, ghost, danger }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final bool fullWidth;
  final Widget? icon;
  final double? height;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.fullWidth = false,
    this.icon,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    // No Obx — read t directly; AppButton is used inside Obx'd parents
    final t = ThemeController.to;
    final isDisabled = onPressed == null || loading;
    Color bg, fg;
    Color? borderColor;
    switch (variant) {
      case AppButtonVariant.primary:
        bg = isDisabled ? AppColors.accent.withOpacity(0.4) : AppColors.accent;
        fg = Colors.white;
        borderColor = null;
        break;
      case AppButtonVariant.secondary:
        bg = AppColors.accentLight;
        fg = AppColors.accent;
        borderColor = AppColors.accent.withOpacity(0.3);
        break;
      case AppButtonVariant.ghost:
        bg = Colors.transparent;
        fg = t.textSec;
        borderColor = t.border;
        break;
      case AppButtonVariant.danger:
        bg = isDisabled ? AppColors.danger.withOpacity(0.4) : AppColors.danger;
        fg = Colors.white;
        borderColor = null;
        break;
    }
    final child = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(fg)))
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                if (icon != null) ...[icon!, const SizedBox(width: 8)],
                Text(label,
                    style: AppTextStyles.buttonMedium.copyWith(color: fg)),
              ]);
    final btn = GestureDetector(
      onTap: isDisabled ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: height ?? 46,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: borderColor != null ? Border.all(color: borderColor) : null,
          boxShadow: variant == AppButtonVariant.primary && !isDisabled
              ? AppShadows.elevated
              : null,
        ),
        child: Center(child: child),
      ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// APP TEXT FIELD
// ═══════════════════════════════════════════════════════════════════════════════
class AppTextField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final bool required;
  final bool enabled;
  final bool obscureText;
  final TextInputType keyboardType;
  final List<dynamic>? inputFormatters;
  final int maxLines;
  final int? maxLength;
  final Widget? suffix;
  final Widget? prefix;
  final void Function(String)? onChanged;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;

  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helperText,
    this.errorText,
    this.required = false,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.maxLines = 1,
    this.maxLength,
    this.suffix,
    this.prefix,
    this.onChanged,
    this.validator,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.to;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label,
            style: AppTextStyles.label
                .copyWith(color: t.textSec, fontWeight: FontWeight.w500)),
        if (required)
          const Text(' *',
              style: TextStyle(
                  color: AppColors.danger,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
        enabled: enabled,
        focusNode: focusNode,
        textInputAction: textInputAction,
        onFieldSubmitted: onSubmitted,
        onChanged: onChanged,
        validator: validator,
        style: AppTextStyles.bodyMedium
            .copyWith(color: enabled ? t.textPrimary : t.textTert),
        decoration: InputDecoration(
          hintText: hint,
          helperText: helperText,
          errorText: errorText,
          suffixIcon: suffix,
          prefixIcon: prefix,
          filled: true,
          fillColor: enabled ? t.surfaceVar : t.surfaceVar.withOpacity(0.5),
          counterText: '',
          contentPadding: EdgeInsets.symmetric(
              horizontal: 14, vertical: maxLines > 1 ? 12 : 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: t.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: t.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.accent, width: 2)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.danger)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.danger, width: 2)),
          disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: t.border)),
        ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// APP DROPDOWN
// ═══════════════════════════════════════════════════════════════════════════════
class AppDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;
  final bool required;
  final bool enabled;
  final String? hint;
  final String? helperText;
  final String? errorText;

  const AppDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.required = false,
    this.enabled = true,
    this.hint,
    this.helperText,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.to;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label,
            style: AppTextStyles.label
                .copyWith(color: t.textSec, fontWeight: FontWeight.w500)),
        if (required)
          const Text(' *',
              style: TextStyle(
                  color: AppColors.danger,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 6),
      DropdownButtonFormField<T>(
        value: value,
        items: items,
        onChanged: enabled ? onChanged : null,
        hint: hint != null
            ? Text(hint!,
                style: AppTextStyles.bodyMedium.copyWith(color: t.textTert))
            : null,
        style: AppTextStyles.bodyMedium.copyWith(color: t.textPrimary),
        dropdownColor: t.surface,
        decoration: InputDecoration(
          filled: true,
          fillColor: t.surfaceVar,
          errorText: errorText,
          helperText: helperText,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: t.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: t.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.accent, width: 2)),
          disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: t.border)),
        ),
        icon:
            Icon(Icons.keyboard_arrow_down_rounded, color: t.textSec, size: 20),
        isExpanded: true,
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION CARD
// ═══════════════════════════════════════════════════════════════════════════════
class SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final bool isExpanded;
  final VoidCallback onToggle;
  final bool hasError;
  final Color? accentColor;
  final Widget? trailing;

  const SectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    required this.isExpanded,
    required this.onToggle,
    this.hasError = false,
    this.accentColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.to;
    final topColor =
        hasError ? AppColors.danger : (accentColor ?? AppColors.accent);
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: hasError ? AppColors.dangerLight : t.border),
        boxShadow: t.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            height: 3,
            decoration: BoxDecoration(
                color: topColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.lg),
                  topRight: Radius.circular(AppRadius.lg),
                ))),
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base, vertical: AppSpacing.md),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: AppTextStyles.headingSmall
                            .copyWith(color: t.textPrimary)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          style: AppTextStyles.caption
                              .copyWith(color: t.textTert)),
                    ],
                  ])),
              if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: t.textSec, size: 22),
              ),
            ]),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(height: 0),
          secondChild: Column(children: [
            Divider(height: 1, color: t.border),
            Padding(
                padding: const EdgeInsets.all(AppSpacing.base), child: child),
          ]),
          crossFadeState:
              isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
          sizeCurve: Curves.easeOut,
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATUS BADGE
// ═══════════════════════════════════════════════════════════════════════════════
class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _config(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: config.$1,
          borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Text(config.$2,
          style: AppTextStyles.caption
              .copyWith(color: config.$3, fontWeight: FontWeight.w600)),
    );
  }

  (Color, String, Color) _config(String s) {
    switch (s.toUpperCase()) {
      case 'ACTIVE':
        return (AppColors.successLight, 'Active', AppColors.success);
      case 'PENDING_APPROVAL':
        return (AppColors.warningLight, 'Pending Approval', AppColors.warning);
      case 'PENDING_SALARY_SETUP':
        return (AppColors.infoLight, 'Pending Setup', AppColors.info);
      case 'REJECTED':
        return (AppColors.dangerLight, 'Rejected', AppColors.danger);
      case 'UNASSIGNED':
        return (const Color(0xFFE2E8F0), 'Unassigned', AppColors.textSecondary);
      default:
        return (const Color(0xFFE2E8F0), _humanize(s), AppColors.textSecondary);
    }
  }

  String _humanize(String s) => s
      .toLowerCase()
      .split('_')
      .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
      .join(' ');
}

// ═══════════════════════════════════════════════════════════════════════════════
// KPI CARD — uniform height via IntrinsicHeight
// ═══════════════════════════════════════════════════════════════════════════════
class KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.to;
    return Container(
      // Fixed height so all three cards are identical
      height: 110,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: t.border),
        boxShadow: t.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(title,
                    style: AppTextStyles.label.copyWith(color: t.textSec),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 4),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: AppTextStyles.numericMedium
                      .copyWith(color: color, fontSize: 20)),
              if (subtitle != null)
                Text(subtitle!,
                    style: AppTextStyles.caption
                        .copyWith(color: t.textTert, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PIPELINE STATUS BAR
// ═══════════════════════════════════════════════════════════════════════════════
class PipelineStatusBar extends StatelessWidget {
  final int total, approved, pending, rejected;
  const PipelineStatusBar({
    super.key,
    required this.total,
    required this.approved,
    required this.pending,
    required this.rejected,
  });

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.to;
    if (total == 0) {
      return Container(
          height: 8,
          decoration: BoxDecoration(
              color: t.surfaceVar,
              borderRadius: BorderRadius.circular(AppRadius.full)));
    }
    final aFlex = (approved / total * 100).round();
    final pFlex = (pending / total * 100).round();
    final rFlex = (rejected / total * 100).round();
    final rem = (100 - aFlex - pFlex - rFlex).clamp(0, 100);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: SizedBox(
          height: 8,
          child: Row(children: [
            if (aFlex > 0)
              Expanded(
                  flex: aFlex,
                  child: Container(color: AppColors.pipelineApproved)),
            if (pFlex > 0)
              Expanded(
                  flex: pFlex,
                  child: Container(color: AppColors.pipelinePending)),
            if (rFlex > 0)
              Expanded(
                  flex: rFlex,
                  child: Container(color: AppColors.pipelineRejected)),
            if (rem > 0)
              Expanded(flex: rem, child: Container(color: t.surfaceVar)),
          ])),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DOCUMENT SLOT TILE
// ═══════════════════════════════════════════════════════════════════════════════
class DocumentSlotTile extends StatelessWidget {
  final String label;
  final String? helperText;
  final bool required;
  final String? fileName;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final bool busy;

  const DocumentSlotTile({
    super.key,
    required this.label,
    this.helperText,
    this.required = false,
    this.fileName,
    required this.onPick,
    required this.onClear,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.to;
    final hasFile = fileName != null;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: hasFile ? AppColors.successLight : t.surfaceVar,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
            color: hasFile ? AppColors.success.withOpacity(0.3) : t.border,
            width: hasFile ? 1.5 : 1),
      ),
      child: Row(children: [
        Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color:
                    hasFile ? AppColors.success.withOpacity(0.15) : t.surface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: t.border)),
            child: Icon(
                hasFile
                    ? Icons.check_circle_outline_rounded
                    : Icons.upload_file_outlined,
                color: hasFile ? AppColors.success : t.textSec,
                size: 18)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(label,
                    style: AppTextStyles.bodySmall.copyWith(
                        color: t.textPrimary, fontWeight: FontWeight.w500))),
            if (required && !hasFile)
              const Text(' *',
                  style: TextStyle(
                      color: AppColors.danger,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
          ]),
          if (hasFile) ...[
            const SizedBox(height: 2),
            Text(fileName!,
                style: AppTextStyles.caption.copyWith(color: AppColors.success),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ] else if (helperText != null) ...[
            const SizedBox(height: 2),
            Text(helperText!,
                style: AppTextStyles.caption.copyWith(color: t.textTert)),
          ],
        ])),
        const SizedBox(width: AppSpacing.sm),
        if (busy)
          const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))
        else if (hasFile)
          GestureDetector(
              onTap: onClear,
              child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: const Icon(Icons.close_rounded,
                      color: AppColors.danger, size: 16)))
        else
          GestureDetector(
              onTap: onPick,
              child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border:
                          Border.all(color: AppColors.accent.withOpacity(0.3))),
                  child: Text('Upload',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600)))),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// AADHAAR CHECK CARD
// ═══════════════════════════════════════════════════════════════════════════════
class AadhaarCheckCard extends StatelessWidget {
  final String state;
  final Map<String, dynamic>? existing;
  final VoidCallback onDismiss;
  final VoidCallback onReenter;
  final void Function(int)? onViewExisting;
  final void Function(int)? onContinueExisting;

  const AadhaarCheckCard({
    super.key,
    required this.state,
    this.existing,
    required this.onDismiss,
    required this.onReenter,
    this.onViewExisting,
    this.onContinueExisting,
  });

  @override
  Widget build(BuildContext context) {
    if (state == 'IDLE' || state == 'NONE') return const SizedBox.shrink();
    if (state == 'CHECKING') {
      return _card(AppColors.infoLight, AppColors.info,
          Icons.manage_search_rounded, 'Checking Aadhaar…', null, []);
    }
    if (state == 'ERROR') {
      return _card(
          AppColors.surfaceVariant,
          AppColors.textSecondary,
          Icons.wifi_off_rounded,
          'Check unavailable',
          'Could not verify right now. Server will validate on submit.', []);
    }
    if (state == 'ACTIVE_DUPLICATE' || state == 'PENDING_DUPLICATE') {
      return _card(
          AppColors.dangerLight,
          AppColors.danger,
          Icons.warning_amber_rounded,
          'Aadhaar already registered',
          'This Aadhaar belongs to ${existing?['fullName'] ?? 'an existing employee'}.',
          [
            _action('View Profile', AppColors.danger, () {
              final id = existing?['employeeId'];
              if (id != null) onViewExisting?.call(id);
            }),
            _action('Re-enter', AppColors.textSecondary, onReenter),
          ]);
    }
    if (state == 'REHIRE') {
      return _card(
          AppColors.warningLight,
          AppColors.warning,
          Icons.person_add_alt_1_rounded,
          'Previous employee found',
          '${existing?['fullName'] ?? 'This person'} was previously employed.',
          [
            _action('Continue Onboarding', AppColors.accent, () {
              final id = existing?['employeeId'];
              if (id != null) onContinueExisting?.call(id);
            }),
            _action('Different Person', AppColors.textSecondary, onDismiss),
          ]);
    }
    return const SizedBox.shrink();
  }

  Widget _card(Color bg, Color accent, IconData icon, String title,
      String? body, List<Widget> actions) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: accent.withOpacity(0.25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(title,
                  style: AppTextStyles.headingSmall
                      .copyWith(color: accent, fontSize: 13))),
        ]),
        if (body != null) ...[
          const SizedBox(height: 4),
          Text(body, style: AppTextStyles.caption),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: actions),
        ],
      ]),
    );
  }

  Widget _action(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: color.withOpacity(0.2))),
          child: Text(label,
              style: AppTextStyles.caption
                  .copyWith(color: color, fontWeight: FontWeight.w600))),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MISSING FIELDS PANEL
// ═══════════════════════════════════════════════════════════════════════════════
class MissingFieldsPanel extends StatelessWidget {
  final List<String> fields;
  final List<String> docs;
  final bool consentMissing;
  final String employmentTypeLabel;

  const MissingFieldsPanel({
    super.key,
    required this.fields,
    required this.docs,
    this.consentMissing = false,
    required this.employmentTypeLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (fields.isEmpty && docs.isEmpty && !consentMissing) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.base),
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.warning, size: 16),
          const SizedBox(width: 8),
          Text('Required information still missing',
              style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.warning, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 4),
        Text('Required for $employmentTypeLabel — Create is disabled.',
            style: AppTextStyles.caption),
        const SizedBox(height: 8),
        ...fields.map((f) => _item('• $f')),
        if (consentMissing) _item('• Aadhaar Consent (DPDP Act)'),
        ...docs.map((d) => _item('• $d (document)')),
      ]),
    );
  }

  Widget _item(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(text,
          style:
              AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)));
}

// ═══════════════════════════════════════════════════════════════════════════════
// STEP RESULT LEDGER
// ═══════════════════════════════════════════════════════════════════════════════
class StepResultLedger extends StatelessWidget {
  final Map<String, dynamic> results;
  final List<String> requiredFailures;
  final VoidCallback? onRetry;
  final VoidCallback? onDiscard;
  final VoidCallback? onContinue;
  final bool discarding;
  final bool retrying;

  const StepResultLedger({
    super.key,
    required this.results,
    this.requiredFailures = const [],
    this.onRetry,
    this.onDiscard,
    this.onContinue,
    this.discarding = false,
    this.retrying = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.to;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.base),
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: t.border),
          boxShadow: t.cardShadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Setup Status',
            style: AppTextStyles.headingSmall.copyWith(color: t.textPrimary)),
        const SizedBox(height: AppSpacing.md),
        ...results.entries.map((e) => _row(e.key, e.value, t)),
        if (requiredFailures.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Row(children: [
            Expanded(
                child: AppButton(
                    label: 'Discard',
                    variant: AppButtonVariant.ghost,
                    onPressed: onDiscard,
                    loading: discarding)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
                child: AppButton(
                    label: 'Retry Upload',
                    onPressed: onRetry,
                    loading: retrying)),
          ]),
        ] else if (onContinue != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppButton(
              label: 'Continue to Profile',
              onPressed: onContinue,
              fullWidth: true),
        ],
      ]),
    );
  }

  Widget _row(String key, dynamic val, ThemeController t) {
    final status = val['status'] ?? 'pending';
    final label = val['label'] ?? key;
    final error = val['error'];
    IconData icon;
    Color color;
    switch (status) {
      case 'success':
        icon = Icons.check_circle_rounded;
        color = AppColors.success;
        break;
      case 'failed':
        icon = Icons.cancel_rounded;
        color = AppColors.danger;
        break;
      case 'running':
        icon = Icons.pending_rounded;
        color = AppColors.info;
        break;
      case 'skipped':
        icon = Icons.remove_circle_outline_rounded;
        color = t.textTert;
        break;
      default:
        icon = Icons.radio_button_unchecked_rounded;
        color = t.textTert;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: AppTextStyles.bodySmall.copyWith(color: t.textPrimary)),
          if (error != null)
            Text(error,
                style: AppTextStyles.caption.copyWith(color: AppColors.danger)),
        ])),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN SHELL STATE — exposed so child AppBars can open sidebar
// ═══════════════════════════════════════════════════════════════════════════════
// Global sidebar opener — registered by MainShell, called by SharedAppBar
// Avoids circular imports between shared_widgets and dashboard_page

// Global tab switcher — registered by MainShell
class TabSwitcher {
  static void Function(int)? _switch;
  static void register(void Function(int) fn) => _switch = fn;
  static void unregister() => _switch = null;
  static void switchTo(int index) => _switch?.call(index);
}

class SidebarOpener {
  static VoidCallback? _open;
  static void register(VoidCallback fn) => _open = fn;
  static void unregister() => _open = null;
  static void open() => _open?.call();
}
