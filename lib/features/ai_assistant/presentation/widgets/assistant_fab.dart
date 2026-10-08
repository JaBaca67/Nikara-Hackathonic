import 'dart:async';

import 'package:flutter/material.dart';

import 'package:nikara_app/features/ai_assistant/presentation/screens/assistant_screen.dart';
import 'package:nikara_app/features/ai_assistant/presentation/widgets/nikara_butterfly.dart';
import 'package:nikara_app/shared/widgets/app_page_transition.dart';
import 'package:nikara_app/theme/app_motion.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Abre la pantalla del asistente.
///
/// Se expone como función además del botón para que otra pantalla pueda
/// lanzarlo desde otro gesto (un estado vacío, un enlace en un texto) sin
/// repetir la transición.
Future<void> openAssistant(BuildContext context, {String? city}) {
  return pushSharedAxis(context, AssistantScreen(city: city));
}

/// Botón flotante que abre el asistente. La mascota **es** el botón.
///
/// No usa el tooltip nativo de Material (solo aparece sosteniendo el dedo y
/// es fácil de no descubrir nunca). En su lugar el propio botón se ensancha
/// hacia la izquierda y revela "Abre Níkara IA" junto a la mariposa — al
/// sostenerlo, y también solo. Esto último (el ciclo automático en [_pulse])
/// es lo que hace de aviso: nadie
/// lo toca y el botón igual llama la atención de vez en cuando.
class AssistantFab extends StatefulWidget {
  const AssistantFab({super.key, this.city});

  final String? city;

  @override
  State<AssistantFab> createState() => _AssistantFabState();
}

class _AssistantFabState extends State<AssistantFab> {
  static const _attentionInterval = Duration(seconds: 15);
  static const _attentionHoldDuration = Duration(seconds: 2);

  bool _expanded = false;
  Timer? _cycleTimer;

  /// Último valor de "Eliminar animaciones" visto, para (re)armar o cortar
  /// el ciclo automático solo cuando el ajuste realmente cambia — no en
  /// cada rebuild.
  bool? _reducedMotion;

  /// El ciclo propio (`_pulse` llamándose a sí mismo) sí es una animación
  /// continua y autodisparada, así que se corta del todo con "Eliminar
  /// animaciones" — mismo criterio que la aurora y el Splash. El reveal por
  /// sostener (`_onLongPress`) es una respuesta a una acción del usuario, no
  /// algo que el botón hace solo, así que sigue disponible igual: con el
  /// ajuste activo [_AssistantRevealSize] cambia el tamaño directamente, por
  /// lo que el texto aparece de golpe en vez de animado.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = AppMotion.reduced(context);
    if (reduced == _reducedMotion) return;
    _reducedMotion = reduced;
    _cycleTimer?.cancel();
    if (reduced) {
      if (_expanded) setState(() => _expanded = false);
    } else {
      _cycleTimer = Timer(_attentionInterval, _pulse);
    }
  }

  void _pulse() {
    if (!mounted) return;
    setState(() => _expanded = true);
    _cycleTimer = Timer(_attentionHoldDuration, () {
      if (!mounted) return;
      setState(() => _expanded = false);
      _cycleTimer = Timer(_attentionInterval, _pulse);
    });
  }

  void _onLongPress() {
    _cycleTimer?.cancel();
    _pulse();
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: 'Abrir asistente Níkara IA',
      child: Material(
        // Fondo claro en vez de un Fill de marca: la mariposa ya trae los
        // tres colores del isotipo, y ponerla sobre un relleno saturado le
        // quitaría el contorno que la hace legible en tamaño chico.
        color: AppColors.surface,
        elevation: 4,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openAssistant(context, city: widget.city),
          onLongPress: _onLongPress,
          child: _AssistantRevealSize(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_expanded) ...[
                    Flexible(
                      child: Text(
                        'Abre Níkara IA',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.homeCardTitle.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  const NikaraButterfly(size: 40, animated: false),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantRevealSize extends StatelessWidget {
  const _AssistantRevealSize({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Con movimiento reducido el tamaño cambia directamente. AnimatedSize
    // con duración cero puede invalidar su propio layout al revelar el texto.
    if (AppMotion.reduced(context)) return child;
    return AnimatedSize(
      duration: AppMotion.largeDuration,
      curve: AppMotion.decelerate,
      alignment: Alignment.centerRight,
      child: child,
    );
  }
}
