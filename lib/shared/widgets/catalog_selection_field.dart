import 'package:flutter/material.dart';
import 'package:nikara_app/core/utils/search_normalize.dart';
// `app_theme.dart` reexporta `app_colors.dart` pero no `app_spacing.dart`,
// así que `AppRadius` necesita su propio import aunque `AppColors` no.
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// El campo es de solo lectura: el valor siempre procede del catálogo.
class CatalogSelectionField<T extends Object> extends StatelessWidget {
  const CatalogSelectionField({
    super.key,
    required this.label,
    required this.options,
    required this.displayString,
    required this.onChanged,
    this.value,
    this.subtitle,
    this.searchString,
    this.leading,
    this.enabled = true,
    this.requiredSelection = true,
  });
  final String label;
  final Iterable<T> options;
  final T? value;
  final String Function(T) displayString;
  final String Function(T)? subtitle;
  final String Function(T)? searchString;
  final Widget Function(T)? leading;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final bool requiredSelection;

  @override
  Widget build(BuildContext context) => FormField<T>(
    key: ValueKey(value),
    initialValue: value,
    validator: (_) => requiredSelection && value == null
        ? 'Selecciona una opción del catálogo.'
        : null,
    builder: (field) => InkWell(
      // InputDecorator también pinta la etiqueta y el texto de ayuda fuera
      // del área visual del campo; el selector completo debe responder al toque.
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: !enabled
          ? null
          : () async {
              final selected = await showModalBottomSheet<T>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                backgroundColor: AppColors.surface,
                builder: (context) => _CatalogSheet<T>(
                  label: label,
                  options: options.toList(),
                  displayString: displayString,
                  subtitle: subtitle,
                  searchString: searchString,
                  leading: leading,
                ),
              );
              if (selected != null) onChanged(selected);
            },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          enabled: enabled,
          errorText: field.errorText,
          suffixIcon: const Icon(Icons.arrow_drop_down),
          helperText: 'Selecciona de la lista; puedes buscar por nombre.',
          helperMaxLines: 2,
        ),
        child: Text(
          value == null ? 'Seleccionar' : displayString(value!),
          style: AppTextStyles.body.copyWith(color: AppColors.neutral800),
        ),
      ),
    ),
  );
}

class _CatalogSheet<T extends Object> extends StatefulWidget {
  const _CatalogSheet({
    required this.label,
    required this.options,
    required this.displayString,
    this.subtitle,
    this.searchString,
    this.leading,
  });
  final String label;
  final List<T> options;
  final String Function(T) displayString;
  final String Function(T)? subtitle;
  final String Function(T)? searchString;
  final Widget Function(T)? leading;
  @override
  State<_CatalogSheet<T>> createState() => _CatalogSheetState<T>();
}

class _CatalogSheetState<T extends Object> extends State<_CatalogSheet<T>> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final results = widget.options
        .where(
          (option) => normalizeForSearch(
            widget.searchString?.call(option) ?? widget.displayString(option),
          ).contains(normalizeForSearch(_query.trim())),
        )
        .toList();
    final query = normalizeForSearch(_query.trim());
    int rank(T option) {
      final label = normalizeForSearch(widget.displayString(option));
      if (label == query) return 0;
      if (label.startsWith(query)) return 1;
      if (label.contains(query)) return 2;
      return 3;
    }

    results.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0
          ? byRank
          : normalizeForSearch(
              widget.displayString(a),
            ).compareTo(normalizeForSearch(widget.displayString(b)));
    });
    return LayoutBuilder(
      builder: (context, constraints) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SizedBox(
            height:
                (constraints.maxHeight -
                        MediaQuery.viewInsetsOf(context).bottom -
                        48)
                    .clamp(0.0, 520.0)
                    .toDouble(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.label, style: AppTextStyles.sectionTitle),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Buscar en el catálogo',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: results.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay coincidencias. Prueba con otro nombre.',
                          ),
                        )
                      : ListView.builder(
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final option = results[index];
                            return ListTile(
                              leading: widget.leading?.call(option),
                              title: Text(
                                widget.displayString(option),
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.neutral1100,
                                ),
                              ),
                              subtitle: widget.subtitle == null
                                  ? null
                                  : Text(
                                      widget.subtitle!(option),
                                      style: AppTextStyles.body.copyWith(
                                        color: AppColors.neutral800,
                                        fontSize: 13,
                                      ),
                                    ),
                              onTap: () => Navigator.pop(context, option),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
