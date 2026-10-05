import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_motion.dart';

/// Transiciones de pantalla de Níkara, en vez del slide plano por defecto de
/// `MaterialPageRoute`.
///
/// Usa el paquete `animations` (oficial de Flutter, agnóstico de router) — no
/// depende de GoRouter, que este proyecto no usa. Dos movimientos, elegidos
/// por lo que significa la navegación, no por gusto:
///
/// - **Shared axis horizontal** ([pushSharedAxis]) para entrar y salir de una
///   jerarquía: Inicio → detalle de negocio, Perfil → Ajustes, una lista →
///   su elemento. Las dos pantallas se desplazan juntas sobre el mismo eje,
///   que es lo que comunica "esto está dentro de aquello".
/// - **Fade through** ([pushFadeThroughAndRemoveUntil]) para cambios de raíz
///   sin relación jerárquica: iniciar sesión, cerrar sesión, cambiar de
///   cuenta, terminar el registro de un negocio. No hay un "atrás" al que
///   volver, así que deslizar mentiría sobre la estructura.
///
/// Todas respetan el ajuste de accesibilidad del sistema vía
/// [AppMotion.respect]: con "Eliminar animaciones" activo la duración es cero
/// y el cambio queda instantáneo, sin dejar de funcionar.

/// Ruta con shared axis horizontal, por si hay que empujarla desde un
/// `NavigatorState` suelto (ej. `rootNavigatorKey` en el servicio de push,
/// donde no hay un `context` de pantalla).
PageRoute<T> sharedAxisRoute<T>(BuildContext context, Widget page) {
  final duration = AppMotion.respect(context, AppMotion.largeDuration);
  return PageRouteBuilder<T>(
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        transitionType: SharedAxisTransitionType.horizontal,
        child: child,
      );
    },
  );
}

/// Empuja [page] entrando en la jerarquía (shared axis horizontal).
Future<T?> pushSharedAxis<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(sharedAxisRoute<T>(context, page));
}

/// Reemplaza la pantalla actual por [page] manteniendo el mismo movimiento.
/// Para continuaciones de flujo donde la pantalla saliente ya no tiene
/// sentido (el gate de identidad legal una vez verificada, por ejemplo).
Future<T?> pushSharedAxisReplacement<T, TO>(BuildContext context, Widget page) {
  return Navigator.of(
    context,
  ).pushReplacement<T, TO>(sharedAxisRoute<T>(context, page));
}

/// Cambia la raíz de la app a [page] con un fade through, descartando la pila.
/// Es el movimiento de login/logout/cambio de cuenta: no se "entra" a ningún
/// lado, se cambia de contexto entero.
Future<T?> pushFadeThroughAndRemoveUntil<T>(BuildContext context, Widget page) {
  final duration = AppMotion.respect(context, AppMotion.largeDuration);
  return Navigator.of(context).pushAndRemoveUntil<T>(
    PageRouteBuilder<T>(
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeThroughTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        );
      },
    ),
    (route) => false,
  );
}
