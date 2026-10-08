import 'package:flutter/material.dart';

/// Duraciones y curvas de animación compartidas.
///
/// Mismo espíritu que [AppSpacing]/[AppRadius]: no sale de Figma, sale de la
/// tabla de referencia verificada en `flutter-animations.md`
/// (Naimehossein77/claude-flutter-ui-skills — solo se tomó el contenido de
/// animación de ese repo, no el skill completo, ver nota de decisión del
/// 2026-09-04). [largeDuration]/[quickDuration]/[emphasized] formalizan el
/// timing que ya traía la píldora de `MainNavigationBar` (320ms/220ms,
/// `Curves.easeInOutCubic`) antes de que existiera este archivo.
abstract class AppMotion {
  /// 150ms — micro-interacciones (tap feedback, ícono que cambia de estado).
  static const microDuration = Duration(milliseconds: 150);

  /// 200ms — cambios de color/tamaño acotados dentro de un mismo componente.
  static const quickDuration = Duration(milliseconds: 200);

  /// 250ms — transición estándar: entrada de una card, aparición de contenido.
  static const standardDuration = Duration(milliseconds: 250);

  /// 320ms — transición grande/con énfasis: cambio de tab, navegación entre
  /// pantallas.
  static const largeDuration = Duration(milliseconds: 320);

  /// Elementos que entran a la pantalla.
  static const enter = Curves.easeOut;

  /// Elementos que salen de la pantalla.
  static const exit = Curves.easeIn;

  /// Transición genérica sin dirección de entrada/salida marcada.
  static const standard = Curves.easeInOut;

  /// Transiciones grandes/con énfasis — misma curva que ya usaba la píldora
  /// de navegación.
  static const emphasized = Curves.easeInOutCubic;

  /// Elementos que se asientan en su posición final desacelerando: hojas
  /// inferiores, chips que crecen, movimientos de cámara del mapa. Se agregó
  /// al formalizar los 9 usos literales que ya existían en el código.
  static const decelerate = Curves.easeOutCubic;

  /// Rebote corto al final. **Solo para momentos de énfasis o celebración**
  /// (pantalla de éxito, logo del Splash, entrada del sheet de Auth) — en una
  /// micro-interacción común se lee como un error de timing, no como gracia.
  static const overshoot = Curves.easeOutBack;

  /// `true` si el sistema pidió eliminar animaciones (Android: Accesibilidad >
  /// Eliminar animaciones; iOS: Reduce Motion).
  ///
  /// Hay que consultarlo en `didChangeDependencies`/`build`, no en
  /// `initState`, para que el widget reaccione si el ajuste cambia mientras la
  /// pantalla está abierta.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duration], o cero si el sistema pidió eliminar animaciones.
  ///
  /// Cero no cancela la animación: la deja instantánea, así el estado final
  /// sigue siendo el mismo y no hace falta una rama de UI aparte.
  static Duration respect(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}
