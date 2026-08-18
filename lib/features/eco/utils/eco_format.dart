/// Escrito a mano en vez de con `intl`: el proyecto no depende de ese paquete y estas son las únicas fechas formateadas del módulo.
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

/// "24 de mayo, 2025 · 9:00 a.m."
String formatEcoDateTimeLong(DateTime dt) =>
    '${dt.day} de ${_kMonths[dt.month - 1]}, ${dt.year} · ${formatEcoTime(dt)}';

/// "24 may · 9:00 a.m." — versión corta para columnas angostas.
String formatEcoDateTimeShort(DateTime dt) =>
    '${dt.day} ${_kShortMonths[dt.month - 1]} · ${formatEcoTime(dt)}';

/// "24 may" — para líneas de una sola fila donde la hora no cabe.
String formatEcoDayMonth(DateTime dt) =>
    '${dt.day} ${_kShortMonths[dt.month - 1]}';
