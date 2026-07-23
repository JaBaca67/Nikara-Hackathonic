import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_theme.dart';

class _NavItem {
  const _NavItem(this.icon, this.label);

  final IconData icon;
  final String label;
}

const List<_NavItem> _kNavItems = [
  _NavItem(Icons.home_rounded, 'Inicio'),
  _NavItem(Icons.map_rounded, 'Mapa'),
  _NavItem(Icons.calendar_month_rounded, 'Reservas'),
  _NavItem(Icons.person_rounded, 'Perfil'),
];

/// Fixed bottom navigation bar with 4 tabs. Fully controlled by the parent
/// (typically a `MainLayout` driving an `IndexedStack`) — this widget holds
/// no selection state of its own.
class BottomNavBarWidget extends StatelessWidget {
  const BottomNavBarWidget({
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
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface100,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              offset: Offset(0, 8),
              blurRadius: 24,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < _kNavItems.length; i++)
              _NavButton(
                item: _kNavItems[i],
                selected: i == currentIndex,
                onTap: () => onTap(i),
              ),
          ],
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
              Container(
                width: 40,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary500 : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  item.icon,
                  size: 18,
                  color: selected ? AppColors.neutral1100 : AppColors.neutral400,
                ),
              ),
              const SizedBox(height: 4),
              Text(item.label, style: AppTextStyles.navLabel.copyWith(color: tint)),
            ],
          ),
        ),
      ),
    );
  }
}
