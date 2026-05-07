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

  /// ✅ MÉTODO DE EXTRACCIÓN (ROBUSTO)
  static Future<List<String>> getExtractionCandidates({
    required String tmdbId,
    required String type,
    int? season,
    int? episode,
  }) async {
    final normalizedId = tmdbId.trim();
    final cleanType = (type.toLowerCase().contains('tv') || type.toLowerCase().contains('serie')) 
        ? 'tv' 
        : 'movie';

    final queryParams = <String, String>{
      'tmdbId': normalizedId,
      'type': cleanType,
      if (cleanType == 'tv' && season != null) 'season': season.toString(),
      if (cleanType == 'tv' && episode != null) 'episode': episode.toString(),
    };

    final url = Uri.parse('$baseUrl/api/extract').replace(queryParameters: queryParams);

    try {
      debugPrint('🚀 [ApiService] Solicitando servidores a: $url');
      
      // Timeout de 45 segundos para dar tiempo al scraper
      final response = await http.get(url, headers: _headers).timeout(const Duration(seconds: 45));

      debugPrint('📥 [ApiService] Status: ${response.statusCode}');
      debugPrint('📥 [ApiService] Cuerpo: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Error del servidor: Status ${response.statusCode}');
      }

      final dynamic decoded = jsonDecode(response.body);
      List<dynamic>? rawList;

      // Intentamos encontrar la lista en múltiples ubicaciones posibles del JSON
      if (decoded is Map) {
        if (decoded['candidates'] is List) {
          rawList = decoded['candidates'];
        } else if (decoded['data'] != null && decoded['data']['candidates'] is List) {
          rawList = decoded['data']['candidates'];
        }
      }

      if (rawList != null && rawList.isNotEmpty) {
        return rawList.map((e) => e.toString()).toList();
      }

      // Si el success es true pero la lista está vacía, lanzamos el error del backend
      throw Exception(decoded['error'] ?? 'No hay enlaces disponibles para este contenido.');

    } on TimeoutException {
      throw Exception('El servidor tardó demasiado. Intenta de nuevo.');
    } on SocketException {
      throw Exception('Sin conexión al servidor. Revisa tu internet.');
    } catch (e) {
      debugPrint('❌ [ApiService] Error crítico: $e');
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
      debugPrint("❌ Error obteniendo contenido ($type): $e");
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
      if (response.statusCode == 201 || response.statusCode == 200) return jsonDecode(response.body);
      return null;
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
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
    } catch (e) { debugPrint("❌ Error en logout: $e"); }
  }
}