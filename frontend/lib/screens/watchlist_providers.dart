import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class WatchlistProvider with ChangeNotifier {
  final List<Map<String, dynamic>> _list = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get favoriteMovies => _list;
  bool get isLoading => _isLoading;

  // URL de tu API (Cámbiala por la real de tu backend)
  final String apiUrl = "https://tu-api-en-production.com/api/watchlist";

  // Cargar lista desde la base de datos (Neon)
  Future<void> loadWatchlist(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse('$apiUrl?userId=$userId'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _list.clear();
        _list.addAll(data.map((item) => item as Map<String, dynamic>));
      }
    } catch (e) {
      debugPrint("Error cargando watchlist: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Guardar o eliminar de la base de datos
  Future<void> toggleFavorite(Map<String, dynamic> movie, String userId) async {
    final bool exists = isFavorite(movie['title'] ?? '');

    try {
      if (exists) {
        // Lógica para eliminar (DELETE)
        final response = await http.delete(
          Uri.parse(apiUrl),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"userId": userId, "contentId": movie['id']}),
        );
        if (response.statusCode == 200) {
          _list.removeWhere((item) => item['title'] == movie['title']);
        }
      } else {
        // Lógica para agregar (POST)
        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "userId": userId,
            "contentId": movie['id'],
            "title": movie['title'],
            "image": movie['image'],
          }),
        );
        if (response.statusCode == 201 || response.statusCode == 200) {
          _list.add(movie);
        }
      }
    } catch (e) {
      debugPrint("Error en comunicación con backend: $e");
    }
    notifyListeners();
  }

  bool isFavorite(String title) {
    return _list.any((item) => item['title'] == title);
  }
}
