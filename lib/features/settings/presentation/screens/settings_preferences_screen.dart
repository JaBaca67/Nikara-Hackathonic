import 'package:flutter/material.dart';

import 'package:nikara_app/features/settings/data/settings_controller.dart';
import 'package:nikara_app/features/settings/presentation/widgets/settings_widgets.dart';

/// Grupo "Preferencias": notificaciones y privacidad, con sus interruptores directamente. Son estado local (ver [SettingsController]).
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
          SettingsSection(
            label: 'Notificaciones',
            children: [
              SettingsToggleRow(
                icon: Icons.notifications_none,
                title: 'Novedades de viaje',
                value: controller.tripAlerts,
                onChanged: controller.setTripAlerts,
              ),
              SettingsToggleRow(
                icon: Icons.eco_outlined,
                title: 'Campañas ecológicas',
                value: controller.ecoCampaigns,
                onChanged: controller.setEcoCampaigns,
              ),
              SettingsToggleRow(
                icon: Icons.local_offer_outlined,
                title: 'Ofertas y promociones',
                value: controller.offers,
                onChanged: controller.setOffers,
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
