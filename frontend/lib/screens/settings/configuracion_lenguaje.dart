import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/settings_provider.dart';

class ConfiguracionLenguajeScreen extends StatefulWidget {
  final String? userId; // Opcional, pero necesario para guardar en backend

  const ConfiguracionLenguajeScreen({super.key, this.userId});

  @override
  State<ConfiguracionLenguajeScreen> createState() =>
      _ConfiguracionLenguajeScreenState();
}

class _ConfiguracionLenguajeScreenState
    extends State<ConfiguracionLenguajeScreen> {
  bool _isSaving = false;

  final List<String> _idiomas = ["Español", "English", "Português"];

  final List<Color> _colorOptions = const [
    Colors.white,
    Colors.yellow,
    Colors.green,
    Colors.cyanAccent,
    Colors.pinkAccent,
  ];

  Future<void> _guardarPreferencias(SettingsProvider provider) async {
    if (widget.userId == null || widget.userId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error: No se encontró el ID de usuario."),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final url = Uri.parse(
        'https://projectstreaming.onrender.com/api/auth/users/${widget.userId}',
      );

      final payload = {
        "language": provider.language,
        "showSubtitles": provider.showSubtitles,
        "subtitleColor": provider.subtitleColorHex, // Ej. #FFFFFF
      };

      debugPrint("🟡 Enviando PUT a: $url");
      debugPrint("🟡 Body: ${json.encode(payload)}");

      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );

      debugPrint("🟢 Respuesta del servidor: ${response.statusCode}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Ajustes guardados correctamente"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (response.statusCode == 404) {
        throw Exception("Ruta incorrecta o usuario no encontrado (404)");
      } else {
        throw Exception("Error del servidor: Código ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("🔴 Excepción capturada: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al guardar ajustes: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          "Idioma y Subtítulos",
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        actions: [
          _isSaving
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.only(right: 20),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.save, color: Colors.blue),
                  onPressed: () {
                    final provider = Provider.of<SettingsProvider>(
                      context,
                      listen: false,
                    );
                    _guardarPreferencias(provider);
                  },
                ),
        ],
      ),
      body: Consumer<SettingsProvider>(
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
                        provider.sampleText,
                        style: TextStyle(
                          color: provider.subtitleColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          shadows: const [
                            Shadow(
                              offset: Offset(1, 1),
                              blurRadius: 3.0,
                              color: Colors.black,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // --- SELECTOR DE IDIOMA COMPACTO ---
                Text(
                  "Idioma de Audio y App",
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: provider.language,
                      dropdownColor: Colors.grey[900],
                      isExpanded: true,
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white,
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          provider.updateSettings(newLanguage: newValue);
                        }
                      },
                      items: _idiomas.map<DropdownMenuItem<String>>((
                        String value,
                      ) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // --- TOGGLE ACTIVAR/DESACTIVAR SUBTÍTULOS ---
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
                    onChanged: (val) =>
                        provider.updateSettings(newShowSubtitles: val),
                  ),
                ),

                const SizedBox(height: 30),

                // --- SELECTOR DE COLOR DE SUBTÍTULOS ---
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
                              onTap: () => provider.updateSettings(
                                newSubtitleColor: color,
                              ),
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
