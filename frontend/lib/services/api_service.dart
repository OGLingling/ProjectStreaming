import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String _baseUrl = "https://tu-proyecto-en-render.com/api";

  /// Función principal para obtener el stream funcional
  Future<String?> getValidStreamUrl({
    required String tmdbId,
    required String type,
    int? season,
    int? episode,
  }) async {
    try {
      // 1. Llamada al Backend para obtener la lista de candidatos
      final queryParams = {
        'tmdbId': tmdbId,
        'type': type,
        if (season != null) 'season': season.toString(),
        if (episode != null) 'episode': episode.toString(),
      };

      final uri = Uri.parse("$_baseUrl/extract").replace(queryParameters: queryParams);
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception("Error en el backend: ${response.statusCode}");
      }

      final data = json.decode(response.body);
      
      if (data['success'] != true || data['candidates'] == null) {
        throw Exception("El backend no devolvió candidatos válidos.");
      }

      List<String> candidates = List<String>.from(data['candidates']);

      // 2. Client-Side Scraping: Validar cuál funciona desde la IP del usuario
      return await _findFirstWorkingUrl(candidates);

    } catch (e) {
      print("Error en ApiService: $e");
      rethrow;
    }
  }

  /// Prueba cada URL de la lista y devuelve la primera que responda exitosamente
  Future<String?> _findFirstWorkingUrl(List<String> urls) async {
    for (String url in urls) {
      try {
        print("[Check] Probando proveedor: $url");

        // Usamos un timeout corto para no hacer esperar al usuario
        // Hacemos un GET ligero para verificar si el servidor responde
        final res = await http.get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
          },
        ).timeout(const Duration(seconds: 4));

        // Si responde 200 y tiene contenido, es un candidato viable
        if (res.statusCode == 200 && res.body.length > 800) {
          print("[Check] ✅ Proveedor funcional encontrado: $url");
          return url;
        }
      } catch (e) {
        print("[Check] ❌ Falló $url: $e");
        continue; // Probar el siguiente si este falla
      }
    }
    
    // Si llegamos aquí, ninguno funcionó desde la IP del usuario
    return null;
  }
}