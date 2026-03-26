import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ConfiguracionSubtitulosScreen extends StatefulWidget {
  const ConfiguracionSubtitulosScreen({super.key});

  @override
  State<ConfiguracionSubtitulosScreen> createState() =>
      _ConfiguracionSubtitulosScreenState();
}

class _ConfiguracionSubtitulosScreenState
    extends State<ConfiguracionSubtitulosScreen> {
  // 1. ESTADOS INICIALES
  double _fontSize = 18.0;
  Color _textColor = Colors.white;
  Color _backgroundColor = Colors.black.withOpacity(0.5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          "Aspecto de los subtítulos",
          style: GoogleFonts.montserrat(),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- SECCIÓN DE VISTA PREVIA ---
            Container(
              height: 200,
              width: double.infinity,
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: const DecorationImage(
                  image: AssetImage(
                    "assets/images/preview_bg.jpg",
                  ), // Asegúrate de tener una imagen de fondo o usa un color
                  fit: BoxFit.cover,
                  opacity: 0.6,
                ),
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  color: _backgroundColor,
                  child: Text(
                    "Así se verán los subtítulos",
                    style: TextStyle(
                      color: _textColor,
                      fontSize: _fontSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: Colors.white24),
            ),

            // --- CONTROLES ---
            _buildSettingSection(
              title: "Tamaño del texto",
              child: Slider(
                activeColor: const Color(0xFFE50914),
                inactiveColor: Colors.white24,
                value: _fontSize,
                min: 12,
                max: 30,
                divisions: 3,
                label: _fontSize == 12
                    ? "Pequeño"
                    : (_fontSize == 18 ? "Mediano" : "Grande"),
                onChanged: (val) => setState(() => _fontSize = val),
              ),
            ),

            _buildSettingSection(
              title: "Color del texto",
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _colorOption(Colors.white),
                  _colorOption(Colors.yellow),
                  _colorOption(Colors.cyan),
                  _colorOption(Colors.greenAccent),
                ],
              ),
            ),

            _buildSettingSection(
              title: "Fondo de los subtítulos",
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _bgOption(Colors.transparent, "Ninguno"),
                  _bgOption(Colors.black.withOpacity(0.5), "Sombra"),
                  _bgOption(Colors.black, "Bloque"),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // BOTÓN GUARDAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE50914),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "GUARDAR CAMBIOS",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS DE APOYO ---

  Widget _buildSettingSection({required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }

  Widget _colorOption(Color color) {
    bool isSelected = _textColor == color;
    return GestureDetector(
      onTap: () => setState(() => _textColor = color),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.red : Colors.white24,
            width: 3,
          ),
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.black, size: 20)
            : null,
      ),
    );
  }

  Widget _bgOption(Color color, String label) {
    bool isSelected = _backgroundColor == color;
    return GestureDetector(
      onTap: () => setState(() => _backgroundColor = color),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(
                color: isSelected ? Colors.red : Colors.white24,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
