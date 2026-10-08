import 'package:flutter/material.dart';

import 'package:nikara_app/features/business/presentation/screens/legal_identity_gate_screen.dart';
import 'package:nikara_app/features/eco/presentation/screens/create_eco_activity_screen.dart';
import 'package:nikara_app/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:nikara_app/shared/widgets/app_page_transition.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Grupo "Comunidad": registro de negocios turísticos y herramientas ECO.
class SettingsCommunityScreen extends StatelessWidget {
  const SettingsCommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsPage(
      title: 'Comunidad',
      subtitle: 'Negocios, actividades y fundaciones',
      children: [
        SettingsSection(
          label: 'Para negocios turísticos',
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
        SettingsSection(
          label: 'Comunidad ECO',
          children: [
            SettingsRow(
              icon: Icons.eco_outlined,
              iconTint: AppColors.oliveText,
              title: 'Registrar actividad ECO',
              caption: 'Organiza una jornada ambiental',
              onTap: () =>
                  pushSharedAxis(context, const CreateEcoActivityScreen()),
            ),
            SettingsRow(
              icon: Icons.groups_outlined,
              iconTint: AppColors.oliveText,
              title: 'Registrar / Gestionar Fundación',
              caption: 'Publica jornadas a nombre de tu organización',
              onTap: () => openOrganizationRegistrationFlow(context),
            ),
          ],
        ),
      ],
    );
  }
}
