import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WatchlistProvider with ChangeNotifier {
  List<Map<String, dynamic>> _watchlist = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get watchlist => _watchlist;
  bool get isLoading => _isLoading;

  final String baseUrl =
      "https://projectstreaming-production.up.railway.app/api/watchlist";

  // Cargar la lista desde Neon
  Future<void> loadWatchlist(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse('$baseUrl?userId=$userId'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _watchlist = List<Map<String, dynamic>>.from(data);

        // Debug para verificar que los datos traigan 'tmdb_id'
        debugPrint("Watchlist sincronizada: $_watchlist");
      }
    } catch (e) {
      debugPrint("Error cargando watchlist: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Guardar o eliminar (Toggle) usando estrictamente TMDB ID
  Future<void> toggleWatchlist(
    String userId,
    dynamic tmdbId, // Aceptamos dynamic para evitar errores de tipo
    String title,
    String image,
  ) async {
    // Normalizamos el ID a String para la comparación local y envío
    final String cleanId = tmdbId.toString();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/toggle'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "userId": userId,
          "tmdbId": cleanId, // Enviamos el ID de TMDB (980431)
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (isInWatchlist(cleanId)) {
          // Si ya estaba, lo removemos localmente buscando por tmdb_id
          _watchlist.removeWhere(
            (item) =>
                (item['tmdb_id']?.toString() == cleanId) ||
                (item['tmdbId']?.toString() == cleanId),
          );
        } else {
          // Si no estaba, lo agregamos localmente con la llave correcta
          _watchlist.add({'tmdb_id': cleanId, 'title': title, 'image': image});
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error en toggleWatchlist: $e");
      rethrow;
    }
  }

  // VERIFICACIÓN CORREGIDA: Compara solo contra IDs de TMDB
  bool isInWatchlist(dynamic tmdbId) {
    if (tmdbId == null || tmdbId == 'null') return false;

    final String idToSearch = tmdbId.toString();

    return _watchlist.any((item) {
      // Priorizamos 'tmdb_id' que es como aparece en tu tabla Content de Neon
      final String? itemTmdbId =
          item['tmdb_id']?.toString() ?? item['tmdbId']?.toString();

      // Solo devolvemos true si el ID coincide exactamente con el ID de TMDB
      return itemTmdbId == idToSearch;
    });
  }
}
