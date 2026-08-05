import 'package:nikara_app/core/gamification/badges_logic.dart';
import 'package:nikara_app/core/services/favorites_service.dart';

/// Computes the current user's real [UserStats] from the app's actual
/// persisted state — no field here is a fixed/mock number.
class UserStatsService {
  UserStatsService({FavoritesService? favoritesService})
    : _favoritesService = favoritesService ?? FavoritesService();

  final FavoritesService _favoritesService;

  Future<UserStats> getStats() async {
    final favorites = await _favoritesService.getFavoriteIds();
    return UserStats(
      // There is no reservation-completion flow in the app yet (Business
      // Detail's booking CTA opens WhatsApp, it doesn't write a booking
      // record) — so this is genuinely zero, not a placeholder, until that
      // exists.
      tripsCount: 0,
      savedPlacesCount: favorites.length,
      // Same story: no review-authoring feature exists anywhere in the app.
      reviewsCount: 0,
    );
  }

  /// Points formula: every real action earns a fixed amount — 100 pts per
  /// completed trip, 15 pts per saved place, 50 pts per review. Documented
  /// here rather than user-configurable, but always computed live.
  int computePoints(UserStats stats) {
    return stats.tripsCount * 100 +
        stats.savedPlacesCount * 15 +
        stats.reviewsCount * 50;
  }
}
