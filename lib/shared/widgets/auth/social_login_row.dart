import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
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

/// Divisor "o continúa con" + 3 botones de provider social; Google/Apple resuelven de inmediato, Facebook solo lanza el flujo y este widget espera [AuthService.authStateChanges] para completar la navegación.
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

  /// Período de gracia al volver del navegador de Facebook antes de asumir que el flujo se abandonó.
  Timer? _facebookResumeGiveUpTimer;

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
    _facebookResumeGiveUpTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state != AppLifecycleState.resumed ||
        _loadingKind != SocialAuthKind.facebook) {
      return;
    }
    // El listener de deep-link de GoTrue puede llegar un instante después del resume; resetear el spinner de inmediato ganaba esa carrera y hacía ver un login exitoso como cancelado. Se da un margen antes de rendirse.
    _facebookResumeGiveUpTimer?.cancel();
    _facebookResumeGiveUpTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted || _loadingKind != SocialAuthKind.facebook) return;
      setState(() => _loadingKind = null);
    });
  }

  void _handleAuthStateChange(AuthState state) {
    if (kDebugMode) {
      // ignore: avoid_print
      print(
        '[SocialLoginRow] onAuthStateChange event=${state.event} '
        'hasSession=${state.session != null}',
      );
    }
    if (_loadingKind != SocialAuthKind.facebook) return;
    // Un email ya existente en otra cuenta (p. ej. Google) hace que Facebook se vincule y GoTrue emita tokenRefreshed/userUpdated en vez de signedIn; por eso se chequea la sesión en sí, no un evento específico.
    if (const {
          AuthChangeEvent.signedIn,
          AuthChangeEvent.tokenRefreshed,
          AuthChangeEvent.userUpdated,
        }.contains(state.event) &&
        _authService.currentAuthUser != null) {
      unawaited(_completeSignIn());
    }
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
    final AuthResult result;
    try {
      result = switch (provider.kind) {
        SocialAuthKind.google => await _authService.signInWithGoogle(),
        SocialAuthKind.apple => await _authService.signInWithApple(),
        SocialAuthKind.facebook => await _authService.signInWithFacebook(),
      };
    } catch (_) {
      // AuthService ya traduce fallas de Supabase/red a un AuthResult; esto solo cubre algo que se escape (p. ej. al lanzar la URL de OAuth) para que el spinner no quede atascado.
      if (!mounted) return;
      setState(() => _loadingKind = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ocurrió un error de conexión. Verifica tu internet e intenta de nuevo.',
          ),
        ),
      );
      return;
    }
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

    // Para Facebook, "success" solo significa que el flujo se lanzó; el spinner sigue hasta que _handleAuthStateChange vea el signedIn real.
    if (provider.kind == SocialAuthKind.facebook) return;
    await _completeSignIn();
  }

  Future<void> _completeSignIn() async {
    _facebookResumeGiveUpTimer?.cancel();
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
