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

  static Future<List<String>> getExtractionCandidates({
    required String tmdbId,
    required String type,
    int? season,
    int? episode,
  }) async {
    // Limpieza agresiva de parámetros
    final cleanId = tmdbId.toString().trim();
    final cleanType = type.toLowerCase().contains('tv') ? 'tv' : 'movie';

    final queryParams = <String, String>{
      'tmdbId': cleanId,
      'type': cleanType,
      if (cleanType == 'tv' && season != null) 'season': season.toString(),
      if (cleanType == 'tv' && episode != null) 'episode': episode.toString(),
    };

    final url = Uri.parse('$baseUrl/api/extract').replace(queryParameters: queryParams);

    try {
      debugPrint('🚀 [API Request] $url');
      final response = await http.get(url, headers: _headers).timeout(const Duration(seconds: 45));
      
      final dynamic decoded = jsonDecode(response.body);
      debugPrint('📥 [API Response] ${response.body}');

      if (decoded is Map && decoded['success'] == true) {
        final List<dynamic>? candidates = decoded['candidates'] ?? decoded['data']?['candidates'];
        if (candidates != null && candidates.isNotEmpty) {
          return candidates.map((e) => e.toString()).toList();
        }
      }

      // Si llegamos aquí, mostramos el error real que envió el backend
      String errorMsg = decoded['error'] ?? 'El servidor no encontró links para este ID ($cleanId).';
      throw Exception(errorMsg);

    } on TimeoutException {
      throw Exception('El servidor tardó demasiado. Intenta de nuevo.');
    } catch (e) {
      debugPrint('❌ [API Error] $e');
      rethrow;
    }
  }

  // --- CONTENIDO ---
  static Future<List<dynamic>> getMoviesByType(String type) async {
    try {
      final url = Uri.parse("$baseUrl/api/movies").replace(queryParameters: {"type": type});
      final response = await http.get(url, headers: _headers);
      return response.statusCode == 200 ? jsonDecode(response.body) as List<dynamic> : [];
    } catch (e) { return []; }
  }

  // --- AUTH (Mantenido igual para no romper el flujo) ---
  static Future<Map<String, dynamic>?> registerUser({
    required String email, required String name, required String plan, required String password,
  }) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/api/auth/register"),
          headers: _headers, body: jsonEncode({"email": email, "name": name, "plan": plan, "password": password}));
      return response.statusCode == 201 ? jsonDecode(response.body) : null;
    } catch (e) { return null; }
  }

  static Future<bool> sendOTP(String email) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/api/auth/send-otp"),
          headers: _headers, body: jsonEncode({"email": email}));
      return response.statusCode == 200;
    } catch (e) { return false; }
  }

  static Future<Map<String, dynamic>?> verifyOTP(String email, String code) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/api/auth/verify-otp"),
          headers: _headers, body: jsonEncode({"email": email, "code": code}));
      return response.statusCode == 200 ? jsonDecode(response.body) : null;
    } catch (e) { return null; }
  }

  static Future<Map<String, dynamic>?> getUserDataByEmail(String email) async {
    try {
      final url = Uri.parse('$baseUrl/api/users').replace(queryParameters: {'email': email});
      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return (decoded is List) ? decoded[0] : decoded;
      }
      return null;
    } catch (e) { return null; }
  }

  static Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
  }
}