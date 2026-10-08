/// Lectura de `businesses.schedules`, que es texto libre con dos formas
/// posibles conviviendo en la misma columna:
///
/// - **Estructurada**, la que escribe el editor de franjas del wizard:
///   una línea por franja, `1,2,3,4,5: 07:00–18:00` (días como número ISO).
///   Nunca se pensó para mostrarse cruda, pero la pantalla de detalle la
///   pintaba tal cual: un negocio registrado desde el wizard mostraba
///   literalmente "1,2,3,4,5: 07:00–18:00".
/// - **Prosa libre**, la de los datos semilla y la del campo de texto del
///   wizard cuando el dueño prefiere escribirlo a mano ("Lunes a Domingo de
///   11:30 AM a 10:00 PM").
///
/// De acá sale lo que ven las pantallas: líneas legibles para la sección
/// "Horarios" y un valor corto para la tarjeta flotante de datos rápidos,
/// donde la columna mide ~105px y cualquier frase completa se corta.
library;

/// Valor compacto de la tarjeta de datos rápidos: [label] cambia según lo que
/// el texto guardado permita afirmar de verdad — "Hoy" solo cuando se pudo
/// resolver la franja del día actual, "Horario" cuando es prosa libre y no
/// hay forma de saber a qué día corresponde.
class BusinessScheduleSummary {
  const BusinessScheduleSummary({required this.label, required this.value});

  final String label;
  final String value;

  static const unknown = BusinessScheduleSummary(
    label: 'Horario',
    value: 'No especificado',
  );
}

class _ScheduleSlot {
  const _ScheduleSlot(this.weekdays, this.start, this.end);

  /// Días ISO (1 = lunes … 7 = domingo).
  final Set<int> weekdays;

  /// Minutos desde medianoche.
  final int start;
  final int end;

  String get hoursLabel => '${_fmt(start)} – ${_fmt(end)}';

  static String _fmt(int minutes) {
    final hour24 = minutes ~/ 60;
    final minute = minutes % 60;
    final suffix = hour24 < 12 ? 'AM' : 'PM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12:${minute.toString().padLeft(2, '0')} $suffix';
  }

  String get daysLabel {
    if (weekdays.length == 7) return 'Todos los días';
    final sorted = weekdays.toList()..sort();
    final isContiguous = List.generate(
      sorted.length,
      (i) => sorted[i] == sorted.first + i,
    ).every((ok) => ok);
    if (sorted.length == 1) return _dayNames[sorted.first]!;
    if (isContiguous) {
      return '${_dayNames[sorted.first]} a ${_dayNames[sorted.last]}';
    }
    return sorted.map((d) => _dayAbbrev[d]).join(', ');
  }
}

const Map<int, String> _dayNames = {
  1: 'Lunes',
  2: 'Martes',
  3: 'Miércoles',
  4: 'Jueves',
  5: 'Viernes',
  6: 'Sábado',
  7: 'Domingo',
};

const Map<int, String> _dayAbbrev = {
  1: 'L',
  2: 'M',
  3: 'X',
  4: 'J',
  5: 'V',
  6: 'S',
  7: 'D',
};

/// Mismas 3 etiquetas fijas que reconoce el wizard, para datos guardados
/// antes del 2026-09-05.
const Map<String, Set<int>> _legacyDayLabels = {
  'Lunes a viernes': {1, 2, 3, 4, 5},
  'Sábado y domingo': {6, 7},
  'Todos los días': {1, 2, 3, 4, 5, 6, 7},
};

final _structuredHours = RegExp(r'^(\d{1,2}):(\d{2})–(\d{1,2}):(\d{2})$');
final _numericDays = RegExp(r'^\d(,\d)*$');

/// Rango horario dentro de prosa libre: "11:30 AM a 10:00 PM", "8:00–18:00",
/// "de 6 am a 6 pm". Exige dígitos en los dos extremos para no confundir el
/// "a" de "Lunes a Domingo" con un separador de horas.
final _freeformRange = RegExp(
  r'(\d{1,2}(?::\d{2})?)\s*([ap]\.?\s?m\.?)?\s*(?:a|hasta|–|—|-|to)\s*'
  r'(\d{1,2}(?::\d{2})?)\s*([ap]\.?\s?m\.?)?',
  caseSensitive: false,
);

