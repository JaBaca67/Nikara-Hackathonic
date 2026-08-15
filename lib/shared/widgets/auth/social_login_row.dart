import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthChangeEvent, AuthState;

import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/services/guest_session_service.dart';
import 'package:nikara_app/models/mock_data.dart';
import 'package:nikara_app/shared/widgets/main_layout.dart';
import 'package:nikara_app/shared/widgets/splash_transition_screen.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// "o continúa con" divider + 3 circular vector provider buttons (Google,
/// Apple, Facebook) — self-contained, each owns its own per-button loading
/// state and navigates to [MainLayout] on success.
///
/// Google and Apple use native id-token exchanges ([AuthService.
/// signInWithGoogle]/[signInWithApple]) — synchronous from this widget's
/// point of view, same as a plain button press. Facebook goes through a
/// browser redirect ([AuthService.signInWithFacebook]): tapping it only
/// *launches* the flow, so the loading spinner stays up and this widget
/// listens for [AuthService.authStateChanges] to actually complete the
/// navigation once the OS redirects back into the app — see
/// [_handleAuthStateChange].
class SocialLoginRow extends StatefulWidget {
  const SocialLoginRow({super.key});

  @override
  State<SocialLoginRow> createState() => _SocialLoginRowState();
}

class _SocialLoginRowState extends State<SocialLoginRow>
    with WidgetsBindingObserver {
  final _authService = AuthService();
  SocialAuthKind? _loadingKind;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSub = _authService.authStateChanges.listen(_handleAuthStateChange);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Covers backing out of the Facebook browser tab without completing
    // sign-in: the app resumes, no signedIn event ever fires, and without
    // this the button would be stuck showing its spinner forever with no
    // way to retry.
    if (state == AppLifecycleState.resumed &&
        _loadingKind == SocialAuthKind.facebook) {
      setState(() => _loadingKind = null);
    }
  }

  void _handleAuthStateChange(AuthState state) {
    if (_loadingKind != SocialAuthKind.facebook) return;
    if (state.event != AuthChangeEvent.signedIn) return;
    unawaited(_completeSignIn());
  }

  Future<void> _handleTap(SocialAuthProvider provider) async {
    if (_loadingKind != null) return;

    if (provider.kind == SocialAuthKind.apple &&
        !_authService.isAppleSignInSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Iniciar sesión con Apple solo está disponible en iOS por ahora.',
          ),
        ),
      );
      return;
    }

    setState(() => _loadingKind = provider.kind);
    final result = switch (provider.kind) {
      SocialAuthKind.google => await _authService.signInWithGoogle(),
      SocialAuthKind.apple => await _authService.signInWithApple(),
      SocialAuthKind.facebook => await _authService.signInWithFacebook(),
    };
    if (!mounted) return;

    if (!result.success) {
      setState(() => _loadingKind = null);
      final message = result.message;
      if (message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }

    // Facebook's "success" here only means the browser flow launched — the
    // spinner stays up until _handleAuthStateChange sees the real
    // signedIn event land. Google/Apple already have a real session at
    // this point, so finish immediately.
    if (provider.kind == SocialAuthKind.facebook) return;
    await _completeSignIn();
  }

  Future<void> _completeSignIn() async {
    setState(() => _loadingKind = null);
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
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Divider(
                color: AppColors.settingsTextDark.withValues(alpha: 0.1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'o continúa con',
                style: AppTextStyles.authDividerLabel,
              ),
            ),
            Expanded(
              child: Divider(
                color: AppColors.settingsTextDark.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final provider in mockSocialAuthProviders) ...[
              _SocialButton(
                provider: provider,
                isLoading: _loadingKind == provider.kind,
                onTap: () => _handleTap(provider),
              ),
              if (provider != mockSocialAuthProviders.last)
                const SizedBox(width: 16),
            ],
          ],
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
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
        color: AppColors.settingsBackground,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isLoading ? null : onTap,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.settingsTextDark.withValues(alpha: 0.08),
              ),
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation(AppColors.authMuted),
                      ),
                    )
                  : provider.assetPath.endsWith('.svg')
                  ? SvgPicture.asset(provider.assetPath, width: 28, height: 28)
                  : Image.asset(
                      provider.assetPath,
                      width: 28,
                      height: 28,
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
