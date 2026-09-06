import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nikara_app/core/services/favorites_service.dart';

/// Regresión de "al cambiar de cuenta se ven los datos del perfil anterior".
///
/// El síntoma reportado fue el avatar (que vivía en `SharedPreferences` bajo
/// una clave global en vez de en `profiles.avatar_url`), pero [FavoritesService]
/// tenía exactamente el mismo defecto y además uno peor: su caché en memoria
/// (`_hydratedKey`) es estado de un singleton, y el cambio de cuenta hace
/// `pushAndRemoveUntil` — recrea la UI, no el proceso. Sin re-hidratar por
/// dueño, los favoritos del perfil anterior sobrevivían hasta reiniciar la app.
///
/// Sin sesión real toda lectura cae en la clave de invitado, así que lo que se
/// puede cubrir acá es la parte que no depende de Supabase: adopción de la
/// clave legacy y invalidación del caché. La separación por usuario se
/// verifica leyendo directamente las claves escritas.
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test-anon-key-not-real',
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FavoritesService().invalidate();
  });

  test('adopta la lista global anterior y borra la clave legacy', () async {
    SharedPreferences.setMockInitialValues({
      'favorite_destination_ids': ['laguna-de-apoyo', 'ometepe'],
    });
    FavoritesService().invalidate();

    final ids = await FavoritesService().getFavoriteIds();
    expect(ids, {'laguna-de-apoyo', 'ometepe'});

    final prefs = await SharedPreferences.getInstance();
    // Migrada a la clave con dueño y borrada la vieja, para que no se vuelva a
    // adoptar desde otra cuenta.
    expect(prefs.getStringList('favorite_destination_ids'), isNull);
    expect(prefs.getStringList('favorite_ids_guest'), isNotNull);
  });

  test('escribe bajo la clave con dueño, no bajo la global', () async {
    await FavoritesService().toggleFavorite('ometepe');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('favorite_ids_guest'), ['ometepe']);
    expect(prefs.getStringList('favorite_destination_ids'), isNull);
  });

  test('invalidate vacía el snapshot en memoria', () async {
    await FavoritesService().toggleFavorite('ometepe');
    expect(FavoritesService().idsNotifier.value, {'ometepe'});

    FavoritesService().invalidate();
    expect(FavoritesService().idsNotifier.value, isEmpty);

    // Y la siguiente lectura vuelve a SharedPreferences, no al snapshot viejo.
    expect(await FavoritesService().getFavoriteIds(), {'ometepe'});
  });

  test(
    'no arrastra favoritos de otra cuenta guardados en su propia clave',
    () async {
      SharedPreferences.setMockInitialValues({
        'favorite_ids_otro-usuario': ['solo-del-otro'],
      });
      FavoritesService().invalidate();

      // La sesión de este test es de invitado: lee su propia clave, vacía.
      expect(await FavoritesService().getFavoriteIds(), isEmpty);
    },
  );

  test('toggle devuelve el estado nuevo y persiste ambos sentidos', () async {
    expect(await FavoritesService().toggleFavorite('ometepe'), isTrue);
    expect(await FavoritesService().isFavorite('ometepe'), isTrue);

    expect(await FavoritesService().toggleFavorite('ometepe'), isFalse);
    expect(await FavoritesService().isFavorite('ometepe'), isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('favorite_ids_guest'), isEmpty);
  });
}
