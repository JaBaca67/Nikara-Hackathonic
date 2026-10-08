import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_colors.dart';

/// Subcategorías por categoría de nivel superior, para el segundo picker del
/// wizard (Paso 1, debajo del de categoría). Texto libre igual que
/// `category` — este set es solo el curado que ofrece la UI, nunca un enum
/// de Postgres, para que una subcategoría nueva no necesite migración.
const Map<String, List<String>> subcategoryPresetsByCategory = {
  'Hospedaje': [
    'Hotel',
    'Hostal',
    'Eco-lodge',
    'Cabañas/Bungalows',
    'Finca turística',
    'Hospedaje familiar',
    'Camping/Glamping',
  ],
  'Restaurante': [
    'Restaurante',
    'Comedor típico',
    'Cafetería',
    'Repostería',
    'Food truck',
  ],
  'Tours': [
    'Tour operador',
    'Deportes acuáticos',
    'Senderismo/volcán',
    'Canopy/zip-line',
    'Pesca deportiva',
    'City tour',
  ],
  'Eco-destino': ['Reserva natural', 'Mirador', 'Cascada', 'Playa', 'Sendero'],
  'Cultura': [
    'Taller artesanal',
    'Museo/sitio histórico',
    'Galería de arte',
    'Turismo comunitario/indígena',
    'Sitio arqueológico',
  ],
  'Agroturismo': [
    'Finca cafetalera',
    'Finca cacaotera',
    'Finca ganadera',
    'Vivero/finca agrícola',
  ],
  'Bienestar': [
    'Spa',
    'Masajes',
    'Retiro de yoga',
    'Medicina natural/temazcal',
  ],
  'Eventos': [
    'Evento cultural',
    'Festival local',
    'Concierto/música en vivo',
    'Feria gastronómica/artesanal',
  ],
  'Compras': [
    'Mercado artesanal',
    'Mercado municipal',
    'Tienda de souvenirs',
    'Boutique local',
  ],
  'Transporte': [
    'Alquiler de vehículos',
    'Alquiler de motos/bicicletas',
    'Traslados/shuttle',
    'Lancha/ferry',
  ],
  'Servicios': [
    'Cambio de moneda',
    'Farmacia/clínica',
    'Cajero automático',
    'Gasolinera',
    'SIM/internet',
  ],
};

/// `[]` para una categoría sin preset (ej. dato legacy con categoría custom).
/// Pasa primero por [businessCategoryPresetFor] para que un negocio guardado
/// con un nombre anterior del catálogo ("Tour", "Agroturismo / Fincas") siga
/// ofreciendo sus subcategorías al editarse.
List<String> subcategoriesFor(String category) {
  final exact = subcategoryPresetsByCategory[category];
  if (exact != null) return exact;
  final preset = businessCategoryPresetFor(category);
  if (preset == null) return const [];
  return subcategoryPresetsByCategory[preset] ?? const [];
}

/// Chips de "qué incluye" para la tarjeta de Pase de día del wizard (solo
/// categoría Hospedaje) y su despliegue en BusinessDetailScreen.
const List<String> dayPassIncludesPresets = [
  'Piscina',
  'Playa',
  'Almuerzo incluido',
  'Bebida de bienvenida',
  'Toallas',
  'Acceso a spa',
];

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
      return AppColors.orangeFill;
    case MapPinCategory.water:
      return AppColors.mapPinWater;
    case MapPinCategory.tour:
      return AppColors.oliveText;
    case MapPinCategory.eco:
      return AppColors.ecoGreen500;
    case MapPinCategory.craft:
      return AppColors.rustText;
    case MapPinCategory.lodging:
      return AppColors.goldDeepText;
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
  // `turismo` y `mirador` van acá explícitamente: "tour" no es substring de
  // "turismo", así que "Turismo y Miradores" —la categoría de varios datos
  // semilla— caía en `general` y se mostraba como "Otros" tanto en el filtro
  // de Inicio como en su pin del mapa.
  if (key.contains('tour') ||
      key.contains('turismo') ||
      key.contains('mirador')) {
    return MapPinCategory.tour;
  }
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

