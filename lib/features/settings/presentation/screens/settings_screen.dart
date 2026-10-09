import 'package:flutter/material.dart';
import 'dart:async';
import 'package:nikara_app/core/services/remote_user_data_service.dart';

import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/services/guest_session_service.dart';
import 'package:nikara_app/features/auth/presentation/screens/login_screen.dart';
import 'package:nikara_app/features/settings/data/settings_controller.dart';
import 'package:nikara_app/features/settings/presentation/screens/settings_account_screen.dart';
import 'package:nikara_app/features/settings/presentation/screens/settings_community_screen.dart';
import 'package:nikara_app/features/settings/presentation/screens/settings_preferences_screen.dart';
import 'package:nikara_app/features/settings/presentation/screens/settings_support_screen.dart';
import 'package:nikara_app/features/settings/presentation/screens/settings_team_screen.dart';
import 'package:nikara_app/features/settings/presentation/widgets/settings_widgets.dart';
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

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  Future<void> Function()? _stopRemoteChanges;
  final _authService = AuthService();
  final _controller = SettingsController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_authService.isLoggedIn) {
      _stopRemoteChanges = RemoteUserDataService().subscribe(['profiles'], () {
        unawaited(_controller.loadProfile());
      });
    }
    _controller.loadProfile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final stop = _stopRemoteChanges;
    if (stop != null) unawaited(stop());
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_controller.loadProfile());
    }
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
                    title: 'Cuenta',
                    onTap: () =>
                        _open(SettingsAccountScreen(controller: _controller)),
                  ),
                  SettingsMenuButton(
                    icon: Icons.tune,
                    title: 'Preferencias',
                    onTap: () => _open(
                      SettingsPreferencesScreen(controller: _controller),
                    ),
                  ),
                  SettingsMenuButton(
                    icon: Icons.groups_outlined,
                    title: 'Comunidad',
                    onTap: () => _open(const SettingsCommunityScreen()),
                  ),
                  if (_controller.role.canAccessAdminPanel)
                    SettingsMenuButton(
                      icon: Icons.shield_outlined,
                      tint: AppColors.oliveText,
                      title: 'Equipo Níkara',
                      onTap: () =>
                          _open(SettingsTeamScreen(controller: _controller)),
                    ),
                  SettingsMenuButton(
                    icon: Icons.help_outline,
                    title: 'Ayuda y soporte',
                    onTap: () => _open(const SettingsSupportScreen()),
                  ),
                ],
              ),
            ),
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
