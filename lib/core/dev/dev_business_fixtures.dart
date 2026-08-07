import 'package:nikara_app/features/business/domain/models/business_model.dart';

/// In-memory-only preview businesses for "Carlos M." (see [AuthService]'s
/// Dev Mode seed users) — NEVER written to `BusinessStorageService`/
/// SharedPreferences, so they never pollute Home/Map's real feed. Editing
/// one through the wizard and saving upserts it into real storage from
/// that point on, same as any other business.
final Map<String, BusinessModel> devBusinessFixtures = {
  'biz_1': const BusinessModel(
    id: 'biz_1',
    name: 'Mirador El Boquete',
    category: 'Eco Turismo',
    description:
        'Senderos con vista al Volcán Mombacho, mirador natural y '
        'hospedaje rústico para quienes buscan desconectarse.',
    city: 'Granada',
    locationText: 'Km 8 carretera a Mombacho, entrada al sendero El Boquete',
    contactPhone: '+505 8888 1111',
    allowsReservations: true,
    price: 250,
    amenities: ['Guías locales', 'Estacionamiento'],
    activities: ['Senderismo', 'Fotografía'],
    hostName: 'Carlos M.',
    ownerId: 'user_carlos',
  ),
  'biz_2': const BusinessModel(
    id: 'biz_2',
    name: 'Café Selva Nublada',
    category: 'Restaurante',
    description:
        'Café de altura cultivado en finca propia, servido con vista al '
        'bosque nublado de Jinotega.',
    city: 'Jinotega',
    locationText: 'De la iglesia central, 3c arriba, Finca Selva Nublada',
    contactPhone: '+505 8888 2222',
    allowsReservations: false,
    amenities: ['Wifi', 'Desayuno incluido'],
    activities: ['Tour de Café'],
    hostName: 'Carlos M.',
    ownerId: 'user_carlos',
  ),
  'biz_3': const BusinessModel(
    id: 'biz_3',
    name: 'Posada Río Escondido',
    category: 'Hospedaje',
    description: 'Cabañas frente al río, ideal para familias y grupos.',
    city: 'Río San Juan',
    locationText: 'Muelle municipal, 1km río arriba',
    contactPhone: '+505 8888 3333',
    allowsReservations: true,
    price: 400,
    amenities: ['Piscina', 'Mascotas permitidas'],
    activities: ['Kayak'],
    hostName: 'Carlos M.',
    ownerId: 'user_carlos',
  ),
};
