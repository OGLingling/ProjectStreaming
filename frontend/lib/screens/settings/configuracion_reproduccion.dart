import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../providers/settings_provider.dart';

class ConfiguracionReproduccionScreen extends StatefulWidget {
  final String? userId; // Necesario para guardar en backend

  const ConfiguracionReproduccionScreen({super.key, this.userId});

  @override
  State<ConfiguracionReproduccionScreen> createState() =>
      _ConfiguracionReproduccionScreenState();
}

class _ConfiguracionReproduccionScreenState
    extends State<ConfiguracionReproduccionScreen> {
  bool _isSaving = false;

  final List<String> _idiomas = ["Español", "English", "Português"];

  final List<Color> _colorOptions = const [
    Colors.white,
    Colors.yellow,
    Colors.green,
    Colors.cyanAccent,
    Colors.pinkAccent,
  ];

  // Función de Auto-Guardado en API + SharedPreferences
  Future<void> _updateAndSave(
    SettingsProvider provider, {
    String? newLanguage,
    bool? newShowSubtitles,
    Color? newSubtitleColor,
  }) async {
    // 1. Guardar localmente en SharedPreferences (redundancia y velocidad local)
    await provider.updateSettings(
      newLanguage: newLanguage,
      newShowSubtitles: newShowSubtitles,
      newSubtitleColor: newSubtitleColor,
    );

    // 2. Guardar en el Backend
    if (widget.userId == null || widget.userId!.isEmpty) {
      debugPrint("Error: No se encontró el ID de usuario para guardar en API.");
      return;
    }

    setState(() => _isSaving = true);

    try {
      final url = Uri.parse(
        'https://projectstreaming-1.onrender.com/api/auth/users/${widget.userId}',
      );

      final payload = {
        "language": provider.language,
        "showSubtitles": provider.showSubtitles,
        "subtitleColor": provider.subtitleColorHex,
      };

      debugPrint("🟡 Guardando preferencias en BD: ${json.encode(payload)}");

      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("🟢 Preferencias guardadas correctamente en BD.");
      } else if (response.statusCode == 404) {
        debugPrint("🔴 Error 404: Ruta incorrecta o usuario no encontrado.");
      } else {
        debugPrint("🔴 Error del servidor: Código ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("🔴 Excepción capturada al guardar en API: $e");
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
          "Configuración de Reproducción",
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 20),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
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
                // --- SECCIÓN 1: IDIOMAS (RadioListTile) ---
                Text(
                  "Sección 1: Idioma de Audio y App",
                  style: GoogleFonts.montserrat(
                    color: Colors.grey[400],
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: _idiomas.map((String idioma) {
                      return RadioListTile<String>(
                        title: Text(
                          idioma,
                          style: const TextStyle(color: Colors.white),
                        ),
                        value: idioma,
                        groupValue: provider.language,
                        activeColor: const Color(0xFFE50914), // Netflix Red
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            _updateAndSave(provider, newLanguage: newValue);
                          }
                        },
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 30),

                // --- SECCIÓN 2: ASPECTO (Subtítulos y Color) ---
                Text(
                  "Sección 2: Aspecto de los subtítulos",
                  style: GoogleFonts.montserrat(
                    color: Colors.grey[400],
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
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
                              ? "Activados durante la reproducción."
                              : "Desactivados.",
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                        value: provider.showSubtitles,
                        onChanged: (val) {
                          _updateAndSave(provider, newShowSubtitles: val);
                        },
                      ),
                      
                      // Selector de colores solo si están activos
                      AnimatedOpacity(
                        opacity: provider.showSubtitles ? 1.0 : 0.3,
                        duration: const Duration(milliseconds: 300),
                        child: AbsorbPointer(
                          absorbing: !provider.showSubtitles,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
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
                                    final isSelected =
                                        provider.subtitleColor == color;
                                    return GestureDetector(
                                      onTap: () {
                                        _updateAndSave(
                                          provider,
                                          newSubtitleColor: color,
                                        );
                                      },
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
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // --- SECCIÓN 3: VISTA PREVIA DINÁMICA ---
                Text(
                  "Sección 3: Vista Previa",
                  style: GoogleFonts.montserrat(
                    color: Colors.grey[400],
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  height: 200,
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
                  padding: const EdgeInsets.only(bottom: 30),
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
                          fontSize: 18,
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
              ],
            ),
          );
        },
      ),
    );
  }
}
