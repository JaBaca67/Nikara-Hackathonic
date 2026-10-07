import 'package:nikara_app/features/business/utils/business_icons.dart';
import 'package:nikara_app/features/profile/domain/models/travel_postcard.dart';

String normalizePostcardSearch(String text) {
  var result = text.toLowerCase().trim();
  const accents = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };
  accents.forEach((accent, plain) => result = result.replaceAll(accent, plain));
  return result;
}

/// Search terms combine with the main-category filter, including legacy labels.
List<TravelPostcard> searchPostcards(
  Iterable<TravelPostcard> postcards, {
  String query = '',
  String? category,
}) {
  final terms = normalizePostcardSearch(
    query,
  ).split(RegExp(r'\s+')).where((term) => term.isNotEmpty);
  return postcards.where((card) {
    if (!card.isStamped) return false;
    final mainCategory = businessCategoryPresetFor(card.category) ?? 'Otros';
    if (category != null && mainCategory != category) return false;
    final label = switch (mainCategory) {
      'Restaurante' => 'Comida',
      'Tour' => 'Tours',
      'Eco-destino' => 'Naturaleza',
      _ => mainCategory,
    };
    final searchable = normalizePostcardSearch(
      '${card.title} ${card.category} $mainCategory $label',
    );
    return terms.every(searchable.contains);
  }).toList()..sort((a, b) => b.sealedAt!.compareTo(a.sealedAt!));
}
