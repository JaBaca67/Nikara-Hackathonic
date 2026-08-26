/// Verbalización en español de las indicaciones de navegación.
///
/// Vive separado del motor porque es lo único de la navegación que se juzga
/// "de oído": un motor TTS lee "200 m" como "doscientos eme" y "1.2 km" como
/// "uno punto dos ka eme". Convertir número y unidad a palabras antes de
/// hablar es lo que hace que la indicación suene a navegador y no a una
/// máquina leyendo una etiqueta de UI.
///
/// Todo acá es función pura: se testea sin dispositivo ni motor de voz.
library;

import 'package:nikara_app/core/services/directions_service.dart';
import 'package:nikara_app/features/map/domain/navigation_engine.dart';

const List<String> _units = [
  'cero',
  'uno',
  'dos',
  'tres',
  'cuatro',
  'cinco',
  'seis',
  'siete',
  'ocho',
  'nueve',
  'diez',
  'once',
  'doce',
  'trece',
  'catorce',
  'quince',
  'dieciséis',
  'diecisiete',
  'dieciocho',
  'diecinueve',
  'veinte',
  'veintiuno',
  'veintidós',
  'veintitrés',
  'veinticuatro',
  'veinticinco',
  'veintiséis',
  'veintisiete',
  'veintiocho',
  'veintinueve',
];

const List<String> _tens = [
  '',
  '',
  '',
  'treinta',
  'cuarenta',
  'cincuenta',
  'sesenta',
  'setenta',
  'ochenta',
  'noventa',
];

const List<String> _hundreds = [
  '',
  'ciento',
  'doscientos',
  'trescientos',
  'cuatrocientos',
  'quinientos',
  'seiscientos',
  'setecientos',
  'ochocientos',
  'novecientos',
];

/// Escribe [value] en palabras (0 a 999 999). Género masculino, que es el que
/// piden "metros" y "kilómetros".
String spellSpanishNumber(int value) {
  if (value < 0) return spellSpanishNumber(-value);
  if (value < 30) return _units[value];
  if (value < 100) {
    final ten = _tens[value ~/ 10];
    final unit = value % 10;
    return unit == 0 ? ten : '$ten y ${_units[unit]}';
  }
  if (value == 100) return 'cien';
  if (value < 1000) {
    final hundred = _hundreds[value ~/ 100];
    final rest = value % 100;
    return rest == 0 ? hundred : '$hundred ${spellSpanishNumber(rest)}';
  }
  final thousands = value ~/ 1000;
  final rest = value % 1000;
  final prefix = thousands == 1
      ? 'mil'
      : '${_apocopate(spellSpanishNumber(thousands))} mil';
  return rest == 0 ? prefix : '$prefix ${spellSpanishNumber(rest)}';
}

/// "uno" -> "un" delante de un sustantivo masculino ("un kilómetro").
String _apocopate(String spelled) {
  if (spelled == 'uno') return 'un';
  if (spelled.endsWith('veintiuno')) {
    return '${spelled.substring(0, spelled.length - 9)}veintiún';
  }
  if (spelled.endsWith(' uno')) {
    return '${spelled.substring(0, spelled.length - 4)} un';
  }
  return spelled;
}

/// Redondea a un número que un conductor pueda usar: nadie navega con
/// "ciento ochenta y siete metros".
int roundSpokenMeters(double meters) {
  if (meters < 100) return (meters / 10).round() * 10;
  if (meters < 1000) return (meters / 50).round() * 50;
  return (meters / 100).round() * 100;
}

/// Distancia hablada: "cincuenta metros", "doscientos metros",
/// "un kilómetro doscientos metros", "quince kilómetros".
String verbalizeDistance(double meters) {
  if (meters < 15) return 'unos metros';
  if (meters < 1000) {
    final rounded = roundSpokenMeters(meters);
    if (rounded <= 0) return 'unos metros';
    if (rounded >= 1000) return 'un kilómetro';
    return '${_apocopate(spellSpanishNumber(rounded))} metros';
  }

  final hundreds = (meters / 100).round();
  final kilometers = hundreds ~/ 10;
  final restMeters = (hundreds % 10) * 100;

  // Arriba de 10 km el detalle de centenas es ruido; se redondea al kilómetro.
  if (kilometers >= 10) {
    final rounded = (meters / 1000).round();
    return '${_apocopate(spellSpanishNumber(rounded))} kilómetros';
  }

  final kmWord = kilometers == 1
      ? 'un kilómetro'
      : '${spellSpanishNumber(kilometers)} kilómetros';
  if (restMeters == 0) return kmWord;
  return '$kmWord ${_apocopate(spellSpanishNumber(restMeters))} metros';
}

