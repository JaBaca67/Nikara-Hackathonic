/// Persona jurídica (RUC) o natural (cédula) — `legal_identities` (una fila
/// por usuario, `supabase/sql/023_legal_identities.sql`). El wizard la carga
/// una sola vez por cuenta y la reusa en cualquier negocio/fundación que esa
/// cuenta registre después.
enum LegalIdentityKind {
  juridica('juridica'),
  natural('natural');

  const LegalIdentityKind(this.wireValue);

  final String wireValue;

  /// Etiqueta del selector inicial del gate.
  String get label => switch (this) {
    LegalIdentityKind.juridica => 'Persona jurídica',
    LegalIdentityKind.natural => 'Persona natural',
  };

  /// Qué documento pide cada tipo.
  String get documentLabel => switch (this) {
    LegalIdentityKind.juridica => 'RUC',
    LegalIdentityKind.natural => 'Cédula',
  };

  static LegalIdentityKind fromWire(Object? value) {
    final raw = value?.toString();
    for (final kind in LegalIdentityKind.values) {
      if (kind.wireValue == raw) return kind;
    }
    throw ArgumentError('LegalIdentityKind desconocido: $value');
  }
}

class LegalIdentityModel {
  const LegalIdentityModel({
    required this.id,
    required this.userId,
    required this.kind,
    required this.documentNumber,
    required this.documentPhotoUrl,
    this.documentPhotoBackUrl,
    this.verifiedAt,
    this.verifiedBy,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final LegalIdentityKind kind;
  final String documentNumber;

  /// Pese al nombre de la columna, esto es el **path** dentro del bucket
  /// privado `legal_identities`, no una URL resuelta — el bucket no es
  /// público, así que hace falta firmar la URL recién al mostrarla (ver
  /// `LegalIdentityService.signedUrlFor`); guardar una URL firmada
  /// permanente vencería.
  final String documentPhotoUrl;

  /// Solo persona natural: la cédula se pide "por ambos lados". Nulo en
  /// persona jurídica — el RUC es un solo documento/QR.
  final String? documentPhotoBackUrl;

  /// No nulo = un admin/auditor confirmó el documento. Es independiente del
  /// `status` del negocio/fundación que use esta identidad — ver docstring de
  /// la migración 023.
  final DateTime? verifiedAt;
  final String? verifiedBy;
  final DateTime createdAt;

  bool get isVerified => verifiedAt != null;

  factory LegalIdentityModel.fromRow(Map<String, dynamic> row) {
    return LegalIdentityModel(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      kind: LegalIdentityKind.fromWire(row['kind']),
      documentNumber: row['document_number'] as String? ?? '',
      documentPhotoUrl: row['document_photo_url'] as String? ?? '',
      documentPhotoBackUrl: row['document_photo_back_url'] as String?,
      verifiedAt: DateTime.tryParse(row['verified_at'] as String? ?? ''),
      verifiedBy: row['verified_by'] as String?,
      createdAt:
          DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
