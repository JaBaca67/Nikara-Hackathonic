import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_theme.dart';

/// Convierte a `#RRGGBB` porque el estilo JSON de Google Maps solo acepta hex literal, no un [Color] de Flutter.
String _hex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Estilo del mapa para [MapScreen]: oculta íconos/etiquetas nativos de POI y transporte de Google (duplicarían los pines propios de Níkara) y retiñe el mapa base a la paleta crema/arena de la app.
final String nikaraMapStyle = jsonEncode([
  {
    'elementType': 'geometry',
    'stylers': [
      {'color': _hex(AppColors.backgroundCream)},
    ],
  },
  // Override explícito para que las manzanas/edificios no queden en gris
  // por defecto de Google al hacer zoom (visible sobre todo en
  // navegación). 'landscape.man_made' es el feature-type válido para esto
  // — 'building'/'landuse' no existen en el enum de Maps y usarlos antes
  // hizo que el SDK rechazara todo el estilo y volviera al look de stock.
  {
    'featureType': 'landscape',
    'elementType': 'geometry',
    'stylers': [
      {'color': _hex(AppColors.backgroundCream)},
    ],
  },
  {
    'featureType': 'landscape.man_made',
    'elementType': 'geometry',
    'stylers': [
      {'color': _hex(AppColors.backgroundCream)},
    ],
  },
  {
    'elementType': 'labels.icon',
    'stylers': [
      {'visibility': 'off'},
    ],
  },
  {
    'elementType': 'labels.text.fill',
    'stylers': [
      {'color': _hex(AppColors.neutral600)},
    ],
  },
  {
    'elementType': 'labels.text.stroke',
    'stylers': [
      {'color': _hex(AppColors.backgroundCream)},
    ],
  },
  {
    'featureType': 'administrative.land_parcel',
    'stylers': [
      {'visibility': 'off'},
    ],
  },
  // Oculta todo POI nativo de Google para que solo se vean los pines propios de Níkara.
  {
    'featureType': 'poi',
    'elementType': 'all',
    'stylers': [
      {'visibility': 'off'},
    ],
  },
  {
    'featureType': 'road',
    'elementType': 'geometry',
    'stylers': [
      {'color': _hex(AppColors.mapStyleRoad)},
    ],
  },
  {
    'featureType': 'road',
    'elementType': 'geometry.stroke',
    'stylers': [
      {'visibility': 'off'},
    ],
  },
  {
    'featureType': 'road.highway',
    'elementType': 'geometry',
    'stylers': [
      {'color': _hex(AppColors.primary500)},
      {'lightness': 55},
    ],
  },
  {
    'featureType': 'transit',
    'stylers': [
      {'visibility': 'off'},
    ],
  },
  {
    'featureType': 'water',
    'elementType': 'geometry',
    'stylers': [
      {'color': _hex(AppColors.mapStyleWater)},
    ],
  },
]);
