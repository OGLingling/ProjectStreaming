import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // Datos de prueba para "Búsquedas populares"
  final List<Map<String, String>> _popularSearches = [
    {
      "title": "Stranger Things",
      "image":
          "https://image.tmdb.org/t/p/w500/x2LSRm21uTEx2Pq2SUTUu8vubMg.jpg",
    },
    {
      "title": "The Witcher",
      "image":
          "https://image.tmdb.org/t/p/w500/7vjaCdSjLkdmvkI9EkyTzY9t3Q6.jpg",
    },
    {
      "title": "Merlina",
      "style":
          "https://image.tmdb.org/t/p/w500/9PFonB9t9S36bdG96db06vsmM9R.jpg",
    },
    {
      "title": "La Casa de Papel",
      "image":
          "https://image.tmdb.org/t/p/w500/reEMDx9m9Xsn09a996Y9AnmD06U.jpg",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: _isSearching
                ? _buildSearchResults()
                : _buildPopularSearches(),
          ),
        ],
      ),
    );
  }

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
            onChanged: (value) {
              setState(() {
                _isSearching = value.isNotEmpty;
              });
            },
            decoration: InputDecoration(
              hintText: "Busca una película, serie...",
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              prefixIcon: const Icon(
                Icons.search,
                color: Colors.grey,
                size: 20,
              ),
              suffixIcon: _isSearching
                  ? IconButton(
                      icon: const Icon(
                        Icons.cancel,
                        color: Colors.grey,
                        size: 20,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _isSearching = false);
                      },
                    )
                  : const Icon(Icons.mic, color: Colors.grey, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),
    );
  }

  // --- VISTA 1: BÚSQUEDAS POPULARES ---
  Widget _buildPopularSearches() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(15.0),
          child: Text(
            "Búsquedas populares",
            style: GoogleFonts.geologica(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _popularSearches.length,
            itemBuilder: (context, index) {
              final item = _popularSearches[index];
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 2),
                color: Colors.grey[900]!.withOpacity(0.3),
                child: Row(
                  children: [
                    Container(
                      width: 140,
                      height: 80,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: NetworkImage(
                            item['image'] ??
                                "https://via.placeholder.com/140x80",
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        item['title']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.play_circle_outline,
                      color: Colors.white,
                      size: 30,
                    ),
                    const SizedBox(width: 15),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- VISTA 2: RESULTADOS DE BÚSQUEDA (GRID) ---
  Widget _buildSearchResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(15.0),
          child: Text(
            "Películas y TV",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2 / 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: 9, // Simulación de resultados
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  image: const DecorationImage(
                    image: NetworkImage(
                      "https://image.tmdb.org/t/p/w500/uxt9XQ9pZzpzp.jpg",
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
