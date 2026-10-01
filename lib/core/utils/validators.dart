/// Validadores reutilizables listos para el `validator:` de un
/// `TextFormField`: devuelven `null` si el valor sirve y un mensaje en español
/// (tuteo, igual que el resto de la app) si no.
///
/// Son la contraparte de `input_sanitizers.dart` y comparten sus reglas: cada
/// validador valida **el valor ya saneado**, no el crudo. Así nunca pasa que
/// el formulario rechace algo que el servicio habría aceptado (o al revés):
/// "  Café   Luna  " se valida como "Café Luna", que es exactamente lo que
/// terminará en Postgres.
///
/// Vive aparte de la sanitización a propósito: sanear es obligatorio y ocurre
/// siempre (capa de servicio); validar es opcional y ocurre donde haya un
/// formulario. Ninguna pantalla está cableada a estos validadores todavía —
/// se dejan disponibles para que las adopten sin tener que reinventar los
/// mensajes.
library;

import 'package:nikara_app/core/utils/input_sanitizers.dart';

/// Nombre de persona: al menos 2 caracteres y algo que no sean solo símbolos.
String? validateFullName(String? value) {
  final name = sanitizeProperName(value);
  if (name.isEmpty) return 'Escribe tu nombre completo.';
  if (name.length < 2) return 'El nombre es demasiado corto.';
  if (!_hasLetter(name)) return 'El nombre debe tener al menos una letra.';
  return null;
}

/// Nombre de negocio, fundación o ruta.
String? validateEntityName(String? value, {String label = 'nombre'}) {
  final name = sanitizeText(value, maxLength: InputLimits.name);
  if (name.isEmpty) return 'Escribe el $label.';
  if (name.length < 3) return 'El $label debe tener al menos 3 caracteres.';
  if (!_hasLetter(name)) return 'El $label debe tener al menos una letra.';
  return null;
}

/// Título de una jornada ECO o de una ruta.
String? validateTitle(String? value) =>
    validateEntityName(value, label: 'título');

/// Campo de texto corto obligatorio y genérico (ciudad, categoría, etiqueta).
String? validateRequiredText(
  String? value, {
  required String label,
  int minLength = 2,
  int maxLength = InputLimits.shortLabel,
}) {
  final text = sanitizeText(value, maxLength: maxLength);
  if (text.isEmpty) return 'Completa $label.';
  if (text.length < minLength) {
    return 'Ese campo debe tener al menos $minLength caracteres.';
  }
  return null;
}

/// Dirección escrita a mano ("de la rotonda 2 c. al sur").
String? validateAddress(String? value) {
  final address = sanitizeText(value, maxLength: InputLimits.address);
  if (address.isEmpty) return 'Escribe la dirección.';
  if (address.length < 5) {
    return 'La dirección es demasiado corta para encontrar el lugar.';
  }
  return null;
}

/// Descripción larga. [required] en `false` la vuelve opcional pero sigue
/// aplicando el tope de longitud.
String? validateDescription(String? value, {bool required = true}) {
  final description = sanitizeMultilineText(value);
  if (description.isEmpty) {
    return required ? 'Escribe una descripción.' : null;
  }
  if (description.length < 10) {
    return 'La descripción debe tener al menos 10 caracteres.';
  }
  return null;
}

/// Correo electrónico.
///
/// El patrón es deliberadamente permisivo: validar RFC 5322 completo con una
/// expresión regular rechaza direcciones válidas y no evita ninguna inválida
/// que importe. Lo único que puede confirmar de verdad que un correo existe es
/// el mail de confirmación que ya manda Supabase.
String? validateEmail(String? value) {
  final email = sanitizeEmail(value);
  if (email.isEmpty) return 'Escribe tu correo electrónico.';
  if (!_emailPattern.hasMatch(email)) {
    return 'Ese correo no parece válido. Revísalo e intenta de nuevo.';
  }
  return null;
}

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s.]+(\.[^@\s.]+)+$');

