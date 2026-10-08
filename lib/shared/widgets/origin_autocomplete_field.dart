import 'package:flutter/material.dart';
import 'package:nikara_app/core/utils/search_normalize.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// El texto sirve para buscar; solo una opción elegida es un valor del Form.
class OriginAutocompleteField<T extends Object> extends StatefulWidget {
  const OriginAutocompleteField({
    super.key,
    required this.options,
    required this.label,
    required this.hint,
    required this.displayString,
    required this.searchString,
    required this.onChanged,
    this.initialValue,
    this.enabled = true,
    this.requiredSelection = true,
    this.optionSubtitle,
    this.optionLeading,
  });

  final Iterable<T> options;
  final String label;
  final String hint;
  final String Function(T) displayString;
  final String Function(T) searchString;
  final ValueChanged<T?> onChanged;
  final T? initialValue;
  final bool enabled;
  final bool requiredSelection;
  final String Function(T)? optionSubtitle;
  final Widget Function(T)? optionLeading;

  @override
  State<OriginAutocompleteField<T>> createState() =>
      _OriginAutocompleteFieldState<T>();
}

class _OriginAutocompleteFieldState<T extends Object>
    extends State<OriginAutocompleteField<T>> {
  late T? _selected = widget.initialValue;
  late final _controller = TextEditingController(
    text: _selected == null ? '' : widget.displayString(_selected!),
  );
  final _focus = FocusNode();
  OptionsViewOpenDirection _direction = OptionsViewOpenDirection.down;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_updateDirection);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateDirection();
  }

  @override
  void didUpdateWidget(OriginAutocompleteField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled) _focus.unfocus();
    if (oldWidget.initialValue != widget.initialValue &&
        _selected != widget.initialValue) {
      _selected = widget.initialValue;
      final selected = _selected;
      // El Form padre puede estar construyéndose; actualizar su controlador
      // aquí emitiría una notificación durante build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _selected != selected) return;
        _controller.text = selected == null
            ? ''
            : widget.displayString(selected);
      });
    }
  }

  // El teclado puede dejar poco espacio debajo del campo. Abre las opciones
  // hacia arriba cuando allí caben mejor, una vez conocido el layout real.
  void _updateDirection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_focus.hasFocus) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final media = MediaQuery.of(context);
      final view = View.of(context);
      final top = box.localToGlobal(Offset.zero).dy;
      final above = top - media.padding.top;
      // Scaffold elimina viewInsets del MediaQuery del body al redimensionar;
      // toma el teclado de la vista para medir el área realmente visible.
      final below =
          (view.physicalSize.height - view.viewInsets.bottom) /
              view.devicePixelRatio -
          top -
          box.size.height;
      final direction = below < 240 && above > below
          ? OptionsViewOpenDirection.up
          : OptionsViewOpenDirection.down;
      if (direction != _direction) setState(() => _direction = direction);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.removeListener(_updateDirection);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _updateDirection();
    final query = normalizeForSearch(_controller.text.trim());
    final noResults =
        _selected == null &&
        query.isNotEmpty &&
        !widget.options.any(
          (option) =>
              normalizeForSearch(widget.searchString(option)).contains(query),
        );
    return LayoutBuilder(
      builder: (context, constraints) => RawAutocomplete<T>(
        optionsViewOpenDirection: _direction,
        textEditingController: _controller,
        focusNode: _focus,
        displayStringForOption: widget.displayString,
        optionsBuilder: (value) {
          if (!widget.enabled) return const Iterable.empty();
          final query = normalizeForSearch(value.text.trim());
          // Después de elegir, evita abrir de nuevo la misma sugerencia.
          if (_selected != null &&
              value.text == widget.displayString(_selected!)) {
            return const Iterable.empty();
          }
          final matches = widget.options
              .where(
                (option) => normalizeForSearch(
                  widget.searchString(option),
                ).contains(query),
              )
              .toList();
          int rank(T option) {
            final label = normalizeForSearch(widget.displayString(option));
            if (label == query) return 0;
            if (label.startsWith(query)) return 1;
            if (label.contains(query)) return 2;
            return 3;
          }

          matches.sort((a, b) {
            final byRank = rank(a).compareTo(rank(b));
            return byRank != 0
                ? byRank
                : normalizeForSearch(
                    widget.displayString(a),
                  ).compareTo(normalizeForSearch(widget.displayString(b)));
          });
          return matches;
        },
        onSelected: (option) {
          setState(() => _selected = option);
          widget.onChanged(option);
        },
        fieldViewBuilder: (context, controller, focus, onSubmitted) =>
            TextFormField(
              controller: controller,
              focusNode: focus,
              enabled: widget.enabled,
              style: AppTextStyles.body.copyWith(color: AppColors.neutral800),
              decoration: InputDecoration(
                labelText: widget.label,
                floatingLabelStyle: AppTextStyles.body.copyWith(
                  fontSize: 12,
                  color: AppColors.neutral800,
                ),
                hintText: widget.hint,
                helperText: noResults
                    ? 'No hay coincidencias. Prueba con otro nombre.'
                    : 'Escribe para buscar y selecciona una opción.',
                helperMaxLines: 2,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Borrar selección',
                        onPressed: !widget.enabled
                            ? null
                            : () {
                                _controller.clear();
                                setState(() => _selected = null);
                                widget.onChanged(null);
                                focus.requestFocus();
                              },
                        icon: const Icon(Icons.close),
                      ),
              ),
              validator: (_) {
                if (!widget.requiredSelection &&
                    controller.text.trim().isEmpty) {
                  return null;
                }
                return _selected == null ||
                        controller.text != widget.displayString(_selected!)
                    ? 'Selecciona una opción de la lista.'
                    : null;
              },
              onFieldSubmitted: (_) => onSubmitted(),
              onChanged: (text) {
                if (_selected != null &&
                    text != widget.displayString(_selected!)) {
                  _selected = null;
                  widget.onChanged(null);
                }
                setState(() {});
                _updateDirection();
              },
            ),
        optionsViewBuilder: (context, onSelected, options) {
          final results = options.toList();
          return Align(
            alignment: _direction == OptionsViewOpenDirection.up
                ? Alignment.bottomLeft
                : Alignment.topLeft,
            child: SizedBox(
              width: constraints.maxWidth,
              child: Material(
                color: AppColors.surface,
                elevation: 4,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    shrinkWrap: true,
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final option = results[index];
                      final highlighted =
                          AutocompleteHighlightedOption.of(context) == index;
                      return ListTile(
                        selected: highlighted,
                        selectedTileColor: AppColors.surface200,
                        leading: widget.optionLeading?.call(option),
                        title: Text(
                          widget.displayString(option),
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.neutral1100,
                          ),
                        ),
                        subtitle: widget.optionSubtitle == null
                            ? null
                            : Text(
                                widget.optionSubtitle!(option),
                                style: AppTextStyles.body.copyWith(
                                  fontSize: 13,
                                  color: AppColors.neutral800,
                                ),
                              ),
                        onTap: widget.enabled ? () => onSelected(option) : null,
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
