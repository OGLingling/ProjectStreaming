import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/movie_model.dart';
import '../services/api_service.dart'; 
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
  bool _isValidating = false;

  // --- LÓGICA DE NAVEGACIÓN CORREGIDA ---
  Future<void> _navigateToPlayer({int season = 1, int episode = 1}) async {
    // Usamos el tmdbId del modelo de forma segura
    final String? tmdbId = widget.movie.tmdbId?.toString();

    if (tmdbId == null || tmdbId.isEmpty || tmdbId == "null") {
      _showSnackBar("ID de contenido no válido para reproducción.", Colors.redAccent);
      return;
    }

    setState(() => _isValidating = true);

    try {
      // ✅ CORRECCIÓN: Llamada estática al servicio (ApiService.método)
      // Se eliminó el uso de la instancia '_apiService'
      final String? workingUrl = await ApiService.getValidStreamUrl(
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
              streamUrl: workingUrl,
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
          "No se encontraron servidores estables. Intenta con otro título.",
          Colors.orangeAccent,
        );
      }
    } catch (e) {
      debugPrint("Error en Scraping: $e");
      _showSnackBar("Error de conexión con la fuente de video.", Colors.redAccent);
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

      if (mounted) {
        final bool isInList = provider.isInWatchlist(widget.movie.id ?? 0);
        _showSnackBar(
          isInList ? "Añadido a Mi Lista" : "Eliminado de Mi Lista",
          isInList ? Colors.green : Colors.grey[800]!,
        );
      }
    } catch (e) {
      _showSnackBar("Error al actualizar la lista", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTV = widget.movie.type.toLowerCase() == 'tv';
    
    // Watch para reaccionar a cambios en la lista
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
                      if (isTV && widget.movie.seasons != null && widget.movie.seasons!.isNotEmpty) ...[
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
          
          // Overlay de carga mejorado
          if (_isValidating)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Container(
                    color: Colors.black87,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.red, strokeWidth: 3),
                          const SizedBox(height: 25),
                          Text(
                            "Buscando el mejor servidor...",
                            style: GoogleFonts.roboto(
                              color: Colors.white, 
                              fontSize: 16,
                              letterSpacing: 1.2
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // --- COMPONENTES VISUALES ---

  Widget _buildSliverAppBar(Size size) {
    return SliverAppBar(
      expandedHeight: size.height * 0.35,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF141414),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              widget.movie.backdropUrl ?? widget.movie.imageUrl ?? '',
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(color: Colors.grey[900]),
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
                  stops: [0.0, 0.5, 1.0],
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
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              widget.movie.releaseDate.length >= 4 
                  ? widget.movie.releaseDate.substring(0, 4) 
                  : "N/A",
              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 15),
            _buildBadge("HD"),
            const SizedBox(width: 15),
            Text(
              "${widget.movie.rating.toStringAsFixed(1)} ★",
              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white60),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
          onTap: () {}, // Implementar descargas después
          icon: Icons.download_rounded,
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
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: isPrimary ? Colors.black : Colors.white, size: 30),
        label: Text(
          label,
          style: TextStyle(
            color: isPrimary ? Colors.black : Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? Colors.white : Colors.white.withOpacity(0.1),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
    );
  }

  Widget _buildDescription() {
    return Text(
      widget.movie.description ?? 'No hay descripción disponible para este título.',
      style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildActionRow(bool isInList) {
    return Row(
      children: [
        _buildActionButton(
          icon: _isProcessing ? Icons.hourglass_empty : (isInList ? Icons.check : Icons.add),
          label: "Mi lista",
          onTap: _isProcessing ? null : _handleWatchlistToggle,
          activeColor: isInList ? Colors.red : Colors.white,
        ),
        const SizedBox(width: 40),
        _buildActionButton(
          icon: Icons.thumb_up_off_alt,
          label: "Calificar",
          onTap: () {},
        ),
        const SizedBox(width: 40),
        _buildActionButton(
          icon: Icons.share_outlined,
          label: "Compartir",
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    Color activeColor = Colors.white,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: activeColor, size: 28),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSeasonSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedSeasonIndex,
          dropdownColor: Color(0xFF2F2F2F),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          items: List.generate(widget.movie.seasons!.length, (index) {
            return DropdownMenuItem(
              value: index,
              child: Text(
                "Temporada ${widget.movie.seasons![index].seasonNumber}",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            );
          }),
          onChanged: (val) => setState(() => _selectedSeasonIndex = val!),
        ),
      ),
    );
  }

  Widget _buildEpisodesList() {
    final episodes = widget.movie.seasons![_selectedSeasonIndex].episodes ?? [];
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: episodes.length,
      itemBuilder: (context, index) {
        final ep = episodes[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: InkWell(
            onTap: _isValidating ? null : () => _navigateToPlayer(
              season: widget.movie.seasons![_selectedSeasonIndex].seasonNumber,
              episode: ep.episodeNumber,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        ep.stillPath ?? widget.movie.imageUrl ?? '',
                        width: 130,
                        height: 75,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(color: Colors.white10, width: 130, height: 75),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${ep.episodeNumber}. ${ep.title}",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          const Text("45 min", style: TextStyle(color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    ),
                    const Icon(Icons.download_for_offline_outlined, color: Colors.white54),
                  ],
                ),
                if (ep.overview != null && ep.overview!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      ep.overview!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}