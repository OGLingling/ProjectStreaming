import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Configura aquí tu URL real de Render
  static const String _baseUrl = "https://projectstreaming-1.onrender.com/api";

  // ---------------------------------------------------
  // SECCIÓN: PELÍCULAS Y CONTENIDO
  // ---------------------------------------------------

  static Future<List<dynamic>> getMoviesByType(String type) async {
    try {
      final response = await http.get(Uri.parse("$_baseUrl/movies?type=$type"));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return [];
    } catch (e) {
      print("Error getMoviesByType: $e");
      return [];
    }
  }

  // ---------------------------------------------------
  // SECCIÓN: AUTENTICACIÓN Y OTP
  // ---------------------------------------------------

  static Future<Map<String, dynamic>?> getUserDataByEmail(String email) async {
    try {
      final response = await http.get(Uri.parse("$_baseUrl/users/$email"));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> sendOTP(String email) async {
    try {
      final response = await http.post(
        Uri.parse("$_baseUrl/auth/send-otp"),
        body: json.encode({'email': email}),
        headers: {'Content-Type': 'application/json'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> verifyOTP(String email, String otp) async {
    try {
      final response = await http.post(
        Uri.parse("$_baseUrl/auth/verify-otp"),
        body: json.encode({'email': email, 'otp': otp}),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> registerUser(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse("$_baseUrl/auth/register"),
        body: json.encode(data),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ---------------------------------------------------
  // SECCIÓN: CLIENT-SIDE SCRAPING (NUEVA LÓGICA)
  // ---------------------------------------------------

  /// Obtiene los candidatos desde el backend (método estático para video_player_screen)
  static Future<List<String>> getExtractionCandidates({
    required String tmdbId,
    required String type,
    int? season,
    int? episode,
  }) async {
    try {
      final queryParams = {
        'tmdbId': tmdbId,
        'type': type,
        if (season != null) 'season': season.toString(),
        if (episode != null) 'episode': episode.toString(),
      };

      final uri = Uri.parse("$_baseUrl/extract").replace(queryParameters: queryParams);
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['candidates'] ?? []);
      }
    } catch (e) {
      print("Error obteniendo candidatos: $e");
    }
    return [];
  }

  /// Prueba los candidatos y devuelve el primero funcional
  static Future<String?> getValidStreamUrl({
    required String tmdbId,
    required String type,
    int? season,
    int? episode,
  }) async {
    final List<String> candidates = await getExtractionCandidates(
      tmdbId: tmdbId,
      type: type,
      season: season,
      episode: episode,
    );

    for (String url in candidates) {
      try {
        final res = await http.get(
          Uri.parse(url),
          headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/124.0.0.0'},
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200 && res.body.length > 800) {
          return url;
        }
      } catch (e) {
        continue;
      }
    }
    return null;
  }
}