import 'package:flutter/material.dart';
import 'package:nikara_app/core/services/user_session_service.dart';
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
      // Decide la pantalla inicial según si ya hay una sesión guardada
      // localmente (shared_preferences) o no.
      home: const _SessionGate(),
    );
  }
}

/// Checks [UserSessionService.isLoggedIn] once at app startup and routes to
/// [MainLayout] or [LoginScreen] accordingly. The check is a single local
/// SharedPreferences read, so the brand-colored placeholder is only visible
/// for a frame or two.
class _SessionGate extends StatefulWidget {
  const _SessionGate();

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  final _sessionService = UserSessionService();
  bool? _isLoggedIn;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final isLoggedIn = await _sessionService.isLoggedIn();
    if (!mounted) return;
    setState(() => _isLoggedIn = isLoggedIn);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn == null) {
      return const Scaffold(backgroundColor: AppColors.primary500);
    }
    return _isLoggedIn! ? const MainLayout() : const LoginScreen();
  }
}