import 'package:flutter/material.dart';
import 'package:nikara_app/core/models/origin_countries.dart';
import 'package:nikara_app/core/models/user_origin.dart';
import 'package:nikara_app/shared/widgets/origin_country_picker.dart';
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
  late final _city = TextEditingController(text: widget.initialValue.city);
  late final _municipality = TextEditingController(
    text: widget.initialValue.municipality,
  );

  void _notify() => widget.onChanged(
    UserOrigin(
      residenceType: _type,
      countryCode: _country,
      city: _city.text,
      municipality: _municipality.text,
    ),
  );

  @override
  void dispose() {
    _city.dispose();
    _municipality.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tu procedencia', style: AppTextStyles.sectionTitle),
        const SizedBox(height: 8),
        Text(
          'Ayuda a los negocios a conocer a sus visitantes y potenciar el turismo.',
          style: AppTextStyles.body.copyWith(
            fontSize: 13,
            color: AppColors.neutral800,
          ),
        ),
        const SizedBox(height: 14),
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
                    _city.clear();
                    _municipality.clear();
                  });
                  _notify();
                },
        ),
        if (_type == ResidenceType.foreign) ...[
          const SizedBox(height: 14),
          FormField<String>(
            key: ValueKey(_type),
            initialValue:
                originCountries.containsKey(_country) && _country != 'NI'
                ? _country
                : null,
            enabled: widget.enabled,
            validator: (v) =>
                v == null ? 'Selecciona tu país de origen.' : null,
            builder: (field) => InkWell(
              onTap: !widget.enabled
                  ? null
                  : () async {
                      final country = await showOriginCountryPicker(context);
                      if (!mounted ||
                          country == null ||
                          _type != ResidenceType.foreign) {
                        return;
                      }
                      field.didChange(country);
                      setState(() => _country = country);
                      _notify();
                    },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'País de origen *',
                  errorText: field.errorText,
                  enabled: widget.enabled,
                  suffixIcon: const Icon(Icons.expand_more),
                ),
                isEmpty: field.value == null,
                child: Text(
                  originCountries[field.value] ?? '',
                  style: AppTextStyles.body,
                ),
              ),
            ),
          ),
        ],
        if (_type == ResidenceType.nicaraguan) ...[
          const SizedBox(height: 14),
          TextFormField(
            controller: _city,
            style: AppTextStyles.body.copyWith(color: AppColors.neutral800),
            enabled: widget.enabled,
            maxLength: 100,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Ciudad de origen *',
              hintText: 'Ej.: Masaya',
            ),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Escribe tu ciudad de origen.'
                : null,
            onChanged: (_) => _notify(),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _municipality,
            style: AppTextStyles.body.copyWith(color: AppColors.neutral800),
            enabled: widget.enabled,
            maxLength: 100,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Municipio de origen *',
              hintText: 'Ej.: Nindirí',
            ),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Escribe tu municipio de origen.'
                : null,
            onChanged: (_) => _notify(),
          ),
        ],
      ],
    );
  }
}
