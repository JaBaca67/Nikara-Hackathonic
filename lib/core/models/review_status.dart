/// Estado de revisión de un negocio, fundación o jornada ECO — columna
/// `status` de `businesses`/`organizations`/`eco_activities`
/// (supabase/sql/019_review_status.sql).
///
/// Texto libre en Postgres con un `CHECK` de enum, igual que
/// `notifications.type`: [wireValue] es exactamente el string que viaja a la
/// base. Los nombres coinciden con los valores porque el `CHECK` está escrito
/// en español; no se traducen a inglés para que el identificador de Dart y el
/// dato en la base se lean igual al depurar.
///
/// El cliente **nunca** escribe esta columna con un `update`: aprobar o
/// rechazar pasa por los RPC `review_business`/`review_organization`/
/// `review_eco_activity`, que validan el rol server-side. Lo único que el
/// dueño puede hacer sobre su propia fila es devolverla a [pendiente] al
/// reenviarla tras un rechazo.
enum ReviewStatus {
  pendiente('pendiente'),
  aprobado('aprobado'),
  rechazado('rechazado');

  const ReviewStatus(this.wireValue);

  final String wireValue;

  bool get isPendiente => this == ReviewStatus.pendiente;
  bool get isAprobado => this == ReviewStatus.aprobado;
  bool get isRechazado => this == ReviewStatus.rechazado;

  /// Etiqueta corta para badges y encabezados.
  String get label => switch (this) {
    ReviewStatus.pendiente => 'En revisión',
    ReviewStatus.aprobado => 'Publicado',
    ReviewStatus.rechazado => 'Necesita ajustes',
  };

  /// Un valor ausente o desconocido degrada a [aprobado], no a [pendiente].
  ///
  /// Es deliberado y va en la dirección segura para el usuario: si la
  /// migración 019 todavía no corrió en un entorno, o una fila vieja quedó con
  /// la columna nula, tratarla como pendiente escondería negocios ya
  /// publicados y dejaría la app vacía. El mismo criterio que usa el backfill
  /// de la migración.
  static ReviewStatus fromWire(Object? value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return ReviewStatus.aprobado;
    for (final status in ReviewStatus.values) {
      if (status.wireValue == raw) return status;
    }
    return ReviewStatus.aprobado;
  }
}
