import 'package:flutter/material.dart';

import 'package:nikara_app/core/services/auth_service.dart';
// ¡Esta es la ruta que conecta tu diseño de Figma con la app!
import 'package:nikara_app/features/auth/presentation/screens/login_screen.dart';
import 'package:nikara_app/shared/widgets/main_layout.dart';
import 'package:nikara_app/theme/app_theme.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nikara',
      debugShowCheckedModeBanner: false, // Esto quita la fea cinta roja de "DEBUG"
      theme: AppTheme.lightTheme,
      // Supabase.initialize() (called in main(), before runApp) already
      // restores any persisted session synchronously by the time this
      // builds, so there's no async gate needed anymore.
      home: AuthService().isLoggedIn ? const MainLayout() : const LoginScreen(),
    );
  }
}