/// Etiqueta corta para el HUD (no para hablar): "200 m", "1,2 km".
/// Coma decimal, que es la convención en español.
String formatDistanceLabel(double meters) {
  if (meters < 1000) {
    final rounded = meters < 100
        ? (meters / 10).round() * 10
        : (meters / 50).round() * 50;
    return '${rounded.clamp(0, 999)} m';
  }
  final km = meters / 1000;
  if (km >= 10) return '${km.round()} km';
  return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
}

/// Limpia el texto de la maniobra antes de leerlo o mostrarlo.
///
/// Google mete en `html_instructions` cosas que no se deben leer en voz alta:
/// una segunda frase de destino pegada a la maniobra, aclaraciones entre
/// paréntesis y códigos de ruta con barras ("NIC-2/Carretera Sur").
String sanitizeInstruction(String instruction) {
  var text = instruction
      .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  // Google separa la maniobra de la aclaración con "Destino..." o
  // "Pasa por..."; la primera frase es la que importa al conductor.
  final cut = RegExp(
    r'\.\s+(Destino|El destino|Pasarás|Pasa por|Continúa durante)\b',
  ).firstMatch(text);
  if (cut != null) text = text.substring(0, cut.start);
  if (text.endsWith('.')) text = text.substring(0, text.length - 1);
  return text.trim();
}

String _lowerFirst(String text) {
  if (text.isEmpty) return text;
  // Solo se baja la inicial si la palabra no es un nombre propio evidente
  // (dos mayúsculas seguidas, típico de "NIC-2").
  if (text.length > 1 && text[1] == text[1].toUpperCase() && text[1] != ' ') {
    return text;
  }
  return text[0].toLowerCase() + text.substring(1);
}

/// Frase completa a leer por TTS para un anuncio de maniobra.
///
/// [nextInstruction] encadena la maniobra siguiente cuando las dos están muy
/// pegadas ("girá a la derecha y luego, a la izquierda") — es la información
/// que evita el clásico "me pasé la segunda".
String verbalizeManeuver({
  required ManeuverCue cue,
  required String instruction,
  String? nextInstruction,
  double? nextManeuverDistanceMeters,
  double chainThresholdMeters = 150,
}) {
  final clean = sanitizeInstruction(instruction);
  final head = cue.isImmediate
      ? clean
      : 'En ${verbalizeDistance(cue.distanceMeters)}, ${_lowerFirst(clean)}';

  if (nextInstruction == null ||
      nextManeuverDistanceMeters == null ||
      nextManeuverDistanceMeters > chainThresholdMeters) {
    return head;
  }
  final chained = sanitizeInstruction(nextInstruction);
  if (chained.isEmpty) return head;
  return '$head, y luego ${_lowerFirst(chained)}';
}

/// Frase de llegada — la ruta ya no tiene más maniobras.
String verbalizeArrival(String destinationName) {
  return destinationName.isEmpty
      ? 'Llegaste a tu destino'
      : 'Llegaste a $destinationName';
}

/// Aviso de recálculo, corto a propósito: suena mientras el conductor sigue
/// moviéndose y no debe tapar la maniobra que viene después.
const String kRerouteSpeech = 'Recalculando la ruta';

/// Texto que se lee al arrancar el viaje.
String verbalizeTripStart(DirectionsRoute route, String destinationName) {
  final distance = verbalizeDistance(route.distanceMeters.toDouble());
  final base = 'Iniciando viaje a $destinationName, $distance';
  if (route.steps.isEmpty) return base;
  return '$base. ${sanitizeInstruction(route.steps.first.instruction)}';
}
