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
        // Mapeamos asegurándonos de que tmdb_id sea tratado como String o int según prefieras
        _watchlist = List<Map<String, dynamic>>.from(data);
        debugPrint("Watchlist cargada: $_watchlist");
      }
    } catch (e) {
      debugPrint("Error cargando watchlist: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Guardar o eliminar (Toggle) usando TMDB ID
  Future<void> toggleWatchlist(
    String userId,
    int tmdbId, // <--- Ahora pasamos el ID de TMDB (ej. 980431)
    String title,
    String image,
  ) async {
    try {
      // Nota: Tu backend debe estar preparado para recibir el tmdb_id
      // y buscar el contentId correspondiente para insertar en la tabla intermedia.
      final response = await http.post(
        Uri.parse('$baseUrl/toggle'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "userId": userId,
          "tmdbId": tmdbId, // Enviamos tmdbId al servidor
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (isInWatchlist(tmdbId)) {
          // Removamos comparando contra el ID de TMDB
          _watchlist.removeWhere(
            (item) =>
                (item['tmdb_id']?.toString() == tmdbId.toString()) ||
                (item['id']?.toString() == tmdbId.toString()),
          );
        } else {
          // Agregamos con la estructura correcta para que la UI lo lea
          _watchlist.add({'tmdb_id': tmdbId, 'title': title, 'image': image});
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error en toggleWatchlist: $e");
      rethrow;
    }
  }

  // Verificar si un ID de TMDB ya está en la lista
  bool isInWatchlist(dynamic tmdbId) {
    if (tmdbId == null) return false;
    String idToSearch = tmdbId.toString();

    return _watchlist.any((item) {
      // Buscamos en todas las posibles llaves donde pueda estar el ID de TMDB
      return item['tmdb_id']?.toString() == idToSearch ||
          item['tmdbId']?.toString() == idToSearch ||
          item['id']?.toString() ==
              idToSearch; // A veces el backend lo manda como 'id'
    });
  }
}
