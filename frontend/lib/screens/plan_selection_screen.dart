import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'payment_method_screen.dart';

class PlanSelectionScreen extends StatefulWidget {
  final String userEmail;
  final String userName;
  // ✅ CAMBIO #1: Se agrega el campo 'password' de vuelta.
  // El archivo original lo había eliminado con el comentario "usas sistema OTP",
  // pero PaymentMethodScreen lo requiere como parámetro obligatorio (required).
  // Sin él, la app no compila. Si en tu flujo no hay contraseña, pasa "" desde
  // la pantalla anterior, pero el campo DEBE existir aquí para ser enviado.
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
  int _selectedPlanIndex = 2; // Premium seleccionado por defecto
  bool _isLoading = false;

  // ✅ CAMBIO #2: Datos de los planes actualizados para coincidir con la imagen.
  // La imagen muestra campos distintos al código original:
  //   - "Calidad de vídeo y audio" (no solo "Calidad de video")
  //   - "Resolución" con descripción larga ("720p (HD)", "1080p (Full HD)", "4K (Ultra HD) + HDR")
  //   - "Audio espacial" (solo en Premium)
  //   - "Dispositivos compatibles" con lista completa
  //   - "Dispositivos simultáneos" como número separado
  //   - "Descargas" como número separado
  // También se agrega 'popular: true' para el badge "Más populares" del plan Premium.
  final List<Map<String, dynamic>> _plans = [
    {
      "id": "basico",
      "name": "Básico",
      "price": "S/ 24.90",
      "quality": "Buena",
      "resolution": "720p (HD)",
      "spatialAudio": null, // No incluido en plan básico
      "devices": "Televisor, ordenador, teléfono móvil, tableta",
      "simultaneousScreens": "1",
      "downloads": "1",
      "popular": false,
      "gradient": [const Color(0xFF4A90E2), const Color(0xFF9013FE)],
    },
    {
      "id": "estandar",
      "name": "Estándar",
      "price": "S/ 34.90",
      "quality": "Excelente",
      "resolution": "1080p (Full HD)",
      "spatialAudio": null,
      "devices": "Televisor, ordenador, teléfono móvil, tableta",
      "simultaneousScreens": "2",
      "downloads": "2",
      "popular": false,
      "gradient": [const Color(0xFF1CB5E0), const Color(0xFF000851)],
    },
    {
      "id": "premium",
      "name": "Premium",
      "price": "S/ 44.90",
      "quality": "Excepcional",
      "resolution": "4K (Ultra HD) + HDR",
      "spatialAudio": "Incluido", // Solo Premium
      "devices": "Televisor, ordenador, teléfono móvil, tableta",
      "simultaneousScreens": "4",
      "downloads": "6",
      "popular": true, // ✅ Badge "Más populares"
      "gradient": [const Color(0xFFE50914), const Color(0xFF8E060C)],
    },
  ];

  Future<void> _handleNextStep() async {
    // ✅ CAMBIO #3: Guardia contra doble ejecución (igual que en PaymentMethodScreen)
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final String planId = _plans[_selectedPlanIndex]["id"].toString();

    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentMethodScreen(
          userEmail: widget.userEmail,
          userName: widget.userName,
          selectedPlan: planId,
          // ✅ CAMBIO #4: Pasamos widget.password en lugar de ""
          // Aunque sea vacío, ahora el flujo es explícito y rastreable.
          // Si decides agregar contraseña más adelante, ya está conectado.
          password: widget.password,
        ),
      ),
    );

    // ✅ CAMBIO #5: setState después de Navigator.push puede causar problemas
    // si el widget ya no está montado cuando el usuario regresa.
    // Se verifica con mounted antes de actualizar estado.
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Encabezado ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Paso 2 de 3",
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
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // ── Carrusel de tarjetas ─────────────────────────────────────
          // ✅ CAMBIO #6: Se envuelve en Expanded para que las cards
          // tengan altura fija y consistente. Antes usaba SingleChildScrollView
          // en el Column principal, lo que hacía que las cards tuvieran
          // alturas variables según el contenido, causando el "descuadre".
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(
                  _plans.length,
                  (index) => _buildPlanCard(index),
                ),
              ),
            ),
          ),

          // ── Disclaimer + Botón ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              children: [
                Text(
                  "La disponibilidad del contenido depende de tu servicio de internet y de las capacidades de tu dispositivo. Al continuar, configuraremos tu acceso mediante un código enviado a tu email.",
                  style: GoogleFonts.geologica(
                    color: Colors.black45,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE50914),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      elevation: 0,
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
    );
  }

  Widget _buildPlanCard(int index) {
    final bool isSelected = _selectedPlanIndex == index;
    final plan = _plans[index];
    final bool isPopular = plan["popular"] == true;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlanIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        // ✅ CAMBIO #7: width fijo para todas las cards (igual que la imagen).
        // Antes las cards también eran de 280, pero al estar dentro de un
        // SingleChildScrollView sin altura definida, se "estiraban" de forma
        // irregular. Ahora con Expanded en el padre, la altura es consistente.
        width: 280,
        margin: const EdgeInsets.only(right: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFE50914) : Colors.grey.shade300,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: Colors.red.withOpacity(0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              )
            else
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ CAMBIO #8: Badge "Más populares" encima de la card (igual a la imagen)
              // En el código original no existía este badge.
              if (isPopular)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  color: const Color(0xFFE50914),
                  alignment: Alignment.center,
                  child: Text(
                    "Más populares",
                    style: GoogleFonts.geologica(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

              // Header con gradiente
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: List<Color>.from(plan["gradient"]),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
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
                            // ✅ Mostrar resolución corta en el header (ej: "4K+HDR")
                            plan["resolution"].toString().split(" ").first,
                            style: GoogleFonts.geologica(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ✅ CAMBIO #9: El checkmark ahora está en el header (esquina superior derecha)
                    // igual que en la imagen de referencia, no al pie de la card.
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Color(0xFFE50914),
                          size: 16,
                        ),
                      ),
                  ],
                ),
              ),

              // ✅ CAMBIO #10: Cuerpo de la card con scroll interno
              // Si el contenido es mucho (Premium tiene "Audio espacial" extra),
              // el scroll evita que una card sea más alta que las otras.
              Flexible(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetail("Precio mensual", plan["price"]),
                        _buildDetail(
                          "Calidad de vídeo y audio",
                          plan["quality"],
                        ),
                        _buildDetail("Resolución", plan["resolution"]),
                        // ✅ CAMBIO #11: Campo "Audio espacial" solo si tiene valor
                        if (plan["spatialAudio"] != null)
                          _buildDetail(
                            "Audio espacial (audio envolvente)",
                            plan["spatialAudio"],
                          ),
                        _buildDetail(
                          "Dispositivos compatibles",
                          plan["devices"],
                        ),
                        _buildDetail(
                          "Dispositivos de tu hogar en los que puede verse a la vez",
                          plan["simultaneousScreens"],
                        ),
                        _buildDetail(
                          "Descargas en dispositivos",
                          plan["downloads"],
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ CAMBIO #12: Helper _buildDetail rediseñado para coincidir con la imagen.
  // La imagen muestra: label pequeño en gris arriba, valor en negro negrita abajo,
  // con un divider tenue entre cada ítem. Esto reemplaza al _buildCardDetail anterior.
  Widget _buildDetail(String label, String value, {bool isLast = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.geologica(color: Colors.black45, fontSize: 11),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.geologica(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        if (!isLast) ...[
          const SizedBox(height: 10),
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
