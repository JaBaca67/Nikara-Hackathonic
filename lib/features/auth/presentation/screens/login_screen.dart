import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInput;

import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/services/guest_session_service.dart';
import 'package:nikara_app/features/auth/presentation/screens/register_screen.dart';
import 'package:nikara_app/shared/widgets/auth/auth_bottom_sheet_layout.dart';
import 'package:nikara_app/shared/widgets/auth/auth_header.dart';
import 'package:nikara_app/shared/widgets/auth/auth_primary_button.dart';
import 'package:nikara_app/shared/widgets/auth/auth_prompt.dart';
import 'package:nikara_app/shared/widgets/auth/auth_text_field.dart';
import 'package:nikara_app/shared/widgets/auth/guest_explore_button.dart';
import 'package:nikara_app/shared/widgets/auth/social_login_row.dart';
import 'package:nikara_app/shared/widgets/main_layout.dart';
import 'package:nikara_app/shared/widgets/splash_transition_screen.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Pantalla de login: shell con degradado atardecer vía
/// [AuthBottomSheetLayout], sin botón de atrás (es la raíz de la app).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  AuthStatus _status = AuthStatus.idle;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  static final RegExp _emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[A-Za-z]{2,}$');

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
    _emailController.dispose();
    _passwordController.dispose();
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

  /// Ej: '123456', 'abcdef', 'fedcba', 'aaaaaa'.
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
    if (_status == AuthStatus.loading) return;
    FocusScope.of(context).unfocus();
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      setState(() {
        _status = AuthStatus.invalid;
        _autovalidateMode = AutovalidateMode.onUserInteraction;
      });
      return;
    }

    setState(() => _status = AuthStatus.loading);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final result = await _authService.signIn(email: email, password: password);
    if (!mounted) return;

    if (result.success) {
      setState(() => _status = AuthStatus.success);
      await GuestSessionService().exitGuestMode();
      if (!mounted) return;
      // Avisa al autofill del sistema que terminó con éxito, para que
      // ofrezca guardar las credenciales recién ingresadas.
      TextInput.finishAutofillContext();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const SplashTransitionScreen(nextPage: MainLayout()),
        ),
        (route) => false,
      );
      return;
    }

    setState(() => _status = AuthStatus.error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message ?? 'No se pudo iniciar sesión')),
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

  void _forgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'La recuperación de contraseña estará disponible pronto.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthBottomSheetLayout(
      child: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AuthHeader(
                title: 'Bienvenido de nuevo',
                subtitle: 'Inicia sesión para continuar tu aventura',
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: 'Correo electrónico',
                hintText: 'ej: usuario@email.com',
                controller: _emailController,
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                validator: _validateEmail,
              ),
              const SizedBox(height: 14),
              AuthTextField(
                label: 'Contraseña',
                hintText: '••••••••',
                controller: _passwordController,
                icon: Icons.lock_outline,
                isPassword: true,
                autofillHints: const [AutofillHints.password],
                validator: _validatePassword,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _forgotPassword,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(
                    '¿Olvidaste tu contraseña?',
                    style: AppTextStyles.linkMd.copyWith(
                      color: AppColors.authLink,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              AuthPrimaryButton(
                label: 'Siguiente',
                onPressed: _status == AuthStatus.loading ? null : _submit,
                isLoading: _status == AuthStatus.loading,
              ),
              const SizedBox(height: 20),
              const SocialLoginRow(),
              const SizedBox(height: 18),
              AuthPrompt(
                text: '¿No tienes cuenta?',
                actionLabel: 'Regístrate aquí',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                },
              ),
              const SizedBox(height: 14),
              GuestExploreButton(onTap: _continueAsGuest),
            ],
          ),
        ),
      ),
    );
  }
}
