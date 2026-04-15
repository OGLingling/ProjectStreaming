class Movie {
  final int? id;
  final String? tmdbId;
  final String title;
  final String? description;
  final String releaseDate;
  final String? imageUrl;
  final String? backdropUrl;
  final String? trailerUrl;
  final double rating;
  final String? category;
  final String type;

  // NUEVO: Relación con temporadas
  final List<Season>? seasons;

  Movie({
    this.id,
    this.tmdbId,
    required this.title,
    this.description,
    required this.releaseDate,
    this.imageUrl,
    this.backdropUrl,
    this.trailerUrl,
    required this.rating,
    this.category,
    required this.type,
    this.seasons,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'],
      tmdbId:
          json['tmdb_id'] ??
          json['tmdbId'], // Maneja ambos formatos (Prisma usa tmdb_id)
      title: json['title'] ?? 'Sin título',
      description: json['description'],
      releaseDate: json['releaseDate'] ?? 'Sin fecha de estreno',
      imageUrl: json['imageUrl'],
      backdropUrl: json['backdropUrl'],
      trailerUrl: json['trailer_url'] ?? json['trailerUrl'],
      rating: json['rating'] != null
          ? double.parse(json['rating'].toString())
          : 0.0,
      category: json['category'],
      type: json['type'] ?? 'movie',
      // Mapeo de temporadas si existen en el JSON
      seasons: json['seasons'] != null
          ? (json['seasons'] as List).map((i) => Season.fromJson(i)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tmdbId': tmdbId,
    'title': title,
    'description': description,
    'releaseDate': releaseDate,
    'imageUrl': imageUrl,
    'backdropUrl': backdropUrl,
    'trailerUrl': trailerUrl,
    'rating': rating,
    'category': category,
    'type': type,
    'seasons': seasons?.map((s) => s.toJson()).toList(),
  };
}

// NUEVO: Modelo de Temporada
class Season {
  final int id;
  final int seasonNumber;
  final String? title;
  final String? tmdbId;
  final List<Episode>? episodes;

  Season({
    required this.id,
    required this.seasonNumber,
    this.title,
    this.tmdbId,
    this.episodes,
  });

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      id: json['id'],
      seasonNumber: json['seasonNumber'],
      title: json['title'],
      tmdbId: json['tmdb_id'] ?? json['tmdbId'],
      episodes: json['episodes'] != null
          ? (json['episodes'] as List).map((i) => Episode.fromJson(i)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'seasonNumber': seasonNumber,
    'title': title,
    'tmdbId': tmdbId,
    'episodes': episodes?.map((e) => e.toJson()).toList(),
  };
}

// NUEVO: Modelo de Episodio
class Episode {
  final int id;
  final int episodeNumber;
  final String title;
  final String? description;
  final String? stillPath;

  Episode({
    required this.id,
    required this.episodeNumber,
    required this.title,
    this.description,
    this.stillPath,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      id: json['id'],
      episodeNumber: json['episodeNumber'],
      title: json['title'] ?? 'Sin título',
      description: json['description'],
      stillPath: json['stillPath'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'episodeNumber': episodeNumber,
    'title': title,
    'description': description,
    'stillPath': stillPath,
  };
}
