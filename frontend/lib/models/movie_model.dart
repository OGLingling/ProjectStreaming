import 'dart:convert';

class Movie {
  final String? id;
  final String title;
  final String? description;
  final DateTime releaseDate;
  final double rating;
  final String? imageUrl;
  final String? backdropUrl;
  final String? category;
  final String? type;
  final String? videoUrl;
  final String? originAddonUrl;
  final List<StreamOption>? streams;

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
    this.originAddonUrl,
    this.streams,
    this.videoUrl,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      // Soporta id de tu DB (int) o de Addons (String/IMDB)
      id: json['id']?.toString() ?? json['imdb_id']?.toString(),
      title: json['title'] ?? json['name'] ?? 'Sin título',
      description: json['description'] ?? json['overview'] ?? '',
      releaseDate: json['releaseDate'] != null
          ? DateTime.parse(json['releaseDate'])
          : (json['last_updated'] != null
                ? DateTime.parse(json['last_updated'])
                : DateTime.now()),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['imageUrl'] ?? json['poster_path'],
      backdropUrl: json['backdropUrl'] ?? json['imageUrl'],
      category: json['category'],
      type: json['type'],
      videoUrl: json['videoUrl'],
      originAddonUrl: json['originAddonUrl'],
      streams: json['streams'] != null
          ? (json['streams'] as List)
                .map((i) => StreamOption.fromJson(i))
                .toList()
          : null,
    );
  }

  // MÉTODO IMPORTANTE: Necesario para _navigateToDetails(movie.toJson())
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'releaseDate': releaseDate.toIso8601String(),
      'rating': rating,
      'imageUrl': imageUrl,
      'backdropUrl': backdropUrl,
      'category': category,
      'type': type,
      'videoUrl': videoUrl,
      'originAddonUrl': originAddonUrl,
      'streams': streams?.map((e) => e.toJson()).toList(),
    };
  }
}

class StreamOption {
  final String quality;
  final String url;

  StreamOption({required this.quality, required this.url});

  factory StreamOption.fromJson(Map<String, dynamic> json) {
    return StreamOption(
      quality: json['title'] ?? json['name'] ?? 'HD',
      url: json['url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'quality': quality, 'url': url};
  }
}
