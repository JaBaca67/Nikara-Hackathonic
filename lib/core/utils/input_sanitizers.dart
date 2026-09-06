/// Normalización ("atomización") de los datos que el usuario escribe, aplicada
/// en la capa de servicio justo antes de cada `insert`/`update` a Supabase.
///
/// Por qué acá y no en las pantallas: es el único punto por el que pasan
/// **todas** las escrituras de un mismo dato, sin importar desde qué formulario
/// vengan. Un `TextFormField` puede olvidarse de un `.trim()`; el servicio no.
///
/// Qué NO hace esto: "escapar" comillas o filtrar palabras clave de SQL.
/// PostgREST parametriza cada valor, así que una blacklist artesanal no agrega
/// seguridad y sí corrompe texto legítimo ("Doña O'Connor", "SELECT café").
/// Lo que sí corresponde es **normalizar** (mismo dato ⇒ misma
/// representación) y **acotar** (longitudes máximas), que es lo que hay acá.
///
/// Todas las funciones son puras y sin dependencias de Flutter: se pueden
/// testear sin `TestWidgetsFlutterBinding`.
library;

/// Topes de longitud por tipo de campo.
///
/// Ninguna columna de `docs/database_erd.md` es `varchar(n)` — son todas
/// `text`, sin límite en Postgres. El límite existe igual porque un campo sin
/// tope es a la vez un problema de UI (desborda tarjetas y listas, ver
/// `test/overflow_audit_test.dart`) y de costo (una descripción de 2 MB se
/// descarga en cada listado). Los valores salen de lo que la UI puede mostrar,
/// no de una restricción del esquema.
abstract final class InputLimits {
  /// Nombre de persona, negocio u organización.
  static const int name = 120;

  /// Título de una jornada ECO o de una ruta.
  static const int title = 120;

  /// Categoría, ciudad, etiqueta corta de ubicación.
  static const int shortLabel = 80;

  /// Dirección escrita a mano.
  static const int address = 200;

  /// Horarios de atención, notas de acceso, subtítulos denormalizados.
  static const int mediumText = 300;

  /// Descripción larga de negocio, jornada u organización.
  static const int description = 2000;

  /// Handle de red social (Instagram tolera 30; Facebook, más).
  static const int handle = 60;

  /// Máximo de un `local@dominio` según RFC 5321.
  static const int email = 254;

  /// Un requisito suelto de la lista de una jornada ECO.
  static const int listItem = 120;

  /// Cuántos ítems se aceptan en una lista de texto (`requirements`).
  static const int listLength = 30;
}

// ---------------------------------------------------------------------------
// Limpieza base
// ---------------------------------------------------------------------------

/// Caracteres invisibles que hay que borrar, no reemplazar por espacio:
/// controles C0/C1 (excepto los saltos de línea, que se tratan aparte), DEL,
/// zero-width space/non-joiner/joiner, word-joiner, BOM y los controles
/// bidireccionales (`U+202A-202E`, `U+2066-2069`).
///
/// El BOM y los zero-width son el caso real más molesto: se cuelan al pegar
/// desde WhatsApp o Word, hacen que dos nombres idénticos a la vista no sean
/// iguales para Postgres, y son invisibles al depurar.
final RegExp _invisibleChars = RegExp(
  '[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F'
  '\u200B-\u200F\u2028\u2029\u202A-\u202E\u2060\u2066-\u2069\uFEFF]',
);

/// Espacios "raros" que sí representan un espacio real y por eso se reemplazan
/// en vez de borrarse: NBSP, espacios tipográficos, espacio ideográfico.
final RegExp _exoticSpaces = RegExp(
  '[\u0009\u00A0\u1680\u2000-\u200A\u202F\u205F\u3000]',
);

final RegExp _singleQuotes = RegExp('[\u2018\u2019\u201A\u201B\u2032]');
final RegExp _doubleQuotes = RegExp('[\u201C\u201D\u201E\u201F\u2033]');

