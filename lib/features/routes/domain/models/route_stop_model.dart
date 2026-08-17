/// De dónde salió una parada. Los tres orígenes que el paso 2 del wizard
/// ofrece: un negocio registrado, una jornada ECO o un punto turístico
/// (los destinos estáticos del Inicio, que todavía no son una tabla).
enum RouteStopKind { business, ecoActivity, destination }

RouteStopKind _kindFromString(String? raw) => switch (raw) {
  'business' => RouteStopKind.business,
  'eco_activity' => RouteStopKind.ecoActivity,
  _ => RouteStopKind.destination,
};

String _kindToString(RouteStopKind kind) => switch (kind) {
  RouteStopKind.business => 'business',
  RouteStopKind.ecoActivity => 'eco_activity',
  RouteStopKind.destination => 'destination',
};

/// Los chips de categoría de las tarjetas de ruta, del buscador del paso 2
/// y de los badges del timeline. Conjunto cerrado a propósito: el `category`
/// libre de un negocio se clasifica en uno de estos tres al agregarlo (ver
/// [RouteStopCategory.forBusinessCategory]), igual que `mapPinCategoryFor`
/// reduce ese mismo texto a un bucket de pin.
enum RouteStopCategory {
  turistico('Turístico'),
  eco('ECO'),
  gastronomico('Gastronómico');

  const RouteStopCategory(this.label);

  final String label;

  static RouteStopCategory fromName(String? raw) =>
      RouteStopCategory.values.firstWhere(
        (c) => c.name == raw,
        orElse: () => RouteStopCategory.turistico,
      );

  /// Clasifica el `businesses.category` libre que escribió el dueño. Solo
  /// distingue comida del resto: las otras categorías (hospedaje, tour,
  /// artesanías…) son todas "Turístico" dentro de un itinerario.
  static RouteStopCategory forBusinessCategory(String category) {
    final key = category.toLowerCase();
    if (key.contains('restaurant') ||
        key.contains('comida') ||
        key.contains('gastro') ||
        key.contains('café') ||
        key.contains('cafe') ||
        key.contains('bar')) {
      return RouteStopCategory.gastronomico;
    }
    return RouteStopCategory.turistico;
  }
}

/// Una fila de `public.route_stops` (ver supabase/sql/011_routes.sql): un
/// lugar dentro de un día del itinerario.
///
/// [title]/[subtitle]/[category]/[imagePath]/[latitude]/[longitude] son una
/// copia de los datos del origen al momento de agregarlo — ver el comentario
/// de esas columnas en la migración. Eso es lo que deja pintar el itinerario
/// completo con una sola consulta y lo que hace que una parada siga
/// legible aunque su negocio o jornada de origen desaparezca.
class RouteStopModel {
  const RouteStopModel({
    this.id,
    required this.kind,
    required this.sourceId,
    required this.title,
    this.subtitle = '',
    this.category = RouteStopCategory.turistico,
    this.imagePath,
    this.latitude,
    this.longitude,
    this.dayNumber = 1,
    this.position = 0,
  });

  /// Null mientras la parada solo existe en el wizard, antes de guardarse.
  final String? id;

  final RouteStopKind kind;

  /// El id en su tabla de origen (o el id del destino estático).
  final String sourceId;

  final String title;
  final String subtitle;
  final RouteStopCategory category;
  final String? imagePath;
  final double? latitude;
  final double? longitude;
  final int dayNumber;
  final int position;

  bool get hasCoordinates => latitude != null && longitude != null;

  /// Identidad de la parada de cara al usuario: dos filas distintas que
  /// apuntan al mismo lugar son "la misma parada" para el botón
  /// "Agregado" del paso 2 y para el chequeo de duplicados.
  String get sourceKey => '${_kindToString(kind)}:$sourceId';

  RouteStopModel copyWith({
    String? id,
    int? dayNumber,
    int? position,
    RouteStopCategory? category,
  }) {
    return RouteStopModel(
      id: id ?? this.id,
      kind: kind,
      sourceId: sourceId,
      title: title,
      subtitle: subtitle,
      category: category ?? this.category,
      imagePath: imagePath,
      latitude: latitude,
      longitude: longitude,
      dayNumber: dayNumber ?? this.dayNumber,
      position: position ?? this.position,
    );
  }

  /// El insert de `route_stops`. `route_id` lo agrega [RouteService], que es
  /// quien conoce la ruta destino (la misma parada se inserta con otro
  /// `route_id` al clonar un itinerario).
  Map<String, dynamic> toInsert() => {
    'day_number': dayNumber,
    'position': position,
    'kind': _kindToString(kind),
    'business_id': kind == RouteStopKind.business ? sourceId : null,
    'eco_activity_id': kind == RouteStopKind.ecoActivity ? sourceId : null,
    'destination_id': kind == RouteStopKind.destination ? sourceId : null,
    'title': title,
    'subtitle': subtitle,
    'category': category.name,
    'image_path': imagePath,
    'latitude': latitude,
    'longitude': longitude,
  };

  factory RouteStopModel.fromRow(Map<String, dynamic> row) {
    final kind = _kindFromString(row['kind'] as String?);
    return RouteStopModel(
      id: row['id'] as String,
      kind: kind,
      sourceId: switch (kind) {
        RouteStopKind.business => row['business_id'] as String? ?? '',
        RouteStopKind.ecoActivity => row['eco_activity_id'] as String? ?? '',
        RouteStopKind.destination => row['destination_id'] as String? ?? '',
      },
      title: row['title'] as String? ?? '',
      subtitle: row['subtitle'] as String? ?? '',
      category: RouteStopCategory.fromName(row['category'] as String?),
      imagePath: row['image_path'] as String?,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      dayNumber: (row['day_number'] as num?)?.toInt() ?? 1,
      position: (row['position'] as num?)?.toInt() ?? 0,
    );
  }
}
