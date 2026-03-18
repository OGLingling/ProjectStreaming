class Movie {
  final int? id;
  final String title;
  final String description;
  final DateTime releaseDate;
  final double rating;
  final String imageUrl;
  final String category;
  final String? type;
  final String? videoUrl;

  Movie({
    this.id,
    required this.title,
    required this.description,
    required this.releaseDate,
    required this.rating,
    required this.imageUrl,
    required this.category,
    this.type,
    this.videoUrl,
  });

  // Añade esto para convertir de JSON a Objeto Movie
  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      releaseDate: DateTime.parse(json['releaseDate']),
      rating: (json['rating'] as num).toDouble(),
      imageUrl: json['imageUrl'] ?? '',
      category: json['category'] ?? '',
      type: json['type'],
      videoUrl: json['videoUrl'],
    );
  }

  Map<String, dynamic> toJson() => {
    "title": title,
    "description": description,
    "releaseDate": releaseDate.toIso8601String(),
    "rating": rating,
    "imageUrl": imageUrl,
    "category": category,
    "type": type,
    "videoUrl": videoUrl,
  };
}
