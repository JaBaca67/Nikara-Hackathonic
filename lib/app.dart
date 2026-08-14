import 'package:flutter/material.dart';

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
    // Supabase.initialize() and GuestSessionService().load() (both called
    // in main(), before runApp) already restore any persisted real session
    // or guest state synchronously by the time this builds, so there's no
    // async gate needed here — the branded Splash below is a real branded
    // pause, not a loading gate for that state.
    final hasAccess = AuthService().isLoggedIn || GuestSessionService().isGuest;
    return MaterialApp(
      title: 'Níkara',
      debugShowCheckedModeBanner:
          false, // Esto quita la fea cinta roja de "DEBUG"
      theme: AppTheme.lightTheme,
      home: SplashTransitionScreen(
        nextPage: hasAccess ? const MainLayout() : const LoginScreen(),
      ),
    );
  }
}
