import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/subtitle_provider.dart'; // Ajusta la ruta si es necesario

class ConfiguracionSubtitulosScreen extends StatelessWidget {
  const ConfiguracionSubtitulosScreen({super.key});

  final List<Color> _colorOptions = const [
    Colors.white,
    Colors.yellow,
    Colors.green,
    Colors.cyanAccent,
    Colors.pinkAccent,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text("Aspecto de los subtítulos", style: GoogleFonts.montserrat()),
      ),
      body: Consumer<SubtitleProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- VISTA PREVIA ---
                Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                    image: const DecorationImage(
                      image: NetworkImage(
                        "https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?q=80&w=1000&auto=format&fit=crop",
                      ),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black45,
                        BlendMode.darken,
                      ),
                    ),
                  ),
                  alignment: Alignment.bottomCenter,
                  padding: const EdgeInsets.only(bottom: 20),
                  child: AnimatedOpacity(
                    opacity: provider.showSubtitles ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "Este es un texto de ejemplo.",
                        style: TextStyle(
                          color: provider.subtitleColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // --- TOGGLE ACTIVAR/DESACTIVAR ---
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SwitchListTile(
                    activeColor: const Color(0xFFE50914),
                    title: const Text(
                      "Mostrar subtítulos",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      provider.showSubtitles
                          ? "Los subtítulos estarán visibles durante la reproducción."
                          : "Los subtítulos están desactivados.",
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                    value: provider.showSubtitles,
                    onChanged: (val) => provider.toggleSubtitles(val),
                  ),
                ),

                const SizedBox(height: 30),

                // --- SELECTOR DE COLOR ---
                AnimatedOpacity(
                  opacity: provider.showSubtitles ? 1.0 : 0.3,
                  duration: const Duration(milliseconds: 300),
                  child: AbsorbPointer(
                    absorbing: !provider.showSubtitles,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Color del texto",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: _colorOptions.map((color) {
                            final isSelected = provider.subtitleColor == color;
                            return GestureDetector(
                              onTap: () => provider.updateColor(color),
                              child: Container(
                                width: 45,
                                height: 45,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    if (isSelected)
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.5),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                  ],
                                ),
                                child: isSelected
                                    ? Icon(
                                        Icons.check,
                                        color: color == Colors.white
                                            ? Colors.black
                                            : Colors.white,
                                      )
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
