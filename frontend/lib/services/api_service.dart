import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Base URL
  static const String baseUrl = "https://projectstreaming-1.onrender.com";

  static const Duration _extractTimeout = Duration(seconds: 60);
  static const int _extractMaxAttempts = 3;
  static const Set<int> _retryableStatusCodes = {502, 503, 504};
  static const Map<String, String> _jsonHeaders = {
    "Content-Type": "application/json",
    "Accept": "application/json",
  };

  static bool _isTransientNetworkError(Object error) {
    return error is SocketException ||
        error is http.ClientException ||
        error is TimeoutException;
  }

  static Future<http.Response> _getWithRetry(Uri url) async {
    Object? lastError;

    for (var attempt = 1; attempt <= _extractMaxAttempts; attempt++) {
      try {
        debugPrint("Extractor GET attempt $attempt URL: $url");
        debugPrint("Extractor GET body: <none>");

        final response = await http
            .get(url, headers: _jsonHeaders)
            .timeout(_extractTimeout);

        debugPrint(
          "Extractor response ${response.statusCode}: ${response.body}",
        );

        if (!_retryableStatusCodes.contains(response.statusCode) ||
            attempt == _extractMaxAttempts) {
          return response;
        }

        lastError = "HTTP ${response.statusCode}";
        debugPrint(
          "Extractor intento $attempt/$_extractMaxAttempts recibio HTTP ${response.statusCode}",
        );
      } catch (error) {
        if (!_isTransientNetworkError(error)) {
          rethrow;
        }

        lastError = error;
        debugPrint(
          "Extractor intento $attempt/$_extractMaxAttempts fallido: $error",
        );
      }

      if (attempt < _extractMaxAttempts) {
        await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
      }
    }

    throw Exception(
      "Extractor no disponible tras $_extractMaxAttempts intentos: $lastError",
    );
  }

  static Future<List<String>> getExtractionCandidates({
    required String tmdbId,
    required String type,
    required int season,
    required int episode,
  }) async {
    final normalizedTmdbId = tmdbId.trim();

    debugPrint(
      "Extractor params -> tmdbId=$normalizedTmdbId (${normalizedTmdbId.runtimeType}), "
      "type=$type (${type.runtimeType}), "
      "season=$season (${season.runtimeType}), "
      "episode=$episode (${episode.runtimeType})",
    );

    if (normalizedTmdbId.isEmpty || normalizedTmdbId == 'null') {
      throw Exception(
        'TMDB ID inválido: "$normalizedTmdbId". '
        'Verifica que el contenido tenga un tmdbId numérico válido en la base de datos.',
      );
    }

    if (int.tryParse(normalizedTmdbId) == null) {
      throw Exception(
        'TMDB ID no numérico: "$normalizedTmdbId". '
        'El campo tmdbId debe ser un entero positivo (ej: 550, 1396).',
      );
    }

    final url = Uri.parse("$baseUrl/api/extract").replace(
      queryParameters: {
        "tmdbId": normalizedTmdbId,
        "type": type,
        "season": season.toString(),
        "episode": episode.toString(),
      },
    );

    debugPrint("Extractor final URL: ${url.toString()}");

    final response = await _getWithRetry(url);

    if (response.statusCode != 200) {
      throw Exception(
        "Error del servidor: ${response.statusCode} - ${response.body}",
      );
    }

    final data = jsonDecode(response.body);
    final candidates = data["data"]?["candidates"];
    if (data["success"] == true &&
        candidates is List &&
        candidates.isNotEmpty) {
      return candidates.map((item) => item.toString()).toList();
    }

    throw Exception("No se encontraron candidatos en el servidor");
  }

  // --- OBTENER PELÍCULAS Y SERIES ---
  static Future<List<dynamic>> getMoviesByType(String type) async {
    try {
      final url = Uri.parse(
        "$baseUrl/api/movies",
      ).replace(queryParameters: {"type": type});

      final response = await http.get(
        url,
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint("❌ Error obteniendo contenido ($type): $e");
      return [];
    }
  }

  // --- REGISTRO ---
  static Future<Map<String, dynamic>?> registerUser({
    required String email,
    required String name,
    required String plan,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/auth/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email.toLowerCase().trim(),
          "name": name,
          "plan": plan,
          "password": password,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      debugPrint(
        "⚠️ Registro fallido: ${response.statusCode} - ${response.body}",
      );
      return null;
    } catch (e) {
      debugPrint("❌ Error en registro: $e");
      return null;
    }
  }

  // --- OTP Y LOGIN ---
  static Future<bool> sendOTP(String email) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/auth/send-otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email.toLowerCase().trim()}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("❌ Error enviando OTP: $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>?> verifyOTP(
    String email,
    String code,
  ) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/auth/verify-otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email.toLowerCase().trim(), "code": code}),
      );
      return response.statusCode == 200 ? jsonDecode(response.body) : null;
    } catch (e) {
      debugPrint("❌ Error verificando OTP: $e");
      return null;
    }
  }

  // --- OBTENER DATOS DEL USUARIO (CORREGIDO PARA EVITAR ERROR 500) ---
  static Future<Map<String, dynamic>?> getUserDataByEmail(String email) async {
    try {
      // Usamos replace para que los caracteres especiales del email no rompan la URL
      final url = Uri.parse(
        '$baseUrl/api/users',
      ).replace(queryParameters: {'email': email.toLowerCase().trim()});

      final response = await http.get(
        url,
        headers: {"Content-Type": "application/json"},
      );

      debugPrint("🔍 Buscando usuario: ${url.toString()}");
      debugPrint(
        "📥 Respuesta servidor (${response.statusCode}): ${response.body}",
      );

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);

        // Caso 1: El backend devuelve una lista [user]
        if (decoded is List) {
          if (decoded.isNotEmpty) {
            return decoded[0] as Map<String, dynamic>;
          } else {
            return null; // Lista vacía = usuario no encontrado
          }
        }

        // Caso 2: El backend devuelve el objeto directo {user}
        if (decoded is Map && decoded.isNotEmpty) {
          return decoded as Map<String, dynamic>;
        }
      }

      return null;
    } catch (e) {
      debugPrint("❌ Error crítico obteniendo usuario: $e");
      return null;
    }
  }

  // --- ACTUALIZAR USUARIO ---
  static Future<bool> updateUser(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/api/users/$userId"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("❌ Error actualizando usuario: $e");
      return false;
    }
  }

  // --- LOGOUT ---
  static Future<void> logout(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (!context.mounted) return;

      Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
    } catch (e) {
      debugPrint("❌ Error en logout: $e");
    }
  }
}
