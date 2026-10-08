/// Fechas y horas en español escritas a mano: el proyecto no depende de `intl`
/// (ver también `lib/features/eco/utils/eco_format.dart`, que cubre otro
/// formato del módulo ECO).
library;

const List<String> _kShortMonths = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// "8 oct 2026 · 3:17 p. m." en la hora local del teléfono.
///
/// Las fechas que llegan de Supabase vienen en UTC (`created_at`), así que se
/// pasan a hora local antes de formatear; una fecha que ya es local queda tal
/// cual. Con [dateTime] nulo devuelve una cadena vacía para que quien llama
/// pueda omitir la línea en vez de mostrar una fecha inventada.
String formatShortDateTime(DateTime? dateTime) {
  if (dateTime == null) return '';
  final local = dateTime.toLocal();
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final meridiem = local.hour < 12 ? 'a. m.' : 'p. m.';
  return '${local.day} ${_kShortMonths[local.month - 1]} ${local.year} · '
      '$hour12:$minute $meridiem';
}
