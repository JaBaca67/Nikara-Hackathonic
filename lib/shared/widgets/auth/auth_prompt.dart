import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_theme.dart';

/// "¿No tienes cuenta? Regístrate aquí" / "¿Ya tienes cuenta? Inicia
/// sesión" — the one shared implementation both Login and Register reach
/// for, so the two can't drift into different sizes again (they briefly
/// did: 12px vs 13px, and neither matched the surrounding body text).
/// `Wrap` centers cleanly even if either string wraps to a second line on
/// a narrow device.
class AuthPrompt extends StatelessWidget {
  const AuthPrompt({
    super.key,
    required this.text,
    required this.actionLabel,
    required this.onTap,
  });

  final String text;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Center wraps this to full width first: every call site sits inside a
    // `Column` with `crossAxisAlignment.start` (so the fields/labels above
    // it stay left-aligned), which would otherwise shrink-wrap the `Wrap`
    // to its own content width and strand it against the left edge —
    // `WrapAlignment.center` only centers *within* that shrunk box, it
    // can't widen the box itself.
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          Text(
            text,
            style: AppTextStyles.body.copyWith(
              color: AppColors.authBodyMuted,
              fontSize: 14,
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: Text(
              actionLabel,
              style: AppTextStyles.linkMd.copyWith(color: AppColors.authLink),
            ),
          ),
        ],
      ),
    );
  }
}
