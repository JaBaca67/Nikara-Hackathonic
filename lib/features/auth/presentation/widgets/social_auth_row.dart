import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/services/guest_session_service.dart';
import 'package:nikara_app/models/mock_data.dart';
import 'package:nikara_app/shared/widgets/main_layout.dart';
import 'package:nikara_app/shared/widgets/splash_transition_screen.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Row of social sign-in buttons (Google/Apple/Facebook) — shared between
/// [LoginScreen] and the registration wizard's Paso 1, since both need the
/// exact same secondary/outlined-hierarchy treatment: a neutral surface
/// with a thin border, never a filled brand color, so these never compete
/// visually with the one primary CTA above them.
///
/// Google is the only provider actually wired to [AuthService] — Apple and
/// Facebook aren't configured in Supabase yet, so tapping them is an honest
/// "Próximamente" instead of a silent no-op. Self-contained (owns its own
/// loading/navigation) so both call sites stay a single `SocialAuthRow()`.
class SocialAuthRow extends StatefulWidget {
  const SocialAuthRow({super.key});

  @override
  State<SocialAuthRow> createState() => _SocialAuthRowState();
}

class _SocialAuthRowState extends State<SocialAuthRow> {
  final _authService = AuthService();
  SocialAuthKind? _loadingKind;

  Future<void> _handleTap(SocialAuthProvider provider) async {
    if (_loadingKind != null) return;
    if (provider.kind != SocialAuthKind.google) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Continuar con ${provider.label} estará disponible pronto.',
          ),
        ),
      );
      return;
    }

    setState(() => _loadingKind = provider.kind);
    final result = await _authService.signInWithGoogle();
    if (!mounted) return;
    setState(() => _loadingKind = null);

    if (!result.success) {
      // A null message means the user closed the picker themselves —
      // nothing went wrong, so there's nothing to tell them.
      final message = result.message;
      if (message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }

    await GuestSessionService().exitGuestMode();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const SplashTransitionScreen(nextPage: MainLayout()),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final provider in mockSocialAuthProviders) ...[
          _SocialAuthButton(
            provider: provider,
            isLoading: _loadingKind == provider.kind,
            onTap: () => _handleTap(provider),
          ),
          if (provider != mockSocialAuthProviders.last)
            const SizedBox(width: 16),
        ],
      ],
    );
  }
}

class _SocialAuthButton extends StatelessWidget {
  const _SocialAuthButton({
    required this.provider,
    required this.isLoading,
    required this.onTap,
  });

  final SocialAuthProvider provider;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Continuar con ${provider.label}',
      child: Material(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isLoading ? null : onTap,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  offset: Offset(0, 2),
                  blurRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                          AppColors.neutral600,
                        ),
                      ),
                    )
                  : provider.assetPath.endsWith('.svg')
                  ? SvgPicture.asset(provider.assetPath, width: 36, height: 36)
                  : Image.asset(
                      provider.assetPath,
                      width: 36,
                      height: 36,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
