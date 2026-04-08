import 'dart:convert';

class Movie {
  final int? id; // ID interno de tu DB (Autoincrement)
  final String? tmdbId; // Nueva llave maestra
  final String? imdbId;
  final String title;
  final String? description;
  final String? releaseDate; // Cambiado a String para consistencia con Prisma
  final String? imageUrl;
  final String? backdropUrl;
  final String? category;
  final String type; // "movie" o "tv"
  final DateTime? createdAt;

  Movie({
    this.id,
    this.tmdbId,
    this.imdbId,
    required this.title,
    this.description,
    this.releaseDate,
    this.imageUrl,
    this.backdropUrl,
    this.category,
    required this.type,
    this.createdAt,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      // Prisma devuelve 'id' como Int, nos aseguramos de capturarlo bien
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? ''),

      // Mapeo flexible para tmdb_id (snake_case de la DB) o tmdbId (camelCase del JSON)
      tmdbId: (json['tmdbId'] ?? json['tmdb_id'])?.toString(),

      // Mapeo flexible para imdbId
      imdbId: (json['imdbId'] ?? json['imdb_id'])?.toString(),

      title: json['title'] ?? 'Sin título',
      description: json['description'] ?? '',

      // Guardamos la fecha como String para evitar errores de parseo DateTime.parse()
      // si el formato de la API cambia.
      releaseDate: json['releaseDate']?.toString(),

      imageUrl: json['imageUrl'],
      backdropUrl: json['backdropUrl'],
      category: json['category'],

      // Valor por defecto "movie" si viene nulo
      type: json['type'] ?? 'movie',

      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tmdbId': tmdbId,
      'imdbId': imdbId,
      'title': title,
      'description': description,
      'releaseDate': releaseDate,
      'imageUrl': imageUrl,
      'backdropUrl': backdropUrl,
      'category': category,
      'type': type,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  // Helper pro: Para mostrar solo el año en la UI
  String get releaseYear => (releaseDate != null && releaseDate!.length >= 4)
      ? releaseDate!.substring(0, 4)
      : 'N/A';
}
