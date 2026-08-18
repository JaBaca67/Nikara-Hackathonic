/// Proveedores de login social, según el diseño de Figma (node 145:72).
enum SocialAuthKind { google, apple, facebook }

class SocialAuthProvider {
  final SocialAuthKind kind;
  final String label;
  final String assetPath;

  const SocialAuthProvider({
    required this.kind,
    required this.label,
    required this.assetPath,
  });
}

/// Apple se omite a propósito por ahora; el soporte ya existe en [AuthService.signInWithApple] y [SocialLoginRow], solo falta agregar la entrada aquí para reactivarlo.
const List<SocialAuthProvider> mockSocialAuthProviders = [
  SocialAuthProvider(
    kind: SocialAuthKind.google,
    label: 'Google',
    assetPath: 'assets/images/social_google.svg',
  ),
  SocialAuthProvider(
    kind: SocialAuthKind.facebook,
    label: 'Facebook',
    assetPath: 'assets/images/social_facebook.png',
  ),
];
