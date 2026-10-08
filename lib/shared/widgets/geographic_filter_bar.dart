import 'package:flutter/material.dart';
import 'package:nikara_app/core/models/geographic_destination.dart';
import 'package:nikara_app/core/models/nicaragua_origin_places.dart';
import 'package:nikara_app/shared/widgets/catalog_selection_field.dart';
import 'package:nikara_app/theme/app_theme.dart';

class DiscoveryFilterSelection {
  const DiscoveryFilterSelection(
    this.destination, {
    this.sortByDistance = false,
  });
  final GeographicDestination destination;
  final bool sortByDistance;
}

Future<DiscoveryFilterSelection?> showGeographicDestinationPicker(
  BuildContext context, {
  required GeographicDestination initial,
  bool showOrdering = false,
  bool sortByDistance = false,
}) => showModalBottomSheet<DiscoveryFilterSelection>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: AppColors.surface,
  builder: (context) => _DestinationSheet(
    initial: initial,
    showOrdering: showOrdering,
    sortByDistance: sortByDistance,
  ),
);

class GeographicFilterBar extends StatelessWidget {
  const GeographicFilterBar({
    super.key,
    required this.destination,
    required this.onChanged,
  });
  final GeographicDestination destination;
  final ValueChanged<GeographicDestination> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.travel_explore, size: 18),
            label: Text(
              destination.isActive
                  ? 'Destino: ${destination.label}'
                  : 'Explorar destino',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onPressed: () async {
              final result = await showGeographicDestinationPicker(
                context,
                initial: destination,
              );
              if (result != null) onChanged(result.destination);
            },
          ),
        ),
        if (destination.isActive)
          IconButton(
            tooltip: 'Quitar filtro de destino',
            onPressed: () => onChanged(const GeographicDestination()),
            icon: const Icon(Icons.close),
          ),
      ],
    ),
  );
}

class _DestinationSheet extends StatefulWidget {
  const _DestinationSheet({
    required this.initial,
    this.showOrdering = false,
    this.sortByDistance = false,
  });
  final GeographicDestination initial;
  final bool showOrdering;
  final bool sortByDistance;
  @override
  State<_DestinationSheet> createState() => _DestinationSheetState();
}

class _DestinationSheetState extends State<_DestinationSheet> {
  late bool _sortByDistance = widget.sortByDistance;
  late String? _department = widget.initial.department;
  late NicaraguaOriginPlace? _place = municipalityByCode(
    widget.initial.municipalityCode,
  );
  @override
  Widget build(BuildContext context) {
    final departments =
        nicaraguaOriginPlaces.map((p) => p.department).toSet().toList()..sort();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('¿Dónde quieres explorar?', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 8),
            const Text('Elige todo un departamento o un municipio específico.'),
            const SizedBox(height: 20),
            CatalogSelectionField<String>(
              label: 'Departamento',
              options: departments,
              value: _department,
              displayString: (v) => v,
              onChanged: (v) => setState(() {
                _department = v;
                _place = null;
              }),
            ),
            const SizedBox(height: 16),
            CatalogSelectionField<NicaraguaOriginPlace>(
              label: 'Municipio / ciudad',
              options: nicaraguaOriginPlaces.where(
                (p) => _department == null || p.department == _department,
              ),
              value: _place,
              requiredSelection: false,
              displayString: (p) => p.municipality,
              subtitle: (p) => '${p.city} · ${p.department}',
              searchString: (p) => p.searchText,
              onChanged: (p) => setState(() {
                _place = p;
                _department = p.department;
              }),
            ),
            if (_place != null)
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.neutral800,
                ),
                onPressed: () => setState(() => _place = null),
                child: const Text('Ver todo el departamento'),
              ),
            if (widget.showOrdering) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<bool>(
                initialValue: _sortByDistance,
                decoration: const InputDecoration(labelText: 'Ordenar lugares'),
                items: const [
                  DropdownMenuItem(value: false, child: Text('Más recientes')),
                  DropdownMenuItem(value: true, child: Text('Más cercanos')),
                ],
                onChanged: (value) =>
                    setState(() => _sortByDistance = value ?? false),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                DiscoveryFilterSelection(
                  GeographicDestination(
                    department: _department,
                    municipalityCode: _place?.municipalityCode,
                  ),
                  sortByDistance: _sortByDistance,
                ),
              ),
              child: const Text('Aplicar destino'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.neutral800,
              ),
              onPressed: () => Navigator.pop(
                context,
                DiscoveryFilterSelection(
                  const GeographicDestination(),
                  sortByDistance: _sortByDistance,
                ),
              ),
              child: const Text('Ver todo Nicaragua'),
            ),
          ],
        ),
      ),
    );
  }
}
