import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/services/guest_session_service.dart';
import 'package:nikara_app/core/services/local_profile_extras_service.dart';
import 'package:nikara_app/core/utils/input_formatters.dart';
import 'package:nikara_app/features/auth/domain/models/country_dial_code.dart';
import 'package:nikara_app/shared/widgets/auth/auth_bottom_sheet_layout.dart';
import 'package:nikara_app/shared/widgets/auth/auth_header.dart';
import 'package:nikara_app/shared/widgets/auth/auth_primary_button.dart';
import 'package:nikara_app/shared/widgets/auth/auth_prompt.dart';
import 'package:nikara_app/shared/widgets/auth/auth_text_field.dart';
import 'package:nikara_app/shared/widgets/auth/country_code_picker.dart';
import 'package:nikara_app/shared/widgets/auth/password_strength_checker.dart';
import 'package:nikara_app/shared/widgets/auth/social_login_row.dart';
import 'package:nikara_app/shared/widgets/auth/step_progress_indicator.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/shared/widgets/main_layout.dart';
import 'package:nikara_app/shared/widgets/otp_input_row.dart';
import 'package:nikara_app/shared/widgets/splash_transition_screen.dart';
import 'package:nikara_app/theme/app_theme.dart';

const _kStepLabels = ['Identidad', 'Perfil', 'Verificación'];

