/// Fila de `public.organizations` (supabase/sql/010_organizations.sql); una persona (`owner_id`) puede tener varias.
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

  /// Se guarda sin arroba y en minúsculas; [handleTag] es la versión mostrada.
  final String handle;

  final String description;

  /// Puede ser URL http(s) o ruta local de `image_picker` indistintamente.
  final String? logoUrl;
  final String? bannerUrl;

  final String ownerId;

  /// Siempre `true` hoy por el default de la tabla (sin flujo de auditoría aún); el cliente solo lo lee, nunca lo escribe.
  final bool isVerified;

  final DateTime createdAt;

  String get handleTag => '@$handle';

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.map((p) => p[0]).take(2).join().toUpperCase();
    return letters.isEmpty ? '?' : letters;
  }

  /// Ej: "@Cocibolca Vive!" -> "cocibolcavive".
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
