import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/movie_model.dart';
import '../services/api_service.dart';
import '../screens/auth_screen.dart';
import '../screens/movie_details_screen.dart';
import '../screens/user_screen.dart';
import '../screens/category_screen.dart';

class MoviesScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  const MoviesScreen({super.key, this.user});

  @override
  _MoviesScreenState createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  final ApiService _apiService = ApiService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Movie> movies = [];
  bool isLoading = true;
  bool _isUserHovered = false;

  @override
  void initState() {
    super.initState();
    _fetchMovies(); // Ahora cargamos siempre, esté logeado o no
  }

  ImageProvider _getProfileImage(String path) {
    if (path.startsWith('assets/')) {
      return AssetImage(path);
    } else if (path.isNotEmpty && path.startsWith('http')) {
      return NetworkImage(path);
    } else {
      return const AssetImage('assets/avatars/perfilPrueba.jpg');
    }
  }

  Future<void> _fetchMovies() async {
    try {
      final response = await http.get(
        Uri.parse('${_apiService.baseUrl}/movies'),
      );
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        setState(() {
          movies = data.map((m) => Movie.fromJson(m)).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  // DIÁLOGO QUE SALTA AL DAR CLICK SIN ESTAR LOGEADO
  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2232),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.redAccent),
            SizedBox(width: 10),
            Text("Contenido Premium", style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          "Para ver los detalles y reproducir esta película, necesitas crear una cuenta o iniciar sesión.",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "MÁS TARDE",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AuthScreen()),
              );
            },
            child: const Text("INICIAR SESIÓN"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool ifLoggedIn = widget.user != null;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF121826),
      endDrawer: ifLoggedIn
          ? Drawer(
              width: MediaQuery.of(context).size.width * 0.3,
              backgroundColor: const Color(0xFF121826),
              child: UserScreen(user: widget.user!),
            )
          : null,
      appBar: AppBar(
        automaticallyImplyLeading: false, // Quita el botón back
        title: const Text(
          "MovieWind",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: const Color(0xFF1A2232),
        elevation: 0,
        actions: [
          if (!ifLoggedIn)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AuthScreen()),
                ),
                child: const Text(
                  "Iniciar sesión",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            )
          else
            _buildUserHeader(),
        ],
      ),
      body: Column(
        children: [
          _buildCategoryList(),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.redAccent),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.7,
                        ),
                    itemCount: movies.length,
                    itemBuilder: (context, index) => MovieCard(
                      movie: movies[index],
                      ifLoggedIn: ifLoggedIn,
                      onLoginRequired: _showLoginRequiredDialog,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserHeader() {
    return MouseRegion(
      onEnter: (_) => setState(() => _isUserHovered = true),
      onExit: (_) => setState(() => _isUserHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _scaffoldKey.currentState!.openEndDrawer(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _isUserHovered ? Colors.white10 : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Text(
                "Hola, ${widget.user!['name']}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _isUserHovered ? Colors.redAccent : Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                radius: 17,
                backgroundImage: _getProfileImage(
                  widget.user!['profilePic'] ?? "",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryList() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
      child: Row(
        children: [
          _categoryChip("Hollywood", "hollywood"),
          _categoryChip("Series", "series"),
          _categoryChip("Bollywood", "bollywood"),
          _categoryChip("Coreanas", "korean"),
          _categoryChip("Otros", "others"),
        ],
      ),
    );
  }

  Widget _categoryChip(String title, String key) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        backgroundColor: const Color(0xFF1A2232),
        label: Text(title, style: const TextStyle(color: Colors.white)),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CategoryScreen(title: title, categoryKey: key),
          ),
        ),
      ),
    );
  }
}

// LA CLASE MOVIECARD CON EL HOVER CORREGIDO
class MovieCard extends StatefulWidget {
  final Movie movie;
  final bool ifLoggedIn;
  final VoidCallback onLoginRequired;

  const MovieCard({
    super.key,
    required this.movie,
    required this.ifLoggedIn,
    required this.onLoginRequired,
  });

  @override
  State<MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<MovieCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Extraemos la URL y limpiamos posibles espacios
    final String imageUrl = widget.movie.imageUrl.trim();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          if (widget.ifLoggedIn) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    MovieDetailsScreen(movieData: widget.movie.toJson()),
              ),
            );
          } else {
            widget.onLoginRequired();
          }
        },
        child: AnimatedScale(
          scale: _isHovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: Colors.redAccent.withOpacity(0.3),
                        blurRadius: 10,
                      ),
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 0.7,
                child: _buildImageWidget(imageUrl),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageWidget(String url) {
    if (url.isEmpty) {
      return Container(
        color: const Color(0xFF1A2232),
        child: const Icon(
          Icons.movie_creation_outlined,
          color: Colors.white10,
          size: 40,
        ),
      );
    }

    if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: const Color(0xFF1A2232),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.redAccent,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => _errorPlaceholder(),
      );
    }

    return Image.asset(
      'assets/Images/$url',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _errorPlaceholder(),
    );
  }

  Widget _errorPlaceholder() {
    return Container(
      color: Colors.black,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, color: Colors.white24),
          Text(
            "No image",
            style: TextStyle(color: Colors.white24, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
