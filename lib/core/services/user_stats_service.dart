import 'package:nikara_app/core/gamification/badges_logic.dart';
import 'package:nikara_app/core/services/auth_service.dart';
import 'package:nikara_app/core/services/favorites_service.dart';
import 'package:nikara_app/features/business/data/business_storage_service.dart';

/// Calcula las [UserStats] reales del usuario a partir del estado persistido de la app; ningún campo es un número fijo/mock.
class UserStatsService {
  UserStatsService({
    FavoritesService? favoritesService,
    BusinessStorageService? businessStorageService,
    AuthService? authService,
  }) : _favoritesService = favoritesService ?? FavoritesService(),
       _businessStorageService =
           businessStorageService ?? BusinessStorageService(),
       _authService = authService ?? AuthService();

  final FavoritesService _favoritesService;
  final BusinessStorageService _businessStorageService;
  final AuthService _authService;

  Future<UserStats> getStats() async {
    final favorites = await _favoritesService.getFavoriteIds();
    final userId = _authService.currentAuthUser?.id;

    // Cuenta reseñas reales del usuario en TODOS los negocios, no solo el propio.
    final myReviewsCount = userId == null
        ? 0
        : (await _businessStorageService.getBusinesses())
              .expand((b) => b.reviews)
              .where((r) => r.authorId == userId)
              .length;

    return UserStats(
      // Aún no existe flujo de viaje/visita completada, por eso es 0 real, no placeholder.
      tripsCount: 0,
      savedPlacesCount: favorites.length,
      reviewsCount: myReviewsCount,
    );
  }

  /// 100 pts por viaje, 15 por lugar guardado, 20 por reseña (coincide con la recompensa de "Escribir una reseña").
  int computePoints(UserStats stats) {
    return stats.tripsCount * 100 +
        stats.savedPlacesCount * 15 +
        stats.reviewsCount * 20;
  }
}
