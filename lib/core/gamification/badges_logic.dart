import 'package:flutter/material.dart';

import 'package:nikara_app/theme/app_theme.dart';

/// Real, countable user activity — the only inputs badge unlock conditions
/// are allowed to look at (never a hardcoded/mock number).
class UserStats {
  const UserStats({
    required this.tripsCount,
    required this.savedPlacesCount,
    required this.reviewsCount,
  });

  final int tripsCount;
  final int savedPlacesCount;
  final int reviewsCount;
}

/// One master badge definition plus whether the current [UserStats] meet
/// its unlock condition.
class BadgeInfo {
  const BadgeInfo({
    required this.id,
    required this.title,
    required this.icon,
    required this.tint,
    required this.unlocked,
    required this.requirementLabel,
  });

  final String id;
  final String title;
  final IconData icon;
  final Color tint;
  final bool unlocked;

  /// Shown when locked — the exact real condition still needed, e.g.
  /// "Guarda 3 lugares favoritos" (not a vague "sigue explorando").
  final String requirementLabel;
}

/// Master badge list (Figma node 421:361) — every unlock condition is
/// evaluated against real [UserStats], never a fixed true/false.
abstract class BadgesLogic {
  static List<BadgeInfo> build(UserStats stats) {
    return [
      BadgeInfo(
        id: 'guardian-bosque',
        title: 'Guardián del Bosque',
        icon: Icons.forest,
        tint: AppColors.badgeForest,
        unlocked: stats.savedPlacesCount >= 3,
        requirementLabel: 'Guarda 3 lugares favoritos',
      ),
      BadgeInfo(
        id: 'protector-lago',
        title: 'Protector del Lago',
        icon: Icons.water_drop,
        tint: AppColors.badgeLake,
        unlocked: stats.tripsCount >= 1,
        requirementLabel: 'Completa tu primer viaje',
      ),
      BadgeInfo(
        id: 'observador-alado',
        title: 'Observador Alado',
        icon: Icons.flutter_dash,
        tint: AppColors.settingsAccent,
        unlocked: stats.savedPlacesCount >= 1,
        requirementLabel: 'Guarda tu primer lugar favorito',
      ),
      BadgeInfo(
        id: 'cultura-viva',
        title: 'Cultura Viva',
        icon: Icons.festival,
        tint: AppColors.coral500,
        unlocked: stats.tripsCount >= 3,
        requirementLabel: 'Completa 3 viajes',
      ),
      BadgeInfo(
        id: 'escalador-eco',
        title: 'Escalador Eco',
        icon: Icons.terrain,
        tint: AppColors.neutral800,
        unlocked: stats.tripsCount >= 5,
        requirementLabel: 'Completa 5 viajes',
      ),
      BadgeInfo(
        id: 'viajero-consciente',
        title: 'Viajero Consciente',
        icon: Icons.card_travel,
        tint: AppColors.ecoForest,
        unlocked: stats.reviewsCount >= 1,
        requirementLabel: 'Deja tu primera reseña',
      ),
    ];
  }
}
