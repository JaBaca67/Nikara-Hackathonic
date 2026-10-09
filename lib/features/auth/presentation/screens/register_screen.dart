import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/models/user_origin.dart';
import 'package:nikara_app/shared/widgets/origin_form_fields.dart';
import 'package:nikara_app/core/services/guest_session_service.dart';
import 'package:nikara_app/core/utils/validators.dart';
import 'package:nikara_app/shared/widgets/app_page_transition.dart';
import 'package:nikara_app/shared/widgets/auth/auth_bottom_sheet_layout.dart';
import 'package:nikara_app/shared/widgets/auth/auth_header.dart';
import 'package:nikara_app/shared/widgets/auth/auth_primary_button.dart';
import 'package:nikara_app/shared/widgets/auth/auth_prompt.dart';
import 'package:nikara_app/shared/widgets/auth/auth_text_field.dart';
import 'package:nikara_app/shared/widgets/auth/password_strength_checker.dart';
import 'package:nikara_app/shared/widgets/auth/social_login_row.dart';
import 'package:nikara_app/shared/widgets/app_snackbar.dart';
import 'package:nikara_app/shared/widgets/auth/step_progress_indicator.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/shared/widgets/main_layout.dart';
import 'package:nikara_app/shared/widgets/splash_transition_screen.dart';
import 'package:nikara_app/theme/app_motion.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

const _kStepLabels = ['Identidad', 'Perfil'];

/// Registro de identidad y perfil remoto, sin teléfono ni paso SMS.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _authService = AuthService();

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

  /// Foto elegida en el paso "Perfil", antes de que la cuenta exista. Se sube
  /// a Storage recién después del signUp, cuando ya hay sesión y un user id
  /// bajo el que guardarla (ver [AuthService.updateAvatar]).
  XFile? _avatarImage;
  UserOrigin _origin = const UserOrigin();
  AutovalidateMode _step2AutovalidateMode = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    // Alimenta la tarjeta de fuerza de contraseña en vivo; los demás campos
    // no necesitan rebuild en cada tecla.
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    super.dispose();
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
    setState(() => _avatarImage = picked);
  }

  Future<void> _createAccountAndContinue() async {
    if (_status == AuthStatus.loading) return;
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
    final result = await _authService.signUp(
      fullName: fullName,
      email: _emailController.text.trim(),
      password: _passwordController.text,
      username: _usernameController.text.trim(),
      origin: _origin,
    );
    if (!mounted) return;

    if (!result.success) {
      setState(() => _status = AuthStatus.error);
      AppSnackbar.showError(
        context,
        result.message ?? 'No se pudo crear la cuenta',
      );
      return;
    }

    final avatarImage = _avatarImage;
    if (avatarImage != null) {
      if (!_authService.isLoggedIn) {
        // Con confirmación de correo activada, signUp crea el usuario pero no
        // deja sesión — y sin sesión no hay a qué perfil subirle la foto ni
        // carpeta de Storage donde ponerla. Se avisa en vez de mostrar un
        // "necesitas iniciar sesión" justo después de registrarse.
        AppSnackbar.showInfo(
          context,
          'Tu foto se podrá subir cuando confirmes tu correo e inicies '
          'sesión, desde tu perfil.',
        );
      } else {
        try {
          await _authService.updateAvatar(avatarImage);
        } on AuthServiceException catch (e) {
          // La cuenta ya se creó: quedarse sin foto no justifica abortar el
          // registro, pero sí decirlo en vez de tragarse el error.
          if (!mounted) return;
          AppSnackbar.showError(context, e.message);
        }
      }
    }
    if (!mounted) return;

    await GuestSessionService().exitGuestMode();
    if (!mounted) return;
    TextInput.finishAutofillContext();
    if (!_authService.isLoggedIn) {
      AppSnackbar.showInfo(
        context,
        'Confirma tu correo e inicia sesión para continuar.',
      );
      Navigator.of(context).pop();
      return;
    }
    pushFadeThroughAndRemoveUntil(
      context,
      const SplashTransitionScreen(nextPage: MainLayout()),
    );
  }

  /// Punto único para el botón de atrás del header y el gesto físico
  /// (vía [AuthBottomSheetLayout.onBack]) — unificarlos arregla el bug de
  /// "Atrás borra todo y vuelve al Login": retroceder siempre pasa por
  /// `setState`, nunca hace pop de la ruta a mitad del wizard, así que
  /// cada controller sobrevive.
  Future<void> _handleBackRequest() async {
    if (_status == AuthStatus.loading) return;
    FocusScope.of(context).unfocus();
    if (_step == 1) {
      _goToIdentityStep();
      return;
    }
    // Solo acá salir borra de verdad lo tipeado, por eso se confirma antes.
    final shouldExit = await _confirmCancelRegistration();
    if (shouldExit && mounted) Navigator.of(context).pop();
  }

  /// [Dialog] a medida en vez de [AlertDialog] para reusar los mismos
  /// botones del resto del flujo de Auth, apilados a todo ancho. "Seguir
  /// aquí" lleva el dorado primario (opción recomendada); "Salir" es el
  /// outlined discreto, para que irse no luzca más invitante que quedarse.
  Future<bool> _confirmCancelRegistration() async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.authInk.withValues(alpha: 0.45),
      builder: (context) => Dialog(
        backgroundColor: AppColors.authCardBackground,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
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

  /// Reemplaza el botón circular flotante que quedaba sobre el degradado
  /// animado de [AuthBottomSheetLayout] y se leía más como decoración que
  /// como control tocable — vivir dentro de la tarjeta plana, con la misma
  /// tipografía del resto del paso, es lo que lo hace leerse como un botón
  /// de atrás real.
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
        duration: AppMotion.standardDuration,
        // El layoutBuilder por defecto centra verticalmente; acá se fija
        // arriba para que un paso más corto no quede flotando a mitad del sheet.
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
          _ => _buildStepProfile(),
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
                validator: validateEmail,
              ),
              const SizedBox(height: 14),
              AuthTextField(
                label: 'Contraseña',
                hintText: '••••••••',
                controller: _passwordController,
                icon: Icons.lock_outline,
                isPassword: true,
                autofillHints: const [AutofillHints.newPassword],
                validator: validatePassword,
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
                child: _AvatarPicker(
                  path: _avatarImage?.path,
                  onTap: _pickAvatar,
                ),
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
                      validator: (v) =>
                          validateRequiredText(v, label: 'tu nombre'),
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
                      validator: (v) =>
                          validateRequiredText(v, label: 'tus apellidos'),
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
                validator: validateUsername,
              ),
              const SizedBox(height: 14),
              OriginFormFields(
                initialValue: _origin,
                onChanged: (value) => _origin = value,
                enabled: _status != AuthStatus.loading,
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
                color: AppColors.surface100,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
