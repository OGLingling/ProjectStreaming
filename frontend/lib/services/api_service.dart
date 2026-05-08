import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = "https://projectstreaming-1.onrender.com";

  static const Map<String, String> _headers = {
    "Content-Type": "application/json",
    "Accept": "application/json",
  };

  /// ✅ MÉTODO DE EXTRACCIÓN (Optimizado para el Admin Panel)
  static Future<List<String>> getExtractionCandidates({
    required String tmdbId,
    required String type,
    int? season,
    int? episode,
  }) async {
    // 1. Limpieza rigurosa de parámetros para que coincidan con la DB del Admin Panel
    final String cleanId = tmdbId.toString().trim();
    final String cleanType = (type.toLowerCase().contains('tv') || type.toLowerCase().contains('serie')) 
        ? 'tv' 
        : 'movie';

    final queryParams = <String, String>{
      'tmdbId': cleanId,
      'type': cleanType,
      if (cleanType == 'tv' && season != null) 'season': season.toString(),
      if (cleanType == 'tv' && episode != null) 'episode': episode.toString(),
    };

    final url = Uri.parse('$baseUrl/api/extract').replace(queryParameters: queryParams);

    try {
      debugPrint('🚀 [ApiService] Intentando extraer de: $url');
      final response = await http.get(url, headers: _headers).timeout(const Duration(seconds: 45));

      debugPrint('📥 [ApiService] Status: ${response.statusCode}');
      debugPrint('📥 [ApiService] Body: ${response.body}');

      final Map<String, dynamic> decoded = jsonDecode(response.body);

      if (decoded['success'] == true) {
        // Buscamos candidatos en las dos estructuras que suele usar tu backend
        final List<dynamic>? rawList = decoded['candidates'] ?? decoded['data']?['candidates'];
        
        if (rawList != null && rawList.isNotEmpty) {
          return rawList.map((e) => e.toString()).toList();
        }
      }

      // ❌ Si el backend dice success:false, lanzamos el error específico del Admin Panel
      throw Exception(decoded['error'] ?? 'El Admin Panel no tiene este contenido registrado.');

    } on TimeoutException {
      throw Exception('El servidor tardó demasiado. ¿Está despierto el Admin Panel?');
    } catch (e) {
      debugPrint('❌ [ApiService Error] $e');
      rethrow;
    }
  }

  // --- MÉTODOS DE PELÍCULAS ---
  static Future<List<dynamic>> getMoviesByType(String type) async {
    try {
      final url = Uri.parse("$baseUrl/api/movies").replace(queryParameters: {"type": type});
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) return jsonDecode(response.body) as List<dynamic>;
      return [];
    } catch (e) {
      return [];
    }
  }

  // --- MÉTODOS DE AUTENTICACIÓN ---
  static Future<Map<String, dynamic>?> registerUser({
    required String email, required String name, required String plan, required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/auth/register"),
        headers: _headers,
        body: jsonEncode({
          "email": email.toLowerCase().trim(),
          "name": name,
          "plan": plan,
          "password": password,
        }),
      );
      return (response.statusCode == 201 || response.statusCode == 200) ? jsonDecode(response.body) : null;
    } catch (e) { return null; }
  }

  static Future<bool> sendOTP(String email) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/auth/send-otp"),
        headers: _headers,
        body: jsonEncode({"email": email.toLowerCase().trim()}),
      );
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  static Future<Map<String, dynamic>?> verifyOTP(String email, String code) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/auth/verify-otp"),
        headers: _headers,
        body: jsonEncode({"email": email.toLowerCase().trim(), "code": code}),
      );
      return response.statusCode == 200 ? jsonDecode(response.body) : null;
    } catch (e) { return null; }
  }

  static Future<Map<String, dynamic>?> getUserDataByEmail(String email) async {
    try {
      final url = Uri.parse('$baseUrl/api/users').replace(queryParameters: {'email': email.toLowerCase().trim()});
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List && decoded.isNotEmpty) return decoded[0] as Map<String, dynamic>;
        if (decoded is Map && decoded.isNotEmpty) return decoded as Map<String, dynamic>;
      }
      return null;
    } catch (e) { return null; }
  }

  static Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
  }
}