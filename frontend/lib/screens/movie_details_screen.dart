import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/movie_model.dart';
import '../services/api_service.dart'; // Asegúrate de tener este import
import 'video_player_screen.dart'; 
import 'watchlist_providers.dart';

class MovieDetailsScreen extends StatefulWidget {
  final Movie movie;
  final Map<String, dynamic>? user;

  const MovieDetailsScreen({super.key, required this.movie, this.user});

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  int _selectedSeasonIndex = 0;
  bool _isProcessing = false;
  bool _isValidating = false; // Nuevo: Para el estado de carga del scraping
  final ApiService _apiService = ApiService(); // Instancia del servicio

  // --- LÓGICA DE NAVEGACIÓN CON CLIENT-SIDE SCRAPING ---
  Future<void> _navigateToPlayer({int season = 1, int episode = 1}) async {
    final String? tmdbId = widget.movie.tmdbId?.toString();

    if (tmdbId == null || tmdbId.isEmpty) {
      _showSnackBar("ID de contenido no encontrado.", Colors.redAccent);
      return;
    }

    setState(() => _isValidating = true);

    try {
      // Intentamos obtener una URL que REALMENTE funcione desde la IP del usuario
      final String? workingUrl = await _apiService.getValidStreamUrl(
        tmdbId: tmdbId,
        type: widget.movie.type,
        season: season,
        episode: episode,
      );

      if (workingUrl != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(
              streamUrl: workingUrl, // Pasamos la URL ya validada
              title: widget.movie.title,
              tmdbId: tmdbId,
              type: widget.movie.type,
              season: season,
              episode: episode,
            ),
          ),
        );
      } else {
        _showSnackBar(
          "No hay servidores disponibles en este momento. Reintenta más tarde.",
          Colors.orangeAccent,
        );
      }
    } catch (e) {
      _showSnackBar("Error al conectar con los servidores.", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isValidating = false);
    }
  }

  // --- LÓGICA DE MI LISTA ---
  Future<void> _handleWatchlistToggle() async {
    if (widget.user == null || widget.user!['id'] == null) {
      _showSnackBar("Inicia sesión para guardar favoritos", Colors.orangeAccent);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final provider = Provider.of<WatchlistProvider>(context, listen: false);
      await provider.toggleWatchlist(
        widget.user!['id'].toString(),
        widget.movie.id ?? 0,
        widget.movie.title,
        widget.movie.imageUrl ?? '',
      );

      final bool isInList = provider.isInWatchlist(widget.movie.id ?? 0);
      _showSnackBar(
        isInList ? "Añadido a Mi Lista" : "Eliminado de Mi Lista",
        isInList ? Colors.green : Colors.grey[800]!,
      );
    } catch (e) {
      _showSnackBar("Error al actualizar la lista", Colors.redAccent);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTV = widget.movie.type == 'tv';
    final bool isInList = context.watch<WatchlistProvider>().isInWatchlist(
      widget.movie.id ?? 0,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(size),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderInfo(),
                      const SizedBox(height: 20),
                      _buildPrimaryButtons(),
                      const SizedBox(height: 20),
                      _buildDescription(),
                      const SizedBox(height: 25),
                      _buildActionRow(isInList),
                      const SizedBox(height: 30),
                      if (isTV &&
                          widget.movie.seasons != null &&
                          widget.movie.seasons!.isNotEmpty) ...[
                        _buildSeasonSelector(),
                        const SizedBox(height: 15),
                        _buildEpisodesList(),
                      ],
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Overlay de carga cuando estamos validando servidores
          if (_isValidating)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.green),
                    SizedBox(height: 20),
                    Text(
                      "Sincronizando mejor servidor...",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- COMPONENTES VISUALES ---

  Widget _buildSliverAppBar(Size size) {
    return SliverAppBar(
      expandedHeight: size.height * 0.40,
      pinned: true,
      backgroundColor: const Color(0xFF141414),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              widget.movie.backdropUrl ?? widget.movie.imageUrl ?? '',
              fit: BoxFit.cover,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black54,
                    Colors.transparent,
                    Color(0xFF141414),
                  ],
                  stops: [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.movie.title,
          style: GoogleFonts.roboto(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              widget.movie.releaseDate.length >= 4 
                  ? widget.movie.releaseDate.substring(0, 4) 
                  : widget.movie.releaseDate,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(width: 15),
            _buildBadge("16+"),
            const SizedBox(width: 15),
            Text(
              "${widget.movie.rating.toStringAsFixed(1)} ★",
              style: const TextStyle(color: Colors.amber),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPrimaryButtons() {
    return Column(
      children: [
        _buildLargeButton(
          onTap: _isValidating ? () {} : () => _navigateToPlayer(), 
          icon: Icons.play_arrow,
          label: "Reproducir",
          isPrimary: true,
        ),
        const SizedBox(height: 10),
        _buildLargeButton(
          onTap: () => _showSnackBar(
            "Función de descarga próximamente",
            Colors.blueGrey,
          ),
          icon: Icons.download,
          label: "Descargar",
          isPrimary: false,
        ),
      ],
    );
  }

  Widget _buildLargeButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required bool isPrimary,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: isPrimary ? Colors.black : Colors.white),
        label: Text(
          label,
          style: TextStyle(
            color: isPrimary ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? Colors.white : Colors.grey[850],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
    );
  }

  Widget _buildDescription() {
    return Text(
      widget.movie.description ?? 'Sin sinopsis disponible.',
      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
    );
  }

  Widget _buildActionRow(bool isInList) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          icon: _isProcessing
              ? Icons.sync
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
        _buildActionButton(icon: Icons.share, label: "Compartir", onTap: () {}),
      ],
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
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildSeasonSelector() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: _selectedSeasonIndex,
        dropdownColor: Colors.grey[900],
        items: List.generate(widget.movie.seasons!.length, (index) {
          return DropdownMenuItem(
            value: index,
            child: Text(
              "Temporada ${widget.movie.seasons![index].seasonNumber}",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }),
        onChanged: (val) => setState(() => _selectedSeasonIndex = val!),
      ),
    );
  }

  Widget _buildEpisodesList() {
    final episodes = widget.movie.seasons![_selectedSeasonIndex].episodes ?? [];
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: episodes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 15),
      itemBuilder: (context, index) {
        final ep = episodes[index];
        return InkWell(
          onTap: _isValidating ? null : () => _navigateToPlayer(
            season: widget.movie.seasons![_selectedSeasonIndex].seasonNumber,
            episode: ep.episodeNumber,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  ep.stillPath ?? widget.movie.imageUrl ?? '',
                  width: 120,
                  height: 70,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(width: 120, height: 70, color: Colors.white10),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${ep.episodeNumber}. ${ep.title}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const Text(
                      "45 min",
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.play_circle_outline, color: Colors.white70),
            ],
          ),
        );
      },
    );
  }
}