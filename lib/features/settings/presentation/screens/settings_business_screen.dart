import 'package:flutter/material.dart';

import 'package:nikara_app/features/business/presentation/screens/legal_identity_gate_screen.dart';
import 'package:nikara_app/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Categoría "Para negocios turísticos".
class SettingsBusinessScreen extends StatelessWidget {
  const SettingsBusinessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsPage(
      title: 'Para negocios turísticos',
      subtitle: 'Llega a más viajeros',
      children: [
        SettingsSection(
          children: [
            SettingsRow(
              icon: Icons.storefront_outlined,
              iconTint: AppColors.oliveText,
              title: 'Registrar mi negocio',
              caption: 'Llega a más viajeros en Nicaragua',
              onTap: () => openBusinessRegistrationFlow(context),
            ),
          ],
        ),
      ],
    );
  }
}
