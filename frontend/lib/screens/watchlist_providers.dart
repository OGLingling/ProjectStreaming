import 'package:flutter/material.dart';

class WatchlistProvider with ChangeNotifier {
  final List<Map<String, String>> _list = [];

  List<Map<String, String>> get favoriteMovies => _list;

  void toggleFavorite(Map<String, String> movie) {
    // Verificamos si ya existe por ID o Título
    final index = _list.indexWhere((item) => item['title'] == movie['title']);

    if (index >= 0) {
      _list.removeAt(index);
    } else {
      _list.add(movie);
    }
    notifyListeners(); // Esto refresca las pantallas automáticamente
  }

  bool isFavorite(String title) {
    return _list.any((item) => item['title'] == title);
  }
}