/// Deja el texto en su forma comparable sin decidir todavía qué hacer con los
/// saltos de línea: normaliza fin de línea, borra invisibles, unifica espacios
/// exóticos y endereza las comillas curvas que insertan iOS y Word.
///
/// Las comillas angulares españolas («») **no** se tocan: son ortografía
/// válida, no basura de autocorrección.
String _normalizeChars(String raw) {
  return raw
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll(_invisibleChars, '')
      .replaceAll(_exoticSpaces, ' ')
      .replaceAll(_singleQuotes, "'")
      .replaceAll(_doubleQuotes, '"');
}

/// Corta en [maxLength] sin partir un par sustituto (emoji) por la mitad, que
/// produciría un carácter inválido en UTF-8 y un error críptico de Postgres.
String _truncate(String value, int maxLength) {
  if (value.length <= maxLength) return value;
  var end = maxLength;
  final unit = value.codeUnitAt(end - 1);
  const highSurrogateStart = 0xD800;
  const highSurrogateEnd = 0xDBFF;
  if (unit >= highSurrogateStart && unit <= highSurrogateEnd) end -= 1;
  return value.substring(0, end).trimRight();
}

// ---------------------------------------------------------------------------
// Texto
// ---------------------------------------------------------------------------

/// Texto de una sola línea (nombres, títulos, categorías, direcciones).
///
/// Colapsa cualquier espacio en blanco —saltos de línea incluidos— en un solo
/// espacio: un nombre de negocio con un `\n` adentro rompe el layout de las
/// tarjetas y no aporta nada.
String sanitizeText(String? raw, {int maxLength = InputLimits.mediumText}) {
  if (raw == null) return '';
  final normalized = _normalizeChars(
    raw,
  ).replaceAll(RegExp(r'\s+'), ' ').trim();
  return _truncate(normalized, maxLength);
}

/// Igual que [sanitizeText] pero devuelve `null` en vez de `''`, para columnas
/// nullable donde "vacío" y "sin dato" no son lo mismo.
String? sanitizeOptionalText(
  String? raw, {
  int maxLength = InputLimits.mediumText,
}) {
  final value = sanitizeText(raw, maxLength: maxLength);
  return value.isEmpty ? null : value;
}

/// Texto largo que sí puede tener párrafos (descripciones).
///
/// Conserva el salto de párrafo pero corta la escalera de enters: 3 o más
/// saltos seguidos quedan en 2 (un párrafo), y cada línea se recorta a los
/// costados. Así "descripción con 40 enters al final" deja de ser una tarjeta
/// de 3 pantallas de alto.
String sanitizeMultilineText(
  String? raw, {
  int maxLength = InputLimits.description,
}) {
  if (raw == null) return '';
  final normalized = _normalizeChars(raw);
  final lines = normalized
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r' {2,}'), ' ').trim());
  final collapsed = lines
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  return _truncate(collapsed, maxLength);
}

/// Partículas que quedan en minúscula dentro de un nombre compuesto, salvo que
/// abran el nombre ("De la Cruz" vs. "Juan de la Cruz").
const Set<String> _lowercaseParticles = {
  'de',
  'del',
  'la',
  'las',
  'lo',
  'los',
  'y',
  'e',
  'da',
  'do',
  'dos',
  'van',
  'von',
  'di',
};

/// Capitalización de nombres propios (persona, negocio, fundación).
///
/// Regla deliberadamente conservadora: **una palabra que ya trae alguna
/// mayúscula no se toca**. Eso preserva siglas ("ONG", "UAM", "S.A."), nombres
/// compuestos ("McDonald") y marcas con capitalización propia ("iNikara"), que
/// es justo lo que rompe el clásico `toLowerCase()` + capitalizar inicial.
/// Solo se corrige lo que llega todo en minúscula, que es el caso real del
/// teclado móvil ("juan pérez" ⇒ "Juan Pérez").
String sanitizeProperName(String? raw, {int maxLength = InputLimits.name}) {
  final base = sanitizeText(raw, maxLength: maxLength);
  if (base.isEmpty) return '';
  final words = base.split(' ');
  final result = <String>[];
  for (var i = 0; i < words.length; i++) {
    final word = words[i];
    if (word.isEmpty) continue;
    if (word.toLowerCase() != word) {
      result.add(word); // Ya tiene mayúsculas: es intención del usuario.
      continue;
    }
    if (i > 0 && _lowercaseParticles.contains(word)) {
      result.add(word);
      continue;
    }
    result.add(_capitalizeSegments(word));
  }
  return result.join(' ');
}

