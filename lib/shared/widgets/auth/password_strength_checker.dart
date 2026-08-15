import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_theme.dart';

/// Live password-strength card shown under the password field on Paso 1 —
/// 4 criteria (min. 8 chars, upper+lowercase, digit, symbol), a 4-segment
/// score bar and a "Débil/Media/Fuerte/Muy fuerte" label. Purely
/// informational: the actual submit gate is each screen's own validator
/// (typically a lower, honest minimum), so this never silently tightens
/// the account-creation policy underneath the user.
class PasswordStrengthChecker extends StatelessWidget {
  const PasswordStrengthChecker({super.key, required this.password});

  final String password;

  bool get _hasMinLength => password.length >= 8;
  bool get _hasUpperAndLower =>
      password.contains(RegExp('[a-z]')) && password.contains(RegExp('[A-Z]'));
  bool get _hasDigit => password.contains(RegExp(r'[0-9]'));
  bool get _hasSymbol => password.contains(RegExp(r'[^a-zA-Z0-9]'));

  int get _score => [
    _hasMinLength,
    _hasUpperAndLower,
    _hasDigit,
    _hasSymbol,
  ].where((met) => met).length;

  (String, Color) get _label => switch (_score) {
    0 || 1 => ('Débil', AppColors.strengthWeak),
    2 => ('Media', AppColors.primary400),
    3 => ('Fuerte', AppColors.statusSuccess),
    _ => ('Muy fuerte', AppColors.ecoForest),
  };

  @override
  Widget build(BuildContext context) {
    final (label, color) = _label;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.settingsTextDark.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Seguridad de contraseña',
                style: AppTextStyles.authFieldLabel.copyWith(
                  fontSize: 11,
                  color: AppColors.authInk,
                  letterSpacing: 0,
                ),
              ),
              Text(
                label,
                style: AppTextStyles.authFieldLabel.copyWith(
                  fontSize: 10.5,
                  color: color,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _score / 4,
              minHeight: 4,
              backgroundColor: AppColors.settingsTextDark.withValues(
                alpha: 0.08,
              ),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _Criterion(met: _hasMinLength, label: 'Mínimo 8 caracteres'),
              _Criterion(
                met: _hasUpperAndLower,
                label: 'Mayúsculas y minúsculas',
              ),
              _Criterion(met: _hasDigit, label: 'Al menos 1 número'),
              _Criterion(met: _hasSymbol, label: 'Al menos 1 símbolo'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Criterion extends StatelessWidget {
  const _Criterion({required this.met, required this.label});

  final bool met;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        met
            ? const Icon(
                Icons.check_circle,
                size: 14,
                color: AppColors.ecoForest,
              )
            : Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.neutral400, width: 1.5),
                ),
              ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.legend.copyWith(
            fontSize: 11,
            color: met ? AppColors.authInk : AppColors.authBodyMuted,
          ),
        ),
      ],
    );
  }
}
