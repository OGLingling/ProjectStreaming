import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart'; // Asegúrate de que esta ruta sea correcta
import 'payment_method_screen.dart';

class PlanSelectionScreen extends StatefulWidget {
  final String userEmail;
  final String userName;
  final String password;

  const PlanSelectionScreen({
    super.key,
    required this.userEmail,
    required this.userName,
    required this.password,
  });

  @override
  State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends State<PlanSelectionScreen> {
  int _selectedPlanIndex = 2; // Premium por defecto
  bool _isLoading = false;

  final List<Map<String, dynamic>> _plans = [
    {
      "name": "Básico",
      "price": "S/ 24.90",
      "quality": "Buena",
      "res": "720p",
      "screens": "1 dispositivo / 1 usuario",
      "devices": "Móvil, Tableta, PC",
      "gradient": [const Color(0xFF4A90E2), const Color(0xFF9013FE)],
    },
    {
      "name": "Estándar",
      "price": "S/ 34.90",
      "quality": "Muy buena",
      "res": "1080p",
      "screens": "2 dispositivos / 2 usuarios",
      "devices": "Móvil, Tableta, PC, TV",
      "gradient": [const Color(0xFF1CB5E0), const Color(0xFF000851)],
    },
    {
      "name": "Premium",
      "price": "S/ 44.90",
      "quality": "Excepcional",
      "res": "4K+HDR",
      "screens": "4 dispositivos / 4 usuarios",
      "devices": "Todos los dispositivos",
      "gradient": [const Color(0xFFE50914), const Color(0xFF8E060C)],
    },
  ];

  Future<void> _handleNextStep() async {
    setState(() => _isLoading = true);

    String planSeleccionado = _plans[_selectedPlanIndex]["name"]
        .toString()
        .toLowerCase();

    try {
      // 1. Intentamos registrar al usuario en la base de datos
      final userData = await ApiService.registerUser(
        widget.userEmail,
        widget.userName,
        widget.password,
        planSeleccionado,
      );

      if (userData != null) {
        // 2. Si el registro es exitoso, guardamos la sesión localmente
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', userData['id'].toString());
        await prefs.setBool('is_logged_in', true);

        if (!mounted) return;

        // 3. Navegamos a la pantalla de pago
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentMethodScreen(
              userEmail: widget.userEmail,
              userName: widget.userName,
              password: widget.password,
              selectedPlan: planSeleccionado,
            ),
          ),
        );
      } else {
        _showSnackBar("Hubo un error al crear tu cuenta. Intenta nuevamente.");
      }
    } catch (e) {
      _showSnackBar("Error de conexión. Verifica que el servidor esté activo.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Atrás",
              style: GoogleFonts.geologica(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "PASO 2 DE 3",
                    style: GoogleFonts.geologica(
                      color: Colors.black54,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "Selecciona el plan ideal para ti",
                    style: GoogleFonts.montserrat(
                      color: Colors.black,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 25),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: List.generate(
                  _plans.length,
                  (index) => _buildPlanCard(index),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Text(
                    "La disponibilidad del contenido depende de tu servicio de internet y de las capacidades de tu dispositivo.",
                    style: GoogleFonts.geologica(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE50914),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      onPressed: _isLoading ? null : _handleNextStep,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              "SIGUIENTE",
                              style: GoogleFonts.geologica(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1.2,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(int index) {
    bool isSelected = _selectedPlanIndex == index;
    var plan = _plans[index];

    return GestureDetector(
      onTap: () => setState(() => _selectedPlanIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 280,
        margin: const EdgeInsets.only(right: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFE50914) : Colors.grey.shade300,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(9),
                ),
                gradient: LinearGradient(
                  colors: plan["gradient"],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan["name"],
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    plan["res"],
                    style: GoogleFonts.geologica(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  _buildCardDetail("Precio mensual", plan["price"]),
                  _buildCardDetail("Calidad de video", plan["quality"]),
                  _buildCardDetail("Resolución", plan["res"]),
                  _buildCardDetail("Uso simultáneo", plan["screens"]),
                  _buildCardDetail("Dispositivos", plan["devices"]),
                  const SizedBox(height: 10),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFFE50914),
                      size: 30,
                    )
                  else
                    const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardDetail(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.geologica(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.geologica(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const Divider(height: 20),
        ],
      ),
    );
  }
}
