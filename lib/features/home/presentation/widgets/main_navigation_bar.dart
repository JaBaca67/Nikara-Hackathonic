import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

class NavItem {
  const NavItem(
    this.icon,
    this.label, {
    this.activeColor = AppColors.primary500,
  });

  final IconData icon;
  final String label;

  /// Color de la píldora activa — dorado de marca en todas las tabs excepto ECO
  /// y las de rol, que usan el olivo ([AppColors.oliveText]).
  final Color activeColor;
}

/// Las cinco tabs de la barra — las mismas para cualquier persona, sin
/// importar el rol.
///
/// Hubo una sexta condicional por rol ("Panel" para admin/auditor,
/// "Negocio" para emprendedor). Se revirtió tras probarla en un teléfono
/// real: con seis slots en 384dp cada tab mide ~57dp y la barra se ve
/// sobrecargada. Esas dos experiencias viven ahora en el sistema de caras de
/// perfil y en una fila de Ajustes, no en la barra.
const List<NavItem> kBaseNavItems = [
  NavItem(Icons.home_rounded, 'Inicio'),
  NavItem(Icons.map_rounded, 'Mapa'),
  NavItem(Icons.eco_rounded, 'ECO', activeColor: AppColors.oliveText),
  NavItem(Icons.route_rounded, 'Rutas'),
  NavItem(Icons.person_rounded, 'Perfil'),
];

const _kPillSize = Size(40, 32);
const _kPillTopInset = 4.0;

/// Barra de navegación inferior flotante con una sola píldora que se desliza entre tabs. No mantiene estado de selección propio; lo controla el padre (`MainLayout`).
class MainNavigationBar extends StatelessWidget {
  const MainNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Siempre [kBaseNavItems]: la barra ya no se arma por rol, así que no hay
  /// una lista variable que pueda desalinearse con el `IndexedStack` de
  /// `MainLayout`.
  List<NavItem> get items => kBaseNavItems;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface100,
          borderRadius: BorderRadius.circular(35),
          border: Border.all(color: AppColors.mapControlBorder),
          boxShadow: const [
            BoxShadow(
              color: AppColors.border,
              offset: Offset(0, 8),
              blurRadius: 24,
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slotWidth = constraints.maxWidth / items.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeInOutCubic,
                  left:
                      slotWidth * currentIndex +
                      (slotWidth - _kPillSize.width) / 2,
                  top: _kPillTopInset,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: _kPillSize.width,
                    height: _kPillSize.height,
                    decoration: BoxDecoration(
                      color: items[currentIndex].activeColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      SizedBox(
                        width: slotWidth,
                        child: _NavButton(
                          item: items[i],
                          selected: i == currentIndex,
                          onTap: () => onTap(i),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = selected ? AppColors.textPrimary : AppColors.neutral700;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xs,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: _kPillSize.width,
                height: _kPillSize.height,
                child: Icon(
                  item.icon,
                  size: 18,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.neutral400,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.navLabel.copyWith(
                  color: tint,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
