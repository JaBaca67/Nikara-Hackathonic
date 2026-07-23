import 'package:flutter/material.dart';

import 'package:nikara_app/features/bookings/presentation/screens/bookings_screen.dart';
import 'package:nikara_app/features/home/presentation/screens/home_screen.dart';
import 'package:nikara_app/features/home/presentation/widgets/bottom_nav_bar_widget.dart';
import 'package:nikara_app/features/map/presentation/screens/map_screen.dart';
import 'package:nikara_app/features/profile/presentation/screens/profile_screen.dart';

/// App shell for the 4 main tabs — Inicio(0), Mapa(1), Reservas(2),
/// Perfil(3). An [IndexedStack] keeps every tab's scroll position and
/// widget state alive across switches instead of rebuilding on each tap.
class MainLayout extends StatefulWidget {
  const MainLayout({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late int _currentIndex = widget.initialIndex;

  static const _tabs = [
    HomeScreen(),
    MapScreen(),
    BookingsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: BottomNavBarWidget(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
