import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/movie_model.dart';
import 'watchlist_providers.dart';

class MovieDetailsScreen extends StatefulWidget {
  final Movie movie;
  final Map<String, dynamic>? user;

  const MovieDetailsScreen({super.key, required this.movie, this.user});

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  bool _isProcessing = false;

  Future<void> _handleWatchlistToggle() async {
    if (widget.user == null || widget.user!['id'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Inicia sesión para usar Mi Lista")),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final provider = Provider.of<WatchlistProvider>(context, listen: false);
      await provider.toggleWatchlist(
        widget.user!['id'].toString(),
        widget.movie.id ?? 0, // Asegúrate que sea un int
        widget.movie.title,
        widget.movie.imageUrl ?? '',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error al conectar con el servidor")),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Escucha si la película está en la lista
    final bool isInList = context.watch<WatchlistProvider>().isInWatchlist(
      widget.movie.id ?? 0,
      // Asegúrate que sea un int
    );

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: CustomScrollView(
        slivers: [
          // ... Tu SliverAppBar actual ...
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // ... Tu info de cabecera y botones principales ...
                  const SizedBox(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(
                        icon: _isProcessing
                            ? Icons.hourglass_empty
                            : (isInList ? Icons.check : Icons.add),
                        label: "Mi lista",
                        onTap: _isProcessing ? null : _handleWatchlistToggle,
                        color: isInList ? Colors.greenAccent : Colors.white,
                      ),
                      _buildActionButton(
                        icon: Icons.thumb_up_alt_outlined,
                        label: "Calificar",
                        onTap: () {},
                      ),
                      _buildActionButton(
                        icon: Icons.share,
                        label: "Compartir",
                        onTap: () {},
                      ),
                    ],
                  ),
                  // ... Resto de la descripción y temporadas ...
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    Color color = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
