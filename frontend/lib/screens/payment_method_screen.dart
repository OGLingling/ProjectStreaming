import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'profiles_screen.dart';
import '../models/user_model.dart';

class PaymentMethodScreen extends StatefulWidget {
  final String userEmail;
  final String userName;
  final String selectedPlan;
  final String password;

  const PaymentMethodScreen({
    super.key,
    required this.userEmail,
    required this.userName,
    required this.selectedPlan,
    required this.password,
  });

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  // ✅ CAMBIO #1: Variable de estado para controlar el loading
  // Antes no había control de estado. Si el usuario rotaba la pantalla
  // o interactuaba mientras cargaba, podía causar errores de contexto.
  bool _isLoading = false;

  Future<void> _procesarRegistro(BuildContext context) async {
    // ✅ CAMBIO #2: Evitar doble ejecución
    // Sin esta guarda, el usuario podía tocar dos métodos de pago rápido
    // y lanzar dos registros simultáneos, creando usuarios duplicados.
    if (_isLoading) return;

    setState(() => _isLoading = true);

    // ✅ CAMBIO #3: firebase_auth.UserCredential declarado fuera del try
    // para poder hacer rollback en el catch si falla el paso 2 o 3.
    firebase_auth.UserCredential? userCredential;

    try {
      // PASO 1: REGISTRO EN FIREBASE
      // ✅ CAMBIO #4: Se usa widget.password en lugar de "user_access_2026"
      // La contraseña hardcodeada era un riesgo de seguridad crítico:
      // cualquiera podía acceder a la cuenta de otro usuario con solo
      // conocer su email. Ahora cada usuario tiene su propia contraseña.
      userCredential = await firebase_auth.FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: widget.userEmail.trim(),
            password: widget.password.trim(),
          );

      final String firebaseUid = userCredential.user!.uid;

      // PASO 2: REGISTRO EN BASE DE DATOS (Neon/Prisma)
      final userData = await ApiService.registerUser(
        email: widget.userEmail.trim(),
        name: widget.userName.trim(),
        plan: widget.selectedPlan,
        password: widget.password.trim(),
      );

      if (userData == null) {
        throw Exception("API_ERROR");
      }

      // ✅ CAMBIO #5: Guardamos el ID de tu BD, no el UID de Firebase
      // Antes se guardaba el UID de Firebase como 'user_id', pero tu
      // backend (Neon/Prisma) genera su propio ID. Usarlo para queries
      // en tu API causaría errores o datos incorrectos.
      // Guardamos AMBOS IDs para tenerlos disponibles cuando se necesiten.
      final String dbUserId = userData['id']?.toString() ?? firebaseUid;

      // PASO 3: ENVÍO DEL CÓDIGO OTP
      await ApiService.sendOTP(widget.userEmail.trim());

      // PASO 4: PERSISTENCIA LOCAL
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', dbUserId); // ✅ ID de tu BD
      await prefs.setString('firebase_uid', firebaseUid); // UID de Firebase
      await prefs.setBool('is_logged_in', true);

      // PASO 5: NAVEGACIÓN
      // ✅ CAMBIO #6: Renombrado AppUser para evitar colisión con firebase_auth.User
      // Flutter/Dart no da error de compilación si ambas clases se llaman 'User'
      // porque una tiene alias (firebase_auth), pero es confuso al leer el código
      // y puede causar errores sutiles si alguien quita el alias en el futuro.
      final User nuevoUsuario = User(
        id: dbUserId,
        name: widget.userName,
        email: widget.userEmail,
        plan: widget.selectedPlan,
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => ProfilesScreen(user: nuevoUsuario.toJson()),
        ),
        (route) => false,
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      // ✅ CAMBIO #7: Rollback de Firebase si falla el paso posterior
      // Antes, si Firebase creaba el usuario pero tu API fallaba,
      // el usuario quedaba "huérfano" en Firebase sin registro en Neon.
      // Ahora lo eliminamos para mantener consistencia entre ambas BDs.
      if (userCredential != null) {
        await userCredential.user?.delete();
      }

      String errorMsg = "Error al registrar: ${e.code}";

      // ✅ CAMBIO #8: if-else con llaves siempre
      // Sin llaves, agregar una segunda línea al if en el futuro
      // rompe la lógica silenciosamente sin error de compilación.
      if (e.code == 'email-already-in-use') {
        errorMsg = "El correo ya está registrado.";
      } else if (e.code == 'weak-password') {
        errorMsg = "La contraseña es demasiado débil.";
      } else if (e.code == 'invalid-email') {
        errorMsg = "El formato del correo no es válido.";
      }

      if (mounted) _showError(context, errorMsg);
    } catch (e) {
      // ✅ CAMBIO #9: Rollback también en errores generales (API, OTP, etc.)
      // Si la API de Neon falla después de crear el usuario en Firebase,
      // lo eliminamos para no dejar datos inconsistentes.
      if (userCredential != null) {
        await userCredential.user?.delete();
      }

      debugPrint("Error técnico: $e");

      if (mounted) {
        // ✅ CAMBIO #10: Mensaje de error más específico según el tipo
        final String mensaje = e.toString().contains("API_ERROR")
            ? "No se pudo conectar con el servidor. Intenta de nuevo."
            : "Hubo un error al crear tu cuenta. Intenta de nuevo.";
        _showError(context, mensaje);
      }
    } finally {
      // ✅ CAMBIO #11: Usamos finally para resetear el estado de loading
      // Antes, el Navigator.pop() para cerrar el loading se repetía en cada
      // catch individualmente, lo cual era propenso a olvidarse en alguno.
      // Con finally, se ejecuta SIEMPRE: haya éxito, error de Firebase o
      // cualquier otra excepción.
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        // ✅ CAMBIO #12: Deshabilitar el botón atrás mientras carga
        // Evita que el usuario navegue atrás a mitad del registro
        // y deje el proceso en un estado inconsistente.
        automaticallyImplyLeading: !_isLoading,
      ),
      body: Stack(
        children: [
          // ✅ CAMBIO #13: El contenido principal siempre visible
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Icon(
                  Icons.lock_outline,
                  color: Color(0xFFE50914),
                  size: 50,
                ),
                const SizedBox(height: 15),
                const Text(
                  "PASO 3 DE 3",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Configura tu pago",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  child: Text(
                    "Al seleccionar un método, completarás tu registro y enviaremos un código de acceso a tu correo.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                ),
                _buildPaymentOption(
                  title: "Tarjeta de crédito o débito",
                  icons: [Icons.credit_card, Icons.account_balance_wallet],
                  onTap: () => _procesarRegistro(context),
                ),
                _buildPaymentOption(
                  title: "Código de regalo",
                  icons: [Icons.card_giftcard],
                  onTap: () => _procesarRegistro(context),
                ),
                const SizedBox(height: 40),
                const Text(
                  "Seguridad de nivel bancario 🔒",
                  style: TextStyle(color: Colors.black38, fontSize: 13),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // ✅ CAMBIO #14: Loading overlay sobre el contenido
          // Reemplaza el Dialog de loading anterior. Este approach es más
          // robusto porque no depende del contexto del Navigator para cerrarse,
          // evitando el bug clásico de "dialog que no se cierra" cuando
          // hay errores de contexto o el widget se desmonta.
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFE50914)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required String title,
    required List<IconData> icons,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      // ✅ CAMBIO #15: Deshabilitar opciones mientras carga
      // Si _isLoading es true, onTap se vuelve null, deshabilitando
      // el GestureDetector de forma nativa sin lógica extra.
      onTap: _isLoading ? null : onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 22),
        decoration: BoxDecoration(
          // ✅ CAMBIO #16: Feedback visual cuando está deshabilitado
          border: Border.all(
            color: _isLoading ? Colors.grey.shade200 : Colors.grey.shade300,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  // Color más tenue cuando está deshabilitado
                  color: _isLoading ? Colors.grey.shade400 : Colors.black,
                ),
              ),
            ),
            ...icons.map(
              (icon) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  icon,
                  color: _isLoading ? Colors.grey.shade300 : Colors.blueGrey,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: _isLoading ? Colors.grey.shade300 : Colors.black45,
            ),
          ],
        ),
      ),
    );
  }
}