/// Catálogo real de categorías con las que se registra un negocio (Paso 1
/// del wizard). Única fuente de verdad: `register_business_wizard.dart` la
/// importa de acá en vez de declarar su propia lista, para que la barra de
/// categorías de Inicio nunca pueda desincronizarse del catálogo real.
///
/// Dos reglas que no son cosméticas:
///
/// - **Una palabra por categoría.** Estos nombres se pintan tal cual en el
///   chip del filtro de Inicio, donde el ancho lo fija el texto: un
///   "Agroturismo / Fincas" se comía media fila y dejaba ver 3 categorías de
///   11. Si hace falta una categoría nueva, el nombre se elige corto desde el
///   principio, no se abrevia después en la UI.
/// - **El orden es el del viaje**, no alfabético ni histórico: dónde dormir,
///   dónde comer, qué hacer, qué ver, y al final lo logístico (Transporte,
///   Servicios) que solo se busca cuando ya se tiene el plan.
const List<String> kBusinessCategoryPresets = [
  'Hospedaje',
  'Restaurante',
  'Tours',
  'Eco-destino',
  'Cultura',
  'Agroturismo',
  'Bienestar',
  'Eventos',
  'Compras',
  'Transporte',
  'Servicios',
];

/// Ícono real por categoría — a diferencia de [mapPinIcon], que agrupa en
/// las 8 familias visuales del Mapa, esto representa 1:1 el catálogo
/// completo de [kBusinessCategoryPresets], para el filtro de Inicio.
IconData businessCategoryIcon(String category) {
  switch (businessCategoryPresetFor(category) ?? category) {
    case 'Hospedaje':
      return Icons.hotel_rounded;
    case 'Restaurante':
      return Icons.restaurant_rounded;
    case 'Tours':
      return Icons.tour_rounded;
    case 'Eco-destino':
      return Icons.eco_rounded;
    case 'Cultura':
      return Icons.palette_rounded;
    case 'Agroturismo':
      return Icons.agriculture_rounded;
    case 'Bienestar':
      return Icons.spa_rounded;
    case 'Eventos':
      return Icons.celebration_rounded;
    case 'Compras':
      return Icons.storefront_rounded;
    case 'Transporte':
      return Icons.directions_car_filled_rounded;
    case 'Servicios':
      return Icons.support_agent_rounded;
    default:
      return Icons.category_rounded;
  }
}

/// Los valores crudos de `businesses.category` normalizados al catálogo y
/// puestos en el orden de [kBusinessCategoryPresets], para los chips del
/// Mapa. Un valor que no se reconozca se conserva al final en vez de
/// desaparecer: perder un chip esconde negocios.
List<String> orderedBusinessCategories(Iterable<String> rawValues) {
  final present = rawValues
      .where((category) => category.isNotEmpty)
      .map((category) => businessCategoryPresetFor(category) ?? category)
      .toSet();
  final unknown =
      present.where((c) => !kBusinessCategoryPresets.contains(c)).toList()
        ..sort();
  return [...kBusinessCategoryPresets.where(present.contains), ...unknown];
}

/// Nombres que tuvo el catálogo antes del 2026-10-07, cuando se acortaron
/// para que entraran en el chip del filtro de Inicio. `businesses.category`
/// es texto libre, así que las filas guardadas con el nombre viejo siguen
/// existiendo: se resuelven acá por igualdad exacta y no por el encadenado de
/// `contains` de abajo, que para "Agroturismo / Fincas" habría dado "Tours"
/// (contiene "turismo").
const Map<String, String> _renamedCategories = {
  'Tour': 'Tours',
  'Compras y mercados': 'Compras',
  'Agroturismo / Fincas': 'Agroturismo',
  'Servicios para el viajero': 'Servicios',
};

