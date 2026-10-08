import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nikara_app/core/models/origin_countries.dart';
import 'package:nikara_app/core/models/nicaragua_origin_places.dart';
import 'package:nikara_app/core/models/user_model.dart';
import 'package:nikara_app/core/models/user_origin.dart';
import 'package:nikara_app/features/business/domain/models/review_model.dart';
import 'package:nikara_app/features/eco/domain/models/eco_activity_model.dart';

void main() {
  const local = UserOrigin(
    residenceType: ResidenceType.nicaraguan,
    countryCode: 'NI',
    city: ' Masaya ',
    municipality: ' Masaya ',
  );
  test(
    'cuentas anteriores permanecen incompletas sin inventar procedencia',
    () {
      final profile = UserModel.fromRow({'id': 'legacy', 'full_name': 'Ana'});
      expect(profile.origin.isComplete, isFalse);
      expect(profile.publicName, 'Ana');
    },
  );
  test('requiere país conocido y ciudad/municipio para nicaragüenses', () {
    expect(local.isComplete, isTrue);
    expect(
      const UserOrigin(
        residenceType: ResidenceType.nicaraguan,
        countryCode: 'NI',
        city: 'Masaya',
      ).isComplete,
      isFalse,
    );
    expect(
      const UserOrigin(
        residenceType: ResidenceType.nicaraguan,
        countryCode: 'US',
        city: 'Masaya',
        municipality: 'Masaya',
      ).isComplete,
      isFalse,
    );
    expect(
      const UserOrigin(
        residenceType: ResidenceType.foreign,
        countryCode: 'ZZ',
      ).isComplete,
      isFalse,
    );
    expect(
      const UserOrigin(
        residenceType: ResidenceType.foreign,
        countryCode: 'NI',
      ).isComplete,
      isFalse,
    );
    expect(
      const UserOrigin(
        residenceType: ResidenceType.foreign,
        countryCode: 'ES',
      ).isComplete,
      isTrue,
    );
  });
  test('normaliza lugares y elimina datos locales al pasar a extranjero', () {
    expect(local.toRow()['origin_city'], 'Masaya');
    expect(local.label, 'Nicaragua · Masaya');
    expect(
      const UserOrigin(
        residenceType: ResidenceType.nicaraguan,
        countryCode: 'NI',
        city: 'Masaya',
        municipality: 'Masaya',
      ).label,
      'Nicaragua · Masaya',
    );
    final row = const UserOrigin(
      residenceType: ResidenceType.foreign,
      countryCode: 'US',
      city: 'Masaya',
      municipality: 'Masaya',
    ).toRow();
    expect(row['origin_city'], isNull);
    expect(row['origin_municipality'], isNull);
    expect(UserOrigin.fromRow(row).isComplete, isTrue);
  });
  test('vista del propietario respeta visibilidad sin borrar origen real', () {
    final hidden = UserModel.fromRow({
      'id': 'own',
      ...local.toRow(),
      'show_origin': false,
    });
    expect(hidden.origin.isComplete, isTrue);
    expect(hidden.publicOrigin.hasCountry, isFalse);
    final countryOnly = UserModel.fromRow({
      'id': 'own',
      ...local.toRow(),
      'show_origin_details': false,
      'public_display_name': '  Viajera  ',
    });
    expect(countryOnly.publicOrigin.label, 'Nicaragua');
    expect(countryOnly.origin.city, 'Masaya');
    expect(countryOnly.publicName, 'Viajera');
  });
  test('todos los países del selector tienen una bandera local', () {
    expect(originCountries.length, greaterThan(200));
    for (final code in originCountries.keys) {
      expect(
        File('assets/flags/${code.toLowerCase()}.png').existsSync(),
        isTrue,
        reason: code,
      );
    }
  });
  test('catálogo municipal completo y sin nombres o códigos ambiguos', () {
    expect(nicaraguaOriginPlaces.length, 153);
    expect(
      nicaraguaOriginPlaces.map((p) => p.municipalityCode).toSet(),
      hasLength(153),
    );
    expect(
      nicaraguaOriginPlaces.map((p) => p.municipality).toSet(),
      hasLength(153),
    );
    expect(
      nicaraguaOriginPlaces.map((p) => p.department).toSet(),
      hasLength(17),
    );
    for (final place in nicaraguaOriginPlaces) {
      expect(RegExp(r'^\d{4}$').hasMatch(place.municipalityCode), isTrue);
      expect(place.searchText, isNot(contains('\uFFFD')));
      expect(findNicaraguaOriginPlace(place.city, place.municipality), place);
    }
    expect(
      findNicaraguaOriginPlace('Malpaisillo', 'Larreynaga')?.department,
      'León',
    );
    expect(
      findNicaraguaOriginPlace('Bilwi', 'Puerto Cabezas')?.municipalityCode,
      '9110',
    );
  });
  test(
    'rechaza texto libre y combinaciones de ciudades y municipios ajenos',
    () {
      for (final origin in [
        const UserOrigin(
          residenceType: ResidenceType.nicaraguan,
          countryCode: 'NI',
          city: 'Mi ciudad',
          municipality: 'Mi municipio',
        ),
        const UserOrigin(
          residenceType: ResidenceType.nicaraguan,
          countryCode: 'NI',
          city: 'Masaya',
          municipality: 'Nindirí',
        ),
        const UserOrigin(
          residenceType: ResidenceType.nicaraguan,
          countryCode: 'NI',
          city: 'nindiri',
          municipality: 'nindiri',
        ),
      ]) {
        expect(origin.isComplete, isFalse);
      }
      expect(
        const UserOrigin(
          residenceType: ResidenceType.nicaraguan,
          countryCode: 'NI',
          city: 'Malpaisillo',
          municipality: 'Larreynaga',
        ).isComplete,
        isTrue,
      );
    },
  );
  test(
    'participantes y reseñas conservan la identidad pública y procedencia',
    () {
      final participant = EcoParticipant.fromRow({
        'user_id': 'person',
        'joined_at': '2026-10-07T12:00:00Z',
        'public_profiles': {'full_name': 'Viajera', ...local.toRow()},
      });
      expect(participant.origin.label, local.label);
      final review = ReviewModel(
        id: 'r',
        authorName: 'Viajera',
        rating: 5,
        comment: 'Bien',
        date: DateTime(2026),
        authorOrigin: local,
        authorAvatarUrl: 'avatar',
      );
      final restored = ReviewModel.fromJson(review.toJson());
      expect(restored.authorOrigin.label, local.label);
      expect(restored.authorAvatarUrl, 'avatar');
    },
  );
}
