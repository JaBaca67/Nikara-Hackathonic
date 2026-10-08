import 'package:flutter/material.dart';

import 'package:nikara_app/features/settings/data/settings_controller.dart';
import 'package:nikara_app/features/settings/presentation/widgets/settings_widgets.dart';

/// Categoría "Privacidad". Los interruptores son estado local (ver [SettingsController]).
class SettingsPrivacyScreen extends StatelessWidget {
  const SettingsPrivacyScreen({super.key, required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => SettingsPage(
        title: 'Privacidad',
        subtitle: 'Controla qué compartes de tu perfil',
        children: [
          SettingsSection(
            children: [
              SettingsToggleRow(
                icon: Icons.person_outline,
                title: 'Perfil público',
                value: controller.publicProfile,
                onChanged: controller.setPublicProfile,
              ),
              SettingsToggleRow(
                icon: Icons.location_on_outlined,
                title: 'Compartir ubicación',
                value: controller.shareLocation,
                onChanged: controller.setShareLocation,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