/// Teléfono. Valida sobre el formato canónico de [sanitizePhone], así que da
/// igual si la persona escribió "8888 7777", "+505 8888-7777" o "005058887777".
///
/// [required] en `false` acepta el campo vacío (el teléfono es opcional en
/// varios formularios) pero sigue rechazando un número mal escrito.
String? validatePhone(String? value, {bool required = true}) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) return required ? 'Escribe un número de teléfono.' : null;

  final canonical = sanitizePhone(raw);
  if (canonical.isEmpty) {
    return 'Ese número no parece válido. Escríbelo con dígitos.';
  }
  final digits = canonical.replaceAll(RegExp(r'\D'), '');
  if (canonical.startsWith('+$nicaraguaCallingCode')) {
    final national = digits.substring(nicaraguaCallingCode.length);
    if (national.length != 8) {
      return 'Un número de Nicaragua tiene 8 dígitos.';
    }
    return null;
  }
  // Otro país: sin catálogo de longitudes por país, solo se descarta lo
  // imposible en vez de inventar una regla que rechace números válidos.
  if (digits.length < 7 || digits.length > 15) {
    return 'Ese número no parece válido. Revísalo e intenta de nuevo.';
  }
  return null;
}

/// Contraseña de registro. El mínimo de 8 lo impone también Supabase; acá se
/// adelanta para no gastar un viaje de red en decir lo mismo.
String? validatePassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Escribe una contraseña.';
  if (password.length < 8) {
    return 'La contraseña debe tener al menos 8 caracteres.';
  }
  if (password.trim() != password) {
    return 'La contraseña no puede empezar ni terminar con espacios.';
  }
  return null;
}

/// Confirmación de contraseña.
String? validatePasswordConfirmation(String? value, String password) {
  if ((value ?? '').isEmpty) return 'Repite la contraseña.';
  if (value != password) return 'Las contraseñas no coinciden.';
  return null;
}

/// Handle de Instagram. Vacío es válido: es un campo opcional del wizard.
String? validateInstagramHandle(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) return null;
  final handle = sanitizeInstagramHandle(raw);
  if (handle.isEmpty) {
    return 'Escribe tu usuario de Instagram, sin la arroba.';
  }
  if (handle.length > 30) return 'Ese usuario de Instagram es demasiado largo.';
  return null;
}

/// Handle de Facebook. Vacío es válido, igual que Instagram.
String? validateFacebookHandle(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) return null;
  if (sanitizeFacebookHandle(raw).isEmpty) {
    return 'Escribe tu página de Facebook o el enlace completo.';
  }
  return null;
}

/// Handle de fundación: es UNIQUE en `organizations`, así que además de la
/// forma se valida que quede algo utilizable después de normalizar.
String? validateOrganizationHandle(String? value) {
  final handle = sanitizeOrganizationHandle(value);
  if (handle.isEmpty) {
    return 'El handle solo puede tener letras, números, puntos o guiones bajos.';
  }
  if (handle.length < 3) return 'El handle debe tener al menos 3 caracteres.';
  return null;
}

/// Cupo máximo de una jornada ECO. Vacío = sin tope, que es válido.
String? validateCapacity(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) return null;
  final capacity = int.tryParse(raw);
  if (capacity == null) return 'El cupo debe ser un número.';
  if (capacity <= 0) return 'El cupo debe ser mayor que cero.';
  if (capacity > 100000) return 'Ese cupo es demasiado grande.';
  return null;
}

/// Cantidad de días de una ruta (`routes.days` acepta 1..30, ver 011).
String? validateRouteDays(String? value) {
  final raw = (value ?? '').trim();
  if (raw.isEmpty) return 'Indica cuántos días dura la ruta.';
  final days = int.tryParse(raw);
  if (days == null) return 'Los días deben ser un número.';
  if (days < 1 || days > 30) return 'Una ruta puede durar entre 1 y 30 días.';
  return null;
}

/// Fecha/hora de una jornada ECO: no puede quedar en el pasado.
String? validateFutureDateTime(DateTime? value) {
  if (value == null) return 'Elige la fecha y la hora.';
  if (!value.isAfter(DateTime.now())) {
    return 'La fecha debe ser posterior a este momento.';
  }
  return null;
}

/// Coordenada elegida en el mapa. `businesses.location` es NOT NULL, así que
/// sin punto no hay negocio que guardar.
String? validateCoordinates(double? latitude, double? longitude) {
  if (latitude == null || longitude == null) {
    return 'Marca la ubicación del lugar en el mapa.';
  }
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    return 'Esa ubicación no es válida. Vuelve a marcarla en el mapa.';
  }
  return null;
}

/// Combina varios validadores y devuelve el primer error. Útil cuando un campo
/// tiene una regla propia además de la genérica.
String? validateAll(List<String? Function()> validators) {
  for (final validator in validators) {
    final error = validator();
    if (error != null) return error;
  }
  return null;
}

bool _hasLetter(String value) =>
    RegExp(r'\p{L}', unicode: true).hasMatch(value);
