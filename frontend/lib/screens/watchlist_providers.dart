import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WatchlistProvider with ChangeNotifier {
  List<Map<String, dynamic>> _watchlist = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get watchlist => _watchlist;
  bool get isLoading => _isLoading;

  // Cambia esta URL por la de tu servidor en Railway
  final String baseUrl =
      "https://projectstreaming-production.app.railway.app/api/watchlist";

  // Cargar la lista desde Neon
  Future<void> loadWatchlist(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse('$baseUrl?userId=$userId'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _watchlist = List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      print("Error cargando watchlist: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Guardar o eliminar (Toggle)
  Future<void> toggleWatchlist(
    String userId,
    int contentId, // <--- Aquí usabas el ID interno (ej. 36)
    String title,
    String image,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/toggle'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"userId": userId, "contentId": contentId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Actualizamos la lista local para que la UI cambie instantáneamente
        if (isInWatchlist(contentId)) {
          _watchlist.removeWhere((item) => item['id'] == contentId);
        } else {
          _watchlist.add({'id': contentId, 'title': title, 'image': image});
        }
        notifyListeners();
      }
    } catch (e) {
      print("Error en toggleWatchlist: $e");
      rethrow;
    }
  }

  // Verificar si un ID ya está en la lista
  bool isInWatchlist(int contentId) {
    return _watchlist.any((item) => item['id'] == contentId);
  }
}
