import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/movie_model.dart';
import 'video_player_screen.dart';

class MovieDetailsScreen extends StatelessWidget {
  // Eliminamos 'movieData' para usar el objeto Movie tipado,
  // siguiendo principios de Clean Code.
  final Movie movie;
  final Map<String, dynamic>? user;

  const MovieDetailsScreen({super.key, required this.movie, this.user});

  // Lógica de navegación centralizada y segura
  void _navigateToPlayer(BuildContext context) {
    // Verificamos que existan IDs válidos antes de intentar abrir el reproductor
    final String? tmdbId = movie.tmdbId?.toString();
    final String? imdbId = movie.imdbId;

    if (_isValidId(tmdbId) || _isValidId(imdbId)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(
            tmdbId: tmdbId,
            imdbId: imdbId,
            title: movie.title,
            type: movie.type,
          ),
        ),
      );
    } else {
      _showErrorSnackBar(
        context,
        "El enlace de streaming no está disponible para este título.",
      );
    }
  }

  bool _isValidId(String? id) => id != null && id.isNotEmpty && id != 'null';

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Extraemos el año de forma segura
    final releaseYear =
        movie.releaseDate != null && movie.releaseDate!.length >= 4
        ? movie.releaseDate!.substring(0, 4)
        : "N/A";

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(size),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleSection(releaseYear),
                  const SizedBox(height: 20),
                  _buildActionButtons(context),
                  const SizedBox(height: 20),
                  _buildDescription(),
                  const SizedBox(height: 15),
                  _buildMetadataInfo(),
                  const SizedBox(height: 40),
                  _buildSocialActions(),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Componente: Header con gradiente profesional
  Widget _buildAppBar(Size size) {
    return SliverAppBar(
      expandedHeight: size.height * 0.45,
      backgroundColor: const Color(0xFF141414),
      elevation: 0,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              movie.backdropUrl ?? movie.imageUrl ?? '',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey[900],
                child: const Icon(Icons.movie, color: Colors.white24, size: 50),
              ),
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

  // Componente: Título y etiquetas de calidad
  Widget _buildTitleSection(String year) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          movie.title,
          style: GoogleFonts.roboto(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              year,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(width: 12),
            _buildBadge("16+"),
            const SizedBox(width: 12),
            _buildBadge("4K Ultra HD", isTransparent: true),
          ],
        ),
      ],
    );
  }

  Widget _buildBadge(String text, {bool isTransparent = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isTransparent ? Colors.transparent : Colors.grey[800],
        border: isTransparent ? Border.all(color: Colors.white38) : null,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Componente: Botones de acción principales
  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        _mainButton(
          label: "Reproducir",
          icon: Icons.play_arrow,
          onPressed: () => _navigateToPlayer(context),
          isPrimary: true,
        ),
        const SizedBox(height: 10),
        _mainButton(
          label: "Descargar",
          icon: Icons.download,
          onPressed: () =>
              _showErrorSnackBar(context, "Disponible en el plan Premium."),
          isPrimary: false,
        ),
      ],
    );
  }

  Widget _mainButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 28),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? Colors.white : Colors.grey[850],
          foregroundColor: isPrimary ? Colors.black : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildDescription() {
    return Text(
      movie.description ?? 'Sin descripción disponible.',
      style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
    );
  }

  Widget _buildMetadataInfo() {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: Colors.grey, fontSize: 13),
        children: [
          const TextSpan(
            text: "Géneros: ",
            style: TextStyle(color: Colors.white60),
          ),
          TextSpan(text: movie.category ?? 'Acción, Ciencia Ficción'),
        ],
      ),
    );
  }

  Widget _buildSocialActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _socialIcon(Icons.add, "Mi lista"),
        _socialIcon(Icons.thumb_up_alt_outlined, "Calificar"),
        _socialIcon(Icons.share, "Compartir"),
      ],
    );
  }

  Widget _socialIcon(IconData icon, String label) {
    return InkWell(
      onTap: () {}, // Implementar lógica social
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 26),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
