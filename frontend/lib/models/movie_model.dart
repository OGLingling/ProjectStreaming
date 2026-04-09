class Movie {
  final int? id;
  final String? tmdbId; // Agregado
  final String? imdbId;
  final String title;
  final String? description;
  final String releaseDate;
  final String? imageUrl;
  final String? backdropUrl;
  final String? trailerUrl; // El campo que faltaba
  final double rating;
  final String? category;
  final String type;

  Movie({
    this.id,
    this.tmdbId, // Agregado
    this.imdbId,
    required this.title,
    this.description,
    required this.releaseDate,
    this.imageUrl,
    this.backdropUrl,
    this.trailerUrl,
    required this.rating,
    this.category,
    required this.type,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'],
      tmdbId: json['tmdbId'], // Agregado
      imdbId: json['imdbId'],
      title: json['title'] ?? 'Sin título',
      description: json['description'],
      releaseDate: json['releaseDate'] ?? 'Sin fecha de estreno',
      imageUrl: json['imageUrl'],
      backdropUrl: json['backdropUrl'],
      trailerUrl: json['trailerUrl'], // Mapeo directo desde el JSON del backend
      rating: json['rating'] != null
          ? double.parse(json['rating'].toString())
          : 0.0,
      category: json['category'],
      type: json['type'] ?? 'movie',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tmdbId': tmdbId, // Agregado
    'imdbId': imdbId,
    'title': title,
    'description': description,
    'releaseDate': releaseDate,
    'imageUrl': imageUrl,
    'backdropUrl': backdropUrl,
    'trailerUrl': trailerUrl,
    'rating': rating,
    'category': category,
    'type': type,
  };
}
