import 'package:nikara_app/features/routes/domain/models/route_stop_model.dart';

/// Las dos pestañas pill de `RoutesMainScreen`.
enum RouteStatus {
  active('Activas'),
  completed('Completadas');

  const RouteStatus(this.label);

  final String label;

  static RouteStatus fromName(String? raw) =>
      raw == 'completed' ? RouteStatus.completed : RouteStatus.active;
}

/// Una fila de `public.routes` (ver supabase/sql/011_routes.sql) con sus
/// paradas embebidas — un itinerario de N días armado con negocios,
/// jornadas ECO y puntos turísticos.
class RouteModel {
  const RouteModel({
    required this.id,
    required this.ownerId,
    required this.title,
    this.days = 1,
    this.isPublic = false,
    this.status = RouteStatus.active,
    this.clonedFromRouteId,
    required this.createdAt,
    this.stops = const [],
    this.imageUrls = const [],
    this.creatorName,
    this.creatorAvatarUrl,
  });

  final String id;
  final String ownerId;
  final String title;
  final int days;
  final bool isPublic;
  final RouteStatus status;

  /// De qué ruta se copió esta, cuando nació de "Copiar / Usar esta ruta".
  final String? clonedFromRouteId;

  final DateTime createdAt;

  /// Ya ordenadas por día y posición — ver [RouteService] y [sortStops].
  final List<RouteStopModel> stops;

  /// Fotos de portada que la persona subió al crear (o editar) la ruta —
  /// cada elemento es una URL http(s) o la ruta local de `image_picker`,
  /// igual que `organizations.logo_url`. [coverImages] las prioriza sobre
  /// las fotos prestadas de las paradas.
  final List<String> imageUrls;

  /// `profiles.full_name` de [ownerId], vía el embed de [RouteService] —
  /// nulo cuando la consulta no lo trajo (por ejemplo `createRoute`, que
  /// no vuelve a pedirlo porque el dueño es siempre quien acaba de crearla).
  /// Lo que pinta la cabecera "de {creador}" de la pestaña Comunidad.
  final String? creatorName;

  /// `profiles.avatar_url` de [ownerId], por el mismo embed que [creatorName].
  final String? creatorAvatarUrl;

  int get stopCount => stops.length;

  bool get isClone => clonedFromRouteId != null;

  bool isOwnedBy(String? userId) => userId != null && userId == ownerId;

  /// "Alguien de Níkara" cuando [creatorName] no llegó a cargarse — nunca
  /// un nombre inventado, mismo criterio que `organizerDisplayName` del
  /// módulo ECO.
  String get creatorDisplayName {
    final name = creatorName;
    return (name == null || name.trim().isEmpty) ? 'Alguien de Níkara' : name;
  }

