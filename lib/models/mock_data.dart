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
const List<SocialAuthProvider> mockSocialAuthProviders = [
  SocialAuthProvider(
    kind: SocialAuthKind.google,
    label: 'Google',
    assetPath: 'assets/images/social_google.svg',
  ),
  SocialAuthProvider(
    kind: SocialAuthKind.apple,
    label: 'Apple',
    assetPath: 'assets/images/social_apple.svg',
  ),
  SocialAuthProvider(
    kind: SocialAuthKind.facebook,
    label: 'Facebook',
    assetPath: 'assets/images/social_facebook.png',
  ),
];
