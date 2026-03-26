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
  State<CategoryScreen> createState() => _CategoryScreenState();
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
      } else {
        setState(() => isLoading = false);
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
        elevation: 0,
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
                childAspectRatio: 0.7, // Ajustado para posters
              ),
              itemCount: movies.length,
              itemBuilder: (context, index) =>
                  CategoryMovieCard(movie: movies[index]),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.movie_filter, color: Colors.grey, size: 60),
          const SizedBox(height: 16),
          Text(
            "No hay contenido en ${widget.title}",
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
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

  Future<void> _handleNavigation(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final String? sessionValue =
        prefs.getString('user_name') ??
        prefs.getString('user') ??
        prefs.getString('auth_token') ??
        prefs.getString('token');

    if (sessionValue != null && sessionValue.isNotEmpty) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MovieDetailsScreen(
            // Enviamos el JSON que ahora incluye backdropUrl e imageUrl correctos
            movieData: widget.movie.toJson(),
          ),
        ),
      );
    } else {
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
    final String path = widget.movie.imageUrl ?? '';

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
            child: Container(
              color: const Color(0xFF1A2232),
              child: _buildImage(path),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty || normalized.toLowerCase() == 'null') {
      return const Center(
        child: Icon(Icons.movie, color: Colors.white10, size: 40),
      );
    }

    // Lógica para detectar si es URL de internet o asset local
    if (normalized.startsWith('http')) {
      return Image.network(
        normalized,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) =>
            const Icon(Icons.error, color: Colors.white10),
      );
    } else {
      // Si el path ya contiene 'assets/', lo usamos tal cual, si no, lo construimos
      final String assetPath = normalized.startsWith('assets')
          ? normalized
          : 'assets/Images/${normalized.split('/').last}';
      return Image.asset(
        assetPath,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) =>
            const Icon(Icons.movie, color: Colors.white10),
      );
    }
  }
}
