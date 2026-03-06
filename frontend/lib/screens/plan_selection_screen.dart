import 'package:flutter/material.dart';
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

  final List<Map<String, dynamic>> _plans = [
    {"name": "Básico", "price": "S/ 24.90", "quality": "Buena", "res": "720p"},
    {
      "name": "Estándar",
      "price": "S/ 34.90",
      "quality": "Muy buena",
      "res": "1080p",
    },
    {
      "name": "Premium",
      "price": "S/ 44.90",
      "quality": "Excepcional",
      "res": "4K+HDR",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // Evitamos que regresen para no duplicar procesos de registro
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cerrar sesión",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "PASO 2 DE 3",
              style: TextStyle(
                color: Colors.black54,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Selecciona el plan ideal para ti",
              style: TextStyle(
                color: Colors.black,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildFeatureRow(
              Icons.check,
              "Ve todo lo que quieras. Sin anuncios.",
            ),
            _buildFeatureRow(
              Icons.check,
              "Recomendaciones exclusivas para ti.",
            ),
            _buildFeatureRow(
              Icons.check,
              "Cambia de plan o cancela cuando quieras.",
            ),
            const SizedBox(height: 30),

            // Selector de Planes
            Row(
              children: List.generate(_plans.length, (index) {
                bool isSelected = _selectedPlanIndex == index;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPlanIndex = index),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      height: 100,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFE50914)
                            : const Color(0xFFE50914).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: isSelected
                            ? [
                                const BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 10,
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          _plans[index]["name"],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 30),
            _buildDetailRow(
              "Precio mensual",
              _plans[_selectedPlanIndex]["price"],
            ),
            const Divider(),
            _buildDetailRow(
              "Calidad de video",
              _plans[_selectedPlanIndex]["quality"],
            ),
            const Divider(),
            _buildDetailRow("Resolución", _plans[_selectedPlanIndex]["res"]),
            const SizedBox(height: 40),

            const Text(
              "La disponibilidad del contenido en HD (720p), Full HD (1080p), Ultra HD (4K) y HDR depende de tu servicio de internet y del dispositivo.",
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 20),

            // --- BOTÓN SIGUIENTE (MODIFICADO) ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE50914),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                onPressed: () {
                  String planSeleccionado = _plans[_selectedPlanIndex]["name"];

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PaymentMethodScreen(
                        userEmail: widget.userEmail,
                        userName: widget.userName,
                        password:
                            widget.password, // <--- AHORA PASAMOS LA CLAVE
                        selectedPlan: planSeleccionado,
                      ),
                    ),
                  );
                },
                child: const Text(
                  "SIGUIENTE",
                  style: TextStyle(
                    color: Colors.white,
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

  // Métodos auxiliares se mantienen igual para no alterar tu diseño
  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFE50914)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.black54, fontSize: 16),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
