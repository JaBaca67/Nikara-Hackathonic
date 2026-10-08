import 'package:flutter/material.dart';
import 'package:nikara_app/core/models/nicaragua_origin_places.dart';
import 'package:nikara_app/shared/widgets/origin_autocomplete_field.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Ubicación de los lugares publicados en Nícara. País y nombres proceden
/// del catálogo; la dirección exacta se captura por separado.
class NicaraguaLocationFormFields extends StatefulWidget {
  const NicaraguaLocationFormFields({
    super.key,
    this.initialValue,
    required this.onChanged,
    this.enabled = true,
  });
  final NicaraguaOriginPlace? initialValue;
  final ValueChanged<NicaraguaOriginPlace?> onChanged;
  final bool enabled;
  @override
  State<NicaraguaLocationFormFields> createState() =>
      _NicaraguaLocationFormFieldsState();
}

class _NicaraguaLocationFormFieldsState
    extends State<NicaraguaLocationFormFields> {
  late NicaraguaOriginPlace? _place = widget.initialValue;
  late String? _department = _place?.department;

  @override
  void didUpdateWidget(NicaraguaLocationFormFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        _place != widget.initialValue) {
      _place = widget.initialValue;
      _department = _place?.department;
    }
  }

  @override
  Widget build(BuildContext context) {
    final departments =
        nicaraguaOriginPlaces.map((p) => p.department).toSet().toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputDecorator(
          decoration: const InputDecoration(labelText: 'País'),
          child: Row(
            children: [
              Image.asset('assets/flags/ni.png', width: 24, height: 18),
              const SizedBox(width: 8),
              Text(
                'Nicaragua',
                style: AppTextStyles.body.copyWith(color: AppColors.neutral800),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OriginAutocompleteField<String>(
          label: 'Departamento',
          hint: 'Escribe tu departamento',
          options: departments,
          initialValue: _department,
          displayString: (value) => value,
          searchString: (value) => value,
          enabled: widget.enabled,
          requiredSelection: false,
          onChanged: (department) {
            setState(() {
              _department = department;
              _place = null;
            });
            widget.onChanged(null);
          },
        ),
        const SizedBox(height: 16),
        OriginAutocompleteField<NicaraguaOriginPlace>(
          key: ValueKey(_department),
          label: 'Ciudad / municipio *',
          hint: 'Escribe la ciudad o municipio',
          options: nicaraguaOriginPlaces.where(
            (p) => _department == null || p.department == _department,
          ),
          initialValue: _place,
          enabled: widget.enabled,
          displayString: (p) => p.city,
          searchString: (p) => p.searchText,
          optionSubtitle: (p) => '${p.municipality} · ${p.department}',
          onChanged: (place) {
            setState(() {
              _place = place;
              if (place != null) _department = place.department;
            });
            widget.onChanged(place);
          },
        ),
        if (_place != null) ...[
          const SizedBox(height: 8),
          Text('Municipio: ${_place!.municipality}', style: AppTextStyles.body),
        ],
      ],
    );
  }
}
