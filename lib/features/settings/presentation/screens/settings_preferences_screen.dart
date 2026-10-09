import 'package:flutter/material.dart';

import 'package:nikara_app/features/settings/data/settings_controller.dart';
import 'package:nikara_app/features/settings/presentation/widgets/settings_widgets.dart';

/// Preferencias persistidas en Supabase con errores de guardado visibles.
class SettingsPreferencesScreen extends StatelessWidget {
  const SettingsPreferencesScreen({super.key, required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => SettingsPage(
        title: 'Preferencias',
        subtitle: 'Avisos y privacidad',
        children: [
          if (controller.error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(controller.error!),
            ),
          SettingsSection(
            label: 'Notificaciones',
            children: [
              SettingsToggleRow(
                icon: Icons.notifications_none,
                title: 'Novedades de viaje',
                value: controller.tripAlerts,
                onChanged: controller.saving ? null : controller.setTripAlerts,
              ),
              SettingsToggleRow(
                icon: Icons.eco_outlined,
                title: 'Campañas ecológicas',
                value: controller.ecoCampaigns,
                onChanged: controller.saving
                    ? null
                    : controller.setEcoCampaigns,
              ),
              SettingsToggleRow(
                icon: Icons.local_offer_outlined,
                title: 'Ofertas y promociones',
                value: controller.offers,
                onChanged: controller.saving ? null : controller.setOffers,
              ),
            ],
          ),
          SettingsSection(
            label: 'Privacidad',
            children: [
              SettingsToggleRow(
                icon: Icons.person_outline,
                title: 'Perfil público',
                value: controller.publicProfile,
                onChanged: controller.saving
                    ? null
                    : controller.setPublicProfile,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
