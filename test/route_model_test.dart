import 'package:flutter_test/flutter_test.dart';

import 'package:nikara_app/features/routes/domain/models/route_model.dart';
import 'package:nikara_app/features/routes/domain/models/route_stop_model.dart';

/// Las reglas de armado de un itinerario viven en [RouteModel] (orden,
/// renumeración, agrupación por día) y en [RouteStopCategory] (clasificar
/// el `category` libre de un negocio). Son pura lógica de dominio, así que
/// se prueban sin widgets ni Supabase.
RouteStopModel _stop(
  String id, {
  int day = 1,
  int position = 0,
  RouteStopCategory category = RouteStopCategory.turistico,
  String? image,
  double? lat,
  double? lng,
}) {
  return RouteStopModel(
    kind: RouteStopKind.destination,
    sourceId: id,
    title: 'Parada $id',
    category: category,
    imagePath: image,
    latitude: lat,
    longitude: lng,
    dayNumber: day,
    position: position,
  );
}

RouteModel _route(
  List<RouteStopModel> stops, {
  int days = 2,
  List<String> imageUrls = const [],
  String? creatorName,
}) {
  return RouteModel(
    id: 'route-1',
    ownerId: 'owner-1',
    title: 'Fin de semana en Granada',
    days: days,
    createdAt: DateTime(2026, 1, 1),
    stops: RouteModel.sortStops(stops),
    imageUrls: imageUrls,
    creatorName: creatorName,
  );
}

