/// Un anuncio publicado manualmente por el dueño de un negocio (promo del
/// día, un pase de día puntual, un evento, un aviso de cierre) — canal de
/// novedades tipo "canal de WhatsApp", no un sistema de ofertas con fechas
/// de vigencia/cupos (ver nota en `business_detail_screen.dart` sobre por
/// qué este proyecto no modela reservas en vivo).
class BusinessPostModel {
  const BusinessPostModel({
    required this.id,
    required this.businessId,
    required this.ownerId,
    required this.body,
    this.imageUrl,
    required this.createdAt,
  });

  final String id;
  final String businessId;
  final String ownerId;
  final String body;
  final String? imageUrl;
  final DateTime createdAt;

  /// Antigüedad en formato corto ("hace 2 h") — mismo formato que
  /// `AppNotification.relativeTime`, duplicado acá en vez de compartido
  /// porque son modelos sin relación de dependencia entre sí. [now] existe
  /// para que los tests no dependan del reloj real.
  String relativeTime({DateTime? now}) {
    final elapsed = (now ?? DateTime.now()).difference(createdAt);
    if (elapsed.inMinutes < 1) return 'ahora';
    if (elapsed.inMinutes < 60) return 'hace ${elapsed.inMinutes} min';
    if (elapsed.inHours < 24) return 'hace ${elapsed.inHours} h';
    if (elapsed.inDays == 1) return 'ayer';
    if (elapsed.inDays < 7) return 'hace ${elapsed.inDays} d';
    if (elapsed.inDays < 30) return 'hace ${elapsed.inDays ~/ 7} sem';
    final months = elapsed.inDays ~/ 30;
    return months <= 1 ? 'hace 1 mes' : 'hace $months meses';
  }

  factory BusinessPostModel.fromRow(Map<String, dynamic> row) {
    return BusinessPostModel(
      id: row['id'] as String,
      businessId: row['business_id'] as String,
      ownerId: row['owner_id'] as String? ?? '',
      body: row['body'] as String? ?? '',
      imageUrl: row['image_url'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }
}
