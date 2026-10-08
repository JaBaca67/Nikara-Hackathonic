import 'package:geolocator/geolocator.dart';
import 'models/route_model.dart';
import 'models/route_stop_model.dart';

/// Suggestions use geographic proximity, never estimated road travel times.
abstract final class RoutePlanner {
  static String searchKey(String text) {
    const accents = 'áéíóúüñ';
    const plain = 'aeiouun';
    var result = text.trim().toLowerCase();
    for (var i = 0; i < accents.length; i++) {
      result = result.replaceAll(accents[i], plain[i]);
    }
    return result;
  }

  /// Keep the starting point and unlocated stops in place; reorder only the
  /// uninterrupted, located runs within this day. Never bridge unknown places.
  static List<RouteStopModel> suggestOrder(
    List<RouteStopModel> stops,
    int day,
  ) {
    final ordered = RouteModel.sortStops(stops);
    final result = <RouteStopModel>[];
    var run = <RouteStopModel>[];
    void flush() {
      if (run.isEmpty) return;
      final remaining = [...run.skip(1)];
      var current = run.first;
      result.add(current);
      while (remaining.isNotEmpty) {
        remaining.sort(
          (a, b) => distance(current, a).compareTo(distance(current, b)),
        );
        current = remaining.removeAt(0);
        result.add(current);
      }
      run = [];
    }

    for (final stop in ordered) {
      if (stop.dayNumber == day && stop.hasCoordinates) {
        run.add(stop);
      } else {
        flush();
        result.add(stop);
      }
    }
    flush();
    final positions = <int, int>{};
    return [
      for (final stop in result)
        stop.copyWith(
          position: positions[stop.dayNumber] =
              (positions[stop.dayNumber] ?? -1) + 1,
        ),
    ];
  }

  static double distance(RouteStopModel a, RouteStopModel b) =>
      Geolocator.distanceBetween(
        a.latitude!,
        a.longitude!,
        b.latitude!,
        b.longitude!,
      );

  static List<(RouteStopModel, RouteStopModel)> legs(
    List<RouteStopModel> stops,
  ) {
    final sorted = RouteModel.sortStops(stops);
    return [
      for (var i = 1; i < sorted.length; i++)
        if (sorted[i - 1].dayNumber == sorted[i].dayNumber &&
            sorted[i - 1].hasCoordinates &&
            sorted[i].hasCoordinates)
          (sorted[i - 1], sorted[i]),
    ];
  }
}
