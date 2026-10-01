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
import 'package:nikara_app/shared/widgets/keep_alive_tab.dart';
import 'package:nikara_app/theme/app_motion.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Shell de las tabs principales; un `PageView` permite deslizar entre tabs
/// además de tocar la barra, y [KeepAliveTab] mantiene vivo el estado/scroll
/// de cada una entre cambios de tab — mismo comportamiento que daba gratis el
/// `IndexedStack` que este widget reemplazó (ver "Movimiento Níkara — Fase 2").
///
/// El swipe se desactiva mientras la tab activa es Mapa: `GoogleMap` es una
/// vista de plataforma nativa que consume el gesto de pan por completo, así
/// que un `PageView` de Flutter no puede competir por él sin configuración
/// especial — no es algo que valga la pena pelear, tocar la barra sigue
/// funcionando para entrar/salir de Mapa.
///
/// Son **cinco siempre**, sin importar el rol. Hubo una sexta tab condicional
/// ("Panel" para admin/auditor, "Negocio" para emprendedor) y se revirtió: en
/// un teléfono real seis slots dejan cada tab en ~57dp y la barra se ve
/// sobrecargada. La experiencia del emprendedor pasó al sistema de caras de
/// perfil y la del admin a una fila de Ajustes.
class MainLayout extends StatefulWidget {
  const MainLayout({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  static const _mapTabIndex = 1;

  late int _currentIndex = widget.initialIndex;
  late final _pageController = PageController(initialPage: widget.initialIndex);
  final _tabController = MainTabController();

  @override
  void initState() {
    super.initState();
    _tabController.requestedTab.addListener(_onTabRequested);
  }

  @override
  void dispose() {
    _tabController.requestedTab.removeListener(_onTabRequested);
    _pageController.dispose();
    super.dispose();
  }

  void _onTabRequested() {
    final index = _tabController.requestedTab.value;
    if (index == null) return;
    _animateToPage(index);
    _tabController.requestedTab.value = null;
  }

  void _goToTab(int index) => _animateToPage(index);

  /// Mueve la píldora y el `PageView` juntos, con el mismo timing —
  /// llamado tanto por un tap en la barra como por un pedido externo vía
  /// [MainTabController].
  void _animateToPage(int index) {
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: AppMotion.largeDuration,
      curve: AppMotion.emphasized,
    );
  }

  bool get _isGuest => !AuthService().isLoggedIn;

  /// Perfil y Rutas necesitan el id de sesión, así que para un invitado se cambian por un placeholder ([KeepAliveTab] monta igual todos los hijos); ECO es visible para cualquiera, solo "Unirme" queda tras el guard.
  ///
  /// El orden y la cantidad tienen que coincidir con [kBaseNavItems].
  List<Widget> get _tabs => [
    const KeepAliveTab(child: HomeScreen()),
    const KeepAliveTab(child: MapScreen()),
    const KeepAliveTab(child: EcoMainScreen()),
    KeepAliveTab(
      child: _isGuest
          ? const _GuestLockedTab(feature: GuestFeature.rutas)
          : const RoutesMainScreen(),
    ),
    KeepAliveTab(
      child: _isGuest
          ? const _GuestLockedTab(feature: GuestFeature.perfil)
          : ProfileScreen(onExploreRequested: () => _goToTab(0)),
    ),
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
    _animateToPage(index);
  }

  /// Réplica del guard de [_onNavTap] para cuando el cambio de tab llega por
  /// swipe en vez de tap: un arrastre no se puede interceptar a mitad de
  /// camino, así que se deja asentar y, si aterrizó en una tab gateada para
  /// un invitado, se anima de vuelta y se muestra el mismo bottom sheet.
  void _onPageChanged(int index) {
    final gated = _guestGatedTabs[index];
    if (_isGuest && gated != null) {
      final previousIndex = _currentIndex;
      GuestGuardBottomSheet.show(context, feature: gated);
      _pageController.animateToPage(
        previousIndex,
        duration: AppMotion.largeDuration,
        curve: AppMotion.emphasized,
      );
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Sin esto, las pantallas de atrás se detendrían antes del margen de la nav bar flotante, dejando ver el fondo del Scaffold.
      extendBody: true,
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        // Ver doc de la clase: Mapa consume el pan gesture por completo.
        physics: _currentIndex == _mapTabIndex
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics(),
        children: _tabs,
      ),
      // Oculta mientras el mapa sigue una ruta (Estado 19c); el mapa mismo cambia esta flag vía [MapFocusController].
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: MapFocusController().navigationActive,
        builder: (context, navigating, child) =>
            navigating ? const SizedBox.shrink() : child!,
        child: MainNavigationBar(currentIndex: _currentIndex, onTap: _onNavTap),
      ),
    );
  }
}

/// Placeholder para un invitado; `_onNavTap` intercepta el tap antes de mostrarlo, pero `KeepAliveTab` igual lo monta offstage, así que debe ser seguro sin usuario logueado.
class _GuestLockedTab extends StatelessWidget {
  const _GuestLockedTab({required this.feature});

  final GuestFeature feature;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
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
