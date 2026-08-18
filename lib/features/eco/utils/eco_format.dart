/// Formato de fechas del módulo ECO. Vive aquí (y no en cada pantalla)
/// porque la tarjeta del feed, la portada del detalle y la tarjeta flotante
/// de datos rápidos muestran la misma fecha con tres largos distintos.
///
/// Escrito a mano en vez de con `intl`: el proyecto no depende de ese
/// paquete y estas son las únicas fechas con formato del módulo.
library;

const List<String> _kMonths = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

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

/// "9:00 a.m."
String formatEcoTime(DateTime dt) {
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$hour12:$minute ${dt.hour < 12 ? 'a.m.' : 'p.m.'}';
}

/// "24 de mayo, 2025 · 9:00 a.m." — la línea de fecha de la tarjeta
/// extendida del feed.
String formatEcoDateTimeLong(DateTime dt) =>
    '${dt.day} de ${_kMonths[dt.month - 1]}, ${dt.year} · ${formatEcoTime(dt)}';

/// "24 may · 9:00 a.m." — la versión corta para columnas angostas
/// (tarjeta flotante de datos rápidos del detalle).
String formatEcoDateTimeShort(DateTime dt) =>
    '${dt.day} ${_kShortMonths[dt.month - 1]} · ${formatEcoTime(dt)}';

/// "24 may" — solo día y mes, para las líneas de una sola fila donde la
/// hora no cabe (buscador de lugares del wizard de rutas, paradas del
/// itinerario).
String formatEcoDayMonth(DateTime dt) =>
    '${dt.day} ${_kShortMonths[dt.month - 1]}';
