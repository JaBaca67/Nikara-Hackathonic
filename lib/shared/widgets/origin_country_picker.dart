import 'package:flutter/material.dart';
import 'package:nikara_app/core/models/origin_countries.dart';
import 'package:nikara_app/core/utils/search_normalize.dart';
import 'package:nikara_app/theme/app_theme.dart';

Future<String?> showOriginCountryPicker(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _CountryPicker(),
    );

class _CountryPicker extends StatefulWidget {
  const _CountryPicker();
  @override
  State<_CountryPicker> createState() => _CountryPickerState();
}

class _CountryPickerState extends State<_CountryPicker> {
  String _search = '';
  @override
  Widget build(BuildContext context) {
    final countries = originCountries.entries
        .where(
          (entry) =>
              entry.key != 'NI' &&
              (normalizeForSearch(
                    entry.value,
                  ).contains(normalizeForSearch(_search)) ||
                  entry.key.toLowerCase().contains(_search.toLowerCase())),
        )
        .toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'País de origen',
                      style: AppTextStyles.sectionTitle,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Buscar país',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _search = value),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: countries.isEmpty
                  ? const Center(child: Text('No se encontraron países'))
                  : ListView.builder(
                      itemCount: countries.length,
                      itemBuilder: (context, index) {
                        final country = countries[index];
                        return ListTile(
                          leading: Image.asset(
                            'assets/flags/${country.key.toLowerCase()}.png',
                            width: 28,
                            height: 20,
                            fit: BoxFit.contain,
                          ),
                          title: Text(country.value),
                          onTap: () => Navigator.of(context).pop(country.key),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
