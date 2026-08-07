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

/// One [IconData] per known activity string — matched by keyword so it
/// still resolves correctly for businesses saved before the wizard's
/// activity labels dropped their emoji prefixes (e.g. "🚶‍♂️ Senderismo"
/// still contains "senderismo"). Falls back to a generic compass glyph.
IconData activityIcon(String label) {
  final key = label.toLowerCase();
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
