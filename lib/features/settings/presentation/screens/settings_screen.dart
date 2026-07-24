import 'package:flutter/material.dart';

import 'package:nikara_app/core/services/user_session_service.dart';
import 'package:nikara_app/features/auth/presentation/screens/login_screen.dart';
import 'package:nikara_app/features/business/presentation/screens/register_business_wizard.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Ajustes screen (Figma node 361:323). Notification/privacy toggles and
/// the account edit / password change flows are local mock state — nothing
/// is persisted beyond this screen's lifetime.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _sessionService = UserSessionService();

  String _name = 'Ixchel Galo';
  String _email = 'sofia@email.com';
  String _phone = '+505 8823 4490';

  bool _bookingAlerts = true;
  bool _ecoCampaigns = true;
  bool _offers = false;
  bool _publicProfile = true;
  bool _shareLocation = false;

  Future<void> _openEditProfile() async {
    final result = await showDialog<(String, String, String)>(
      context: context,
      builder: (_) => _EditProfileDialog(
        name: _name,
        email: _email,
        phone: _phone,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _name = result.$1;
      _email = result.$2;
      _phone = result.$3;
    });
    _showSnack('Perfil actualizado');
  }

  Future<void> _openChangePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (changed == true && mounted) _showSnack('Contraseña actualizada');
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface100,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text('Cerrar sesión', style: AppTextStyles.settingsTitle.copyWith(fontSize: 18)),
        content: Text(
          '¿Seguro que quieres cerrar tu sesión de Nikara?',
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
              'Cerrar sesión',
              style: AppTextStyles.settingsRowTitle.copyWith(
                color: AppColors.settingsDanger,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _sessionService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.settingsBackground,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SettingsHeader(onBack: () => Navigator.of(context).maybePop()),
              const SizedBox(height: 20),
              _SettingsSection(
                label: 'Mi cuenta',
                children: [
                  _SettingsRow(
                    icon: Icons.person_outline,
                    title: 'Editar perfil',
                    onTap: _openEditProfile,
                  ),
                  _SettingsRow(
                    icon: Icons.lock_outline,
                    title: 'Cambiar contraseña',
                    onTap: _openChangePassword,
                  ),
                  _SettingsRow(
                    icon: Icons.mail_outline,
                    title: 'Correo electrónico',
                    value: _email,
                    onTap: () => _showSnack('Próximamente'),
                  ),
                  _SettingsRow(
                    icon: Icons.call_outlined,
                    title: 'Teléfono',
                    value: _phone,
                    onTap: () => _showSnack('Próximamente'),
                  ),
                ],
              ),
              _SettingsSection(
                label: 'Notificaciones',
                children: [
                  _SettingsToggleRow(
                    icon: Icons.notifications_none,
                    title: 'Reservas y confirmaciones',
                    value: _bookingAlerts,
                    onChanged: (v) => setState(() => _bookingAlerts = v),
                  ),
                  _SettingsToggleRow(
                    icon: Icons.eco_outlined,
                    title: 'Campañas ecológicas',
                    value: _ecoCampaigns,
                    onChanged: (v) => setState(() => _ecoCampaigns = v),
                  ),
                  _SettingsToggleRow(
                    icon: Icons.local_offer_outlined,
                    title: 'Ofertas y promociones',
                    value: _offers,
                    onChanged: (v) => setState(() => _offers = v),
                  ),
                ],
              ),
              _SettingsSection(
                label: 'Privacidad',
                children: [
                  _SettingsToggleRow(
                    icon: Icons.person_outline,
                    title: 'Perfil público',
                    value: _publicProfile,
                    onChanged: (v) => setState(() => _publicProfile = v),
                  ),
                  _SettingsToggleRow(
                    icon: Icons.location_on_outlined,
                    title: 'Compartir ubicación',
                    value: _shareLocation,
                    onChanged: (v) => setState(() => _shareLocation = v),
                  ),
                ],
              ),
              _SettingsSection(
                label: 'Para negocios turísticos',
                children: [
                  _SettingsRow(
                    icon: Icons.storefront_outlined,
                    iconTint: AppColors.accent300,
                    title: 'Registrar mi negocio',
                    caption: 'Llega a más viajeros en Nicaragua',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RegisterBusinessWizard(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              _SettingsSection(
                label: 'Soporte',
                children: [
                  _SettingsRow(
                    icon: Icons.help_outline,
                    title: 'Centro de ayuda',
                    onTap: () => _showSnack('Próximamente'),
                  ),
                  _SettingsRow(
                    icon: Icons.description_outlined,
                    title: 'Términos y condiciones',
                    onTap: () => _showSnack('Próximamente'),
                  ),
                  _SettingsRow(
                    icon: Icons.info_outline,
                    title: 'Acerca de Nikara',
                    value: 'v1.0.0',
                    onTap: () => _showSnack('Próximamente'),
                  ),
                ],
              ),
              _SettingsSection(
                label: 'Sesión',
                children: [
                  _SettingsRow(
                    icon: Icons.logout,
                    iconTint: AppColors.settingsDanger,
                    titleColor: AppColors.settingsDanger,
                    title: 'Cerrar sesión',
                    onTap: _confirmLogout,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface100,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFF2EBE0),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                size: 18,
                color: AppColors.settingsTextDark,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ajustes', style: AppTextStyles.settingsTitle),
              Text('Cuenta y preferencias', style: AppTextStyles.settingsSubtitle),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(label.toUpperCase(), style: AppTextStyles.settingsSectionLabel),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14F0B500),
                    offset: Offset(0, 2),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  for (var i = 0; i < children.length; i++)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: i == children.length - 1
                            ? null
                            : const Border(
                                bottom: BorderSide(
                                  color: Color(0x1AF0B500),
                                  width: 0.8,
                                ),
                              ),
                      ),
                      child: children[i],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.value,
    this.caption,
    this.iconTint = AppColors.settingsAccent,
    this.titleColor = AppColors.settingsTextDark,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? value;
  final String? caption;
  final Color iconTint;
  final Color titleColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconTint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: iconTint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.settingsRowTitle.copyWith(color: titleColor),
                  ),
                  if (caption != null)
                    Text(caption!, style: AppTextStyles.settingsRowCaption),
                ],
              ),
            ),
            if (value != null) ...[
              Text(value!, style: AppTextStyles.settingsRowValue),
              const SizedBox(width: 8),
            ],
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: AppColors.settingsTextMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.settingsAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: AppColors.settingsAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: AppTextStyles.settingsRowTitle),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.settingsAccent,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: AppColors.settingsToggleOff,
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

  static final _emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[A-Za-z]{2,}$');

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Editar perfil', style: AppTextStyles.settingsTitle.copyWith(fontSize: 18)),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
            ),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Correo'),
              validator: (v) {
                final trimmed = v?.trim() ?? '';
                if (trimmed.isEmpty) return 'Ingresa un correo';
                if (!_emailRegex.hasMatch(trimmed)) return 'Correo no válido';
                return null;
              },
            ),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingresa tu teléfono' : null,
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
          style: FilledButton.styleFrom(backgroundColor: AppColors.settingsAccent),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Ingresa tu contraseña actual' : null,
            ),
            TextFormField(
              controller: _newController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nueva contraseña'),
              validator: (v) => (v == null || v.length < 6)
                  ? 'Mínimo 6 caracteres'
                  : null,
            ),
            TextFormField(
              controller: _confirmController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirmar contraseña'),
              validator: (v) =>
                  v != _newController.text ? 'Las contraseñas no coinciden' : null,
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
          style: FilledButton.styleFrom(backgroundColor: AppColors.settingsAccent),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
