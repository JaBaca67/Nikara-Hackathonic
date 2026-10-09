import 'package:flutter/material.dart';

import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/utils/validators.dart';
import 'package:nikara_app/features/settings/data/settings_controller.dart';
import 'package:nikara_app/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:nikara_app/shared/widgets/account_switcher_sheet.dart';
import 'package:nikara_app/shared/widgets/app_snackbar.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Grupo "Cuenta": los datos de la persona y, aparte, el cambio de cuenta.
/// Editar perfil y cambiar contraseña son estado mock local — no se persiste
/// nada (ver [SettingsController]).
class SettingsAccountScreen extends StatefulWidget {
  const SettingsAccountScreen({super.key, required this.controller});

  final SettingsController controller;

  @override
  State<SettingsAccountScreen> createState() => _SettingsAccountScreenState();
}

class _SettingsAccountScreenState extends State<SettingsAccountScreen> {
  final _authService = AuthService();

  SettingsController get _controller => widget.controller;

  /// Cuentas guardadas además de la activa; alimenta el subtítulo de la fila
  /// "Cambiar de cuenta".
  int _otherAccountsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSavedAccounts();
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

  Future<void> _openEditProfile() async {
    final result = await showDialog<(String, String, String, String)>(
      context: context,
      builder: (_) => _EditProfileDialog(
        name: _controller.name,
        email: _controller.email,
        phone: _controller.phone,
        username: _controller.username,
      ),
    );
    if (result == null || !mounted) return;
    try {
      await _controller.updateProfile(
        name: result.$1,
        email: result.$2,
        phone: result.$3,
        username: result.$4,
      );
      if (mounted) AppSnackbar.showSuccess(context, 'Perfil actualizado');
    } on AuthServiceException catch (e) {
      if (mounted) AppSnackbar.showError(context, e.message);
    }
  }

  Future<void> _openChangePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (changed == true && mounted) {
      AppSnackbar.showSuccess(context, 'Contraseña actualizada');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => SettingsPage(
        title: 'Cuenta',
        subtitle: 'Tu perfil y tus sesiones',
        children: [
          SettingsSection(
            children: [
              SettingsRow(
                icon: Icons.alternate_email,
                title: 'Nombre de usuario',
                value: _controller.username,
                onTap: _openEditProfile,
              ),
              SettingsRow(
                icon: Icons.person_outline,
                title: 'Editar perfil',
                onTap: _openEditProfile,
              ),
              SettingsRow(
                icon: Icons.lock_outline,
                title: 'Cambiar contraseña',
                onTap: _openChangePassword,
              ),
              SettingsRow(
                icon: Icons.mail_outline,
                title: 'Correo electrónico',
                value: _controller.email,
                onTap: () => AppSnackbar.showInfo(context, 'Próximamente'),
              ),
              SettingsRow(
                icon: Icons.call_outlined,
                title: 'Teléfono',
                value: _controller.phone,
                onTap: () => AppSnackbar.showInfo(context, 'Próximamente'),
              ),
            ],
          ),
          SettingsSection(
            children: [
              SettingsRow(
                icon: Icons.switch_account_outlined,
                iconTint: AppColors.oliveText,
                title: 'Cambiar de cuenta',
                caption: _savedAccountsCaption,
                onTap: _openAccountSwitcher,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({
    required this.name,
    required this.email,
    required this.phone,
    required this.username,
  });

  final String name;
  final String email;
  final String phone;
  final String username;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.name);
  late final _emailController = TextEditingController(text: widget.email);
  late final _phoneController = TextEditingController(text: widget.phone);
  late final _usernameController = TextEditingController(text: widget.username);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop((
      _nameController.text.trim(),
      _emailController.text.trim(),
      _phoneController.text.trim(),
      _usernameController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: Text(
        'Editar perfil',
        style: AppTextStyles.settingsTitle.copyWith(fontSize: 18),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: validateFullName,
              ),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de usuario',
                ),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? null
                    : validateUsername(value),
              ),
              TextFormField(
                controller: _emailController,
                readOnly: true,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Correo'),
                validator: validateEmail,
              ),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Teléfono'),
                // Antes solo exigía que no estuviera vacío: un teléfono de 3
                // dígitos pasaba y quedaba guardado en el perfil.
                validator: (v) => validatePhone(v, required: false),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar', style: AppTextStyles.settingsRowValue),
        ),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.settingsAccent,
          ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  bool _saving = false;
  String? _error;
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AuthService().changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on AuthServiceException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: Text(
        'Cambiar contraseña',
        style: AppTextStyles.settingsTitle.copyWith(fontSize: 18),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            TextFormField(
              controller: _currentController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña actual'),
              validator: (v) => (v == null || v.isEmpty)
                  ? 'Ingresa tu contraseña actual'
                  : null,
            ),
            TextFormField(
              controller: _newController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nueva contraseña'),
              validator: validatePassword,
            ),
            TextFormField(
              controller: _confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmar contraseña',
              ),
              validator: (v) =>
                  validatePasswordConfirmation(v, _newController.text),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar', style: AppTextStyles.settingsRowValue),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.settingsAccent,
          ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
