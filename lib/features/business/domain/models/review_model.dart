class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.authorName,
    this.authorId = '',
    required this.rating,
    required this.comment,
    required this.date,
    this.mediaPaths = const [],
  });

  final String id;
  final String authorName;

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
      rating: (json['rating'] as num).toDouble(),
      comment: json['comment'] as String,
      date: DateTime.parse(json['date'] as String),
      mediaPaths:
          (json['mediaPaths'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }
}
