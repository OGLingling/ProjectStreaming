import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/movie_model.dart';
import '../models/user_model.dart';

class ApiService {
  static const String baseUrl = "http://localhost:3000";

  static Future<User?> getUserByEmail(String email) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/users?email=$email',
        ), // Ajusta este endpoint según tu backend
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          // Asumiendo que el backend devuelve una lista y tomamos el primero
          return User.fromJson(data[0]);
        }
      }
      return null;
    } catch (e) {
      print("❌ Error buscando usuario: $e");
      return null;
    }
  }

  static Future<bool> registerUser(User user, bool emailVerified) async {
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

  static Future<bool> postMovie(Movie movie) async {
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

  static Future<void> updateUser(int id, Map<String, dynamic> data) async {
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
