import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // Para debugPrint
import 'package:http/http.dart' as http;

class ApiService {
  // ✅ CORRECCIÓN: Mantén tu URL de Render aquí
  static const String _baseUrl = "https://tu-proyecto-en-render.com/api";

  // Headers comunes para evitar ser bloqueado por proveedores de streaming
  static const Map<String, String> _defaultHeaders = {
    'Content-Type': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  };

  // ===================================================
  // 1. MÉTODOS DE CONTENIDO (Películas y Series)
  // ===================================================

  static Future<List<dynamic>> getMoviesByType(String type) async {
    try {
      final response = await http
          .get(Uri.parse("$_baseUrl/movies?type=$type"))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint("Error en getMoviesByType ($type): $e");
      return [];
    }
  }

  // ===================================================
  // 2. MÉTODOS DE AUTENTICACIÓN Y USUARIOS (OTP)
  // ===================================================

  static Future<Map<String, dynamic>?> getUserDataByEmail(String email) async {
    try {
      final response = await http
          .get(Uri.parse("$_baseUrl/users/${email.trim().toLowerCase()}"))
          .timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("Error en getUserDataByEmail: $e");
    }
    return null;
  }

  static Future<bool> sendOTP(String email) async {
    try {
      final response = await http.post(
        Uri.parse("$_baseUrl/auth/send-otp"),
        body: json.encode({'email': email.trim().toLowerCase()}),
        headers: _defaultHeaders,
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Error en sendOTP: $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>?> verifyOTP(String email, String otp) async {
    try {
      final response = await http.post(
        Uri.parse("$_baseUrl/auth/verify-otp"),
        body: json.encode({
          'email': email.trim().toLowerCase(), 
          'otp': otp.trim()
        }),
        headers: _defaultHeaders,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("Error en verifyOTP: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>?> registerUser(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse("$_baseUrl/auth/register"),
        body: json.encode(data),
        headers: _defaultHeaders,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("Error en registerUser: $e");
    }
    return null;
  }

  // ===================================================
  // 3. LÓGICA DE SCRAPING (Optimizado)
  // ===================================================

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
      final response = await http.get(uri).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // ✅ CORRECCIÓN: Manejo seguro de la lista de candidatos
        if (data is Map && data.containsKey('candidates')) {
          return List<String>.from(data['candidates']);
        }
      }
    } catch (e) {
      debugPrint("Error obteniendo candidatos: $e");
    }
    return [];
  }

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

    if (candidates.isEmpty) return null;

    for (String url in candidates) {
      try {
        debugPrint("[ClientScraper] Probando: $url");
        
        // Usamos un HEAD request si es posible para ahorrar datos, 
        // pero muchos providers requieren GET. Usamos GET con un timeout corto.
        final res = await http.get(
          Uri.parse(url),
          headers: _defaultHeaders,
        ).timeout(const Duration(seconds: 5));

        // ✅ Validación mejorada: Un cuerpo muy pequeño suele ser una página de error o captcha
        if (res.statusCode == 200 && res.body.length > 1000) {
          debugPrint("[ClientScraper] ✅ URL Válida encontrada");
          return url;
        }
      } catch (e) {
        debugPrint("[ClientScraper] ❌ Falló: $url - Error: $e");
        continue;
      }
    }
    return null;
  }
}