void main() {
  group('RouteModel.sortStops', () {
    test('ordena por día y, dentro del día, por posición', () {
      final sorted = RouteModel.sortStops([
        _stop('c', day: 2, position: 1),
        _stop('a', day: 1, position: 1),
        _stop('b', day: 1, position: 0),
      ]);

      expect(sorted.map((s) => s.sourceId), ['b', 'a', 'c']);
    });
  });

  group('RouteModel.reindex', () {
    test('renumera desde 0 dentro de cada día, sin huecos', () {
      final reindexed = RouteModel.reindex([
        _stop('a', day: 1, position: 5),
        _stop('b', day: 1, position: 9),
        _stop('c', day: 2, position: 3),
      ]);

      expect(
        reindexed.map((s) => '${s.sourceId}:${s.dayNumber}:${s.position}'),
        ['a:1:0', 'b:1:1', 'c:2:0'],
      );
    });

    test('deja un orden estable cuando dos paradas empatan de posición', () {
      final reindexed = RouteModel.reindex([
        _stop('a', day: 1, position: 0),
        _stop('b', day: 1, position: 0),
      ]);

      expect(reindexed.map((s) => s.position), [0, 1]);
    });
  });

  group('RouteModel', () {
    test('stopsForDay solo devuelve las paradas de ese día', () {
      final route = _route([
        _stop('a', day: 1, position: 0),
        _stop('b', day: 2, position: 0),
        _stop('c', day: 2, position: 1),
      ]);

      expect(route.stopsForDay(1).map((s) => s.sourceId), ['a']);
      expect(route.stopsForDay(2).map((s) => s.sourceId), ['b', 'c']);
      expect(route.stopsForDay(3), isEmpty);
    });

    test('categories no repite y respeta el orden de aparición', () {
      final route = _route([
        _stop('a', category: RouteStopCategory.turistico),
        _stop('b', position: 1, category: RouteStopCategory.eco),
        _stop('c', position: 2, category: RouteStopCategory.turistico),
      ]);

      expect(route.categories, [
        RouteStopCategory.turistico,
        RouteStopCategory.eco,
      ]);
    });

    test('coverImages toma las primeras fotos reales, sin repetir', () {
      final route = _route([
        _stop('a', image: 'foto-1.jpg'),
        _stop('b', position: 1),
        _stop('c', position: 2, image: 'foto-1.jpg'),
        _stop('d', position: 3, image: 'foto-2.jpg'),
      ]);

      expect(route.coverImages(), ['foto-1.jpg', 'foto-2.jpg']);
    });

    test(
      'coverImages prioriza las fotos de portada sobre las de las paradas',
      () {
        final route = _route(
          [
            _stop('a', image: 'parada-1.jpg'),
            _stop('b', position: 1, image: 'parada-2.jpg'),
          ],
          imageUrls: ['portada-1.jpg'],
        );

        expect(route.coverImages(), [
          'portada-1.jpg',
          'parada-1.jpg',
          'parada-2.jpg',
        ]);
      },
    );

    test(
      'coverImages no completa con fotos de parada si la portada ya llenó el cupo',
      () {
        final route = _route(
          [_stop('a', image: 'parada-1.jpg')],
          imageUrls: ['p1.jpg', 'p2.jpg', 'p3.jpg'],
        );

        expect(route.coverImages(), ['p1.jpg', 'p2.jpg', 'p3.jpg']);
      },
    );

    test('summaryLine singulariza día y parada', () {
      final oneDay = _route([_stop('a')], days: 1);
      expect(oneDay.summaryLine, '1 día · 1 parada');

      final twoDays = _route([_stop('a'), _stop('b', position: 1)], days: 2);
      expect(twoDays.summaryLine, '2 días · 2 paradas');
    });

    test('mappableStops descarta las paradas sin coordenadas', () {
      final route = _route([
        _stop('a', lat: 12.1, lng: -86.2),
        _stop('b', position: 1),
      ]);

      expect(route.mappableStops.map((s) => s.sourceId), ['a']);
    });

    test('isOwnedBy es falso para un invitado (sin sesión)', () {
      final route = _route([_stop('a')]);

      expect(route.isOwnedBy('owner-1'), isTrue);
      expect(route.isOwnedBy('otra-cuenta'), isFalse);
      expect(route.isOwnedBy(null), isFalse);
    });

    test('creatorDisplayName cae a un genérico sin inventar un nombre', () {
      final withName = _route([_stop('a')], creatorName: 'Sofía Ramírez');
      final withoutName = _route([_stop('a')]);

      expect(withName.creatorDisplayName, 'Sofía Ramírez');
      expect(withoutName.creatorDisplayName, 'Alguien de Níkara');
    });

    test('creatorInitials toma las primeras dos iniciales', () {
      final route = _route([_stop('a')], creatorName: 'Sofía Ramírez');

      expect(route.creatorInitials, 'SR');
    });
  });

  group('RouteStopCategory.forBusinessCategory', () {
    test('manda a Gastronómico lo que suena a comida', () {
      for (final category in [
        'Restaurante',
        'Comida típica',
        'Café de altura',
        'Bar',
      ]) {
        expect(
          RouteStopCategory.forBusinessCategory(category),
          RouteStopCategory.gastronomico,
          reason: category,
        );
      }
    });

    test('el resto de las categorías cae en Turístico', () {
      for (final category in ['Hospedaje', 'Tour', 'Artesanías', '']) {
        expect(
          RouteStopCategory.forBusinessCategory(category),
          RouteStopCategory.turistico,
          reason: category,
        );
      }
    });
  });

  group('RouteModel.fromRow', () {
    test(
      'lee image_urls y el embed de profiles cuando la consulta los trae',
      () {
        final route = RouteModel.fromRow({
          'id': 'route-1',
          'owner_id': 'owner-1',
          'title': 'Fin de semana en Granada',
          'days': 2,
          'is_public': true,
          'status': 'active',
          'created_at': '2026-01-01T00:00:00Z',
          'image_urls': ['portada-1.jpg', 'portada-2.jpg'],
          'profiles': {'id': 'owner-1', 'full_name': 'Sofía Ramírez'},
          'route_stops': [],
        });

        expect(route.imageUrls, ['portada-1.jpg', 'portada-2.jpg']);
        expect(route.creatorName, 'Sofía Ramírez');
      },
    );

    test('degrada a vacío/nulo cuando faltan (migración 012 sin correr)', () {
      final route = RouteModel.fromRow({
        'id': 'route-1',
        'owner_id': 'owner-1',
        'title': 'Fin de semana en Granada',
        'days': 2,
        'created_at': '2026-01-01T00:00:00Z',
        'route_stops': [],
      });

      expect(route.imageUrls, isEmpty);
      expect(route.creatorName, isNull);
      expect(route.creatorDisplayName, 'Alguien de Níkara');
    });
  });

  group('RouteStopModel', () {
    test('sourceKey distingue el origen además del id', () {
      const business = RouteStopModel(
        kind: RouteStopKind.business,
        sourceId: 'abc',
        title: 'Negocio',
      );
      const destination = RouteStopModel(
        kind: RouteStopKind.destination,
        sourceId: 'abc',
        title: 'Destino',
      );

      expect(business.sourceKey, 'business:abc');
      expect(business.sourceKey == destination.sourceKey, isFalse);
    });

    test('toInsert manda el id en la columna que corresponde al origen', () {
      const stop = RouteStopModel(
        kind: RouteStopKind.ecoActivity,
        sourceId: 'eco-1',
        title: 'Jornada',
        category: RouteStopCategory.eco,
      );

      final insert = stop.toInsert();
      expect(insert['kind'], 'eco_activity');
      expect(insert['eco_activity_id'], 'eco-1');
      expect(insert['business_id'], isNull);
      expect(insert['destination_id'], isNull);
      expect(insert['category'], 'eco');
    });

    test('fromRow lee la fila que devuelve Supabase', () {
      final stop = RouteStopModel.fromRow({
        'id': 'stop-1',
        'kind': 'business',
        'business_id': 'biz-1',
        'title': 'Restaurante El Malecón',
        'subtitle': 'Granada · 4 km',
        'category': 'gastronomico',
        'day_number': 2,
        'position': 1,
        'latitude': 11.9,
        'longitude': -85.9,
      });

      expect(stop.kind, RouteStopKind.business);
      expect(stop.sourceId, 'biz-1');
      expect(stop.category, RouteStopCategory.gastronomico);
      expect(stop.dayNumber, 2);
      expect(stop.hasCoordinates, isTrue);
    });
  });
}
