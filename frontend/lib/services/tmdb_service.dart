import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/movie_model.dart';

class TmdbService {
  static const String _apiKey = 'd8a00b94f5c00821e497b569fec9a61f';

  static Future<Movie?> getMovieDetails(dynamic tmdbId, String type) async {
    // Protección contra IDs vacíos o nulos
    if (tmdbId == null || tmdbId.toString() == 'null' || tmdbId.toString().isEmpty) {
      return null;
    }

    final String cleanId = tmdbId.toString().trim();
    // Normalizar media_type para TMDB
    final String mediaType = (type.toLowerCase().contains('serie') || type.toLowerCase() == 'tv') 
        ? 'tv' 
        : 'movie';

    final url = Uri.parse(
      'https://api.themoviedb.org/3/$mediaType/$cleanId?api_key=$_apiKey&language=es-ES&append_to_response=videos,credits,images,seasons',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        return Movie(
          id: data['id'] ?? 0,
          tmdbId: data['id']?.toString() ?? cleanId,
          title: data['title'] ?? data['name'] ?? 'Sin título',
          description: data['overview'] ?? 'Sin sinopsis disponible',
          releaseDate: data['release_date'] ?? data['first_air_date'] ?? '',
          imageUrl: data['poster_path'] ?? '',
          backdropUrl: data['backdrop_path'] ?? '',
          rating: (data['vote_average'] as num?)?.toDouble() ?? 0.0,
          category: '',
          type: mediaType,
          // Mapeo seguro de la lista de temporadas
          seasons: (data['seasons'] as List?)
              ?.map((s) => Season.fromJson(s))
              .toList(),
        );
      } else {
        print("❌ [TmdbService] Error ${response.statusCode} buscando ID: $cleanId");
      }
    } catch (e) {
      print("❌ [TmdbService] Error crítico: $e");
    }
    return null;
  }
}