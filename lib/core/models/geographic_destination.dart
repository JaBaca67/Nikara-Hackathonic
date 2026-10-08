import 'package:nikara_app/core/models/nicaragua_origin_places.dart';
import 'package:nikara_app/core/utils/search_normalize.dart';

NicaraguaOriginPlace? municipalityByCode(String? code) {
  for (final place in nicaraguaOriginPlaces) {
    if (place.municipalityCode == code) return place;
  }
  return null;
}

/// Solo resuelve nombres completos y unívocos; una dirección no es un municipio.
NicaraguaOriginPlace? resolveMunicipality(String label, {String? department}) {
  final name = normalizeForSearch(label.trim());
  final matches = nicaraguaOriginPlaces.where((place) {
    if (department != null && place.department != department) return false;
    return [
      place.city,
      place.municipality,
      ...place.aliases,
    ].any((value) => normalizeForSearch(value.trim()) == name);
  }).toList();
  return matches.length == 1 ? matches.single : null;
}

NicaraguaOriginPlace? resolveLegacyEcoMunicipality(String location) {
  final codes = <String>{};
  for (final part in location.split(RegExp(r'[,·\n]'))) {
    final place = resolveMunicipality(part);
    if (place != null) codes.add(place.municipalityCode);
  }
  return codes.length == 1 ? municipalityByCode(codes.single) : null;
}

class GeographicDestination {
  const GeographicDestination({this.department, this.municipalityCode});

  final String? department;
  final String? municipalityCode;
  bool get isActive => department != null || municipalityCode != null;
  String get label =>
      municipalityByCode(municipalityCode)?.municipality ??
      department ??
      'Todo Nicaragua';

  bool matches(NicaraguaOriginPlace? place) {
    if (!isActive) return true;
    if (place == null) return false;
    if (municipalityCode != null) {
      return municipalityCode == place.municipalityCode;
    }
    return department == place.department;
  }
}
