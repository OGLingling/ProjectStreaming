import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'movie_details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allMovies = [];
  List<Map<String, dynamic>> _filteredResults = [];
  bool _isSearching = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMoviesFromNeon();
  }

  // 1. FUNCIÓN PARA LLAMAR A TU BACKEND (Que está conectado a Neon)
  Future<void> _fetchMoviesFromNeon() async {
    try {
      // Reemplaza con la URL de tu API (ej: )
      final response = await http.get(
        Uri.parse(
          'https://projectstreaming-production.up.railway.app/api/movies',
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _allMovies = data.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        throw Exception('Error al cargar datos de Neon');
      }
    } catch (e) {
      print("Error: $e");
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _isSearching = false;
        _filteredResults = [];
      } else {
        _isSearching = true;
        _filteredResults = _allMovies
            .where(
              (movie) => movie['title'].toString().toLowerCase().contains(
                query.toLowerCase(),
              ),
            )
            .toList();
      }
    });
  }

  void _openMovie(Map<String, dynamic> movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovieDetailsScreen(movieData: movie),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: _isSearching
                      ? _buildGridResults()
                      : _buildPopularList(),
                ),
              ],
            ),
    );
  }

  // --- LOS WIDGETS DE LA INTERFAZ ---

  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 10,
      ),
      color: Colors.grey[900]!.withOpacity(0.4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(5),
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: "Buscar en Neon...",
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              prefixIcon: const Icon(
                Icons.search,
                color: Colors.grey,
                size: 20,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGridResults() {
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _filteredResults.length,
      itemBuilder: (context, index) {
        final movie = _filteredResults[index];
        return GestureDetector(
          onTap: () => _openMovie(movie),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.network(movie['imageUrl'] ?? '', fit: BoxFit.cover),
          ),
        );
      },
    );
  }

  Widget _buildPopularList() {
    return ListView.builder(
      itemCount: _allMovies.length,
      itemBuilder: (context, index) {
        final movie = _allMovies[index];
        return ListTile(
          onTap: () => _openMovie(movie),
          leading: Image.network(
            movie['imageUrl'] ?? '',
            width: 100,
            fit: BoxFit.cover,
          ),
          title: Text(
            movie['title'] ?? '',
            style: const TextStyle(color: Colors.white),
          ),
          trailing: const Icon(Icons.play_arrow, color: Colors.white),
        );
      },
    );
  }
}
