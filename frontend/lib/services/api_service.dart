import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {

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

        final response = await http
            .get(url, headers: _jsonHeaders)
            .timeout(_extractTimeout);

        debugPrint("Extractor response ${response.statusCode}: ${response.body}");

        if (!_retryableStatusCodes.contains(response.statusCode) ||
            attempt == _extractMaxAttempts) {
          return response;
        }

        lastError = "HTTP ${response.statusCode}";

      } catch (error) {
        if (!_isTransientNetworkError(error)) {
          rethrow;
        }

        lastError = error;
      }

      if (attempt < _extractMaxAttempts) {
        await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
      }
    }

    throw Exception("Extractor no disponible: $lastError");
  }

  // 🔥 FUNCIÓN CLAVE CORREGIDA
  static Future<List<String>> getExtractionCandidates({
    required String tmdbId,
    required String type,
    int? season,
    int? episode,
  }) async {

    final normalizedTmdbId = tmdbId.trim();

    final isTV = type.toLowerCase().contains('tv') ||
        type.toLowerCase().contains('serie');

    // VALIDACIÓN REAL
    if (normalizedTmdbId.isEmpty || int.tryParse(normalizedTmdbId) == null) {
      throw Exception('TMDB ID inválido: "$normalizedTmdbId"');
    }

    // 🔥 NO enviar season/episode si no es TV
    final queryParams = <String, String>{
      'tmdbId': normalizedTmdbId,
      'type': type,
      if (isTV && season != null) 'season': season.toString(),
      if (isTV && episode != null) 'episode': episode.toString(),
    };

    final url = Uri.parse('$baseUrl/api/extract')
        .replace(queryParameters: queryParams);

    debugPrint('[Extractor] URL final: $url');

    final response = await _getWithRetry(url);

    if (response.statusCode != 200) {
      throw Exception('Error servidor: ${response.body}');
    }

    final data = jsonDecode(response.body);

    final candidates = data['data']?['candidates'];

    if (data['success'] == true &&
        candidates is List &&
        candidates.isNotEmpty) {

      return candidates.map((item) => item.toString()).toList();
    }

    final debugInfo = data['data']?['debug_info'];

    throw Exception(
      'Sin candidatos: ${debugInfo?['reason'] ?? 'unknown'}'
    );
  }

  // --- resto sin cambios relevantes ---

  static Future<List<dynamic>> getMoviesByType(String type) async {
    try {
      final url = Uri.parse("$baseUrl/api/movies")
          .replace(queryParameters: {"type": type});

      final response = await http.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      debugPrint("Error: $e");
      return [];
    }
  }

  static Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!context.mounted) return;

    Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
  }
}