/// Pantallas 10a/10b/10c — "Registro en 3 pasos" (Claude Design canvas
/// "Nikara Inicio y Mapa", turn 10):
///
/// 10a. Identidad — correo + contraseña, fuerza de contraseña en vivo.
/// 10b. Perfil — avatar, nombre, apellidos, usuario, celular. The real
///      Supabase account is created at the end of this step (needs
///      email+password from 10a and phone from here) — 10c that follows
///      is onboarding for an account that already exists.
/// 10c. Verificación — 6 cajas OTP con auto-focus, reenvío con cooldown.
///      There's no SMS/email OTP provider configured in Supabase, so
///      "Verificar código" is an honest stub (never fakes success) and
///      "Saltar por ahora" — which stores `isPhoneVerified: false`
///      locally — is the fully-supported path, ending the flow.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _authService = AuthService();
  final _extrasService = LocalProfileExtrasService();

  int _step = 0;
  AuthStatus _status = AuthStatus.idle;

  // Paso 10a: Identidad.
  final _step1FormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  AutovalidateMode _step1AutovalidateMode = AutovalidateMode.disabled;

  // Paso 10b: Perfil.
  final _step2FormKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _avatarPath;
  CountryDialCode _selectedCountry = kDefaultCountryDialCode;
  AutovalidateMode _step2AutovalidateMode = AutovalidateMode.disabled;

  // Paso 10c: Verificación.
  String _otpCode = '';
  Timer? _resendTimer;
  int _resendCooldown = 0;

  static final RegExp _emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[A-Za-z]{2,}$');

  static final RegExp _usernameRegex = RegExp(r'^[a-zA-Z0-9_.]+$');

  @override
  void initState() {
    super.initState();
    // Drives the live password-strength card — no other field needs a
    // rebuild on every keystroke.
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _resendTimer?.cancel();
    super.dispose();
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

  String? _validateUsername(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Elige un nombre de usuario';
    if (trimmed.length < 3) return 'Mínimo 3 caracteres';
    if (!_usernameRegex.hasMatch(trimmed)) {
      return 'Solo letras, números, "." y "_"';
    }
    return null;
  }

  void _goToProfileStep() {
    FocusScope.of(context).unfocus();
    if (!(_step1FormKey.currentState?.validate() ?? false)) {
      setState(
        () => _step1AutovalidateMode = AutovalidateMode.onUserInteraction,
      );
      return;
    }
    setState(() => _step = 1);
  }

  void _goToIdentityStep() {
    FocusScope.of(context).unfocus();
    setState(() => _step = 0);
  }

  Future<void> _pickAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface100,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text('Foto de perfil', style: AppTextStyles.detailSectionTitle),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.photo_camera_outlined,
                color: AppColors.primary500,
              ),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.primary500,
              ),
              title: const Text('Elegir de galería'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _avatarPath = picked.path);
  }

  Future<void> _showCountryPicker() async {
    final picked = await showCountryDialCodePicker(context);
    if (picked != null && mounted) {
      setState(() => _selectedCountry = picked);
    }
  }

  /// Validates Perfil, then actually creates the Supabase account (needs
  /// email/password from 10a plus phone from here) and saves
  /// username/photo locally. 10c that follows is onboarding for an
  /// account that already exists — there's no "Atrás" past this point.
  Future<void> _createAccountAndContinue() async {
    FocusScope.of(context).unfocus();
    if (!(_step2FormKey.currentState?.validate() ?? false)) {
      setState(
        () => _step2AutovalidateMode = AutovalidateMode.onUserInteraction,
      );
      return;
    }

    setState(() => _status = AuthStatus.loading);
    final fullName =
        '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
            .trim();
    final phone = '${_selectedCountry.dialCode} ${_phoneController.text.trim()}'
        .trim();
    final result = await _authService.signUp(
      fullName: fullName,
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      phone: phone,
    );
    if (!mounted) return;

    if (!result.success) {
      setState(() => _status = AuthStatus.error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'No se pudo crear la cuenta')),
      );
      return;
    }

    // Best-effort: the real account already exists at this point even if
    // these local writes somehow fail, so failures here don't block
    // moving forward.
    final username = _usernameController.text.trim();
    if (username.isNotEmpty) {
      await _extrasService.updateUsername(username);
    }
    final avatarPath = _avatarPath;
    if (avatarPath != null) {
      await _extrasService.updateAvatar(avatarPath);
    }
    if (!mounted) return;

    await GuestSessionService().exitGuestMode();
    if (!mounted) return;
    TextInput.finishAutofillContext();
    setState(() {
      _status = AuthStatus.success;
      _step = 2;
    });
    _startResendCooldown();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendCooldown = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
        return;
      }
      setState(() => _resendCooldown -= 1);
    });
  }

  void _attemptVerifyOtp() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'La verificación por SMS todavía no está disponible. Usa '
          '"Saltar por ahora" para continuar — no afecta tu cuenta.',
        ),
      ),
    );
  }

  Future<void> _skipVerification() async {
    await _extrasService.updateIsPhoneVerified(false);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const SplashTransitionScreen(nextPage: MainLayout()),
      ),
      (route) => false,
    );
  }

  /// Single entry point for both the header's back button and the
  /// hardware back gesture (wired via [AuthBottomSheetLayout.onBack]) —
  /// keeping them on one method is what fixes the "Atrás borra todo y
  /// regresa al Login" bug: stepping backward always goes through
  /// `setState` instead of ever popping the route mid-wizard, so every
  /// controller (and everything already typed into it) survives.
  Future<void> _handleBackRequest() async {
    FocusScope.of(context).unfocus();
    if (_step == 1) {
      _goToIdentityStep();
      return;
    }
    if (_step >= 2) {
      // Verificación — the real account already exists at this point, so
      // there's no in-progress data left to protect; just let the user out.
      Navigator.of(context).pop();
      return;
    }
    // _step == 0: only here can leaving actually discard typed
    // email/password, so confirm first instead of exiting silently.
    final shouldExit = await _confirmCancelRegistration();
    if (shouldExit && mounted) Navigator.of(context).pop();
  }

  /// Custom [Dialog] instead of [AlertDialog] so the two actions can be the
  /// exact same [AuthPrimaryButton]/[AuthOutlinedButton] widgets the rest
  /// of the Auth flow uses, full-width and stacked, rather than a generic
  /// Material action row. "Seguir aquí" (stay) gets the gold primary
  /// treatment — it's the recommended/default path — and "Salir" (discard
  /// everything typed) is deliberately the quieter outlined button instead
  /// of a loud red one, so leaving doesn't read as more inviting than
  /// staying.
  Future<bool> _confirmCancelRegistration() async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.authInk.withValues(alpha: 0.45),
      builder: (context) => Dialog(
        backgroundColor: AppColors.authCardBackground,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Cancelar registro?',
                style: AppTextStyles.registerHeading.copyWith(
                  color: AppColors.authInk,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Perderás la información que ya ingresaste. ¿Deseas salir '
                'del registro?',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.authBodyMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              AuthPrimaryButton(
                label: 'Seguir aquí',
                trailingIcon: null,
                onPressed: () => Navigator.of(context).pop(false),
              ),
              const SizedBox(height: 10),
              AuthOutlinedButton(
                label: 'Salir del registro',
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }

  /// Inline "Atrás" affordance for the step content itself — replaces the
  /// floating circular button that used to sit on top of
  /// [AuthBottomSheetLayout]'s busy animated gradient, which read as
  /// decoration more than as a clearly tappable control. Living inside the
  /// flat card background, in the same League Spartan / [AppColors.authInk]
  /// type system as everything else on the step, is what makes it actually
  /// read as a back button.
  Widget _buildStepBackRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: _handleBackRequest,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.arrow_back_rounded,
              size: 18,
              color: AppColors.authInk,
            ),
            const SizedBox(width: 6),
            Text(
              'Atrás',
              style: AppTextStyles.linkSm.copyWith(color: AppColors.authInk),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthBottomSheetLayout(
      onBack: _handleBackRequest,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        // AnimatedSwitcher.defaultLayoutBuilder stacks with
        // Alignment.center, which would float shorter step content in
        // the middle of whatever height the sheet currently is instead
        // of pinning it to the top — override just the alignment.
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.topCenter,
          children: [...previousChildren, ?currentChild],
        ),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: switch (_step) {
          0 => _buildStepIdentity(),
          1 => _buildStepProfile(),
          _ => _buildStepVerification(),
        },
      ),
    );
  }

  Widget _buildStepIdentity() {
    return KeyedSubtree(
      key: const ValueKey('register-step-10a'),
      child: Form(
        key: _step1FormKey,
        autovalidateMode: _step1AutovalidateMode,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStepBackRow(),
              StepProgressIndicator(step: 0, labels: _kStepLabels),
              const SizedBox(height: 16),
              const AuthHeader(
                title: 'Crea tu cuenta',
                subtitle: 'Empecemos con lo básico',
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: 'Correo electrónico',
                hintText: 'ej: jose@example.com',
                controller: _emailController,
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: _validateEmail,
              ),
              const SizedBox(height: 14),
              AuthTextField(
                label: 'Contraseña',
                hintText: '••••••••',
                controller: _passwordController,
                icon: Icons.lock_outline,
                isPassword: true,
                autofillHints: const [AutofillHints.newPassword],
                validator: _validatePassword,
              ),
              if (_passwordController.text.isNotEmpty) ...[
                const SizedBox(height: 10),
                PasswordStrengthChecker(password: _passwordController.text),
              ],
              const SizedBox(height: 18),
              AuthPrimaryButton(
                label: 'Siguiente',
                onPressed: _goToProfileStep,
              ),
              const SizedBox(height: 20),
              const SocialLoginRow(),
              const SizedBox(height: 16),
              _buildLoginPrompt(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepProfile() {
    return KeyedSubtree(
      key: const ValueKey('register-step-10b'),
      child: Form(
        key: _step2FormKey,
        autovalidateMode: _step2AutovalidateMode,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStepBackRow(),
              StepProgressIndicator(step: 1, labels: _kStepLabels),
              const SizedBox(height: 16),
              const AuthHeader(
                title: 'Cuéntanos sobre ti',
                subtitle: 'Así te vamos a reconocer en Níkara',
              ),
              const SizedBox(height: 16),
              Center(
                child: _AvatarPicker(path: _avatarPath, onTap: _pickAvatar),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AuthTextField(
                      label: 'Nombre',
                      hintText: 'ej: Samanta',
                      controller: _firstNameController,
                      icon: Icons.badge_outlined,
                      autofillHints: const [AutofillHints.givenName],
                      validator: (v) => _required(v, 'Ingresa tu nombre'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AuthTextField(
                      label: 'Apellidos',
                      hintText: 'ej: Ixchel',
                      controller: _lastNameController,
                      icon: Icons.badge_outlined,
                      autofillHints: const [AutofillHints.familyName],
                      validator: (v) => _required(v, 'Ingresa tus apellidos'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AuthTextField(
                label: 'Nombre de usuario',
                hintText: 'ej: samy.ixchel',
                controller: _usernameController,
                icon: Icons.alternate_email,
                autofillHints: const [AutofillHints.newUsername],
                validator: _validateUsername,
              ),
              const SizedBox(height: 14),
              AuthTextField(
                label: 'Celular',
                hintText: '8545-9245',
                controller: _phoneController,
                prefix: CountryPrefixBadge(
                  country: _selectedCountry,
                  onTap: _showCountryPicker,
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: _selectedCountry.dialCode == '+505'
                    ? const [NicaraguaPhoneInputFormatter()]
                    : [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(12),
                      ],
                autofillHints: const [AutofillHints.telephoneNumber],
                validator: (v) => _required(v, 'Ingresa tu celular'),
              ),
              const SizedBox(height: 18),
              AuthPrimaryButton(
                label: 'Crear mi cuenta',
                onPressed: _status == AuthStatus.loading
                    ? null
                    : _createAccountAndContinue,
                isLoading: _status == AuthStatus.loading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepVerification() {
    final canResend = _resendCooldown == 0;
    return KeyedSubtree(
      key: const ValueKey('register-step-10c'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepBackRow(),
          StepProgressIndicator(step: 2, labels: _kStepLabels),
          const SizedBox(height: 16),
          const AuthHeader(
            title: 'Verifica tu número',
            subtitle:
                'La verificación por SMS estará disponible pronto. Mientras '
                'tanto, puedes continuar sin problema.',
          ),
          const SizedBox(height: 22),
          OtpInputRow(
            length: 6,
            onChanged: (code) => setState(() => _otpCode = code),
          ),
          const SizedBox(height: 14),
          Center(
            child: GestureDetector(
              onTap: canResend ? _startResendCooldown : null,
              child: Text(
                canResend
                    ? 'Reenviar código'
                    : 'Reenviar código en 0:${_resendCooldown.toString().padLeft(2, '0')}',
                style: AppTextStyles.linkSm.copyWith(
                  color: canResend ? AppColors.authLink : AppColors.authMuted,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          AuthOutlinedButton(
            label: 'Verificar código',
            onPressed: _otpCode.length == 6 ? _attemptVerifyOtp : null,
          ),
          const SizedBox(height: 12),
          AuthPrimaryButton(
            label: 'Saltar por ahora',
            onPressed: _skipVerification,
            trailingIcon: null,
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return AuthPrompt(
      text: '¿Ya tienes cuenta?',
      actionLabel: 'Inicia sesión',
      onTap: () => Navigator.of(context).maybePop(),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({required this.path, required this.onTap});

  final String? path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.profileDivider,
            ),
            child: path == null
                ? const Icon(
                    Icons.person,
                    size: 38,
                    color: AppColors.authPlaceholder,
                  )
                : ClipOval(child: LocalImage(path: path)),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary500,
                border: Border.all(
                  color: AppColors.authCardBackground,
                  width: 3,
                ),
              ),
              child: const Icon(
                Icons.photo_camera,
                size: 15,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
