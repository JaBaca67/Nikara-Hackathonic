import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_theme.dart';

class _NavItem {
  const _NavItem(
    this.icon,
    this.label, {
    this.activeColor = AppColors.primary500,
  });

  final IconData icon;
  final String label;

  /// Color de la píldora activa — dorado de marca en todas las tabs excepto ECO, que usa su propio olivo ([AppColors.ecoActive]).
  final Color activeColor;
}

const List<_NavItem> _kNavItems = [
  _NavItem(Icons.home_rounded, 'Inicio'),
  _NavItem(Icons.map_rounded, 'Mapa'),
  _NavItem(Icons.eco_rounded, 'ECO', activeColor: AppColors.ecoActive),
  _NavItem(Icons.route_rounded, 'Rutas'),
  _NavItem(Icons.person_rounded, 'Perfil'),
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
              color: AppColors.cardBorder,
              offset: Offset(0, 8),
              blurRadius: 24,
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slotWidth = constraints.maxWidth / _kNavItems.length;
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
                      color: _kNavItems[currentIndex].activeColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < _kNavItems.length; i++)
                      SizedBox(
                        width: slotWidth,
                        child: _NavButton(
                          item: _kNavItems[i],
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

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = selected ? AppColors.neutral1100 : AppColors.neutral700;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
                      ? AppColors.neutral1100
                      : AppColors.neutral400,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
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
