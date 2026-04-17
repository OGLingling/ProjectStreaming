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

  // 1. Cargar lista: Forzamos que los datos se guarden como Strings para comparar fácil
  Future<void> loadWatchlist(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse('$baseUrl?userId=$userId'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _watchlist = List<Map<String, dynamic>>.from(data);

        // Imprime esto en consola para ver qué llaves llegan realmente de Railway
        debugPrint("DATOS RECIBIDOS DE NEON: $_watchlist");
      }
    } catch (e) {
      debugPrint("Error cargando watchlist: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 2. Toggle: Enviamos y comparamos usando el nombre de tu columna en Neon: 'tmdb_id'
  Future<void> toggleWatchlist(
    String userId,
    dynamic tmdbId,
    String title,
    String image,
  ) async {
    final String idString = tmdbId.toString();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/toggle'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "userId": userId,
          "tmdbId": idString, // Tu API debe esperar 'tmdbId' o 'tmdb_id'
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (isInWatchlist(idString)) {
          // Si ya está, lo quitamos de la lista local
          _watchlist.removeWhere((item) => _getIdFromItem(item) == idString);
        } else {
          // Si es nuevo, lo agregamos con la llave 'tmdb_id' igual que en Neon
          _watchlist.add({'tmdb_id': idString, 'title': title, 'image': image});
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error en toggleWatchlist: $e");
    }
  }

  // 3. Verificación: Esta es la función que decide si sale "+" o "Check"
  bool isInWatchlist(dynamic tmdbId) {
    if (tmdbId == null || tmdbId == 'null') return false;
    final String idToSearch = tmdbId.toString();

    return _watchlist.any((item) {
      return _getIdFromItem(item) == idToSearch;
    });
  }

  // Función auxiliar para extraer el ID sin importar si la API manda 'tmdb_id' o 'tmdbId'
  String? _getIdFromItem(Map<String, dynamic> item) {
    return item['tmdb_id']?.toString() ?? item['tmdbId']?.toString();
  }
}
