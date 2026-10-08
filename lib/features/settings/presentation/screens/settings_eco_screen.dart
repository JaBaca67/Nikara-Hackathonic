import 'package:flutter/material.dart';

import 'package:nikara_app/features/business/presentation/screens/legal_identity_gate_screen.dart';
import 'package:nikara_app/features/eco/presentation/screens/create_eco_activity_screen.dart';
import 'package:nikara_app/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:nikara_app/shared/widgets/app_page_transition.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Categoría "Comunidad ECO".
class SettingsEcoScreen extends StatelessWidget {
  const SettingsEcoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsPage(
      title: 'Comunidad ECO',
      subtitle: 'Actividades y fundaciones',
      children: [
        SettingsSection(
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
