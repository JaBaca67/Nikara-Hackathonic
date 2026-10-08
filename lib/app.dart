import 'package:flutter/material.dart';

import 'package:nikara_app/core/navigation/root_navigator.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/services/guest_session_service.dart';
// ¡Esta es la ruta que conecta tu diseño de Figma con la app!
import 'package:nikara_app/features/auth/presentation/screens/login_screen.dart';
import 'package:nikara_app/shared/widgets/main_layout.dart';
import 'package:nikara_app/shared/widgets/splash_transition_screen.dart';
import 'package:nikara_app/theme/app_theme.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Supabase.initialize() (en main(), antes de runApp) ya restauró la sesión
    // real, así que no hace falta una compuerta async aquí — el Splash de
    // abajo es una pausa de marca, no una carga. El invitado nunca se
    // restaura: arranca en false, por eso un invitado reabre en Login.
    final hasAccess = AuthService().isLoggedIn || GuestSessionService().isGuest;
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'Níkara',
      debugShowCheckedModeBanner:
          false, // Esto quita la fea cinta roja de "DEBUG"
      theme: AppTheme.lightTheme,
      home: SplashTransitionScreen(
        showIsotipoOnly: true,
        // 2400ms: cubre el peor caso de arranque de la apertura del logo
        // (hasta 900ms, ver `_kOpeningLatest` en splash_transition_screen.dart)
        // más sus 1300ms de duración, con margen — si no, la navegación corta
        // la animación a mitad de camino.
        duration: const Duration(milliseconds: 2400),
        // Con sesión, el destino es Inicio (sin sheet de Auth al que subir):
        // el logo se queda centrado. Sin sesión, sube a su lugar en Login.
        ascendToAuth: !hasAccess,
        nextPage: hasAccess ? const MainLayout() : const LoginScreen(),
      ),
    );
  }
}
