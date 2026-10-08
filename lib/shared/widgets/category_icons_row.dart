import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

class CategoryIconsRow extends StatelessWidget {
  const CategoryIconsRow({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelect,
    required this.iconBuilder,
    this.labelBuilder,
    this.allLabel = 'Todos',
    this.iconColor,
  });

  final List<String> categories;
  final IconData Function(String) iconBuilder;
  final String Function(String)? labelBuilder;
  final String allLabel;
  final Color? iconColor;

  /// null es "Todos".
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    // Con una sola categoría el filtro no filtra nada.
    if (categories.length <= 1) return const SizedBox.shrink();

    return SizedBox(
      height: 46 + MediaQuery.textScalerOf(context).scale(10),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: AppSpacing.md),
        physics: const BouncingScrollPhysics(),
        // +1 por "Todos", que no es una categoría sino la ausencia de filtro.
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _CategoryIcon(
              icon: Icons.grid_view_rounded,
              label: allLabel,
              iconColor: iconColor,
              isSelected: selected == null,
              onTap: () => onSelect(null),
            );
          }
          final category = categories[index - 1];
          return Tooltip(
            message: category,
            child: _CategoryIcon(
              icon: iconBuilder(category),
              label: labelBuilder?.call(category) ?? category,
              iconColor: iconColor,
              isSelected: selected == category,
              onTap: () => onSelect(category),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Filtrar por $label',
      child: Center(
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            // `maxWidth` es el techo que impide que una etiqueta larga
            // convierta un chip en media fila: el catálogo de categorías ya
            // usa nombres de una palabra, pero el widget es compartido y no
            // puede confiar en que el siguiente lo sea.
            constraints: const BoxConstraints(
              minWidth: 48,
              maxWidth: 96,
              minHeight: 48,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 24,
                    color:
                        iconColor ??
                        (isSelected
                            ? AppColors.settingsTextDark
                            : AppColors.settingsTextMuted),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.homeChipLabel.copyWith(
                      color: isSelected
                          ? AppColors.settingsTextDark
                          : AppColors.settingsTextMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
