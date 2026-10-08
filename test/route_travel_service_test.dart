import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nikara_app/features/routes/data/route_travel_service.dart';
import 'package:nikara_app/features/routes/domain/models/route_model.dart';
import 'package:nikara_app/features/routes/domain/models/route_stop_model.dart';

RouteStopModel stop(
  String id, {
  int day = 1,
  int position = 0,
  String? rowId,
}) => RouteStopModel(
  id: rowId,
  kind: RouteStopKind.destination,
  sourceId: id,
  title: id,
  dayNumber: day,
  position: position,
);
RouteModel route(List<RouteStopModel> stops, {String id = 'route'}) =>
    RouteModel(
      id: id,
      ownerId: 'owner',
      title: 'Granada',
      days: 2,
      createdAt: DateTime(2026),
      stops: stops,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RouteTravelService service;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = RouteTravelService.forTesting();
  });

  test(
    'reiniciar la app recupera visitas sin confundir el mismo lugar en otro día',
    () async {
      final first = stop('cafe', rowId: 'old');
      final second = stop('cafe', day: 2);
      await service.open(route([first, second]), accountId: 'owner');
      await service.setStatus(
        accountId: 'owner',
        routeId: 'route',
        visitKey: first.visitKey,
        status: StopVisitStatus.visited,
      );
      final restarted = RouteTravelService.forTesting();
      await restarted.open(
        route([first.copyWith(id: 'new'), second]),
        accountId: 'owner',
      );
      expect(restarted.active.value!.visitedCount, 1);
      expect(restarted.active.value!.nextForDay(1), isNull);
      expect(restarted.active.value!.nextForDay(2)!.sourceId, 'cafe');
      expect(restarted.active.value!.isFinished, isFalse);
    },
  );

  test('cuentas y rutas tienen progreso independiente', () async {
    final a = stop('a');
    await service.open(route([a]), accountId: 'owner');
    await service.setStatus(
      accountId: 'owner',
      routeId: 'route',
      visitKey: a.visitKey,
      status: StopVisitStatus.visited,
    );
    await service.open(route([a]), accountId: 'other');
    expect(service.active.value!.progress, isEmpty);
    await service.open(route([a], id: 'different'), accountId: 'owner');
    expect(service.active.value!.progress, isEmpty);
  });

  test(
    'escrituras simultáneas conservan ambas visitas; omitir no cuenta como visitar',
    () async {
      final a = stop('a');
      final b = stop('b', position: 1);
      await service.open(route([a, b]), accountId: 'owner');
      await Future.wait([
        service.setStatus(
          accountId: 'owner',
          routeId: 'route',
          visitKey: a.visitKey,
          status: StopVisitStatus.visited,
        ),
        service.setStatus(
          accountId: 'owner',
          routeId: 'route',
          visitKey: b.visitKey,
          status: StopVisitStatus.skipped,
        ),
      ]);
      expect(service.active.value!.visitedCount, 1);
      expect(service.active.value!.isFinished, isTrue);
      await service.setStatus(
        accountId: 'owner',
        routeId: 'route',
        visitKey: b.visitKey,
      );
      expect(service.active.value!.nextForDay(1)!.sourceId, 'b');
      expect(service.active.value!.isFinished, isFalse);
    },
  );

  test('editar elimina el progreso de paradas que ya no existen', () async {
    final a = stop('a');
    final b = stop('b', position: 1);
    await service.open(route([a, b]), accountId: 'owner');
    await service.setStatus(
      accountId: 'owner',
      routeId: 'route',
      visitKey: a.visitKey,
      status: StopVisitStatus.visited,
    );
    await service.open(route([b]), accountId: 'owner');
    expect(service.active.value!.progress, isEmpty);
  });

  test('una caché corrupta no bloquea el itinerario', () async {
    SharedPreferences.setMockInitialValues({
      'route_travel_v1:owner:route': '{broken',
    });
    await service.open(route([stop('a')]), accountId: 'owner');
    expect(service.active.value!.progress, isEmpty);
  });

  test(
    'una solicitud de otra cuenta no modifica progreso ni bloquea escrituras posteriores',
    () async {
      final a = stop('a');
      await service.open(route([a]), accountId: 'owner');
      await expectLater(
        service.setStatus(
          accountId: 'other',
          routeId: 'route',
          visitKey: a.visitKey,
          status: StopVisitStatus.visited,
        ),
        throwsStateError,
      );
      expect(service.active.value!.progress, isEmpty);
      await service.setStatus(
        accountId: 'owner',
        routeId: 'route',
        visitKey: a.visitKey,
        status: StopVisitStatus.visited,
      );
      expect(service.active.value!.visitedCount, 1);
    },
  );
}
