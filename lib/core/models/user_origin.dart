import 'package:nikara_app/core/models/origin_countries.dart';
import 'package:nikara_app/core/models/nicaragua_origin_places.dart';

enum ResidenceType { nicaraguan, foreign }

class UserOrigin {
  const UserOrigin({
    this.residenceType,
    this.countryCode,
    this.city = '',
    this.municipality = '',
  });

  final ResidenceType? residenceType;
  final String? countryCode;
  final String city;
  final String municipality;

  bool get isNicaraguan => residenceType == ResidenceType.nicaraguan;
  bool get hasCountry => originCountries.containsKey(countryCode);
  bool get isComplete =>
      hasCountry &&
      switch (residenceType) {
        ResidenceType.nicaraguan =>
          countryCode == 'NI' &&
              findNicaraguaOriginPlace(city, municipality) != null,
        ResidenceType.foreign => countryCode != 'NI',
        null => false,
      };

  String get label {
    final country = originCountries[countryCode] ?? '';
    if (!isNicaraguan) return country;
    final places = {city.trim(), municipality.trim()}..remove('');
    return places.isEmpty ? country : '$country · ${places.join(', ')}';
  }

  Map<String, dynamic> toRow() => {
    'residence_type': residenceType?.name,
    'origin_country_code': countryCode,
    'origin_city': isNicaraguan ? city.trim() : null,
    'origin_municipality': isNicaraguan ? municipality.trim() : null,
  };

  factory UserOrigin.fromRow(Map<String, dynamic> row) => UserOrigin(
    residenceType: switch (row['residence_type']) {
      'nicaraguan' => ResidenceType.nicaraguan,
      'foreign' => ResidenceType.foreign,
      _ => null,
    },
    countryCode: row['origin_country_code'] as String?,
    city: row['origin_city'] as String? ?? '',
    municipality: row['origin_municipality'] as String? ?? '',
  );
}
