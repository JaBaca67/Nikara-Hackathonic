import 'package:flutter/material.dart';

import 'package:nikara_app/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:nikara_app/shared/widgets/app_snackbar.dart';

/// Grupo "Ayuda y soporte".
class SettingsSupportScreen extends StatelessWidget {
  const SettingsSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsPage(
      title: 'Ayuda y soporte',
      subtitle: 'Ayuda e información de la app',
      children: [
        SettingsSection(
          children: [
            SettingsRow(
              icon: Icons.help_outline,
              title: 'Centro de ayuda',
              onTap: () => AppSnackbar.showInfo(context, 'Próximamente'),
            ),
            SettingsRow(
              icon: Icons.description_outlined,
              title: 'Términos y condiciones',
              onTap: () => AppSnackbar.showInfo(context, 'Próximamente'),
            ),
            SettingsRow(
              icon: Icons.info_outline,
              title: 'Acerca de Níkara',
              value: 'v1.0.0',
              onTap: () => AppSnackbar.showInfo(context, 'Próximamente'),
            ),
          ],
        ),
      ],
    );
  }
}
