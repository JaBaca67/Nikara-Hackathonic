import 'package:flutter_test/flutter_test.dart';
import 'package:nikara_app/features/routes/domain/models/route_stop_model.dart';
import 'package:nikara_app/features/routes/domain/route_planner.dart';

RouteStopModel stop(String id, {int day = 1, int position = 0, double? lng}) =>
    RouteStopModel(
      kind: RouteStopKind.destination,
      sourceId: id,
      title: id,
      dayNumber: day,
      position: position,
      latitude: lng == null ? null : 12,
      longitude: lng,
    );

void main() {
  test('buscar ignora mayúsculas y tildes', () {
    expect(RoutePlanner.searchKey('  CAÑÓN de León  '), 'canon de leon');
  });
  test('el trazado no conecta días ni salta paradas sin ubicación', () {
    final legs = RoutePlanner.legs([
      stop('a', lng: -86),
      stop('missing', position: 1),
      stop('b', position: 2, lng: -85.9),
      stop('c', position: 3, lng: -85.8),
      stop('d', day: 2, lng: -85.7),
    ]);
    expect(legs.map((leg) => '${leg.$1.sourceId}>${leg.$2.sourceId}'), ['b>c']);
  });
  test(
    'cercanía conserva el inicio, los lugares sin coordenadas y otros días',
    () {
      final result = RoutePlanner.suggestOrder([
        stop('a', lng: -86),
        stop('far', position: 1, lng: -85),
        stop('near', position: 2, lng: -85.9),
        stop('missing', position: 3),
        stop('other', day: 2, lng: -84),
      ], 1);
      expect(result.map((s) => s.sourceId), [
        'a',
        'near',
        'far',
        'missing',
        'other',
      ]);
      expect(result.map((s) => s.position), [0, 1, 2, 3, 0]);
    },
  );
  test('coordenadas inválidas no habilitan la navegación', () {
    for (final lng in [double.nan, double.infinity, 181.0, -181.0]) {
      expect(stop('invalid', lng: lng).hasCoordinates, isFalse);
    }
    expect(stop('valid', lng: -86).hasCoordinates, isTrue);
    expect(
      stop('same', lng: -86).visitKey,
      isNot(stop('same', day: 2, lng: -86).visitKey),
    );
  });
}
