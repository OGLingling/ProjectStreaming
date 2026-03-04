import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/movie_model.dart';
import '../models/user_model.dart';

class ApiService {
  final String baseUrl = "http://localhost:3000";

  Future<bool> registerUser(User user) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(user.toJson()),
      );

      if (response.statusCode == 201) {
        print("✅ Registro exitoso");
        return true;
      } else {
        print("❌ Error en el registro: ${response.body}");
        return false;
      }
    } catch (e) {
      print("❌ Error de conexión: $e");
      return false;
    }
  }

  Future<bool> postMovie(Movie movie) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/movies'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(movie.toJson()),
      );
      return response.statusCode == 201;
    } catch (e) {
      print("Error al postear película: $e");
      return false;
    }
  }

  Future<void> updateUser(int id, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/users/$id'), // Endpoint para actualizar
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      if (response.statusCode != 200) {
        throw Exception("Error al actualizar el usuario en el servidor");
      }
    } catch (e) {
      print("Error en ApiService (updateUser): $e");
      rethrow; // Lanza el error para que UserScreen lo atrape en el catch
    }
  }
}
