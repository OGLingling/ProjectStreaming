import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Configura tu URL de producción aquí
  static const String _baseUrl = "https://projectstreaming-1.onrender.com/api";

  static const Map<String, String> _defaultHeaders = {
    'Content-Type': 'application/json',
    'User-Agent': 'MovieWind-App/1.0',
  };

  // --- AUTENTICACIÓN ---

  static Future<Map<String, dynamic>?> getUserDataByEmail(String email) async {
    try {
      final response = await http
          .get(Uri.parse("$_baseUrl/users/${email.trim().toLowerCase()}"))
          .timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) return data[0];
        if (data is Map<String, dynamic>) return data;
      }
      return null;
    } catch (e) {
      debugPrint("Error getUserDataByEmail: $e");
      return null;
    }
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

      if (response.statusCode == 200) return json.decode(response.body);
    } catch (e) {
      debugPrint("Error verifyOTP: $e");
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
        return json.decode(response.body);
      }
    } catch (e) {
      debugPrint("Error registerUser: $e");
    }
    return null;
  }

  // --- STREAMING (Extractores) ---

  static Future<String?> getValidStreamUrl({
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
        if (data is Map && data.containsKey('candidates')) {
          List<String> candidates = List<String>.from(data['candidates']);
          return candidates.isNotEmpty ? candidates.first : null;
        }
      }
    } catch (e) {
      debugPrint("Error en getValidStreamUrl: $e");
    }
    return null;
  }
}