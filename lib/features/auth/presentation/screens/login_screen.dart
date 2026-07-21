import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nikara_app/models/mock_data.dart';
import 'package:nikara_app/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Proportions lifted directly from the Figma frame (390x844, node 157:2):
    // the card starts at y=235 and leaves a 16px gradient margin at the bottom.
    final cardTop = size.height * (235 / 844);
    final cardBottomMargin = size.height * (16 / 844);

    return Scaffold(
      backgroundColor: AppColors.primary500,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(child: _GradientBackground(size: size)),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: cardTop,
            child: const Center(child: _Logo()),
          ),
          Positioned(
            top: cardTop,
            left: 27,
            right: 27,
            bottom: cardBottomMargin,
            child: SafeArea(top: false, bottom: false, child: _buildCard()),
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 29, 24, 24),
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
              hintText: 'bugnuelitos@email.com',
              controller: emailController,
              iconAsset: 'assets/images/icon_email.svg',
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
            _PrimaryButton(onPressed: () {}, label: 'Siguiente'),
            const SizedBox(height: 40),
            const _SocialAuthRow(),
            const SizedBox(height: 24),
            _buildRegisterPrompt(),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('¿No tienes cuenta? ', style: AppTextStyles.registerPrompt),
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
        Image.asset(
          'assets/images/flower.png',
          width: 150,
          height: 150,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
        const SizedBox(height: 8),
        Text('NIKARA', style: AppTextStyles.logoWordmark),
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
          begin: Alignment(-0.16, -0.99),
          end: Alignment(0.16, 0.99),
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
                  ? SvgPicture.asset(
                      provider.assetPath,
                      width: 36,
                      height: 36,
                    )
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
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final String iconAsset;
  final bool isPassword;
  final bool obscureText;
  final VoidCallback? onToggleObscure;

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
                child: TextField(
                  controller: controller,
                  obscureText: isPassword && obscureText,
                  style: AppTextStyles.inputText,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: hintText,
                    hintStyle: AppTextStyles.inputText.copyWith(
                      color: AppColors.neutral600,
                    ),
                    border: InputBorder.none,
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
