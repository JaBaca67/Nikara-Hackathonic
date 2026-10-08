import 'package:flutter/material.dart';

import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/features/admin/presentation/screens/admin_shell_screen.dart';
import 'package:nikara_app/features/settings/data/settings_controller.dart';
import 'package:nikara_app/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:nikara_app/shared/widgets/app_page_transition.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Categoría "Equipo Níkara": el menú solo la ofrece a roles con acceso al panel.
class SettingsTeamScreen extends StatelessWidget {
  const SettingsTeamScreen({super.key, required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => SettingsPage(
        title: 'Equipo Níkara',
        subtitle: 'Herramientas para el equipo',
        children: [
          SettingsSection(
            children: [
              SettingsRow(
                icon: Icons.shield_outlined,
                iconTint: AppColors.oliveText,
                title: 'Panel de administración',
                caption: controller.role.permissionsSummary,
                onTap: () => pushSharedAxis(context, const AdminShellScreen()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
