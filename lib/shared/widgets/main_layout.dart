import 'package:flutter/material.dart';

import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/features/eco/presentation/screens/eco_main_screen.dart';
import 'package:nikara_app/features/home/presentation/screens/home_screen.dart';
import 'package:nikara_app/features/home/presentation/widgets/main_navigation_bar.dart';
import 'package:nikara_app/features/map/presentation/screens/map_screen.dart';
import 'package:nikara_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:nikara_app/features/routes/presentation/screens/routes_main_screen.dart';
import 'package:nikara_app/shared/services/main_tab_controller.dart';
import 'package:nikara_app/shared/services/map_focus_controller.dart';
import 'package:nikara_app/shared/widgets/guest_guard_bottom_sheet.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// App shell for the 5 main tabs — Inicio(0), Mapa(1), ECO(2), Rutas(3),
/// Perfil(4). An [IndexedStack] keeps every tab's scroll position and
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

  /// Consumes a pending cross-route tab switch request.
  void _onTabRequested() {
    final index = _tabController.requestedTab.value;
    if (index == null) return;
    setState(() => _currentIndex = index);
    _tabController.requestedTab.value = null;
  }

  void _goToTab(int index) => setState(() => _currentIndex = index);

  bool get _isGuest => !AuthService().isLoggedIn;

  /// Perfil (4) y Rutas (3) leen el id de la sesión para traer datos reales
  /// — para un invitado eso es null, así que esos dos slots se cambian por
  /// un placeholder bloqueado en vez de montar la pantalla real (IndexedStack
  /// construye todos sus hijos, se vean o no). ECO (2) sí lo puede ver
  /// cualquiera: solo la acción "Unirme" está detrás del guard, dentro de
  /// EcoMainScreen/EcoDetailScreen (mismo patrón que marcar un favorito).
  List<Widget> get _tabs => [
    const HomeScreen(),
    const MapScreen(),
    const EcoMainScreen(),
    _isGuest
        ? const _GuestLockedTab(feature: GuestFeature.rutas)
        : const RoutesMainScreen(),
    _isGuest
        ? const _GuestLockedTab(feature: GuestFeature.perfil)
        : ProfileScreen(onExploreRequested: () => _goToTab(0)),
  ];

  static const _guestGatedTabs = {
    3: GuestFeature.rutas,
    4: GuestFeature.perfil,
  };

  void _onNavTap(int index) {
    final gated = _guestGatedTabs[index];
    if (_isGuest && gated != null) {
      GuestGuardBottomSheet.show(context, feature: gated);
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The floating nav bar has margin on every side, so without this the
      // screens behind it would be sized to stop short of it, leaving a
      // solid Scaffold-background rectangle showing through the margin
      // instead of the screen's own content/background.
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _tabs),
      // Hidden while the map is following a route (Estado 19c) so its
      // floating navigation panel owns the bottom of the screen — the map
      // flips that flag itself via [MapFocusController].
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: MapFocusController().navigationActive,
        builder: (context, navigating, child) =>
            navigating ? const SizedBox.shrink() : child!,
        child: MainNavigationBar(currentIndex: _currentIndex, onTap: _onNavTap),
      ),
    );
  }
}

/// Shown in place of ProfileScreen for a guest — in practice
/// [_MainLayoutState._onNavTap] intercepts the tap before this is ever
/// visible, but IndexedStack still builds it offstage, so it has to be
/// safe (and cheap) to mount without a signed-in user.
class _GuestLockedTab extends StatelessWidget {
  const _GuestLockedTab({required this.feature});

  final GuestFeature feature;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(feature.icon, size: 40, color: AppColors.neutral600),
              const SizedBox(height: 12),
              Text(
                'Crea tu cuenta para ver ${feature.label}',
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
