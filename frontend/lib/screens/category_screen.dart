import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../screens/movie_details_screen.dart';
import '../models/movie_model.dart';

class CategoryScreen extends StatefulWidget {
  final String title;
  final String categoryKey;

  const CategoryScreen({
    super.key,
    required this.title,
    required this.categoryKey,
  });

  @override
  _CategoryScreenState createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  List<Movie> movies = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCategoryData();
  }

  Future<void> _fetchCategoryData() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/movies'),
      );

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);

        setState(() {
          movies = data.map((m) => Movie.fromJson(m)).where((movie) {
            final movieType = movie.type?.toLowerCase().trim() ?? '';
            final targetKey = widget.categoryKey.toLowerCase().trim();
            return movieType == targetKey;
          }).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error al cargar datos: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121826),
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1A2232),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.redAccent),
            )
          : movies.isEmpty
          ? _buildEmptyState()
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2 / 3,
              ),
              itemCount: movies.length,
              itemBuilder: (context, index) =>
                  CategoryMovieCard(movie: movies[index]),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        "No hay contenido en ${widget.title}",
        style: const TextStyle(color: Colors.grey),
      ),
    );
  }
}

class CategoryMovieCard extends StatefulWidget {
  final Movie movie;
  const CategoryMovieCard({super.key, required this.movie});

  @override
  State<CategoryMovieCard> createState() => _CategoryMovieCardState();
}

class _CategoryMovieCardState extends State<CategoryMovieCard> {
  bool _isHovered = false;

  // Lógica de navegación ultra-compatible
  Future<void> _handleNavigation(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    // IMPORTANTE: Recarga forzada para Flutter Web
    await prefs.reload();

    // Buscamos cualquier rastro de sesión.
    // Si la app muestra "Alfredo Pers", es porque 'user_name' o 'user' tiene datos.
    final String? sessionValue =
        prefs.getString('user_name') ??
        prefs.getString('user') ??
        prefs.getString('auth_token') ??
        prefs.getString('token');

    // Imprimimos en consola para que veas qué está pasando realmente
    debugPrint("--- ESTADO DE SESIÓN ---");
    debugPrint("Nombre/Token detectado: $sessionValue");
    debugPrint("Todas las llaves: ${prefs.getKeys()}");

    if (sessionValue != null && sessionValue.isNotEmpty) {
      // SI HAY SESIÓN -> Entramos a detalles
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              MovieDetailsScreen(movieData: widget.movie.toJson()),
        ),
      );
    } else {
      // NO HAY SESIÓN -> Bloqueamos con el mensaje rojo
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión para ver los detalles'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lógica original de tus Assets
    final String fileName = widget.movie.imageUrl.split('/').last;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => _handleNavigation(context),
        child: AnimatedScale(
          scale: _isHovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: Container(
                color: const Color(0xFF1A2232),
                child: Image.asset(
                  'assets/Images/$fileName',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFF1A2232),
                    child: const Icon(
                      Icons.movie,
                      color: Colors.white10,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