/// Capitaliza también después de guion o apóstrofo ("jean-luc" ⇒ "Jean-Luc",
/// "d'angelo" ⇒ "D'Angelo").
String _capitalizeSegments(String word) {
  final buffer = StringBuffer();
  var capitalizeNext = true;
  for (final char in word.split('')) {
    if (capitalizeNext) {
      buffer.write(char.toUpperCase());
      capitalizeNext = false;
    } else {
      buffer.write(char);
    }
    if (char == '-' || char == "'" || char == '.') capitalizeNext = true;
  }
  return buffer.toString();
}

/// Lista de textos cortos (`eco_activities.requirements`): sanea cada ítem,
/// descarta vacíos y duplicados, y acota el largo de la lista.
List<String> sanitizeTextList(
  List<String>? raw, {
  int maxItemLength = InputLimits.listItem,
  int maxItems = InputLimits.listLength,
}) {
  if (raw == null || raw.isEmpty) return const [];
  final seen = <String>{};
  final result = <String>[];
  for (final item in raw) {
    final value = sanitizeText(item, maxLength: maxItemLength);
    if (value.isEmpty) continue;
    if (!seen.add(value.toLowerCase())) continue;
    result.add(value);
    if (result.length >= maxItems) break;
  }
  return List<String>.unmodifiable(result);
}

// ---------------------------------------------------------------------------
// Correo
// ---------------------------------------------------------------------------

/// Trim + minúsculas. Sin minúsculas, "Jose@x.com" y "jose@x.com" son dos
/// cuentas distintas para cualquier comparación del cliente aunque el servidor
/// de correo las trate igual.
String sanitizeEmail(String? raw) {
  if (raw == null) return '';
  final normalized = _normalizeChars(raw)
      .replaceAll(RegExp(r'\s+'), '')
      .replaceFirst(RegExp('^mailto:', caseSensitive: false), '')
      .toLowerCase();
  return _truncate(normalized, InputLimits.email);
}

// ---------------------------------------------------------------------------
// Teléfono
// ---------------------------------------------------------------------------

/// Nicaragua: +505, 8 dígitos, sin prefijo troncal.
const String nicaraguaCallingCode = '505';

/// Los mismos códigos que ofrece el selector del wizard de negocios, ordenados
/// de más largo a más corto para que el prefijo se resuelva sin ambigüedad
/// (si "+1" se probara primero, "+1" se comería el "1" de cualquier número).
const List<String> supportedCallingCodes = [
  nicaraguaCallingCode, // Nicaragua
  '506', // Costa Rica
  '504', // Honduras
  '503', // El Salvador
  '502', // Guatemala
  '1', // EE. UU. / Canadá
];

