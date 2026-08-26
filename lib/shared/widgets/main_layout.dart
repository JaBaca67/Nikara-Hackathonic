import 'package:flutter/material.dart';

import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/services/permission_service.dart';
import 'package:nikara_app/features/admin/presentation/screens/admin_shell_screen.dart';
import 'package:nikara_app/features/eco/presentation/screens/eco_main_screen.dart';
import 'package:nikara_app/features/home/presentation/screens/home_screen.dart';
import 'package:nikara_app/features/home/presentation/widgets/main_navigation_bar.dart';
import 'package:nikara_app/features/map/presentation/screens/map_screen.dart';
import 'package:nikara_app/features/my_business/presentation/screens/my_business_screen.dart';
import 'package:nikara_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:nikara_app/features/routes/presentation/screens/routes_main_screen.dart';
import 'package:nikara_app/shared/services/main_tab_controller.dart';
import 'package:nikara_app/shared/services/map_focus_controller.dart';
import 'package:nikara_app/shared/widgets/guest_guard_bottom_sheet.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Shell de las tabs principales; [IndexedStack] mantiene vivo el
/// estado/scroll de cada una entre cambios de tab.
///
/// Son cinco para un turista y **seis** para quien tiene un rol con espacio
/// propio: admin y auditor suman "Panel" (el shell de moderación) y el
/// emprendedor suma "Negocio" (su dashboard). Es también la única entrada a
/// `AdminShellScreen`, que hasta ahora estaba construido pero no era alcanzable
/// desde ninguna pantalla de la app.
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
    _syncRole();
  }

  /// `PermissionService.load()` resuelve el rol contra `profiles` de forma
  /// asíncrona, así que en el primer build todavía puede decir `turista`. Sin
  /// este refresco la sexta tab no aparecería hasta que algo más reconstruyera
  /// la pantalla.
  Future<void> _syncRole() async {
    if (_isGuest) return;
    final before = _role;
    final after = await PermissionService().load();
    if (!mounted || before == after) return;
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.requestedTab.removeListener(_onTabRequested);
    super.dispose();
  }

  void _onTabRequested() {
    final index = _tabController.requestedTab.value;
    if (index == null) return;
    setState(() => _currentIndex = index);
    _tabController.requestedTab.value = null;
  }

  void _goToTab(int index) => setState(() => _currentIndex = index);

  bool get _isGuest => !AuthService().isLoggedIn;

  /// Un invitado nunca tiene rol con tab propia: sin sesión
  /// `PermissionService.currentRole` ya devuelve `turista`, pero se corta acá
  /// igual para no depender de ese detalle.
  UserRole get _role =>
      _isGuest ? UserRole.turista : PermissionService().currentRole;

  List<NavItem> get _navItems => navItemsForRole(_role);

  /// Perfil y Rutas necesitan el id de sesión, así que para un invitado se cambian por un placeholder (IndexedStack monta igual todos los hijos); ECO es visible para cualquiera, solo "Unirme" queda tras el guard.
  ///
  /// El orden y la cantidad tienen que coincidir con [_navItems]: los dos salen
  /// del mismo rol, así que la sexta pantalla se agrega bajo la misma condición
  /// que su tab.
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
    if (_role == UserRole.admin || _role == UserRole.auditor)
      // `onExit` devuelve a Inicio en vez de hacer `pop`: acá el panel es una
      // tab del shell, no una pantalla apilada, así que no hay a dónde volver.
      AdminShellScreen(onExit: () => _goToTab(0)),
    if (_role == UserRole.emprendedor) const MyBusinessScreen(),
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
      // Sin esto, las pantallas de atrás se detendrían antes del margen de la nav bar flotante, dejando ver el fondo del Scaffold.
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _tabs),
      // Oculta mientras el mapa sigue una ruta (Estado 19c); el mapa mismo cambia esta flag vía [MapFocusController].
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: MapFocusController().navigationActive,
        builder: (context, navigating, child) =>
            navigating ? const SizedBox.shrink() : child!,
        child: MainNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onNavTap,
          items: _navItems,
        ),
      ),
    );
  }
}

/// Placeholder para un invitado; `_onNavTap` intercepta el tap antes de mostrarlo, pero IndexedStack igual lo monta offstage, así que debe ser seguro sin usuario logueado.
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