/// Normaliza el texto libre de `businesses.category` a uno de
/// [kBusinessCategoryPresets]. Cubre los presets actuales del wizard (match
/// exacto), los nombres anteriores del catálogo ([_renamedCategories]) y las
/// categorías de los datos semilla, que usan otra redacción ("Cultura y
/// Patrimonio", "Turismo y Miradores", "Artesanía y Alfarería", "Gastronomía
/// Tradicional"). Devuelve `null` en vez de adivinar — mismo criterio que
/// [mapPinCategoryFor] — para que el llamador decida cómo tratar un negocio
/// sin categoría reconocible (ej. agruparlo en "Otros").
///
/// El orden de las ramas importa: "Agroturismo" va **antes** que la de Tours
/// porque contiene "turismo" como substring.
String? businessCategoryPresetFor(String category) {
  if (kBusinessCategoryPresets.contains(category)) return category;
  final renamed = _renamedCategories[category];
  if (renamed != null) return renamed;
  final key = category.toLowerCase();
  if (key.contains('restaurant') ||
      key.contains('comida') ||
      key.contains('gastro')) {
    return 'Restaurante';
  }
  if (key.contains('hospedaje') ||
      key.contains('hotel') ||
      key.contains('hostal') ||
      key.contains('cabañ') ||
      key.contains('caban') ||
      key.contains('lodge')) {
    return 'Hospedaje';
  }
  if (key.contains('agroturismo') ||
      key.contains('finca') ||
      key.contains('cafetalera') ||
      key.contains('cacaotera') ||
      key.contains('ganadera') ||
      key.contains('vivero')) {
    return 'Agroturismo';
  }
  if (key.contains('tour') ||
      key.contains('turismo') ||
      key.contains('mirador')) {
    return 'Tours';
  }
  if (key.contains('eco') ||
      key.contains('sender') ||
      key.contains('bosque') ||
      key.contains('natural') ||
      key.contains('laguna') ||
      key.contains('lago') ||
      key.contains('playa') ||
      key.contains('río') ||
      key.contains('rio') ||
      key.contains('cascada') ||
      key.contains('reserva')) {
    return 'Eco-destino';
  }
  // "arte" cubre tanto "Artesanía y Alfarería" como "Arte y Escultura", dos
  // categorías de los datos semilla. Hasta ahora la segunda caía acá por
  // accidente: "escultura" contiene "cultura".
  if (key.contains('artesan') ||
      key.contains('arte') ||
      key.contains('cultura') ||
      key.contains('museo') ||
      key.contains('galería') ||
      key.contains('galeria') ||
      key.contains('patrimonio') ||
      key.contains('arqueológ') ||
      key.contains('arqueolog')) {
    return 'Cultura';
  }
  if (key.contains('transporte') ||
      key.contains('taxi') ||
      key.contains('shuttle') ||
      key.contains('traslado') ||
      key.contains('lancha') ||
      key.contains('ferry')) {
    return 'Transporte';
  }
  if (key.contains('bienestar') ||
      key.contains('spa') ||
      key.contains('masaje') ||
      key.contains('yoga') ||
      key.contains('retiro') ||
      key.contains('temazcal')) {
    return 'Bienestar';
  }
  if (key.contains('evento') ||
      key.contains('festival') ||
      key.contains('concierto') ||
      key.contains('feria')) {
    return 'Eventos';
  }
  if (key.contains('mercado') ||
      key.contains('tienda') ||
      key.contains('boutique') ||
      key.contains('souvenir') ||
      key.contains('compras')) {
    return 'Compras';
  }
  // Última rama a propósito: "servicio" es genérico y se lo comerían
  // categorías más específicas si se evaluara antes.
  if (key.contains('servicio') ||
      key.contains('cambio de moneda') ||
      key.contains('farmacia') ||
      key.contains('clínica') ||
      key.contains('clinica') ||
      key.contains('cajero') ||
      key.contains('gasolinera')) {
    return 'Servicios';
  }
  return null;
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

/// Etiqueta corta en español de una familia de pin, para el filtro por
/// categoría de Inicio.
///
/// Son nombres de **familia**, no la `businesses.category` que escribió el
/// dueño: esa es texto libre y produce etiquetas como "Artesanía y Alfarería"
/// que no entran en un chip sin cortarse. Agrupar acá además hace que el
/// filtro de Inicio y los pines del Mapa hablen el mismo idioma — el usuario
/// ve el mismo glifo en los dos lados.
String mapPinCategoryLabel(MapPinCategory category) {
  switch (category) {
    case MapPinCategory.food:
      return 'Comida';
    case MapPinCategory.water:
      return 'Agua';
    case MapPinCategory.tour:
      return 'Tours';
    case MapPinCategory.eco:
      return 'ECO';
    case MapPinCategory.craft:
      return 'Cultura';
    case MapPinCategory.lodging:
      return 'Hospedaje';
    case MapPinCategory.transport:
      return 'Transporte';
    case MapPinCategory.general:
      return 'Otros';
  }
}
