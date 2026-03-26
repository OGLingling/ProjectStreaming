import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Asegúrate de que esta URL sea accesible desde tu navegador si usas Flutter Web
  static const String baseUrl = "http://localhost:3000/api";

  // --- OBTENER PELÍCULAS Y SERIES ---
  static Future<List<dynamic>> getMoviesByType(String type) async {
    try {
      // type debe ser 'movie' o 'Serie'
      final response = await http.get(
        Uri.parse("$baseUrl/movies?type=$type"),
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

  // --- REGISTRO (CORREGIDO: SIN PASSWORD PARA PRISMA) ---
  static Future<Map<String, dynamic>?> registerUser({
    required String email,
    required String name,
    required String plan,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "name": name,
          "plan": plan,
          "password": password, // Enviar contraseña para Prisma
          // Ya no enviamos password porque usamos OTP
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
        Uri.parse("$baseUrl/auth/send-otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
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
        Uri.parse("$baseUrl/auth/verify-otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "code": code}),
      );
      return response.statusCode == 200 ? jsonDecode(response.body) : null;
    } catch (e) {
      debugPrint("❌ Error verificando OTP: $e");
      return null;
    }
  }

  // --- ACTUALIZAR USUARIO (Perfil o Plan) ---
  static Future<bool> updateUser(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/users/$userId"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("❌ Error actualizando usuario: $e");
      return false;
    }
  }

  // --- OBTENER DATOS DEL USUARIO ---
  static Future<Map<String, dynamic>?> getUserDataByEmail(String email) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/users?email=$email'));
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        // Si el backend devuelve una lista, tomamos el primer elemento
        if (decoded is List && decoded.isNotEmpty) {
          return decoded[0] as Map<String, dynamic>;
        }
        // Si el backend devuelve el objeto directo
        if (decoded is Map) {
          return decoded as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      debugPrint("❌ Error obteniendo usuario: $e");
      return null;
    }
  }

  // --- LOGOUT ---
  static Future<void> logout(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (!context.mounted) return;

      // Asegúrate de tener esta ruta definida en tu main.dart
      Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
    } catch (e) {
      debugPrint("❌ Error en logout: $e");
    }
  }
}
