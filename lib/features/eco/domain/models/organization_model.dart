/// Una fila de `public.organizations` (ver supabase/sql/010_organizations.sql)
/// — la fundación/organización en cuyo nombre se puede publicar una jornada
/// ECO. Su dueño es una persona (`owner_id` -> `profiles.id`); una misma
/// persona puede tener varias.
class OrganizationModel {
  const OrganizationModel({
    required this.id,
    required this.name,
    required this.handle,
    this.description = '',
    this.logoUrl,
    this.bannerUrl,
    required this.ownerId,
    this.isVerified = true,
    required this.createdAt,
  });

  final String id;
  final String name;

  /// Sin arroba y en minúsculas tal como se guarda ("cocibolcavive") —
  /// [handleTag] es la versión que se muestra.
  final String handle;

  final String description;

  /// URL http(s) o ruta local de `image_picker`, indistintamente — ver el
  /// comentario de la columna en la migración.
  final String? logoUrl;
  final String? bannerUrl;

  final String ownerId;

  /// `organizations.is_verified` — hoy siempre `true` por el default de la
  /// tabla (fase de prueba, sin flujo de auditoría todavía). El cliente
  /// nunca lo escribe: solo lo lee para pintar el badge "VERIFICADO".
  final bool isVerified;

  final DateTime createdAt;

  String get handleTag => '@$handle';

  /// Iniciales para el avatar cuando la fundación no subió logo — mismo
  /// recurso que usa `UserModel.initials`.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.map((p) => p[0]).take(2).join().toUpperCase();
    return letters.isEmpty ? '?' : letters;
  }

  /// Normaliza lo que la persona escribió en el campo "Handle" a lo que
  /// guarda la columna: sin arroba, en minúsculas y sin espacios ni
  /// caracteres raros ("@Cocibolca Vive!" -> "cocibolcavive").
  static String normalizeHandle(String raw) {
    return raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._]'), '')
        .replaceAll(RegExp(r'^[._]+'), '');
  }

  factory OrganizationModel.fromRow(Map<String, dynamic> row) {
    return OrganizationModel(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      handle: row['handle'] as String? ?? '',
      description: row['description'] as String? ?? '',
      logoUrl: row['logo_url'] as String?,
      bannerUrl: row['banner_url'] as String?,
      ownerId: row['owner_id'] as String? ?? '',
      isVerified: row['is_verified'] as bool? ?? false,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
