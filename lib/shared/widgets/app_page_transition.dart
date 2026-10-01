import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_motion.dart';

/// Empuja [page] con una transición de Material Motion (shared axis
/// horizontal) en vez del slide plano por defecto de `MaterialPageRoute`.
///
/// Usa el paquete `animations` (oficial de Flutter, agnóstico de router) —
/// no depende de GoRouter, que este proyecto no usa. Primer uso real: Inicio
/// → detalle de negocio (ver "Movimiento Níkara — Fase 2"); el resto de las
/// navegaciones de la app quedan en `MaterialPageRoute` para una migración
/// progresiva futura.
Future<T?> pushSharedAxis<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      transitionDuration: AppMotion.largeDuration,
      reverseTransitionDuration: AppMotion.largeDuration,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: SharedAxisTransitionType.horizontal,
          child: child,
        );
      },
    ),
  );
}
