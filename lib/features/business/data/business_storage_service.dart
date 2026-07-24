import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/domain/models/review_model.dart';

/// Local persistence for [BusinessModel]s, backed by [SharedPreferences]
/// (the whole list round-trips as a single JSON string — there's no
/// backend, so this is the source of truth for every registered business).
class BusinessStorageService {
  static const _key = 'businesses_json';

  Future<List<BusinessModel>> getBusinesses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) {
      final seeded = [_sampleBusiness];
      await _write(prefs, seeded);
      return seeded;
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => BusinessModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addBusiness(BusinessModel business) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getBusinesses();
    await _write(prefs, [...current, business]);
  }

  Future<void> updateBusiness(BusinessModel business) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getBusinesses();
    final updated = [
      for (final b in current) if (b.id == business.id) business else b,
    ];
    await _write(prefs, updated);
  }

  Future<void> _write(
    SharedPreferences prefs,
    List<BusinessModel> businesses,
  ) async {
    final encoded = jsonEncode(businesses.map((b) => b.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  static final BusinessModel _sampleBusiness = BusinessModel(
    id: 'sample-laguna-de-apoyo',
    name: 'Laguna de Apoyo',
    category: 'Eco Turismo',
    description:
        'Reserva natural formada por un cráter volcánico con aguas '
        'cristalinas ideales para nadar, hacer kayak y observar aves. Un '
        'refugio tranquilo a solo 40 minutos de Granada.',
    locationText: 'Laguna de Apoyo, Masaya, Nicaragua',
    latitude: 11.9394,
    longitude: -86.0392,
    contactPhone: '+505 8123 4567',
    socialMediaLink: 'https://instagram.com/lagunadeapoyo',
    allowsReservations: true,
    price: 350,
    amenities: const [
      'Kayaks',
      'Área de camping',
      'Restaurante',
      'Miradores',
      'Guías locales',
    ],
    hostName: 'Cooperativa Laguna Verde',
    schedules: 'Todos los días, 7:00 am – 6:00 pm',
    localImagePaths: const [],
    reviews: [
      ReviewModel(
        id: 'review-1',
        authorName: 'Marlon R.',
        rating: 5,
        comment: 'El agua está increíblemente clara y el ambiente es muy '
            'tranquilo. Volveremos pronto.',
        date: DateTime(2026, 4, 12),
      ),
      ReviewModel(
        id: 'review-2',
        authorName: 'Ana L.',
        rating: 4,
        comment: 'Hermoso lugar, el kayak vale mucho la pena. Falta un poco '
            'más de señalización en los senderos.',
        date: DateTime(2026, 5, 3),
      ),
    ],
  );
}
