import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/movie_model.dart';

class TmdbService {
  static const String _apiKey = 'd8a00b94f5c00821e497b569fec9a61f';

  static Future<Movie?> getMovieDetails(dynamic tmdbId, String type) async {
    if (tmdbId == null || tmdbId.toString() == 'null' || tmdbId.toString().isEmpty) return null;

    final String cleanId = tmdbId.toString().trim();
    final String mediaType = type.toLowerCase().contains('tv') ? 'tv' : 'movie';

    final url = Uri.parse(
      'https://api.themoviedb.org/3/$mediaType/$cleanId?api_key=$_apiKey&language=es-ES&append_to_response=seasons,videos',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Movie(
          id: data['id'] ?? 0,
          tmdbId: data['id']?.toString() ?? cleanId,
          title: data['title'] ?? data['name'] ?? 'Sin título',
          description: data['overview'] ?? '',
          releaseDate: data['release_date'] ?? data['first_air_date'] ?? '',
          imageUrl: data['poster_path'] ?? '',
          backdropUrl: data['backdrop_path'] ?? '',
          rating: (data['vote_average'] as num?)?.toDouble() ?? 0.0,
          category: '',
          type: mediaType,
          seasons: (data['seasons'] as List?)?.map((s) => Season.fromJson(s)).toList(),
        );
      }
    } catch (e) {
      print("❌ [TMDB Error] $e");
    }
    return null;
  }
}