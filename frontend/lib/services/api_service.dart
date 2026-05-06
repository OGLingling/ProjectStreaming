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

    throw Exception(
      "Extractor no disponible tras $_extractMaxAttempts intentos: $lastError",
    );
  }

  // ✅ FIX LIMPIO (SIN TOCAR AUTH NI LOGIN)
  static Future<List<String>> getExtractionCandidates({
    required String tmdbId,
    required String type,
    int? season,
    int? episode,
  }) async {

    final normalizedTmdbId = tmdbId.trim();

    final isTV = type.toLowerCase().contains('tv') ||
        type.toLowerCase().contains('serie');

    debugPrint(
      '[Extractor] Params → tmdbId=$normalizedTmdbId, type=$type, isTV=$isTV, '
      'season=$season, episode=$episode',
    );

    // VALIDACIÓN
    if (normalizedTmdbId.isEmpty || int.tryParse(normalizedTmdbId) == null) {
      throw Exception(
        '[Extractor] TMDB ID inválido: "$normalizedTmdbId"',
      );
    }

    // 🔥 CLAVE: NO enviar season/episode si es movie
    final queryParams = <String, String>{
      'tmdbId': normalizedTmdbId,
      'type': type,
      if (isTV && season != null) 'season': season.toString(),
      if (isTV && episode != null) 'episode': episode.toString(),
    };

    final url = Uri.parse('$baseUrl/api/extract')
        .replace(queryParameters: queryParams);

    debugPrint('[Extractor] → URL final: ${url.toString()}');

    final response = await _getWithRetry(url);

    if (response.statusCode != 200) {
      final detail = _parseServerError(response.statusCode, response.body);
      throw Exception('[Extractor] Error del servidor: $detail');
    }

    final data = jsonDecode(response.body);

    final candidates = data['data']?['candidates'];

    if (data['success'] == true &&
        candidates is List &&
        candidates.isNotEmpty) {
      return candidates.map((item) => item.toString()).toList();
    }

    final debugInfo = data['data']?['debug_info'];
    final reason = debugInfo?['reason'] ?? 'empty_candidates';
    final serverDetail =
        debugInfo?['detail'] ?? 'El servidor no devolvió candidatos';

    throw Exception(
      '[Extractor] Sin candidatos: reason=$reason | $serverDetail',
    );
  }

  /// Parser de errores (SE MANTIENE IGUAL)
  static String _parseServerError(int statusCode, String body) {
    try {
      final errData = jsonDecode(body);
      final debugInfo = errData['debug_info'];

      if (debugInfo != null) {
        final reason  = debugInfo['reason']  ?? '';
        final detail  = debugInfo['detail']  ?? '';
        final hint    = debugInfo['hint'] != null
            ? ' | hint: ${debugInfo['hint']}'
            : '';
        final errMsg  = errData['error'] ?? 'Error $statusCode';

        return '$errMsg | reason=$reason | $detail$hint';
      }

      return errData['error'] ?? 'HTTP $statusCode';
    } catch (_) {
      return 'HTTP $statusCode → $body';
    }
  }

  // --- OBTENER PELÍCULAS Y SERIES (SIN CAMBIOS) ---
  static Future<List<dynamic>> getMoviesByType(String type) async {
    try {
      final url = Uri.parse("$baseUrl/api/movies")
          .replace(queryParameters: {"type": type});

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

  // --- REGISTRO (INTOCADO) ---
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

  // --- OTP Y LOGIN (INTOCADO) ---
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
        body: jsonEncode({
          "email": email.toLowerCase().trim(),
          "code": code
        }),
      );

      return response.statusCode == 200
          ? jsonDecode(response.body)
          : null;
    } catch (e) {
      debugPrint("❌ Error verificando OTP: $e");
      return null;
    }
  }

  // --- USER DATA (INTOCADO) ---
  static Future<Map<String, dynamic>?> getUserDataByEmail(String email) async {
    try {
      final url = Uri.parse('$baseUrl/api/users')
          .replace(queryParameters: {'email': email.toLowerCase().trim()});

      final response = await http.get(
        url,
        headers: {"Content-Type": "application/json"},
      );

      debugPrint("🔍 Buscando usuario: ${url.toString()}");
      debugPrint("📥 Respuesta servidor (${response.statusCode}): ${response.body}");

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);

        if (decoded is List && decoded.isNotEmpty) {
          return decoded[0] as Map<String, dynamic>;
        }

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

  // --- UPDATE USER (INTOCADO) ---
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

  // --- LOGOUT (INTOCADO) ---
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