import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WatchlistProvider with ChangeNotifier {
  List<Map<String, dynamic>> _watchlist = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get watchlist => _watchlist;
  bool get isLoading => _isLoading;

  // CORRECCIÓN CRÍTICA: Se añade ".up" a la URL para validar el certificado SSL
  final String baseUrl =
      "https://projectstreaming-production.up.railway.app/api/watchlist";

  Future<void> loadWatchlist(String userId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.get(Uri.parse('$baseUrl?userId=$userId'));
      if (response.statusCode == 200) {
        _watchlist = List<Map<String, dynamic>>.from(
          json.decode(response.body),
        );
      }
    } catch (e) {
      debugPrint("Error conexión: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleWatchlist({
    required String userId,
    required dynamic tmdbId,
    required String title,
    required String image,
    String type = 'movie',
  }) async {
    final String idString = tmdbId.toString();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/toggle'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "userId": userId,
          "tmdbId": idString,
          "title": title,
          "image": image,
          "type": type,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (isInWatchlist(idString)) {
          _watchlist.removeWhere(
            (item) =>
                (item['tmdb_id']?.toString() ?? item['tmdbId']?.toString()) ==
                idString,
          );
        } else {
          _watchlist.add({'tmdb_id': idString, 'title': title, 'image': image});
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Fallo de red: $e");
    }
  }

  bool isInWatchlist(dynamic tmdbId) {
    if (tmdbId == null) return false;
    final String idToSearch = tmdbId.toString();
    return _watchlist.any(
      (item) =>
          (item['tmdb_id']?.toString() ?? item['tmdbId']?.toString()) ==
          idToSearch,
    );
  }
}
