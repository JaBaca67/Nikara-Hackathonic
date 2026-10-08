import 'package:flutter/material.dart';

import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/services/guest_session_service.dart';
import 'package:nikara_app/features/auth/presentation/screens/login_screen.dart';
import 'package:nikara_app/features/settings/data/settings_controller.dart';
import 'package:nikara_app/features/settings/presentation/screens/settings_account_screen.dart';
import 'package:nikara_app/features/settings/presentation/screens/settings_business_screen.dart';
import 'package:nikara_app/features/settings/presentation/screens/settings_eco_screen.dart';
import 'package:nikara_app/features/settings/presentation/screens/settings_notifications_screen.dart';
import 'package:nikara_app/features/settings/presentation/screens/settings_privacy_screen.dart';
import 'package:nikara_app/features/settings/presentation/screens/settings_support_screen.dart';
import 'package:nikara_app/features/settings/presentation/screens/settings_team_screen.dart';
import 'package:nikara_app/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:nikara_app/shared/widgets/account_switcher_sheet.dart';
import 'package:nikara_app/shared/widgets/app_confirm_dialog.dart';
import 'package:nikara_app/shared/widgets/app_loading.dart';
import 'package:nikara_app/shared/widgets/app_page_transition.dart';
import 'package:nikara_app/shared/widgets/app_snackbar.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Menú de Ajustes (nodo Figma 361:323): un botón por categoría, cada una con
/// su propia vista en este mismo directorio. Aquí quedan además "Cambiar de
/// cuenta" y, separadas abajo, las acciones de sesión (cerrar sesión y eliminar
/// la cuenta). El estado de las categorías vive en [SettingsController], que
/// pertenece a esta pantalla para que sobreviva a entrar y salir de cada vista.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService();
  final _controller = SettingsController();

  /// Cuentas guardadas además de la activa; alimenta la descripción del botón
  /// "Cambiar de cuenta".
  int _otherAccountsCount = 0;

  @override
  void initState() {
    super.initState();
    _controller.loadProfile();
    _loadSavedAccounts();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSavedAccounts() async {
    final accounts = await _authService.getSavedAccounts();
    if (!mounted) return;
    setState(() => _otherAccountsCount = accounts.length);
  }

  String get _savedAccountsCaption => switch (_otherAccountsCount) {
    0 => 'Agrega otra cuenta y alterna sin volver a iniciar sesión',
    1 => '1 cuenta más guardada en este dispositivo',
    final n => '$n cuentas más guardadas en este dispositivo',
  };

  Future<void> _openAccountSwitcher() async {
    await showAccountSwitcherSheet(context);
    if (!mounted) return;
    // La hoja puede haber quitado una cuenta guardada (o haber guardado la
    // activa por primera vez), así que el contador se recalcula al cerrarla.
    await _loadSavedAccounts();
  }

  void _open(Widget page) => pushSharedAxis(context, page);

  /// Mientras corre cerrar sesión o eliminar la cuenta: bloquea la pantalla
  /// (`AppBusyOverlay`) y el botón atrás, porque ambas acciones terminan
  /// sacando a la persona de Ajustes y no admiten un segundo disparo.
  bool _isBusy = false;
  String _busyMessage = '';

  Future<void> _confirmLogout() async {
    if (_isBusy) return;
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Cerrar sesión',
      message: '¿Seguro que quieres cerrar tu sesión de Níkara?',
      confirmLabel: 'Cerrar sesión',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _isBusy = true;
      _busyMessage = 'Cerrando sesión…';
    });
    try {
      await _authService.signOut();
      await GuestSessionService().exitGuestMode();
      if (!mounted) return;
      pushFadeThroughAndRemoveUntil(context, const LoginScreen());
    } on AuthServiceException catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, e.message);
    } on Exception {
      if (!mounted) return;
      AppSnackbar.showError(
        context,
        'No se pudo cerrar la sesión. Verifica tu internet e intenta de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    if (_isBusy) return;
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Eliminar cuenta',
      message:
          'Esta acción es permanente: se borrará tu perfil y toda tu '
          'información de Níkara, y no podrás recuperarla. ¿Seguro que '
          'quieres eliminar tu cuenta?',
      confirmLabel: 'Eliminar cuenta',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _isBusy = true;
      _busyMessage = 'Eliminando tu cuenta…';
    });
    try {
      await _authService.deleteAccount();
      await GuestSessionService().exitGuestMode();
      if (!mounted) return;
      pushFadeThroughAndRemoveUntil(context, const LoginScreen());
    } on AuthServiceException catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, e.message);
    } on Exception {
      if (!mounted) return;
      AppSnackbar.showError(
        context,
        'No se pudo eliminar tu cuenta. Verifica tu internet e intenta de '
        'nuevo.',
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: AppColors.settingsBackground,
      // El header blanco (surface100) llega hasta y=0 y absorbe la barra de
      // estado con su propio color, en vez de que el Scaffold pinte una
      // franja de settingsBackground (beige) detrás — ver home_screen.dart.
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsHeader(
              title: 'Ajustes',
              subtitle: 'Cuenta y preferencias',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => SettingsSection(
                children: [
                  SettingsMenuButton(
                    icon: Icons.person_outline,
                    title: 'Mi cuenta',
                    description: 'Tu perfil, contraseña y datos de contacto',
                    onTap: () =>
                        _open(SettingsAccountScreen(controller: _controller)),
                  ),
                  if (_controller.role.canAccessAdminPanel)
                    SettingsMenuButton(
                      icon: Icons.shield_outlined,
                      tint: AppColors.oliveText,
                      title: 'Equipo Níkara',
                      description: 'Herramientas para el equipo',
                      onTap: () =>
                          _open(SettingsTeamScreen(controller: _controller)),
                    ),
                  SettingsMenuButton(
                    icon: Icons.notifications_none,
                    title: 'Notificaciones',
                    description: 'Elige qué avisos quieres recibir',
                    onTap: () => _open(
                      SettingsNotificationsScreen(controller: _controller),
                    ),
                  ),
                  SettingsMenuButton(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacidad',
                    description: 'Controla qué compartes de tu perfil',
                    onTap: () =>
                        _open(SettingsPrivacyScreen(controller: _controller)),
                  ),
                  SettingsMenuButton(
                    icon: Icons.storefront_outlined,
                    title: 'Para negocios turísticos',
                    description: 'Registra tu negocio y llega a más viajeros',
                    onTap: () => _open(const SettingsBusinessScreen()),
                  ),
                  SettingsMenuButton(
                    icon: Icons.eco_outlined,
                    tint: AppColors.oliveText,
                    title: 'Comunidad ECO',
                    description: 'Organiza actividades y gestiona tu fundación',
                    onTap: () => _open(const SettingsEcoScreen()),
                  ),
                  SettingsMenuButton(
                    icon: Icons.help_outline,
                    title: 'Soporte',
                    description: 'Ayuda, términos e información de la app',
                    onTap: () => _open(const SettingsSupportScreen()),
                  ),
                  SettingsMenuButton(
                    icon: Icons.switch_account_outlined,
                    title: 'Cambiar de cuenta',
                    description: _savedAccountsCaption,
                    onTap: _openAccountSwitcher,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            SettingsSection(
              label: 'Sesión',
              children: [
                SettingsRow(
                  icon: Icons.logout,
                  iconTint: AppColors.destructive,
                  titleColor: AppColors.destructive,
                  title: 'Cerrar sesión',
                  onTap: _confirmLogout,
                ),
                SettingsRow(
                  icon: Icons.delete_forever_outlined,
                  iconTint: AppColors.destructive,
                  titleColor: AppColors.destructive,
                  title: 'Eliminar cuenta',
                  caption: 'Borra tu perfil y datos de forma permanente',
                  onTap: _confirmDeleteAccount,
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return PopScope(
      canPop: !_isBusy,
      child: AppBusyOverlay(
        visible: _isBusy,
        message: _busyMessage,
        child: scaffold,
      ),
    );
  }
}
