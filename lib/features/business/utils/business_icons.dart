import 'package:flutter/material.dart';

/// One [IconData] per known amenity string — falls back to a generic
/// checkmark for anything outside the wizard's fixed amenity list. Shared
/// between the wizard's chip picker and BusinessDetailScreen's display so
/// both always agree on the same glyph.
IconData amenityIcon(String label) {
  final key = label.toLowerCase();
  if (key.contains('wifi')) return Icons.wifi_rounded;
  if (key.contains('estacionamiento')) return Icons.local_parking_outlined;
  if (key.contains('piscina')) return Icons.pool_outlined;
  if (key.contains('restaurante')) return Icons.restaurant_outlined;
  if (key.contains('guía') || key.contains('guia')) {
    return Icons.groups_outlined;
  }
  if (key.contains('camping')) return Icons.cabin_outlined;
  if (key.contains('mascota')) return Icons.pets_outlined;
  if (key.contains('accesible')) return Icons.accessible_forward_outlined;
  if (key.contains('aire')) return Icons.ac_unit_outlined;
  if (key.contains('desayuno')) return Icons.free_breakfast_outlined;
  return Icons.check_circle_outline;
}

/// Separator between a custom activity's chosen icon key and its label,
/// e.g. `"kayaking::Kayak en aguas termales"` — internal encoding only,
/// never shown to the user (see [activityLabel]). Chosen because it can't
/// plausibly appear inside real, hand-typed activity text.
const String _kActivityIconSeparator = '::';

/// Curated icon choices offered by the "agregar otra actividad" picker
/// (Pantalla 4c) — one Material glyph per Spanish label, shared between
/// the wizard's dropdown and [activityIcon]'s lookup so a custom
/// activity's chosen icon round-trips exactly.
const Map<String, IconData> activityIconLibrary = {
  'hiking': Icons.hiking,
  'kayaking': Icons.kayaking,
  'directions_bike': Icons.directions_bike,
  'directions_boat': Icons.directions_boat,
  'nature_people': Icons.nature_people,
  'local_cafe': Icons.local_cafe,
  'photo_camera': Icons.camera_alt_outlined,
  'pool': Icons.pool,
  'restaurant': Icons.restaurant,
  'flutter_dash': Icons.flutter_dash,
  'cabin': Icons.cabin_outlined,
  'phishing': Icons.phishing,
  'self_improvement': Icons.self_improvement,
  'palette': Icons.palette_outlined,
  'music_note': Icons.music_note_rounded,
  'beach_access': Icons.beach_access,
  'terrain': Icons.terrain,
  'volunteer_activism': Icons.volunteer_activism,
  'shopping_bag': Icons.shopping_bag_outlined,
  'explore': Icons.explore_outlined,
};

/// Spanish label shown next to each [activityIconLibrary] entry in the
/// icon picker — same key set, display order matters (picker renders it
/// as-is), so this is a separate ordered map rather than derived from
/// [activityIconLibrary]'s (unordered) keys.
const Map<String, String> activityIconLibraryLabels = {
  'hiking': 'Senderismo',
  'kayaking': 'Kayak',
  'directions_boat': 'Tour en lancha',
  'directions_bike': 'Ciclismo',
  'nature_people': 'Canopy',
  'terrain': 'Aventura / extremo',
  'beach_access': 'Playa',
  'pool': 'Natación',
  'local_cafe': 'Café',
  'restaurant': 'Gastronomía',
  'photo_camera': 'Fotografía',
  'flutter_dash': 'Avistamiento de aves',
  'phishing': 'Pesca',
  'cabin': 'Camping',
  'self_improvement': 'Yoga / bienestar',
  'palette': 'Artesanías / cultura',
  'music_note': 'Música en vivo',
  'volunteer_activism': 'Voluntariado',
  'shopping_bag': 'Compras locales',
  'explore': 'Otro',
};

/// Encodes a custom activity's user-picked icon key alongside its label —
/// used only by the "agregar otra actividad" flow. Preset activity chips
/// (Senderismo, Kayak, ...) never need this: their icon always comes from
/// [activityIcon]'s keyword match against the plain label.
String encodeActivity(String iconKey, String label) =>
    '$iconKey$_kActivityIconSeparator$label';

/// Human-facing label for an activity string — strips the icon-key prefix
/// [encodeActivity] adds, if present; returns [raw] unchanged otherwise,
/// which covers every activity saved before this feature shipped.
String activityLabel(String raw) {
  final index = raw.indexOf(_kActivityIconSeparator);
  if (index == -1) return raw;
  final key = raw.substring(0, index);
  if (!activityIconLibrary.containsKey(key)) return raw;
  return raw.substring(index + _kActivityIconSeparator.length);
}

/// One [IconData] per activity string. A custom activity with an explicit
/// [encodeActivity]-picked icon always resolves to exactly that icon;
/// everything else (preset chips, activities saved before this feature
/// existed) falls back to a keyword match — matched loosely enough to
/// still resolve correctly for businesses saved before the wizard's
/// activity labels dropped their emoji prefixes (e.g. "🚶‍♂️ Senderismo"
/// still contains "senderismo"). Falls back to a generic compass glyph.
IconData activityIcon(String raw) {
  final separatorIndex = raw.indexOf(_kActivityIconSeparator);
  if (separatorIndex != -1) {
    final explicitIcon = activityIconLibrary[raw.substring(0, separatorIndex)];
    if (explicitIcon != null) return explicitIcon;
  }
  final key = activityLabel(raw).toLowerCase();
  if (key.contains('senderismo')) return Icons.hiking;
  if (key.contains('kayak')) return Icons.kayaking;
  if (key.contains('canopy')) return Icons.nature_people;
  if (key.contains('café') || key.contains('cafe')) return Icons.local_cafe;
  if (key.contains('fotografía') || key.contains('fotografia')) {
    return Icons.camera_alt_outlined;
  }
  if (key.contains('natación') || key.contains('natacion')) return Icons.pool;
  if (key.contains('gastronomía') || key.contains('gastronomia')) {
    return Icons.restaurant;
  }
  if (key.contains('ave')) return Icons.flutter_dash;
  return Icons.explore_outlined;
}

/// Whether an on-device media path (from `image_picker`'s
/// `pickMultipleMedia`) is a video rather than a photo — there's no
/// video-thumbnail package in this project, so callers use this to decide
/// between rendering [LocalImage] and a generic video placeholder.
bool isVideoPath(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.avi') ||
      lower.endsWith('.mkv') ||
      lower.endsWith('.webm') ||
      lower.endsWith('.m4v');
}
