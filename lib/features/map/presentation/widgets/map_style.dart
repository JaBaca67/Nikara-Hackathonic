import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_theme.dart';

/// `#RRGGBB` for the Google Maps JSON style below — Maps styling only
/// accepts literal hex strings (no way to hand it a Flutter [Color]), so
/// every color here is still pulled from [AppColors] rather than typed out
/// loose, just converted at the boundary.
String _hex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Google Maps JSON style for [MapScreen] and its navigation mode — hides
/// Google's native POI/transit icons and labels (Níkara has its own
/// business pins, showing Google's on top would double up and clash) and
/// retints the base map into the app's cream/sand palette instead of
/// Google's default white/grey, per the "Mapa — evolución" prototype.
final String nikaraMapStyle = jsonEncode([
  {
    'elementType': 'geometry',
    'stylers': [
      {'color': _hex(AppColors.backgroundCream)},
    ],
  },
  // Explicit override for landscape polygons — the top-level 'geometry'
  // rule above already colors everything cream, but Google's default
  // style still bakes in its own gray fill for building
  // footprints/hyper-manzanas that becomes visible once the camera zooms
  // in close (navigation's tilted view especially). 'landscape.man_made'
  // is the real (schema-valid) feature type that covers those — NOT
  // 'building' or 'landuse', neither of which exists in Google's Maps
  // JSON styling feature-type enum (https://developers.google.com/maps/
  // documentation/javascript/style-reference#style-features): an earlier
  // version of this file used those two invalid values, which appears to
  // have made the native SDK reject the whole style and silently fall
  // back to Google's stock look — the exact bug this comment is here to
  // stop from happening again.
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
  // Hides every stock Google POI (shops, banks, generic restaurant pins,
  // ...) so only Níkara's own business markers ever show on the map.
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
