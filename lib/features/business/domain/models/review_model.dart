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

  /// [UserSessionService]'s account email at the moment this review was
  /// submitted — lets [UserStatsService] count "reviews I wrote" for real
  /// across every business, instead of guessing from [authorName]. Empty
  /// for reviews saved before this field existed.
  final String authorId;
  final double rating;
  final String comment;
  final DateTime date;

  /// On-device paths to photos/videos attached via "Escribir una reseña"'s
  /// media picker — empty for reviews that didn't attach anything.
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
