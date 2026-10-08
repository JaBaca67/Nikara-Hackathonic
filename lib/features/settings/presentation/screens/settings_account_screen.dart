import 'package:flutter/material.dart';

import 'package:nikara_app/core/utils/validators.dart';
import 'package:nikara_app/features/settings/data/settings_controller.dart';
import 'package:nikara_app/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:nikara_app/shared/widgets/app_snackbar.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Categoría "Mi cuenta". Editar perfil y cambiar contraseña son estado mock
/// local — no se persiste nada (ver [SettingsController]).
class SettingsAccountScreen extends StatelessWidget {
  const SettingsAccountScreen({super.key, required this.controller});

  final SettingsController controller;

  Future<void> _openEditProfile(BuildContext context) async {
    final result = await showDialog<(String, String, String)>(
      context: context,
      builder: (_) => _EditProfileDialog(
        name: controller.name,
        email: controller.email,
        phone: controller.phone,
      ),
    );
    if (result == null || !context.mounted) return;
    controller.updateProfile(
      name: result.$1,
      email: result.$2,
      phone: result.$3,
    );
    AppSnackbar.showSuccess(context, 'Perfil actualizado');
  }

  Future<void> _openChangePassword(BuildContext context) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (changed == true && context.mounted) {
      AppSnackbar.showSuccess(context, 'Contraseña actualizada');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => SettingsPage(
        title: 'Mi cuenta',
        subtitle: 'Tu perfil y datos de contacto',
        children: [
          SettingsSection(
            children: [
              SettingsRow(
                icon: Icons.person_outline,
                title: 'Editar perfil',
                onTap: () => _openEditProfile(context),
              ),
              SettingsRow(
                icon: Icons.lock_outline,
                title: 'Cambiar contraseña',
                onTap: () => _openChangePassword(context),
              ),
              SettingsRow(
                icon: Icons.mail_outline,
                title: 'Correo electrónico',
                value: controller.email,
                onTap: () => AppSnackbar.showInfo(context, 'Próximamente'),
              ),
              SettingsRow(
                icon: Icons.call_outlined,
                title: 'Teléfono',
                value: controller.phone,
                onTap: () => AppSnackbar.showInfo(context, 'Próximamente'),
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
  });

  final String name;
  final String email;
  final String phone;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.name);
  late final _emailController = TextEditingController(text: widget.email);
  late final _phoneController = TextEditingController(text: widget.phone);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop((
      _nameController.text.trim(),
      _emailController.text.trim(),
      _phoneController.text.trim(),
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
      content: Form(
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
              controller: _emailController,
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
              validator: validatePhone,
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

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(true);
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
