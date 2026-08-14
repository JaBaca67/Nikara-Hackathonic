import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/services/guest_session_service.dart';
import 'package:nikara_app/core/services/local_profile_extras_service.dart';
import 'package:nikara_app/core/utils/input_formatters.dart';
import 'package:nikara_app/features/auth/domain/models/country_dial_code.dart';
import 'package:nikara_app/features/auth/presentation/widgets/social_auth_row.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/shared/widgets/main_layout.dart';
import 'package:nikara_app/shared/widgets/otp_input_row.dart';
import 'package:nikara_app/shared/widgets/splash_transition_screen.dart';
import 'package:nikara_app/theme/app_theme.dart';
import 'package:nikara_app/widgets/aurora_background_widget.dart';

/// Real, non-mock interest categories offered in Paso 4 — the same
/// vocabulary the rest of the app already uses for destinations/business
/// categories (eco-tourism, adventure, culture...), not an invented list.
const List<String> _kInterestCategories = [
  'Playas',
  'Volcanes',
  'Eco Turismo',
  'Aventura',
  'Cultura',
  'Gastronomía',
  'Naturaleza',
  'Relajación',
];

/// 4-step registration wizard (Figma nodes 157:96 / 113:95 as the visual
/// starting point, extended per the UX redesign):
///
/// 1. Identidad — correo + contraseña (o social login), fuerza de
///    contraseña en vivo.
/// 2. Perfil — foto, nombre completo, usuario, celular. The real Supabase
///    account is created at the end of this step (needs email+password
///    from Paso 1 and phone from here) — Pasos 3 y 4 are then onboarding
///    for an account that already exists.
/// 3. Verificación — cajas OTP independientes. There's no SMS/email OTP
///    provider configured in Supabase, so "Verificar código" is an honest
///    stub (never fakes success) and "Saltar por ahora" — which stores
///    `isPhoneVerified: false` locally — is the fully-supported path.
/// 4. Preferencias — categorías de interés, guardadas localmente (no
///    columna en Supabase todavía) via [LocalProfileExtrasService].
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _authService = AuthService();
  final _extrasService = LocalProfileExtrasService();

  int _step = 0;
  bool _isCreatingAccount = false;
  bool _isFinishing = false;

  // Paso 1: Identidad.
  final _step1FormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  AutovalidateMode _step1AutovalidateMode = AutovalidateMode.disabled;

  // Paso 2: Perfil.
  final _step2FormKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _avatarPath;
  CountryDialCode _selectedCountry = kDefaultCountryDialCode;
  AutovalidateMode _step2AutovalidateMode = AutovalidateMode.disabled;

  // Paso 3: Verificación.
  String _otpCode = '';

  // Paso 4: Preferencias.
  final Set<String> _selectedCategories = {};

  static final RegExp _emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[A-Za-z]{2,}$');

  static final RegExp _usernameRegex = RegExp(r'^[a-zA-Z0-9_.]+$');

  @override
  void initState() {
    super.initState();
    // Only these two drive live visual feedback (strength meter, username
    // availability copy) — no other field needs a rebuild on every
    // keystroke, keeping typing elsewhere in the form cheap.
    _passwordController.addListener(() => setState(() {}));
    _usernameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
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

  bool get _usernameLooksGood =>
      _usernameController.text.trim().isNotEmpty &&
      _validateUsername(_usernameController.text) == null;

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

  /// Single entry point for both the header's back button and the hardware
  /// back gesture/button (wired via [PopScope] in [build]) — keeping them
  /// on one method is what fixes the "Atrás borra todo y regresa al
  /// Login" bug: stepping backward now always goes through `setState`
  /// instead of ever popping the route while mid-wizard, so every
  /// controller (and everything already typed into it) survives.
  Future<void> _handleBackRequest() async {
    FocusScope.of(context).unfocus();
    if (_step == 1) {
      _goToIdentityStep();
      return;
    }
    if (_step >= 2) {
      // Verificación/Preferencias — the real account already exists at
      // this point (see [_createAccountAndContinue]'s doc comment), so
      // there's no in-progress data left to protect; just let the user out.
      Navigator.of(context).pop();
      return;
    }
    // _step == 0: only here can leaving actually discard typed
    // email/password, so confirm first instead of exiting silently.
    final shouldExit = await _confirmCancelRegistration();
    if (shouldExit && mounted) Navigator.of(context).pop();
  }

  Future<bool> _confirmCancelRegistration() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface100,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '¿Cancelar registro?',
          style: AppTextStyles.detailSectionTitle,
        ),
        content: Text(
          'Perderás la información que ya ingresaste. ¿Deseas salir del '
          'registro?',
          style: AppTextStyles.body,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Seguir aquí', style: AppTextStyles.link),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.settingsDanger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    return result ?? false;
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
                color: AppColors.wizardFocus,
              ),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.wizardFocus,
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
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<CountryDialCode>(
      context: context,
      backgroundColor: AppColors.surface100,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text(
                'Selecciona tu país',
                style: AppTextStyles.detailSectionTitle,
              ),
              const SizedBox(height: 4),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: kCountryDialCodes.length,
                  itemBuilder: (context, index) {
                    final country = kCountryDialCodes[index];
                    return ListTile(
                      leading: Text(
                        country.flagEmoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                      title: Text(country.name, style: AppTextStyles.inputText),
                      trailing: Text(
                        country.dialCode,
                        style: AppTextStyles.inputLabel,
                      ),
                      onTap: () => Navigator.of(context).pop(country),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedCountry = picked);
    }
  }

  /// Validates Perfil, then actually creates the Supabase account (needs
  /// email/password from Paso 1 plus phone from here) and saves
  /// username/photo locally. Pasos 3-4 that follow are onboarding for an
  /// account that already exists — there's no "Atrás" past this point.
  Future<void> _createAccountAndContinue() async {
    FocusScope.of(context).unfocus();
    if (!(_step2FormKey.currentState?.validate() ?? false)) {
      setState(
        () => _step2AutovalidateMode = AutovalidateMode.onUserInteraction,
      );
      return;
    }

    setState(() => _isCreatingAccount = true);
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
      setState(() => _isCreatingAccount = false);
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

    // A real account now exists — clears any leftover guest flag from
    // whoever arrived here via "Explorar como invitado" or the guest
    // guard's "Crear mi cuenta" CTA.
    await GuestSessionService().exitGuestMode();
    if (!mounted) return;
    // Lets the OS actually offer to save the credentials just created.
    TextInput.finishAutofillContext();
    setState(() {
      _isCreatingAccount = false;
      _step = 2;
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
    setState(() => _step = 3);
  }

  Future<void> _finish() async {
    setState(() => _isFinishing = true);
    await _extrasService.updateInterestCategories(_selectedCategories.toList());
    if (!mounted) return;
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
    final logoAreaHeight = screenSize.height * (200 / 844);
    final cardBottomGap = screenSize.height * (16 / 844);

    return PopScope(
      // Never let the system back gesture/button pop this route directly —
      // [_handleBackRequest] decides whether that means "go back one step"
      // (preserving every controller) or a confirmed exit to Login.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackRequest();
      },
      child: Scaffold(
        backgroundColor: AppColors.primary500,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              width: screenSize.width,
              height: screenSize.height,
              child: const AuroraBackgroundWidget(),
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
                              // Same short-viewport safety net as
                              // LoginScreen's logo — fixed-size content
                              // inside a proportionally-scaling area.
                              child: const Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: _RegisterLogo(),
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
            // Floating header back-button — top-left, 48x48dp tap target,
            // same "floating control over a colorful background" language
            // as MapScreen's recenter/filter buttons, per the project's UI
            // standards for this kind of control.
            Positioned(
              top: 8,
              left: 8,
              child: SafeArea(
                child: _HeaderBackButton(onTap: _handleBackRequest),
              ),
            ),
          ],
        ),
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
            _WizardProgressBar(step: _step),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
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
                2 => _buildStepVerification(),
                _ => _buildStepPreferences(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIdentity() {
    return KeyedSubtree(
      key: const ValueKey('register-step-identity'),
      child: Form(
        key: _step1FormKey,
        autovalidateMode: _step1AutovalidateMode,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Crea tu cuenta', style: AppTextStyles.registerHeading),
              const SizedBox(height: 4),
              Text('Empecemos con lo básico', style: AppTextStyles.body),
              const SizedBox(height: 18),
              _RegisterField(
                label: 'Correo electrónico',
                hintText: 'ej: jose@example.com',
                controller: _emailController,
                iconAsset: 'assets/images/icon_email.svg',
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
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
                autofillHints: const [AutofillHints.newPassword],
                onToggleObscure: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                validator: _validatePassword,
              ),
              if (_passwordController.text.isNotEmpty) ...[
                const SizedBox(height: 10),
                _PasswordStrengthMeter(password: _passwordController.text),
              ],
              const SizedBox(height: 20),
              _PrimaryButton(onPressed: _goToProfileStep, label: 'Siguiente'),
              const SizedBox(height: 24),
              _CenteredDivider(label: 'o continúa con'),
              const SizedBox(height: 16),
              const SocialAuthRow(),
              const SizedBox(height: 20),
              _buildLoginPrompt(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepProfile() {
    return KeyedSubtree(
      key: const ValueKey('register-step-profile'),
      child: Form(
        key: _step2FormKey,
        autovalidateMode: _step2AutovalidateMode,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cuéntanos sobre ti', style: AppTextStyles.registerHeading),
              const SizedBox(height: 4),
              Text(
                'Así te vamos a reconocer en Níkara',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 18),
              Center(
                child: _AvatarPicker(path: _avatarPath, onTap: _pickAvatar),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _RegisterField(
                      label: 'Nombre',
                      hintText: 'ej: Samanta',
                      controller: _firstNameController,
                      icon: Icons.person_outline,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.givenName],
                      validator: (v) => _required(v, 'Ingresa tu nombre'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RegisterField(
                      label: 'Apellidos',
                      hintText: 'ej: Ixchel Galo',
                      controller: _lastNameController,
                      icon: Icons.person_outline,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.familyName],
                      validator: (v) => _required(v, 'Ingresa tus apellidos'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _RegisterField(
                label: 'Nombre de usuario',
                hintText: 'ej: samy.ixchel',
                controller: _usernameController,
                icon: Icons.alternate_email,
                autofillHints: const [AutofillHints.newUsername],
                validator: _validateUsername,
              ),
              if (_usernameLooksGood) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 14,
                      color: AppColors.ecoForest,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '¡Se ve bien!',
                      style: AppTextStyles.legend.copyWith(
                        color: AppColors.ecoForest,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              _PhoneRegisterField(
                controller: _phoneController,
                selectedCountry: _selectedCountry,
                onCountryTap: _showCountryPicker,
                validator: (v) => _required(v, 'Ingresa tu celular'),
              ),
              const SizedBox(height: 20),
              _PrimaryButton(
                onPressed: _isCreatingAccount
                    ? null
                    : _createAccountAndContinue,
                label: 'Crear mi cuenta',
                isLoading: _isCreatingAccount,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepVerification() {
    return KeyedSubtree(
      key: const ValueKey('register-step-verification'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Verifica tu número', style: AppTextStyles.registerHeading),
          const SizedBox(height: 4),
          Text(
            'La verificación por SMS estará disponible pronto. Mientras '
            'tanto, puedes continuar sin problema.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 24),
          OtpInputRow(
            length: 6,
            onChanged: (code) => setState(() => _otpCode = code),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: _otpCode.length == 6 ? _attemptVerifyOtp : null,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: _otpCode.length == 6
                      ? AppColors.wizardFocus
                      : AppColors.cardBorder,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Verificar código',
                style: AppTextStyles.buttonLg.copyWith(
                  color: AppColors.neutral900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _PrimaryButton(
            onPressed: _skipVerification,
            label: 'Saltar por ahora',
          ),
        ],
      ),
    );
  }

  Widget _buildStepPreferences() {
    return KeyedSubtree(
      key: const ValueKey('register-step-preferences'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('¿Qué te gusta explorar?', style: AppTextStyles.registerHeading),
          const SizedBox(height: 4),
          Text(
            'Elige tus intereses — nos ayuda a recomendarte mejores lugares.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final category in _kInterestCategories)
                _InterestChip(
                  label: category,
                  selected: _selectedCategories.contains(category),
                  onTap: () => setState(() {
                    if (!_selectedCategories.remove(category)) {
                      _selectedCategories.add(category);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 28),
          _PrimaryButton(
            onPressed: _isFinishing ? null : _finish,
            label: 'Explorar la app',
            isLoading: _isFinishing,
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('¿Ya tienes cuenta?', style: AppTextStyles.registerPrompt),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Text('Inicia sesión', style: AppTextStyles.registerLink),
        ),
      ],
    );
  }
}

/// Slim 4-segment progress bar + "Paso X de 4 · Nombre" caption — replaces
/// the earlier 2-circle indicator now that there are 4 steps.
class _WizardProgressBar extends StatelessWidget {
  const _WizardProgressBar({required this.step});

  final int step;

  static const _labels = [
    'Identidad',
    'Perfil',
    'Verificación',
    'Preferencias',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < _labels.length; i++) ...[
              if (i != 0) const SizedBox(width: 6),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 5,
                  decoration: BoxDecoration(
                    color: i <= step
                        ? AppColors.wizardFocus
                        : AppColors.warmChipBorder,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Paso ${step + 1} de ${_labels.length} · ${_labels[step]}',
          style: AppTextStyles.stepIndicatorCaption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
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
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface100,
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: AppColors.cardShadow,
            ),
            child: path == null
                ? const Icon(
                    Icons.person_outline,
                    size: 36,
                    color: AppColors.neutral600,
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
                color: AppColors.wizardFocus,
                border: Border.all(color: AppColors.backgroundCream, width: 2),
              ),
              child: const Icon(
                Icons.photo_camera,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InterestChip extends StatelessWidget {
  const _InterestChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.wizardFocus : AppColors.surface100,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.wizardFocus : AppColors.cardBorder,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.wizardFocus.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: AppTextStyles.bodyText2.copyWith(
            color: selected ? Colors.white : AppColors.neutral900,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _CenteredDivider extends StatelessWidget {
  const _CenteredDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.cardBorder)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: AppTextStyles.legend.copyWith(color: AppColors.neutral600),
          ),
        ),
        Expanded(child: Divider(color: AppColors.cardBorder)),
      ],
    );
  }
}

/// Floating circular back button — top-left, 48x48dp tap target (meets the
/// project's minimum touch-target standard), same floating-control styling
/// MapScreen uses for controls sitting directly over a busy background
/// (surface100 fill, hairline border, soft shadow) rather than the plain
/// profileDivider circle used in AppBar-based headers elsewhere, since this
/// screen has no AppBar to anchor to.
class _HeaderBackButton extends StatelessWidget {
  const _HeaderBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface100,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.mapControlBorder),
          boxShadow: const [
            BoxShadow(
              color: AppColors.mapControlShadow,
              offset: Offset(0, 4),
              blurRadius: 14,
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_back,
          size: 20,
          color: AppColors.settingsTextDark,
        ),
      ),
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
            width: 120,
            height: 120,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -1),
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

/// Live checklist + strength bar shown under the password field as the
/// user types — real-time feedback instead of only finding out a password
/// is too weak after tapping "Siguiente". Purely informational (the actual
/// submit gate stays the existing 6-character minimum in
/// [_RegisterScreenState._validatePassword]); this doesn't silently
/// tighten the account-creation policy underneath the user.
class _PasswordStrengthMeter extends StatelessWidget {
  const _PasswordStrengthMeter({required this.password});

  final String password;

  bool get _hasMinLength => password.length >= 8;
  bool get _hasUpperAndLower =>
      password.contains(RegExp('[a-z]')) && password.contains(RegExp('[A-Z]'));
  bool get _hasDigit => password.contains(RegExp(r'[0-9]'));
  bool get _hasSymbol => password.contains(RegExp(r'[^a-zA-Z0-9]'));

  int get _score => [
    _hasMinLength,
    _hasUpperAndLower,
    _hasDigit,
    _hasSymbol,
  ].where((met) => met).length;

  (String, Color) get _label => switch (_score) {
    0 || 1 => ('Débil', AppColors.settingsDanger),
    2 => ('Media', AppColors.primary400),
    3 => ('Fuerte', AppColors.bookingConfirmed),
    _ => ('Muy fuerte', AppColors.ecoForest),
  };

  @override
  Widget build(BuildContext context) {
    final (label, color) = _label;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Seguridad de contraseña', style: AppTextStyles.inputLabel),
              Text(
                label,
                style: AppTextStyles.inputLabel.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _score / 4,
              minHeight: 4,
              backgroundColor: AppColors.surface200,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _Criterion(met: _hasMinLength, label: 'Mínimo 8 caracteres'),
              _Criterion(
                met: _hasUpperAndLower,
                label: 'Mayúsculas y minúsculas',
              ),
              _Criterion(met: _hasDigit, label: 'Al menos 1 número'),
              _Criterion(met: _hasSymbol, label: 'Al menos 1 símbolo'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Criterion extends StatelessWidget {
  const _Criterion({required this.met, required this.label});

  final bool met;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          met ? Icons.check_circle : Icons.circle_outlined,
          size: 14,
          color: met ? AppColors.ecoForest : AppColors.neutral600,
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTextStyles.legend.copyWith(
            color: met ? AppColors.neutral900 : AppColors.neutral600,
          ),
        ),
      ],
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
    this.autofillHints,
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
                      color: AppColors.formError,
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

/// Phone field with a tappable country-dial-code pill in place of a fixed
/// "+505 " prefix — Nicaragua still gets its "XXXX-XXXX" mask
/// ([NicaraguaPhoneInputFormatter]); every other country falls back to a
/// plain digits-only input, since that formatter's dash placement/length
/// cap is specific to Nicaraguan numbers.
class _PhoneRegisterField extends StatelessWidget {
  const _PhoneRegisterField({
    required this.controller,
    required this.selectedCountry,
    required this.onCountryTap,
    required this.validator,
  });

  final TextEditingController controller;
  final CountryDialCode selectedCountry;
  final VoidCallback onCountryTap;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    final isNicaragua = selectedCountry.dialCode == '+505';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CELULAR', style: AppTextStyles.inputLabel),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
              GestureDetector(
                onTap: onCountryTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selectedCountry.flagEmoji,
                        style: const TextStyle(fontSize: 17),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        selectedCountry.dialCode,
                        style: AppTextStyles.inputText,
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.expand_more,
                        size: 16,
                        color: AppColors.neutral600,
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                height: 22,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: AppColors.cardBorder,
              ),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  inputFormatters: isNicaragua
                      ? const [NicaraguaPhoneInputFormatter()]
                      : [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(12),
                        ],
                  autofillHints: const [AutofillHints.telephoneNumber],
                  validator: validator,
                  style: AppTextStyles.inputText,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: isNicaragua ? '8545-9245' : 'Número de celular',
                    hintStyle: AppTextStyles.inputText.copyWith(
                      color: AppColors.neutral600,
                    ),
                    border: InputBorder.none,
                    errorMaxLines: 1,
                    errorStyle: GoogleFonts.nunito(
                      color: AppColors.formError,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
