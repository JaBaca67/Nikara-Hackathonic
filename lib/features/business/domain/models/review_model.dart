import 'package:nikara_app/core/models/user_origin.dart';

class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.authorName,
    this.authorId = '',
    required this.rating,
    required this.comment,
    required this.date,
    this.mediaPaths = const [],
    this.authorAvatarUrl,
    this.authorOrigin = const UserOrigin(),
  });

  final String id;
  final String authorName;
  final String? authorAvatarUrl;
  final UserOrigin authorOrigin;

  /// Email de cuenta al momento de escribir la reseña; permite a [UserStatsService] contar reseñas reales en vez de adivinar por [authorName]. Vacío en reseñas previas a este campo.
  final String authorId;
  final double rating;
  final String comment;
  final DateTime date;

  /// Rutas locales de fotos/videos adjuntos en "Escribir una reseña".
  final List<String> mediaPaths;

  Map<String, dynamic> toJson() => {
    'id': id,
    'authorName': authorName,
    'authorId': authorId,
    'authorAvatarUrl': authorAvatarUrl,
    'authorOrigin': authorOrigin.toRow(),
    'rating': rating,
    'comment': comment,
    'date': date.toIso8601String(),
    'mediaPaths': mediaPaths,
  };

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] as String,
      authorName: json['authorName'] as String,
      authorId: json['authorId'] as String? ?? '',
      authorAvatarUrl: json['authorAvatarUrl'] as String?,
      authorOrigin: UserOrigin.fromRow(
        json['authorOrigin'] as Map<String, dynamic>? ?? const {},
      ),
      rating: (json['rating'] as num).toDouble(),
      comment: json['comment'] as String,
      date: DateTime.parse(json['date'] as String),
      mediaPaths:
          (json['mediaPaths'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }
}

/// Deja una sola reseña por persona: la más reciente de cada [ReviewModel.authorId].
///
/// Cada persona califica un negocio una sola vez; si la base todavía trae
/// duplicados (de antes de la restricción única), solo cuenta la última para el
/// promedio, el conteo y el desglose. Las reseñas sin autor identificado
/// (`authorId` vacío, del cache local antiguo) no se pueden deduplicar y se
/// conservan todas. El orden de la lista original se respeta.
List<ReviewModel> onePerAuthor(List<ReviewModel> reviews) {
  final latestByAuthor = <String, ReviewModel>{};
  for (final review in reviews) {
    if (review.authorId.isEmpty) continue;
    final current = latestByAuthor[review.authorId];
    if (current == null || review.date.isAfter(current.date)) {
      latestByAuthor[review.authorId] = review;
    }
  }
  return [
    for (final review in reviews)
      if (review.authorId.isEmpty ||
          identical(latestByAuthor[review.authorId], review))
        review,
  ];
}

/// [reviews] con [review] aplicada: si su autora ya había reseñado, se
/// reemplaza esa reseña (editar), y si no, se agrega (crear). Nunca deja dos
/// de la misma persona.
List<ReviewModel> upsertReviewByAuthor(
  List<ReviewModel> reviews,
  ReviewModel review,
) {
  if (review.authorId.isEmpty) return [...reviews, review];
  final kept = reviews.where((r) => r.authorId != review.authorId).toList();
  final index = reviews.indexWhere((r) => r.authorId == review.authorId);
  if (index < 0) return [...kept, review];
  final position = reviews
      .take(index)
      .where((r) => r.authorId != review.authorId)
      .length;
  return [...kept.take(position), review, ...kept.skip(position)];
}

/// [reviews] sin ninguna de las reseñas de [authorId] (al eliminar la propia).
List<ReviewModel> removeReviewsByAuthor(
  List<ReviewModel> reviews,
  String authorId,
) => [
  for (final review in reviews)
    if (review.authorId != authorId) review,
];
