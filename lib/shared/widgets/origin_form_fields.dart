import 'package:flutter/material.dart';
import 'package:nikara_app/core/models/nicaragua_origin_places.dart';
import 'package:nikara_app/core/models/origin_countries.dart';
import 'package:nikara_app/core/models/user_origin.dart';
import 'package:nikara_app/shared/widgets/origin_autocomplete_field.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Se monta dentro del Form del registro, la compuerta o el editor.
class OriginFormFields extends StatefulWidget {
  const OriginFormFields({
    super.key,
    this.initialValue = const UserOrigin(),
    required this.onChanged,
    this.enabled = true,
  });
  final UserOrigin initialValue;
  final ValueChanged<UserOrigin> onChanged;
  final bool enabled;

  @override
  State<OriginFormFields> createState() => _OriginFormFieldsState();
}

class _OriginFormFieldsState extends State<OriginFormFields> {
  late ResidenceType? _type = widget.initialValue.residenceType;
  late String? _country = widget.initialValue.countryCode;
  late NicaraguaOriginPlace? _place = findNicaraguaOriginPlace(
    widget.initialValue.city,
    widget.initialValue.municipality,
  );

  void _notify() => widget.onChanged(
    UserOrigin(
      residenceType: _type,
      countryCode: _country,
      city: _place?.city ?? '',
      municipality: _place?.municipality ?? '',
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tu procedencia', style: AppTextStyles.sectionTitle),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Ayuda a los negocios a conocer a sus visitantes y potenciar el turismo.',
          style: AppTextStyles.body.copyWith(
            fontSize: 13,
            color: AppColors.neutral800,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        DropdownButtonFormField<ResidenceType>(
          initialValue: _type,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Condición de residencia *',
          ),
          items: const [
            DropdownMenuItem(
              value: ResidenceType.nicaraguan,
              child: Text('Nicaragüense'),
            ),
            DropdownMenuItem(
              value: ResidenceType.foreign,
              child: Text('Extranjero'),
            ),
          ],
          validator: (v) =>
              v == null ? 'Selecciona tu condición de residencia.' : null,
          onChanged: !widget.enabled
              ? null
              : (type) {
                  if (type == _type) return;
                  setState(() {
                    _type = type;
                    _country = type == ResidenceType.nicaraguan ? 'NI' : null;
                    _place = null;
                  });
                  _notify();
                },
        ),
        if (_type == ResidenceType.foreign) ...[
          const SizedBox(height: AppSpacing.lg),
          OriginAutocompleteField<String>(
            key: const ValueKey('origin-country'),
            options: originCountries.keys.where((code) => code != 'NI'),
            initialValue:
                originCountries.containsKey(_country) && _country != 'NI'
                ? _country
                : null,
            enabled: widget.enabled,
            label: 'País de origen *',
            hint: 'Busca tu país, ej.: Costa Rica',
            displayString: (code) => originCountries[code]!,
            searchString: (code) => '${originCountries[code]} $code',
            optionLeading: (code) => Image.asset(
              'assets/flags/${code.toLowerCase()}.png',
              width: 28,
              height: 20,
              fit: BoxFit.contain,
            ),
            onChanged: (code) {
              setState(() => _country = code);
              _notify();
            },
          ),
        ],
        if (_type == ResidenceType.nicaraguan) ...[
          const SizedBox(height: AppSpacing.lg),
          OriginAutocompleteField<NicaraguaOriginPlace>(
            key: const ValueKey('origin-place'),
            options: nicaraguaOriginPlaces,
            initialValue: _place,
            enabled: widget.enabled,
            label: 'Ciudad / municipio de origen *',
            hint: 'Busca tu ciudad, ej.: Masaya',
            displayString: (place) => place.city,
            searchString: (place) => place.searchText,
            optionSubtitle: (place) =>
                '${place.municipality} · ${place.department}',
            onChanged: (place) {
              setState(() => _place = place);
              _notify();
            },
          ),
          if (_place != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Municipio: ${_place!.municipality}\n${_place!.department}',
              style: AppTextStyles.body.copyWith(
                fontSize: 13,
                color: AppColors.neutral800,
              ),
            ),
          ],
        ],
      ],
    );
  }
}
