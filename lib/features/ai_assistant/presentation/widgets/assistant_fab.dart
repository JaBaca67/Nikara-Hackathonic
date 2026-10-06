import 'package:flutter/material.dart';

import 'package:nikara_app/features/ai_assistant/presentation/screens/assistant_screen.dart';
import 'package:nikara_app/features/ai_assistant/presentation/widgets/nikara_butterfly.dart';
import 'package:nikara_app/shared/widgets/app_page_transition.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Abre la pantalla del asistente.
///
/// Se expone como función además del botón para que otra pantalla pueda
/// lanzarlo desde otro gesto (un estado vacío, un enlace en un texto) sin
/// repetir la transición.
Future<void> openAssistant(BuildContext context, {String? city}) {
  return pushSharedAxis(context, AssistantScreen(city: city));
}

/// Botón flotante que abre el asistente. La mascota **es** el botón: una
/// mariposa que aletea invita a tocarla de un modo que un ícono genérico no.
class AssistantFab extends StatelessWidget {
  const AssistantFab({super.key, this.city});

  final String? city;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => openAssistant(context, city: city),
      // Fondo claro en vez de un Fill de marca: la mariposa ya trae los tres
      // colores del isotipo, y ponerla sobre un relleno saturado le quitaría
      // el contorno que la hace legible en tamaño chico.
      backgroundColor: AppColors.surface,
      elevation: 4,
      shape: const CircleBorder(),
      tooltip: 'Abrir Níkara IA',
      child: const Padding(
        padding: EdgeInsets.all(4),
        child: NikaraButterfly(size: 40),
      ),
    );
  }
}
