import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/movie_model.dart';
import '../models/user_model.dart';

class ApiService {
  final String baseUrl = "http://localhost:3000";

  Future<bool> registerUser(User user, bool emailVerified) async {
    try {
      Map<String, dynamic> userData = user.toJson();

      userData['isVerified'] = emailVerified;

      final response = await http.post(
        Uri.parse('$baseUrl/sync-user'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(userData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ Sincronización exitosa con Neon");
        return true;
      } else {
        print(
          "❌ Error en el servidor: ${response.statusCode} - ${response.body}",
        );
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
