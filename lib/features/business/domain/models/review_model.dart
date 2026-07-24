class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.authorName,
    required this.rating,
    required this.comment,
    required this.date,
  });

  final String id;
  final String authorName;
  final double rating;
  final String comment;
  final DateTime date;

  Map<String, dynamic> toJson() => {
    'id': id,
    'authorName': authorName,
    'rating': rating,
    'comment': comment,
    'date': date.toIso8601String(),
  };

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] as String,
      authorName: json['authorName'] as String,
      rating: (json['rating'] as num).toDouble(),
      comment: json['comment'] as String,
      date: DateTime.parse(json['date'] as String),
    );
  }
}
