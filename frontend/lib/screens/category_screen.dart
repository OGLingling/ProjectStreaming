import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
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
  final ApiService _apiService = ApiService();
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
        Uri.parse('${_apiService.baseUrl}/movies'),
      );

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);

        // DEBUG: Esto te dirá en consola qué está llegando exactamente
        debugPrint("API DATA SAMPLE: ${data.isNotEmpty ? data[0] : 'Vacío'}");

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
      debugPrint("Error: $e");
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
                childAspectRatio: 0.7,
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

  // Función de apoyo para el error (Placeholder)
  Widget _errorPlaceholder() {
    return Container(
      color: const Color(0xFF1A2232),
      child: const Center(
        child: Icon(Icons.movie, color: Colors.white10, size: 40),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Extraemos solo el nombre del archivo si la base de datos trae una ruta larga
    // Si tu DB solo trae "mi_imagen.jpg", esto funcionará directo.
    final String fileName = widget.movie.imageUrl.split('/').last;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  MovieDetailsScreen(movieData: widget.movie.toJson()),
            ),
          );
        },
        child: AnimatedScale(
          scale: _isHovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 0.7,
              child: Container(
                color: const Color(0xFF1A2232),
                // USAMOS IMAGE.ASSET COMO PEDISTE
                child: Image.asset(
                  'assets/Images/$fileName',
                  fit: BoxFit.cover,
                  // Si el archivo no existe en la carpeta assets, muestra el icono
                  errorBuilder: (context, error, stackTrace) =>
                      _errorPlaceholder(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