List<_ScheduleSlot>? _parseStructured(String raw) {
  final lines = raw
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList(growable: false);
  if (lines.isEmpty) return null;
  final slots = <_ScheduleSlot>[];
  for (final line in lines) {
    final parts = line.split(': ');
    if (parts.length != 2) return null;
    final hours = _structuredHours.firstMatch(parts[1]);
    if (hours == null) return null;
    final start = int.parse(hours.group(1)!) * 60 + int.parse(hours.group(2)!);
    final end = int.parse(hours.group(3)!) * 60 + int.parse(hours.group(4)!);
    Set<int>? weekdays;
    if (_numericDays.hasMatch(parts[0])) {
      weekdays = parts[0].split(',').map(int.parse).toSet();
      if (weekdays.any((d) => d < 1 || d > 7)) return null;
    } else {
      weekdays = _legacyDayLabels[parts[0]];
    }
    if (weekdays == null || weekdays.isEmpty) return null;
    slots.add(_ScheduleSlot(weekdays, start, end));
  }
  return slots;
}

/// Líneas legibles para la sección "Horarios". Para prosa libre devuelve el
/// texto tal cual partido por saltos de línea — nunca lo reescribe, misma
/// regla que el wizard.
List<String> businessScheduleLines(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return const [];
  final slots = _parseStructured(text);
  if (slots == null) {
    return text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList(growable: false);
  }
  return slots
      .map((s) => '${s.daysLabel} · ${s.hoursLabel}')
      .toList(growable: false);
}

String _normalizeMeridiem(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  return raw.replaceAll(RegExp(r'[.\s]'), '').toUpperCase();
}

/// Rango horario corto sacado de prosa libre, o `null` si no hay ninguno
/// reconocible.
String? _freeformHours(String line) {
  final match = _freeformRange.firstMatch(line);
  if (match == null) return null;
  final endMeridiem = _normalizeMeridiem(match.group(4));
  // "11:30 a 10:00 PM": el AM/PM de la izquierda suele omitirse, pero
  // repetir el de la derecha diría una hora falsa, así que se deja vacío.
  final startMeridiem = _normalizeMeridiem(match.group(2));
  final start = startMeridiem.isEmpty
      ? match.group(1)!
      : '${match.group(1)} $startMeridiem';
  final end = endMeridiem.isEmpty
      ? match.group(3)!
      : '${match.group(3)} $endMeridiem';
  return '$start – $end';
}

/// Valor corto para la tarjeta de datos rápidos del detalle.
BusinessScheduleSummary businessScheduleSummary(String raw, {DateTime? now}) {
  final text = raw.trim();
  if (text.isEmpty) return BusinessScheduleSummary.unknown;

  final slots = _parseStructured(text);
  if (slots != null) {
    final weekday = (now ?? DateTime.now()).weekday;
    final today = slots.where((s) => s.weekdays.contains(weekday)).toList();
    if (today.isEmpty) {
      return const BusinessScheduleSummary(label: 'Hoy', value: 'Cerrado');
    }
    return BusinessScheduleSummary(
      label: 'Hoy',
      // Con más de una franja el mismo día ("8–12 y 14–18") la tarjeta solo
      // muestra la primera; las dos completas están en la sección Horarios.
      value: today.first.hoursLabel,
    );
  }

  final firstLine = text.split('\n').first.trim();
  if (RegExp(
    r'24\s*(horas|hrs|h\b)',
    caseSensitive: false,
  ).hasMatch(firstLine)) {
    return const BusinessScheduleSummary(label: 'Horario', value: '24 horas');
  }
  final hours = _freeformHours(firstLine);
  return BusinessScheduleSummary(label: 'Horario', value: hours ?? firstLine);
}