/// Formato canónico de teléfono: `+<código> <número nacional>`, y para los
/// números nicaragüenses de 8 dígitos, agrupados: **`+505 8888-7777`**.
///
/// Por qué este formato y no E.164 puro (`+50588887777`):
///
/// 1. Es el que ya produce el resto de la app —
///    `NicaraguaPhoneInputFormatter` escribe `XXXX-XXXX` y el wizard antepone
///    el código elegido—, así que canonizar no cambia lo que el usuario ve ni
///    obliga a migrar las filas existentes.
/// 2. `register_business_wizard._splitPhone` vuelve a separar código y número
///    buscando el prefijo `+NNN`; el espacio hace que ese round-trip sea exacto.
/// 3. Los enlaces `tel:` y `wa.me` no se ven afectados: `social_contact_row`
///    los arma con `digitsOnly()`, que borra espacios y guiones — o sea, la
///    forma E.164 se deriva del canónico cuando hace falta, no al revés.
///
/// El guion **solo** se agrega a los números de 8 dígitos con código 505: la
/// agrupación de otros países es distinta e inventarla sería peor que no
/// agrupar. Un número que no encaja en ningún patrón conocido se conserva tal
/// cual (solo dígitos): nunca se trunca ni se descarta lo que el usuario
/// escribió.
String sanitizePhone(String? raw) {
  if (raw == null) return '';
  final normalized = _normalizeChars(raw).trim();
  if (normalized.isEmpty) return '';

  var digits = normalized.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';

  // "+505…" y "00505…" son la misma intención: el código viene explícito.
  final hasExplicitCode = normalized.startsWith('+') || digits.startsWith('00');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.isEmpty) return '';

  const nationalLength = 8;
  String callingCode;
  String national;

  if (!hasExplicitCode && digits.length <= nationalLength) {
    // 8 dígitos sueltos son SIEMPRE un número local: un móvil nicaragüense
    // puede empezar con "505" (5055-1234) y confundirlo con el código de país
    // dejaría un número de 5 dígitos que no existe.
    callingCode = nicaraguaCallingCode;
    national = digits;
  } else {
    final matched = _matchCallingCode(digits);
    if (matched == null) {
      // Código de país desconocido: se conserva textual en vez de forzarlo a
      // Nicaragua, que inventaría un número de otro país.
      if (hasExplicitCode) return '+$digits';
      callingCode = nicaraguaCallingCode;
      national = digits;
    } else {
      callingCode = matched;
      national = digits.substring(matched.length);
    }
  }

  if (national.isEmpty) return '+$callingCode';
  if (callingCode == nicaraguaCallingCode &&
      national.length == nationalLength) {
    return '+$callingCode ${national.substring(0, 4)}-${national.substring(4)}';
  }
  return '+$callingCode $national';
}

String? _matchCallingCode(String digits) {
  for (final code in supportedCallingCodes) {
    if (digits.length > code.length && digits.startsWith(code)) return code;
  }
  return null;
}

/// Forma E.164 (`+50588887777`) derivada del canónico, para cuando haga falta
/// comparar dos números o armar un enlace sin pasar por la UI.
String phoneToE164(String? raw) {
  final canonical = sanitizePhone(raw);
  if (canonical.isEmpty) return '';
  return '+${canonical.replaceAll(RegExp(r'\D'), '')}';
}

// ---------------------------------------------------------------------------
// Handles de redes sociales
// ---------------------------------------------------------------------------

/// `businesses.instagram_handle` / `facebook_handle` y `organizations.handle`
/// se guardan **sin arroba** (ver `docs/database_erd.md`). Guardar a veces con
/// y a veces sin obliga a cada pantalla a adivinar, y `social_contact_row` ya
/// arma la URL asumiendo el handle pelado.
String _sanitizeHandle(
  String? raw, {
  required String hostFragment,
  required RegExp allowed,
  required bool lowercase,
}) {
  if (raw == null) return '';
  var value = _normalizeChars(raw).replaceAll(RegExp(r'\s+'), '').trim();
  if (value.isEmpty) return '';

  value = value.replaceFirst(RegExp(r'^[a-zA-Z]+://'), '');
  value = value.replaceFirst(RegExp(r'^www\.', caseSensitive: false), '');
  value = value.replaceFirst(
    RegExp('^${RegExp.escape(hostFragment)}/*', caseSensitive: false),
    '',
  );

  // facebook.com/profile.php?id=123 no tiene vanity URL; el id numérico sí
  // funciona como handle (facebook.com/123), así que se rescata.
  final numericId = RegExp(r'^profile\.php\?id=(\d+)').firstMatch(value);
  if (numericId != null) return numericId.group(1)!;

  value = value.split('?').first;
  value = value.split('#').first;
  value = value.split('/').where((part) => part.isNotEmpty).firstOrNull ?? '';
  value = value.replaceFirst('@', '');
  if (lowercase) value = value.toLowerCase();
  value = value.replaceAll(allowed, '');
  // Un handle no empieza ni termina en punto en ninguna de las dos redes.
  value = value.replaceAll(RegExp(r'^\.+|\.+$'), '');
  return _truncate(value, InputLimits.handle);
}

/// Instagram: minúsculas (los handles no distinguen mayúsculas) y solo
/// letras, dígitos, punto y guion bajo.
String sanitizeInstagramHandle(String? raw) => _sanitizeHandle(
  raw,
  hostFragment: 'instagram.com',
  allowed: RegExp(r'[^a-z0-9._]'),
  lowercase: true,
);

