import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = "https://tu-proyecto-en-render.com/api";

  static const Map<String, String> _defaultHeaders = {
    'Content-Type': 'application/json',
  };

  // --- MÉTODOS DE AUTENTICACIÓN ---
  static Future<Map<String, dynamic>?> getUserDataByEmail(String email) async {
    try {
      final response = await http.get(Uri.parse("$_baseUrl/users/${email.trim().toLowerCase()}"));
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (e) { debugPrint("Error: $e"); }
    return null;
  }

  static Future<bool> sendOTP(String email) async {
    try {
      final response = await http.post(Uri.parse("$_baseUrl/auth/send-otp"),
          body: json.encode({'email': email.trim().toLowerCase()}), headers: _defaultHeaders);
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  static Future<Map<String, dynamic>?> verifyOTP(String email, String otp) async {
    try {
      final response = await http.post(Uri.parse("$_baseUrl/auth/verify-otp"),
          body: json.encode({'email': email.trim().toLowerCase(), 'otp': otp}), headers: _defaultHeaders);
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (e) { debugPrint("Error: $e"); }
    return null;
  }

  static Future<Map<String, dynamic>?> registerUser(Map<String, dynamic> data) async {
    try {
      final response = await http.post(Uri.parse("$_baseUrl/auth/register"),
          body: json.encode(data), headers: _defaultHeaders);
      if (response.statusCode == 201 || response.statusCode == 200) return json.decode(response.body);
    } catch (e) { debugPrint("Error: $e"); }
    return null;
  }

  // --- MÉTODOS PARA PELÍCULAS Y SERIES (Restaurados) ---
  static Future<List<dynamic>> getMoviesByType(String type) async {
    try {
      final response = await http.get(Uri.parse("$_baseUrl/content/$type"));
      if (response.statusCode == 200) return json.decode(response.body);
    } catch (e) { debugPrint("Error cargando contenido: $e"); }
    return [];
  }

  // Este es el que pide video_player_screen.dart
  static Future<List<String>> getExtractionCandidates({required String tmdbId, required String type, int? season, int? episode}) async {
    try {
      final queryParams = {
        'tmdbId': tmdbId,
        'type': type,
        if (season != null) 'season': season.toString(),
        if (episode != null) 'episode': episode.toString(),
      };
      final uri = Uri.parse("$_baseUrl/extract").replace(queryParameters: queryParams);
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['candidates'] ?? []);
      }
    } catch (e) { debugPrint("Error extrayendo: $e"); }
    return [];
  }

  // Mantenemos este por si movie_details_screen lo usa
  static Future<String?> getValidStreamUrl({required String tmdbId, required String type, int? season, int? episode}) async {
    final candidates = await getExtractionCandidates(tmdbId: tmdbId, type: type, season: season, episode: episode);
    return candidates.isNotEmpty ? candidates.first : null;
  }
}