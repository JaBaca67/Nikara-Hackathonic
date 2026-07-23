import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nikara_app/models/mock_data.dart';
import 'package:nikara_app/shared/widgets/main_layout.dart';
import 'package:nikara_app/shared/widgets/splash_transition_screen.dart';
import 'package:nikara_app/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

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

  void _submit() {
    FocusScope.of(context).unfocus();
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      // Only from here on do further keystrokes get live feedback.
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            const SplashTransitionScreen(nextPage: MainLayout()),
      ),
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
            child: _GradientBackground(size: screenSize),
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
                            child: const Center(child: _Logo()),
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
              _PrimaryButton(onPressed: _submit, label: 'Siguiente'),
              const SizedBox(height: 40),
              const _SocialAuthRow(),
              const SizedBox(height: 24),
              _buildRegisterPrompt(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterPrompt() {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      // 1. Quita el espacio en blanco al final del texto
      Text('¿No tienes cuenta?', style: AppTextStyles.registerPrompt),
      
      // 2. Agrega un SizedBox para dar el espacio exacto que deseas (ej. 6 u 8 píxeles)
      const SizedBox(width: 8), 
      
      GestureDetector(
        onTap: () {},
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
          child: Text('NIKARA', style: AppTextStyles.logoWordmark),
        ),
      ],
    );
  }
}

/// Full-bleed gradient background with the two decorative radial blurs from
/// the Figma frame (nodes 157:5 and 157:74), positioned proportionally.
class _GradientBackground extends StatelessWidget {
  const _GradientBackground({required this.size});

  final Size size;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.65, -0.76),
          end: Alignment(0.65, 0.76),
          colors: [
            AppColors.primary500,
            Color(0xFFFFCC33),
            AppColors.primary400,
          ],
          stops: [0.0893, 0.4265, 0.9323],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: size.width * (262 / 390),
            top: size.height * (-32 / 844),
            child: _radialBlur(
              diameter: size.width * (160 / 390),
              colors: [
                Colors.white.withValues(alpha: 0.25),
                Colors.white.withValues(alpha: 0),
              ],
            ),
          ),
          Positioned(
            right: size.width * (-30 / 390),
            top: size.height * (-10 / 844),
            child: _topRightGlow(diameter: size.width * (160 / 390)),
          ),
          Positioned(
            left: size.width * (-79 / 390),
            top: size.height * (97 / 844),
            child: _radialBlur(
              diameter: size.width * (224 / 390),
              colors: [
                AppColors.accent300.withValues(alpha: 0.3),
                AppColors.accent300.withValues(alpha: 0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _radialBlur({required double diameter, required List<Color> colors}) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }

  Widget _topRightGlow({required double diameter}) {
    // A soft, warm bloom rather than a glassy disc: every stop fades the
    // *same* hue down to zero alpha instead of mixing white toward
    // black-at-zero-alpha, which is what produced the grayish "cristal" ring.
    // A wide, gentle stop curve stands in for a real blur (cheaper and
    // consistent across web renderers).
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.5),
            Colors.white.withValues(alpha: 0.22),
            AppColors.primary700.withValues(alpha: 0.10),
            AppColors.primary700.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.3, 0.65, 1.0],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.onPressed, required this.label});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment(0.00, 0.00),
          end: Alignment(1.00, 1.00),
          colors: [AppColors.primary500, AppColors.primary700],
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
          child: Center(child: Text(label, style: AppTextStyles.buttonLarge)),
        ),
      ),
    );
  }
}

class _SocialAuthRow extends StatelessWidget {
  const _SocialAuthRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final provider in mockSocialAuthProviders) ...[
          _SocialAuthButton(provider: provider),
          if (provider != mockSocialAuthProviders.last)
            const SizedBox(width: 16),
        ],
      ],
    );
  }
}

class _SocialAuthButton extends StatelessWidget {
  const _SocialAuthButton({required this.provider});

  final SocialAuthProvider provider;

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
          onTap: () {},
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  offset: Offset(0, 2),
                  blurRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: provider.assetPath.endsWith('.svg')
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
                  child: SvgPicture.asset(
                    'assets/images/icon_eye.svg',
                    width: 16,
                    height: 16,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
