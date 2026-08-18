import 'package:flutter/material.dart';

import 'package:nikara_app/core/models/saved_account.dart';
import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/services/guest_session_service.dart';
import 'package:nikara_app/features/auth/presentation/screens/login_screen.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/shared/widgets/main_layout.dart';
import 'package:nikara_app/shared/widgets/splash_transition_screen.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Abre el selector "Cambiar de cuenta" como hoja modal. Al alternar de cuenta
/// reconstruye la app desde cero (`MainLayout` nuevo), porque cada pantalla
/// cachea los datos del usuario que estaba activo cuando se montó.
Future<void> showAccountSwitcherSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface100,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const AccountSwitcherSheet(),
  );
}

class AccountSwitcherSheet extends StatefulWidget {
  const AccountSwitcherSheet({super.key});

  @override
  State<AccountSwitcherSheet> createState() => _AccountSwitcherSheetState();
}

class _AccountSwitcherSheetState extends State<AccountSwitcherSheet> {
  final _authService = AuthService();

  bool _isLoading = true;
  List<SavedAccount> _accounts = const [];
  UserModel? _currentProfile;

  /// Id de la cuenta a la que se está alternando; deshabilita el resto de la
  /// lista mientras dura el intercambio de tokens.
  String? _switchingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // La sesión activa puede no estar todavía en el almacén (primer arranque
    // tras actualizar la app): guardarla aquí la deja disponible para el
    // próximo cambio de cuenta.
    await _authService.rememberCurrentAccount();
    final accounts = await _authService.getSavedAccounts();
    UserModel? profile;
    try {
      profile = await _authService.getCurrentProfile();
    } on AuthServiceException {
      // Sin conexión: la hoja sigue sirviendo para alternar, solo que la
      // cabecera muestra el fallback genérico.
    }
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _currentProfile = profile;
      _isLoading = false;
    });
  }

  Future<void> _switchTo(SavedAccount account) async {
    if (_switchingId != null) return;
    setState(() => _switchingId = account.userId);

    final result = await _authService.switchAccount(account.userId);
    if (!mounted) return;

    if (!result.success) {
      setState(() => _switchingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'No se pudo cambiar de cuenta.'),
        ),
      );
      await _load();
      return;
    }

    await GuestSessionService().exitGuestMode();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const SplashTransitionScreen(nextPage: MainLayout()),
      ),
      (route) => false,
    );
  }

  Future<void> _addAccount() async {
    Navigator.of(context).pop();
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  Future<void> _confirmForget(SavedAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface100,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Quitar cuenta',
          style: AppTextStyles.settingsTitle.copyWith(fontSize: 18),
        ),
        content: Text(
          'Se olvidará la sesión de ${account.displayName} en este '
          'dispositivo. La cuenta no se elimina: podrás volver a entrar con '
          'tu contraseña.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar', style: AppTextStyles.settingsRowValue),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Quitar',
              style: AppTextStyles.settingsRowTitle.copyWith(
                color: AppColors.settingsDanger,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _authService.forgetAccount(account.userId);
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentProfile;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surface200,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Cambiar de cuenta',
              style: AppTextStyles.settingsTitle.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              'Alterna entre tus perfiles sin volver a escribir la contraseña.',
              style: AppTextStyles.settingsSubtitle.copyWith(fontSize: 12.5),
            ),
            const SizedBox(height: 18),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (current != null)
                _AccountTile(
                  title: current.fullName.trim().isEmpty
                      ? current.email
                      : current.fullName,
                  subtitle: current.email,
                  roleLabel: _roleLabel(current.role),
                  initials: current.initials,
                  avatarUrl: current.avatarUrl,
                  isActive: true,
                  onTap: () => Navigator.of(context).pop(),
                ),
              for (final account in _accounts) ...[
                const SizedBox(height: 10),
                _AccountTile(
                  title: account.displayName,
                  subtitle: account.email,
                  roleLabel: account.roleLabel,
                  initials: account.initials,
                  avatarUrl: account.avatarUrl,
                  isActive: false,
                  isBusy: _switchingId == account.userId,
                  isDimmed:
                      _switchingId != null && _switchingId != account.userId,
                  onTap: () => _switchTo(account),
                  onForget: _switchingId == null
                      ? () => _confirmForget(account)
                      : null,
                ),
              ],
              if (_accounts.isEmpty && current != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Todavía no hay otras cuentas guardadas en este '
                  'dispositivo. Agrega una y podrás alternar con un toque.',
                  style: AppTextStyles.settingsSubtitle.copyWith(fontSize: 12),
                ),
              ],
              const SizedBox(height: 14),
              _AddAccountButton(
                onTap: _switchingId == null ? _addAccount : null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _roleLabel(UserRole role) => switch (role) {
    UserRole.turista => 'Turista',
    UserRole.emprendedor => 'Emprendedor',
    UserRole.admin => 'Equipo Níkara',
    UserRole.auditor => 'Auditor',
  };
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.title,
    required this.subtitle,
    required this.roleLabel,
    required this.initials,
    required this.isActive,
    required this.onTap,
    this.avatarUrl,
    this.isBusy = false,
    this.isDimmed = false,
    this.onForget,
  });

  final String title;
  final String subtitle;
  final String roleLabel;
  final String initials;
  final bool isActive;
  final VoidCallback onTap;
  final String? avatarUrl;
  final bool isBusy;
  final bool isDimmed;
  final VoidCallback? onForget;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isDimmed ? 0.45 : 1,
      child: Material(
        color: isActive ? AppColors.warmChipBackground : AppColors.surface100,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: isBusy || isDimmed ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isActive
                    ? AppColors.primary500
                    : AppColors.mapControlBorder,
                width: isActive ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                _Avatar(initials: initials, avatarUrl: avatarUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.settingsRowTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTextStyles.settingsSubtitle.copyWith(
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      _RolePill(label: roleLabel, isActive: isActive),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isBusy)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (isActive)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 22,
                    color: AppColors.statusSuccess,
                  )
                else if (onForget != null)
                  IconButton(
                    onPressed: onForget,
                    tooltip: 'Quitar cuenta',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.settingsTextMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.label, required this.isActive});

  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? AppColors.surface100 : AppColors.detailActivityIconBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isActive ? 'Cuenta activa · $label' : label,
        style: AppTextStyles.settingsRowCaption.copyWith(
          fontSize: 10.5,
          color: isActive ? AppColors.settingsTextDark : AppColors.ecoActive,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, this.avatarUrl});

  final String initials;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 44,
        height: 44,
        child: url == null || url.isEmpty
            ? Container(
                color: AppColors.primario1,
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: AppTextStyles.settingsRowTitle.copyWith(
                    fontSize: 15,
                    color: AppColors.primario7,
                  ),
                ),
              )
            : LocalImage(path: url, fallbackIcon: Icons.person_rounded),
      ),
    );
  }
}

class _AddAccountButton extends StatelessWidget {
  const _AddAccountButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
        label: const Text('Agregar otra cuenta'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.settingsTextDark,
          side: const BorderSide(color: AppColors.mapControlBorder),
          backgroundColor: AppColors.settingsBackground,
          textStyle: AppTextStyles.settingsRowTitle,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
