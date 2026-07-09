import 'package:flutter/material.dart';
// ¡Esta es la ruta que conecta tu diseño de Figma con la app!
import 'package:nikara_app/features/auth/presentation/screens/login_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nikara',
      debugShowCheckedModeBanner: false, // Esto quita la fea cinta roja de "DEBUG"
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFF9F0),
      ),
      // AQUÍ ESTÁ LA MAGIA: Le decimos que arranque directamente en el Login
      home: const LoginScreen(), 
    );
  }
}