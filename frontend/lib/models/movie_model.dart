class Movie {
  final int? id;
  final String title;
  final String? description;
  final DateTime releaseDate;
  final double rating;
  final String? imageUrl;
  final String? backdropUrl; // Lo mantenemos para el banner
  final String? category;
  final String? type;
  final String? videoUrl;

  Movie({
    this.id,
    required this.title,
    this.description,
    required this.releaseDate,
    required this.rating,
    this.imageUrl,
    this.backdropUrl,
    this.category,
    this.type,
    this.videoUrl,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'],
      // Prisma usa camelCase: releaseDate
      releaseDate: json['releaseDate'] != null
          ? DateTime.parse(json['releaseDate'])
          : DateTime.now(),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['imageUrl'],
      backdropUrl: json['backdropUrl'] ?? json['imageUrl'],
      category: json['category'],
      type: json['type'],
      videoUrl: json['videoUrl'],
    );
  }

  Map<String, dynamic> toJson() => {
    // IMPORTANTE: Estos nombres ahora coinciden 100% con tu esquema de Prisma
    "title": title,
    "description": description,
    "releaseDate": releaseDate.toIso8601String(),
    "rating": rating,
    "imageUrl": imageUrl,
    "backdropUrl": backdropUrl,
    "category": category,
    "type": type ?? "hollywood",
    "videoUrl": videoUrl,
    // a menos que lo agregues al esquema de la DB.
  };
}
