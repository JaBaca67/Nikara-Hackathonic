import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/shared/widgets/main_layout.dart';
import 'package:nikara_app/shared/widgets/splash_transition_screen.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Registro screen (Figma nodes 157:96 "Datos Personales" and 113:95
/// "Credenciales de acceso") built as a 2-step form inside the same
/// fixed-background/scrollable-card shell as [LoginScreen]. Step switching
/// is driven by a local `_step` index rather than a `PageView` — the visual
/// progress indicator (the two numbered circles) is what the Figma design
/// actually calls for; the content underneath just needs to swap.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _authService = AuthService();

  int _step = 0;
  bool _isSubmitting = false;

  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  static final RegExp _emailRegex = RegExp(
    r'^[\w.+-]+@[\w-]+\.[A-Za-z]{2,}$',
  );

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _goToStep2() {
    FocusScope.of(context).unfocus();
    if (!(_step1FormKey.currentState?.validate() ?? false)) return;
    setState(() => _step = 1);
  }

  void _goToStep1() {
    FocusScope.of(context).unfocus();
    setState(() => _step = 0);
  }

  String? _required(String? value, String message) {
    return (value == null || value.trim().isEmpty) ? message : null;
  }

  String? _validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Ingresa un correo';
    if (!_emailRegex.hasMatch(trimmed)) return 'Correo no válido';
    return null;
  }

  String? _validatePassword(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Ingresa una contraseña';
    if (trimmed.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _passwordController.text) return 'No coinciden';
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_step2FormKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    final fullName =
        '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
            .trim();
    final result = await _authService.signUp(
      fullName: fullName,
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      phone: _phoneController.text.trim(),
    );
    if (!mounted) return;

    if (!result.success) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'No se pudo crear la cuenta')),
      );
      return;
    }

    // Clears the whole registration stack (both steps) so the back button
    // can't return to a completed sign-up flow once inside the app.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const SplashTransitionScreen(nextPage: MainLayout()),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final logoAreaHeight = screenSize.height * (235 / 844);
    final cardBottomGap = screenSize.height * (16 / 844);

    return Scaffold(
      backgroundColor: AppColors.primary500,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            width: screenSize.width,
            height: screenSize.height,
            child: _RegisterGradientBackground(size: screenSize),
          ),
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
                            child: const Center(child: _RegisterLogo()),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Crea una cuenta', style: AppTextStyles.registerHeading),
            const SizedBox(height: 4),
            Text('Únete a la comunidad Nikara', style: AppTextStyles.body),
            const SizedBox(height: 20),
            _StepIndicator(step: _step),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0.06, 0),
                        end: Offset.zero,
                      ).animate(animation),
                  child: child,
                ),
              ),
              child: _step == 0 ? _buildStep1() : _buildStep2(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return KeyedSubtree(
      key: const ValueKey('register-step-1'),
      child: Form(
        key: _step1FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RegisterField(
              label: 'Nombres',
              hintText: 'ej: Samanta Ixchel',
              controller: _firstNameController,
              icon: Icons.person_outline,
              textCapitalization: TextCapitalization.words,
              validator: (v) => _required(v, 'Ingresa tu nombre'),
            ),
            const SizedBox(height: 14),
            _RegisterField(
              label: 'Apellidos',
              hintText: 'ej: Galo Olivas',
              controller: _lastNameController,
              icon: Icons.badge_outlined,
              textCapitalization: TextCapitalization.words,
              validator: (v) => _required(v, 'Ingresa tu apellido'),
            ),
            const SizedBox(height: 14),
            _RegisterField(
              label: 'Celular',
              hintText: 'ej: +505 8545-9245',
              controller: _phoneController,
              icon: Icons.call_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) => _required(v, 'Ingresa tu celular'),
            ),
            const SizedBox(height: 20),
            _PrimaryButton(onPressed: _goToStep2, label: 'Siguiente'),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return KeyedSubtree(
      key: const ValueKey('register-step-2'),
      child: Form(
        key: _step2FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RegisterField(
              label: 'Correo electrónico',
              hintText: 'ej: jose@example.com',
              controller: _emailController,
              iconAsset: 'assets/images/icon_email.svg',
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
            ),
            const SizedBox(height: 14),
            _RegisterField(
              label: 'Contraseña',
              hintText: '••••••••',
              controller: _passwordController,
              iconAsset: 'assets/images/icon_lock.svg',
              isPassword: true,
              obscureText: _obscurePassword,
              onToggleObscure: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
              validator: _validatePassword,
            ),
            const SizedBox(height: 14),
            _RegisterField(
              label: 'Confirmar contraseña',
              hintText: '••••••••',
              controller: _confirmPasswordController,
              iconAsset: 'assets/images/icon_lock.svg',
              isPassword: true,
              obscureText: _obscureConfirmPassword,
              onToggleObscure: () {
                setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                );
              },
              validator: _validateConfirmPassword,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: _isSubmitting ? null : _goToStep1,
                  child: Text('Atrás', style: AppTextStyles.link),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 4),
            _PrimaryButton(
              onPressed: _isSubmitting ? null : _submit,
              label: 'Finalizar',
              isLoading: _isSubmitting,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepCircle(number: 1, active: step >= 0, filled: step >= 0),
        Expanded(
          child: Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: AppColors.primary500,
          ),
        ),
        _StepCircle(number: 2, active: step >= 1, filled: step >= 1),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Text(
            step == 0 ? 'Datos Personales' : 'Credenciales de acceso',
            style: AppTextStyles.stepIndicatorCaption,
          ),
        ),
      ],
    );
  }
}

class _StepCircle extends StatelessWidget {
  const _StepCircle({
    required this.number,
    required this.active,
    required this.filled,
  });

  final int number;
  final bool active;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 25,
      height: 25,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? AppColors.primary500 : Colors.white,
        border: Border.all(color: AppColors.primary500, width: 1),
      ),
      child: Text('$number', style: AppTextStyles.stepIndicatorNumber),
    );
  }
}

class _RegisterLogo extends StatelessWidget {
  const _RegisterLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.translate(
          offset: const Offset(0, 8),
          child: Image.asset(
            'assets/images/nikara_logo.png',
            width: 150,
            height: 150,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -1),
          child: Text('NIKARA', style: AppTextStyles.logoWordmark),
        ),
      ],
    );
  }
}

/// Full-bleed gradient background matching the login screen's, reused here
/// as a private copy since the two decorative blurs are per-node absolute
/// coordinates in Figma (157:98/101 vs 113:97/98) and not identical enough
/// to justify a shared widget.
class _RegisterGradientBackground extends StatelessWidget {
  const _RegisterGradientBackground({required this.size});

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

class _RegisterField extends StatelessWidget {
  const _RegisterField({
    required this.label,
    required this.hintText,
    required this.controller,
    this.icon,
    this.iconAsset,
    this.isPassword = false,
    this.obscureText = false,
    this.onToggleObscure,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  }) : assert(
         icon != null || iconAsset != null,
         'Provide either icon or iconAsset',
       );

  final String label;
  final String hintText;
  final TextEditingController controller;
  final IconData? icon;
  final String? iconAsset;
  final bool isPassword;
  final bool obscureText;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
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
              SizedBox(
                width: 16,
                height: 16,
                child: iconAsset != null
                    ? SvgPicture.asset(iconAsset!, width: 16, height: 16)
                    : Icon(icon, size: 16, color: AppColors.neutral600),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  obscureText: isPassword && obscureText,
                  keyboardType: keyboardType,
                  textCapitalization: textCapitalization,
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
