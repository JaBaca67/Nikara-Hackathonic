import 'package:nikara_app/core/gamification/badges_logic.dart';
import 'package:nikara_app/core/services/favorites_service.dart';
import 'package:nikara_app/core/services/user_session_service.dart';
import 'package:nikara_app/features/business/data/business_storage_service.dart';

/// Computes the current user's real [UserStats] from the app's actual
/// persisted state — no field here is a fixed/mock number.
class UserStatsService {
  UserStatsService({
    FavoritesService? favoritesService,
    BusinessStorageService? businessStorageService,
    UserSessionService? sessionService,
  }) : _favoritesService = favoritesService ?? FavoritesService(),
       _businessStorageService =
           businessStorageService ?? BusinessStorageService(),
       _sessionService = sessionService ?? UserSessionService();

  final FavoritesService _favoritesService;
  final BusinessStorageService _businessStorageService;
  final UserSessionService _sessionService;

  Future<UserStats> getStats() async {
    final favorites = await _favoritesService.getFavoriteIds();
    final userData = await _sessionService.getUserData();

    // Count real reviews the signed-in account wrote — across EVERY
    // business, not just their own — matched by ReviewModel.authorId.
    final myReviewsCount = userData == null
        ? 0
        : (await _businessStorageService.getBusinesses())
              .expand((b) => b.reviews)
              .where((r) => r.authorId == userData.email)
              .length;

    return UserStats(
      // There is no reservation-completion flow in the app yet (Business
      // Detail's booking CTA opens WhatsApp, it doesn't write a booking
      // record) — so this is genuinely zero, not a placeholder, until that
      // exists.
      tripsCount: 0,
      savedPlacesCount: favorites.length,
      reviewsCount: myReviewsCount,
    );
  }

  /// Points formula: every real action earns a fixed amount — 100 pts per
  /// completed trip, 15 pts per saved place, 20 pts per review written
  /// (matches "Escribir una reseña"'s +20 reward). Documented here rather
  /// than user-configurable, but always computed live.
  int computePoints(UserStats stats) {
    return stats.tripsCount * 100 +
        stats.savedPlacesCount * 15 +
        stats.reviewsCount * 20;
  }
}
