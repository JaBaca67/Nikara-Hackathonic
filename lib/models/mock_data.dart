/// Supported third-party sign-in providers, matching the three social
/// buttons in the Figma login design (node 145:72).
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

/// Mock data standing in for a future remote-config/auth-providers endpoint.
///
/// Apple is intentionally left out for now — [AuthService.signInWithApple],
/// [SocialAuthKind.apple], and the Apple branch in [SocialLoginRow]'s
/// `_handleTap` are all still there as a ready-to-use component; re-add a
/// [SocialAuthProvider] entry for it here (`assets/images/social_apple.svg`
/// already exists) whenever it's ready to ship again.
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