/// Facebook: además del punto acepta guion (las vanity URLs de páginas los
/// usan, ej. `Cafe-Las-Flores-123456`), y se conserva la capitalización
/// porque una página puede mostrarla así.
String sanitizeFacebookHandle(String? raw) => _sanitizeHandle(
  raw,
  hostFragment: 'facebook.com',
  allowed: RegExp(r'[^A-Za-z0-9.\-]'),
  lowercase: false,
);

/// TikTok: minúsculas y mismo alfabeto que Instagram (letras, dígitos, punto,
/// guion bajo) — TikTok además acepta guion, así que se suma acá.
String sanitizeTiktokHandle(String? raw) => _sanitizeHandle(
  raw,
  hostFragment: 'tiktok.com',
  allowed: RegExp(r'[^a-z0-9._\-]'),
  lowercase: true,
);

/// Handle de fundación (`organizations.handle`, UNIQUE). Mismo criterio que
/// `OrganizationModel.normalizeHandle`, pero tolerando que peguen una URL.
String sanitizeOrganizationHandle(String? raw) {
  final handle = _sanitizeHandle(
    raw,
    hostFragment: 'nikara.app',
    allowed: RegExp(r'[^a-z0-9._]'),
    lowercase: true,
  );
  return handle.replaceAll(RegExp(r'^[._]+'), '');
}

// ---------------------------------------------------------------------------
// Identidad legal (RUC / cédula) — legal_identities.document_number
// ---------------------------------------------------------------------------

/// RUC de persona jurídica: letra `J` + 13 dígitos, 14 caracteres en total
/// (comúnmente empieza `J0`, pero eso no es parte del formato exigido). Sin
/// guiones — a diferencia de la cédula, la DGI no agrupa el RUC.
final RegExp rucPattern = RegExp(r'^J\d{13}$');

/// Cédula de persona natural, formato canónico con guiones:
/// `001-201208-1009S` (departamento/municipio 3 + fecha de nacimiento 6 +
/// control 4 + letra). Confirmado por José el 2026-08-27, con ejemplo real —
/// corrige tanto la nota fuente original ("14 dígitos + letra", sin guiones)
/// como la primera versión de esta migración (sin guiones tampoco). El
/// agrupado en vivo lo pone `CedulaInputFormatter`, no solo la validación.
final RegExp cedulaPattern = RegExp(r'^\d{3}-\d{6}-\d{4}[A-Z]$');

/// Persona natural **sin** cédula (extranjeros, menores, casos especiales):
/// letra `N` + 13 dígitos, 14 caracteres — mismo formato que el RUC pero con
/// `N` en vez de `J`. Pedido explícito de José, 2026-08-27, con ejemplo real
/// (`N0000000000019`). Sin guiones: no es una cédula real, es un número
/// administrativo de la DGI para quien no tiene una.
final RegExp cedulaSinDocumentoPattern = RegExp(r'^N\d{13}$');

/// A diferencia del resto de los sanitizadores de texto, **no** le quita los
/// guiones: son parte del formato canónico de la cédula
/// (`001-201208-1009S`), no ruido a limpiar. Solo pasa a mayúsculas y saca
/// espacios/caracteres invisibles — la forma exacta (con o sin guion, según
/// el tipo de documento) la exige `rucPattern`/`cedulaPattern`/
/// `cedulaSinDocumentoPattern` en el punto de guardado, no este sanitizador.
String sanitizeLegalDocumentNumber(String? raw) {
  if (raw == null) return '';
  final normalized = _normalizeChars(raw).toUpperCase();
  return normalized.replaceAll(RegExp(r'\s+'), '');
}

// ---------------------------------------------------------------------------
// URLs
// ---------------------------------------------------------------------------

/// URL de imagen ya subida a Storage. Solo se aceptan `http(s)`: una
/// `javascript:`/`data:` guardada en la base terminaría en un `Image.network`
/// o en un `launchUrl`, y ninguno de los dos debería recibirla.
String? sanitizeHttpUrl(String? raw) {
  if (raw == null) return null;
  final value = _normalizeChars(raw).replaceAll(RegExp(r'\s+'), '').trim();
  if (value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  return value;
}
