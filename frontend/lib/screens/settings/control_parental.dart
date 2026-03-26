import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ControlParentalScreen extends StatefulWidget {
  const ControlParentalScreen({super.key});

  @override
  State<ControlParentalScreen> createState() => _ControlParentalScreenState();
}

class _ControlParentalScreenState extends State<ControlParentalScreen> {
  // 1. Estado de la clasificación por edad
  String _selectedMaturity = "18+";

  // 2. Estado del PIN de seguridad
  bool _pinEnabled = false;

  final List<Map<String, String>> _levels = [
    {"label": "Todos", "desc": "Contenido para todas las edades."},
    {"label": "7+", "desc": "Recomendado para mayores de 7 años."},
    {"label": "13+", "desc": "Contenido para adolescentes."},
    {"label": "16+", "desc": "Contenido para jóvenes adultos."},
    {"label": "18+", "desc": "Sin restricciones de edad."},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text("Controles parentales", style: GoogleFonts.montserrat()),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader("Clasificación por edad"),
            const SizedBox(height: 10),
            Text(
              "Muestra solo títulos con esta clasificación o inferiores para este perfil.",
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 20),

            // LISTA DE NIVELES DE MADUREZ
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: _levels
                    .map((level) => _buildLevelTile(level))
                    .toList(),
              ),
            ),

            const SizedBox(height: 40),
            _buildHeader("Seguridad del perfil"),
            const SizedBox(height: 10),

            // TOGGLE DE PIN
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SwitchListTile(
                activeColor: const Color(0xFFE50914),
                title: const Text(
                  "Bloqueo de perfil",
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  _pinEnabled
                      ? "Se requiere PIN para acceder."
                      : "Sin PIN de acceso.",
                  style: const TextStyle(color: Colors.grey),
                ),
                value: _pinEnabled,
                onChanged: (val) {
                  setState(() => _pinEnabled = val);
                  if (val) _showPinDialog();
                },
              ),
            ),

            const SizedBox(height: 50),

            // BOTÓN GUARDAR
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: () => _saveSettings(),
                child: const Text(
                  "GUARDAR",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS INTERNOS ---

  Widget _buildHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 13,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildLevelTile(Map<String, String> level) {
    bool isSelected = _selectedMaturity == level['label'];
    return RadioListTile<String>(
      activeColor: const Color(0xFFE50914),
      title: Text(
        level['label']!,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        level['desc']!,
        style: TextStyle(
          color: isSelected ? Colors.white70 : Colors.grey[600],
          fontSize: 12,
        ),
      ),
      value: level['label']!,
      groupValue: _selectedMaturity,
      onChanged: (val) => setState(() => _selectedMaturity = val!),
    );
  }

  // --- LÓGICA ---

  void _showPinDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          "Crear PIN de perfil",
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            letterSpacing: 10,
          ),
          decoration: const InputDecoration(
            hintText: "0000",
            hintStyle: TextStyle(color: Colors.white24),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CREAR"),
          ),
        ],
      ),
    );
  }

  void _saveSettings() {
    // Aquí conectarías con tu ApiService
    print("Guardando: $_selectedMaturity, PIN: $_pinEnabled");
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(content: Text("Preferencias parentales actualizadas")),
    );
  }
}
