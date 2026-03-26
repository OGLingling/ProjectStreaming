import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ConfiguracionLenguajeScreen extends StatefulWidget {
  const ConfiguracionLenguajeScreen({super.key});

  @override
  State<ConfiguracionLenguajeScreen> createState() =>
      _ConfiguracionLenguajeScreenState();
}

class _ConfiguracionLenguajeScreenState
    extends State<ConfiguracionLenguajeScreen> {
  // 1. Estado local para el idioma seleccionado
  String _idiomaSeleccionado = "Español";

  // 2. Lista de idiomas disponibles
  final List<Map<String, String>> _idiomas = [
    {"nombre": "Español", "codigo": "es"},
    {"nombre": "English", "codigo": "en"},
    {"nombre": "Français", "codigo": "fr"},
    {"nombre": "Português", "codigo": "pt"},
    {"nombre": "Deutsch", "codigo": "de"},
    {"nombre": "Italiano", "codigo": "it"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414), // Fondo oscuro
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          "Idiomas",
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              "Selecciona el idioma de audio y subtítulos",
              style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 16),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _idiomas.length,
              separatorBuilder: (context, index) =>
                  const Divider(color: Colors.white10, height: 1),
              itemBuilder: (context, index) {
                final idioma = _idiomas[index];
                final bool esSeleccionado =
                    _idiomaSeleccionado == idioma['nombre'];

                return Theme(
                  data:
                      ThemeData.dark(), // Asegura que el Radio sea visible en fondo oscuro
                  child: RadioListTile<String>(
                    activeColor: const Color(0xFFE50914), // Rojo Netflix
                    title: Text(
                      idioma['nombre']!,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: esSeleccionado
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    value: idioma['nombre']!,
                    groupValue: _idiomaSeleccionado,
                    onChanged: (String? value) {
                      setState(() {
                        _idiomaSeleccionado = value!;
                      });
                      _guardarIdioma(value!);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 3. Función para guardar la preferencia (Placeholder para ApiService)
  void _guardarIdioma(String idioma) {
    print("Idioma cambiado a: $idioma");
    // Aquí llamarías a:
    // ApiService.updateUserPreference(userId, {"language": idioma});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Idioma actualizado a $idioma"),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green.withOpacity(0.8),
      ),
    );
  }
}
