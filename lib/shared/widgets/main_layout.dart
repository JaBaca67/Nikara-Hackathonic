import 'package:flutter/material.dart';

import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/features/home/presentation/screens/home_screen.dart';
import 'package:nikara_app/features/home/presentation/widgets/main_navigation_bar.dart';
import 'package:nikara_app/features/map/presentation/screens/map_screen.dart';
import 'package:nikara_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:nikara_app/shared/services/main_tab_controller.dart';
import 'package:nikara_app/shared/widgets/guest_guard_bottom_sheet.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// App shell for the 4 main tabs — Inicio(0), Mapa(1), Rutas(2, inert
/// placeholder — see [_RoutesComingSoonTab]), Perfil(3). An [IndexedStack]
/// keeps every tab's scroll position and widget state alive across
/// switches instead of rebuilding on each tap.
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

  /// Perfil (3) reads the signed-in user's id to fetch real data — for a
  /// guest that's null, so that slot is swapped for a lightweight locked
  /// placeholder instead of ever mounting the real screen (IndexedStack
  /// builds every child up front, visible or not). Rutas (2) has no real
  /// feature behind it yet — see [_RoutesComingSoonTab] — so it's never
  /// guest-gated; there's nothing there to protect.
  List<Widget> get _tabs => [
    const HomeScreen(),
    const MapScreen(),
    const _RoutesComingSoonTab(),
    _isGuest
        ? const _GuestLockedTab(feature: GuestFeature.perfil)
        : ProfileScreen(onExploreRequested: () => _goToTab(0)),
  ];

  void _onNavTap(int index) {
    if (_isGuest && index == 3) {
      GuestGuardBottomSheet.show(context, feature: GuestFeature.perfil);
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
      bottomNavigationBar: MainNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
    );
  }
}

/// Placeholder for the "Rutas" tab — the reservations feature it used to
/// hold was removed; a future map-based routes/itinerary system will take
/// this slot. Deliberately inert (no auth gate, no data) until that ships.
class _RoutesComingSoonTab extends StatelessWidget {
  const _RoutesComingSoonTab();

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
              const Icon(
                Icons.route_rounded,
                size: 40,
                color: AppColors.neutral600,
              ),
              const SizedBox(height: 12),
              Text(
                'Muy pronto',
                textAlign: TextAlign.center,
                style: AppTextStyles.sectionTitle,
              ),
              const SizedBox(height: 6),
              Text(
                'Rutas y planes por explorar en el mapa — estamos trabajando '
                'en ello.',
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
