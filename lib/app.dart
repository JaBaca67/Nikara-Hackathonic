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
        nextPage: hasAccess ? const MainLayout() : const LoginScreen(),
      ),
    );
  }
}
