import 'package:flutter/material.dart';

import 'package:nikara_app/features/settings/data/settings_controller.dart';
import 'package:nikara_app/features/settings/presentation/widgets/settings_widgets.dart';

/// Categoría "Notificaciones". Los interruptores son estado local (ver [SettingsController]).
class SettingsNotificationsScreen extends StatelessWidget {
  const SettingsNotificationsScreen({super.key, required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => SettingsPage(
        title: 'Notificaciones',
        subtitle: 'Elige qué avisos quieres recibir',
        children: [
          SettingsSection(
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
        ],
      ),
    );
  }
}
