import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInput;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/services/guest_session_service.dart';
import 'package:nikara_app/features/auth/presentation/screens/register_screen.dart';
import 'package:nikara_app/features/auth/presentation/widgets/social_auth_row.dart';
import 'package:nikara_app/shared/widgets/main_layout.dart';
import 'package:nikara_app/shared/widgets/splash_transition_screen.dart';
import 'package:nikara_app/theme/app_theme.dart';
import 'package:nikara_app/widgets/aurora_background_widget.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  /// Starts disabled so nothing is flagged while the user is still typing
  /// their first character; the very first failed "Siguiente" tap switches
  /// this to onUserInteraction so fixes are reflected live from then on.
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  static final RegExp _emailRegex = RegExp(
    r'^[\w.+-]+@[\w-]+\.[A-Za-z]{2,}$',
  );

  static const Set<String> _weakPasswords = {
    '123456',
    '1234',
    '12345',
    '12345678',
    '123456789',
    'password',
    'qwerty',
    'abcdef',
    '000000',
    '111111',
  };

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Ingresa un correo';
    if (!_emailRegex.hasMatch(trimmed)) return 'Correo no válido';
    return null;
  }

  String? _validatePassword(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Ingresa tu contraseña';
    if (trimmed.length < 6) return 'Mínimo 6 caracteres';
    if (_weakPasswords.contains(trimmed.toLowerCase()) ||
        _isSequentialOrRepeated(trimmed)) {
      return 'Contraseña muy débil';
    }
    return null;
  }

  /// Flags strings like '123456', 'abcdef', 'fedcba' or 'aaaaaa'.
  bool _isSequentialOrRepeated(String value) {
    var ascending = true;
    var descending = true;
    var repeated = true;
    for (var i = 1; i < value.length; i++) {
      final diff = value.codeUnitAt(i) - value.codeUnitAt(i - 1);
      if (diff != 1) ascending = false;
      if (diff != -1) descending = false;
      if (diff != 0) repeated = false;
    }
    return value.length >= 4 && (ascending || descending || repeated);
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      // Only from here on do further keystrokes get live feedback.
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }

    setState(() => _isSubmitting = true);
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final result = await _authService.signIn(email: email, password: password);
    if (!mounted) return;

    if (result.success) {
      // A real session now exists — a guest who came back here from the
      // GuestGuardBottomSheet's "Ya tengo cuenta" shouldn't stay flagged
      // as a guest afterwards.
      await GuestSessionService().exitGuestMode();
      if (!mounted) return;
      // Signals iOS/Android's autofill service that this "autofill
      // context" finished successfully, so it actually offers to save the
      // credentials just entered — without this, some platforms never
      // trigger the save prompt even inside an AutofillGroup.
      TextInput.finishAutofillContext();
      // Clears the login screen (and anything behind it) from the stack so
      // the back button can't return to it once inside the app.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const SplashTransitionScreen(nextPage: MainLayout()),
        ),
        (route) => false,
      );
      return;
    }

    setState(() => _isSubmitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message ?? 'No se pudo iniciar sesión')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // MediaQuery.sizeOf is the *physical* screen size — unlike the
    // BoxConstraints Scaffold hands to `body`, it never shrinks when the
    // keyboard opens, so it's the safe source for a background that must
    // stay put.
    final screenSize = MediaQuery.sizeOf(context);
    // Proportions lifted directly from the Figma frame (390x844, node 157:2).
    final logoAreaHeight = screenSize.height * (235 / 844);
    final cardBottomGap = screenSize.height * (16 / 844);

    return Scaffold(
      backgroundColor: AppColors.primary500,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Fondo fijo al 100%: se ancla con el alto físico real de la
          // pantalla en vez de Positioned.fill, porque Positioned.fill
          // heredaría el alto ya reducido que Scaffold le da a `body`
          // cuando el teclado está abierto (eso era lo que comprimía y
          // deformaba el degradado y la tarjeta). Cualquier sobrante queda
          // oculto detrás del teclado, sin recortes visibles.
          Positioned(
            top: 0,
            left: 0,
            width: screenSize.width,
            height: screenSize.height,
            child: const AuroraBackgroundWidget(),
          ),
          // Capa de contenido: se puede desplazar y se centra sola cuando
          // sobra espacio (teclado cerrado).
          SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusScope.of(context).unfocus(),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: logoAreaHeight,
                            // _Logo's content (150px image + wordmark) is
                            // fixed-size, but logoAreaHeight scales down
                            // proportionally with the screen — on a short
                            // viewport that proportional area can shrink
                            // below the logo's natural height, overflowing
                            // the Column. FittedBox lets it scale down to
                            // fit instead.
                            child: const Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: _Logo(),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 27,
                            ),
                            child: _buildCard(),
                          ),
                          SizedBox(height: cardBottomGap),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.backgroundCream,
        borderRadius: BorderRadius.circular(44),
        boxShadow: const [
          BoxShadow(
            color: Color(0x660C0C0D),
            offset: Offset(0, 16),
            blurRadius: 32,
            spreadRadius: -8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 29, 24, 24),
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidateMode,
          // Groups both fields for the platform's password manager (iCloud
          // Keychain / Google Credential Manager) — combined with each
          // field's AutofillHints below, this is what makes the OS offer to
          // fill (and later save) real saved credentials.
          child: AutofillGroup(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bienvenido de nuevo', style: AppTextStyles.heading),
              const SizedBox(height: 8),
              Text(
                'Inicia sesión para continuar tu aventura',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 20),
              _InputField(
                label: 'Correo electrónico',
                hintText: 'ej: jose@example.com',
                controller: emailController,
                iconAsset: 'assets/images/icon_email.svg',
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                validator: _validateEmail,
              ),
              const SizedBox(height: 14),
              _InputField(
                label: 'Contraseña',
                hintText: '••••••••',
                controller: passwordController,
                iconAsset: 'assets/images/icon_lock.svg',
                isPassword: true,
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.password],
                onToggleObscure: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                validator: _validatePassword,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    '¿Olvidaste tu contraseña?',
                    style: AppTextStyles.link,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              _PrimaryButton(
                onPressed: _isSubmitting ? null : _submit,
                label: 'Siguiente',
                isLoading: _isSubmitting,
              ),
              const SizedBox(height: 40),
              const SocialAuthRow(),
              const SizedBox(height: 24),
              _buildRegisterPrompt(),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _isSubmitting ? null : _continueAsGuest,
                  child: Text('Explorar como invitado', style: AppTextStyles.link),
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _continueAsGuest() async {
    await GuestSessionService().enterGuestMode();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const SplashTransitionScreen(nextPage: MainLayout()),
      ),
      (route) => false,
    );
  }

  Widget _buildRegisterPrompt() {
    // Wrap, not Row: on a very narrow screen (or with a substituted font
    // whose metrics run wider) "¿No tienes cuenta? Regístrate aquí" can
    // exceed the card's width — Wrap drops to a second line instead of
    // overflowing, and looks identical to a Row on any normal-width device.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('¿No tienes cuenta?', style: AppTextStyles.registerPrompt),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RegisterScreen()),
            );
          },
          child: Text('Regístrate aquí', style: AppTextStyles.registerLink),
        ),
      ],
    );
}
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.translate(
          offset: const Offset(0, 8), // baja la imagen 8 px
          child: Image.asset(
            'assets/images/nikara_logo.png',
            width: 150,
            height: 150,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -1), // mueve el texto hacia arriba
          child: Text('NÍKARA', style: AppTextStyles.logoWordmark),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.onPressed,
    required this.label,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(0.00, 0.00),
          end: const Alignment(1.00, 1.00),
          colors: [
            AppColors.primary500.withValues(alpha: isEnabled ? 1 : 0.6),
            AppColors.primary700.withValues(alpha: isEnabled ? 1 : 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66FDBE02),
            offset: Offset(0, 8),
            blurRadius: 12,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation(AppColors.textInk),
                    ),
                  )
                : Text(label, style: AppTextStyles.buttonLarge),
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.label,
    required this.hintText,
    required this.controller,
    required this.iconAsset,
    this.isPassword = false,
    this.obscureText = false,
    this.onToggleObscure,
    this.keyboardType,
    this.autofillHints,
    this.validator,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final String iconAsset;
  final bool isPassword;
  final bool obscureText;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppTextStyles.inputLabel),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.surface100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.neutral600, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1FFDBE02),
                offset: Offset(0, 4),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            children: [
              SvgPicture.asset(iconAsset, width: 16, height: 16),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  obscureText: isPassword && obscureText,
                  keyboardType: keyboardType,
                  autofillHints: autofillHints,
                  validator: validator,
                  style: AppTextStyles.inputText,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: hintText,
                    hintStyle: AppTextStyles.inputText.copyWith(
                      color: AppColors.neutral600,
                    ),
                    border: InputBorder.none,
                    errorMaxLines: 1,
                    errorStyle: GoogleFonts.nunito(
                      color: const Color(0xFFD64545),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (isPassword)
                GestureDetector(
                  onTap: onToggleObscure,
                  child: Icon(
                    obscureText ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                    color: AppColors.neutral600,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