  /// Iniciales del creador, respaldo cuando no tiene [creatorAvatarUrl].
  String get creatorInitials {
    final parts = creatorDisplayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty);
    final letters = parts.map((p) => p[0]).take(2).join().toUpperCase();
    return letters.isEmpty ? '?' : letters;
  }

  /// "2 días · 5 paradas" — la línea de meta de la tarjeta, del detalle y
  /// del selector "Agregar a ruta".
  String get summaryLine =>
      '$days ${days == 1 ? 'día' : 'días'} · $stopCount '
      '${stopCount == 1 ? 'parada' : 'paradas'}';

  /// Las categorías presentes en la ruta, en el orden en que aparecen —
  /// los chips de la tarjeta ("Turístico", "Gastronómico", "ECO").
  List<RouteStopCategory> get categories {
    final seen = <RouteStopCategory>[];
    for (final stop in stops) {
      if (!seen.contains(stop.category)) seen.add(stop.category);
    }
    return seen;
  }

  /// Las imágenes del collage de la tarjeta: primero las fotos que la
  /// persona subió a mano ([imageUrls]) y, si no completan [max], se
  /// rellena con las fotos prestadas de las paradas agregadas. Puede
  /// devolver menos de [max] (o ninguna) — el collage llena los huecos con
  /// el placeholder, nunca inventa una foto.
  List<String> coverImages({int max = 3}) {
    final images = <String>[];
    for (final url in imageUrls) {
      if (url.isNotEmpty && !images.contains(url)) images.add(url);
      if (images.length == max) return images;
    }
    for (final stop in stops) {
      final path = stop.imagePath;
      if (path != null && path.isNotEmpty && !images.contains(path)) {
        images.add(path);
        if (images.length == max) break;
      }
    }
    return images;
  }

  List<RouteStopModel> stopsForDay(int day) =>
      stops.where((s) => s.dayNumber == day).toList(growable: false);

  /// Todas las paradas con coordenadas, en orden de recorrido — lo que el
  /// mini-mapa numera y une con la polilínea.
  List<RouteStopModel> get mappableStops =>
      stops.where((s) => s.hasCoordinates).toList(growable: false);

  RouteModel copyWith({
    String? title,
    int? days,
    bool? isPublic,
    RouteStatus? status,
    List<RouteStopModel>? stops,
    List<String>? imageUrls,
  }) {
    return RouteModel(
      id: id,
      ownerId: ownerId,
      title: title ?? this.title,
      days: days ?? this.days,
      isPublic: isPublic ?? this.isPublic,
      status: status ?? this.status,
      clonedFromRouteId: clonedFromRouteId,
      createdAt: createdAt,
      stops: stops ?? this.stops,
      imageUrls: imageUrls ?? this.imageUrls,
      creatorName: creatorName,
      creatorAvatarUrl: creatorAvatarUrl,
    );
  }

  /// Orden canónico de las paradas: por día y, dentro del día, por la
  /// posición que dejó el paso 3 del wizard. Se aplica al leer de Supabase
  /// (PostgREST no garantiza el orden de una relación embebida) y después
  /// de cada reordenamiento local.
  static List<RouteStopModel> sortStops(List<RouteStopModel> stops) {
    final sorted = [...stops];
    sorted.sort((a, b) {
      final byDay = a.dayNumber.compareTo(b.dayNumber);
      return byDay != 0 ? byDay : a.position.compareTo(b.position);
    });
    return List.unmodifiable(sorted);
  }

  /// Renumera `position` de 0 en adelante dentro de cada día — se llama
  /// después de mover, borrar o reubicar paradas para que lo que se guarda
  /// no tenga huecos ni empates.
  static List<RouteStopModel> reindex(List<RouteStopModel> stops) {
    final byDay = <int, int>{};
    return [
      for (final stop in sortStops(stops))
        stop.copyWith(
          position: byDay[stop.dayNumber] = (byDay[stop.dayNumber] ?? -1) + 1,
        ),
    ];
  }

  factory RouteModel.fromRow(Map<String, dynamic> row) {
    final stops = (row['route_stops'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(RouteStopModel.fromRow)
        .toList();
    // `profiles` es un embed to-one por `owner_id` (ver RouteService._select)
    // — un mapa cuando la consulta lo pidió, ausente si no (por ejemplo el
    // insert de `createRoute`, que no vuelve a pedirlo).
    final owner = row['profiles'] as Map<String, dynamic>?;
    return RouteModel(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String? ?? '',
      title: row['title'] as String? ?? '',
      days: (row['days'] as num?)?.toInt() ?? 1,
      isPublic: row['is_public'] as bool? ?? false,
      status: RouteStatus.fromName(row['status'] as String?),
      clonedFromRouteId: row['cloned_from_route_id'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      stops: sortStops(stops),
      // Ausente (no `[]`) hasta que corra la migración 012 — `select('*')`
      // simplemente no trae la columna, sin lanzar ningún error.
      imageUrls:
          (row['image_urls'] as List<dynamic>?)?.cast<String>() ?? const [],
      creatorName: owner?['full_name'] as String?,
      creatorAvatarUrl: owner?['avatar_url'] as String?,
    );
  }
}
