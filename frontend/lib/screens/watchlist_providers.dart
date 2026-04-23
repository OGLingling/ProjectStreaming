import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WatchlistProvider with ChangeNotifier {
  List<Map<String, dynamic>> _watchlist = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get watchlist => _watchlist;
  bool get isLoading => _isLoading;

  final String baseUrl =
      "https://projectstreaming.onrender.com/api/watchlist";

  // Cargar la lista desde Neon
  Future<void> loadWatchlist(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse('$baseUrl?userId=$userId'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        // Ahora cargamos la lista completa con tmdb_id y type
        _watchlist = List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      debugPrint("Error cargando watchlist: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Guardar o eliminar (Toggle)
  Future<void> toggleWatchlist(
    String userId,
    int contentId,
    String title,
    String image, {
    String? tmdbId, // Agregamos estos para actualizar la UI localmente
    String? type,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/toggle'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"userId": userId, "contentId": contentId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Buscamos si ya existe usando el internal ID (ej: 36)
        if (isInWatchlist(contentId)) {
          _watchlist.removeWhere((item) => item['id'] == contentId);
        } else {
          // Al agregar, guardamos todos los datos necesarios para que
          // el frontend no dé error al intentar abrir la serie recién agregada
          _watchlist.add({
            'id': contentId,
            'tmdb_id': tmdbId, // Fundamental para evitar el error 'null'
            'title': title,
            'image': image,
            'type': type ?? 'movie',
          });
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error en toggleWatchlist: $e");
      rethrow;
    }
  }

  // Verificar si un ID ya está en la lista (Usa el ID de la DB interna)
  bool isInWatchlist(int contentId) {
    return _watchlist.any((item) => item['id'] == contentId);
  }
}
