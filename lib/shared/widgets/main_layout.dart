import 'package:flutter/material.dart';

import 'package:nikara_app/features/bookings/presentation/screens/bookings_screen.dart';
import 'package:nikara_app/features/home/presentation/screens/home_screen.dart';
import 'package:nikara_app/features/home/presentation/widgets/bottom_nav_bar_widget.dart';
import 'package:nikara_app/features/map/presentation/screens/map_screen.dart';
import 'package:nikara_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:nikara_app/shared/services/main_tab_controller.dart';

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
  final _tabController = MainTabController();

  @override
  void initState() {
    super.initState();
    _tabController.requestedTab.addListener(_onTabRequested);
  }

  @override
  void dispose() {
    _tabController.requestedTab.removeListener(_onTabRequested);
    super.dispose();
  }

  /// Consumes a pending cross-route tab switch request — e.g. from
  /// [BusinessDetailScreen] right after creating a booking.
  void _onTabRequested() {
    final index = _tabController.requestedTab.value;
    if (index == null) return;
    setState(() => _currentIndex = index);
    _tabController.requestedTab.value = null;
  }

  void _goToTab(int index) => setState(() => _currentIndex = index);

  List<Widget> get _tabs => [
    const HomeScreen(),
    const MapScreen(),
    BookingsScreen(onExploreMapRequested: () => _goToTab(1)),
    ProfileScreen(onExploreRequested: () => _goToTab(0)),
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
