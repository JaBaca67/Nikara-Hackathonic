import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_colors.dart';

/// Compartido entre el picker del wizard y BusinessDetailScreen para que ambos usen el mismo glifo.
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

/// Separador interno (nunca visible, ver [activityLabel]); "::" no aparece de forma plausible en texto de actividad escrito a mano.
const String _kActivityIconSeparator = '::';

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

/// Mapa separado (no derivado de [activityIconLibrary]) porque el orden de despliegue en el picker importa.
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

/// Solo lo usa el flujo "agregar otra actividad"; los chips preset resuelven su icono por keyword match, no por esta codificación.
String encodeActivity(String iconKey, String label) =>
    '$iconKey$_kActivityIconSeparator$label';

/// Devuelve [raw] sin cambios si no tiene el prefijo de [encodeActivity], cubriendo actividades guardadas antes de esta feature.
String activityLabel(String raw) {
  final index = raw.indexOf(_kActivityIconSeparator);
  if (index == -1) return raw;
  final key = raw.substring(0, index);
  if (!activityIconLibrary.containsKey(key)) return raw;
  return raw.substring(index + _kActivityIconSeparator.length);
}

/// El match por keyword es deliberadamente laxo para seguir resolviendo bien actividades guardadas cuando los labels aún tenían prefijo de emoji.
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

/// Set acotado de "looks" de pin para no precomputar un bitmap por cada valor libre de `businesses.category`, que es ilimitado.
enum MapPinCategory {
  food,
  water,
  tour,
  eco,
  craft,
  lodging,
  transport,
  general,
}

/// Compartido entre los bitmaps del mapa y el badge del bottom sheet para mantener el mismo glifo.
IconData mapPinIcon(MapPinCategory category) {
  switch (category) {
    case MapPinCategory.food:
      return Icons.restaurant_rounded;
    case MapPinCategory.water:
      return Icons.water_rounded;
    case MapPinCategory.tour:
      return Icons.tour_rounded;
    case MapPinCategory.eco:
      return Icons.eco_rounded;
    case MapPinCategory.craft:
      return Icons.palette_rounded;
    case MapPinCategory.lodging:
      return Icons.hotel_rounded;
    case MapPinCategory.transport:
      return Icons.directions_car_filled_rounded;
    case MapPinCategory.general:
      return Icons.storefront_rounded;
  }
}

/// Reutiliza tokens existentes de [AppColors] salvo [mapPinWater] (ver su propio doc comment).
Color mapPinColor(MapPinCategory category) {
  switch (category) {
    case MapPinCategory.food:
      return AppColors.coral500;
    case MapPinCategory.water:
      return AppColors.mapPinWater;
    case MapPinCategory.tour:
      return AppColors.accent300;
    case MapPinCategory.eco:
      return AppColors.ecoGreen500;
    case MapPinCategory.craft:
      return AppColors.complementario8;
    case MapPinCategory.lodging:
      return AppColors.primario7;
    case MapPinCategory.transport:
      return AppColors.neutral800;
    case MapPinCategory.general:
      return AppColors.settingsTextMuted;
  }
}

/// Cubre tanto los presets actuales del wizard como categorías legacy de datos semilla; cae a [MapPinCategory.general] en vez de adivinar.
MapPinCategory mapPinCategoryFor(String category) {
  final key = category.toLowerCase();
  if (key.contains('restaurant') ||
      key.contains('comida') ||
      key.contains('gastro')) {
    return MapPinCategory.food;
  }
  if (key.contains('laguna') ||
      key.contains('lago') ||
      key.contains('playa') ||
      key.contains('río') ||
      key.contains('rio') ||
      key.contains('agua')) {
    return MapPinCategory.water;
  }
  if (key.contains('tour')) return MapPinCategory.tour;
  if (key.contains('eco') ||
      key.contains('sender') ||
      key.contains('bosque') ||
      key.contains('natural')) {
    return MapPinCategory.eco;
  }
  if (key.contains('artesan') || key.contains('cultura')) {
    return MapPinCategory.craft;
  }
  if (key.contains('hospedaje') ||
      key.contains('hotel') ||
      key.contains('hostal') ||
      key.contains('cabañ') ||
      key.contains('caban')) {
    return MapPinCategory.lodging;
  }
  if (key.contains('transporte') ||
      key.contains('taxi') ||
      key.contains('shuttle')) {
    return MapPinCategory.transport;
  }
  return MapPinCategory.general;
}

/// No hay paquete de miniaturas de video en el proyecto; los llamadores usan esto para elegir entre [LocalImage] y un placeholder genérico.
bool isVideoPath(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.avi') ||
      lower.endsWith('.mkv') ||
      lower.endsWith('.webm') ||
      lower.endsWith('.m4v');
}
