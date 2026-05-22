import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../services/api_service.dart';
import 'profiles_screen.dart';

const Color _paymentBackground = Color(0xFF07110F);
const Color _paymentSurface = Color(0xFF101817);
const Color _paymentSurfaceHigh = Color(0xFF17211F);
const Color _paymentPrimary = Color(0xFF00C853);
const Color _paymentSecondary = Color(0xFF00D8FF);

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
  bool _isLoading = false;

  Future<void> _procesarRegistro() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    firebase_auth.UserCredential? userCredential;

    try {
      userCredential = await firebase_auth.FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: widget.userEmail.trim(),
            password: widget.password.trim(),
          );

      final String firebaseUid = userCredential.user!.uid;

      final userData = await ApiService.registerUser(
        email: widget.userEmail.trim(),
        name: widget.userName.trim(),
        plan: widget.selectedPlan,
        password: widget.password.trim(),
      );

      if (userData == null) {
        throw Exception('API_ERROR');
      }

      final String dbUserId = userData['id']?.toString() ?? firebaseUid;

      await ApiService.sendOTP(widget.userEmail.trim());

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', dbUserId);
      await prefs.setString('firebase_uid', firebaseUid);
      await prefs.setBool('is_logged_in', true);

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
      if (userCredential != null) {
        await userCredential.user?.delete();
      }

      String errorMsg = 'Error al registrar: ${e.code}';

      if (e.code == 'email-already-in-use') {
        errorMsg = 'El correo ya esta registrado.';
      } else if (e.code == 'weak-password') {
        errorMsg = 'La contrasena es demasiado debil.';
      } else if (e.code == 'invalid-email') {
        errorMsg = 'El formato del correo no es valido.';
      }

      if (mounted) _showError(errorMsg);
    } catch (e) {
      if (userCredential != null) {
        await userCredential.user?.delete();
      }

      debugPrint('Error tecnico: $e');

      if (mounted) {
        final String mensaje = e.toString().contains('API_ERROR')
            ? 'No se pudo conectar con el servidor. Intenta de nuevo.'
            : 'Hubo un error al crear tu cuenta. Intenta de nuevo.';
        _showError(mensaje);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showPaypalPendingMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PayPal requiere endpoints backend antes de activarlo.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final planLabel = widget.selectedPlan.toUpperCase();
    final planPrice = _planPrice(widget.selectedPlan);

    return Scaffold(
      backgroundColor: _paymentBackground,
      appBar: AppBar(
        backgroundColor: _paymentBackground,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: !_isLoading,
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                const _StepPill(label: 'Paso 3 de 3'),
                const SizedBox(height: 16),
                Text(
                  'Configura tu metodo de pago',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Tu cuenta se activara cuando el metodo seleccionado confirme el acceso.',
                  style: GoogleFonts.geologica(
                    color: Colors.white.withValues(alpha: 0.64),
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 22),
                _PlanSummaryCard(planLabel: planLabel, price: planPrice),
                const SizedBox(height: 22),
                _SectionTitle('Metodos disponibles'),
                _PaymentOptionCard(
                  title: 'Tarjeta de credito o debito',
                  subtitle: 'Activa el registro con el flujo actual',
                  icons: const [
                    Icons.credit_card_rounded,
                    Icons.account_balance_wallet_rounded,
                  ],
                  accent: _paymentPrimary,
                  isLoading: _isLoading,
                  onTap: _procesarRegistro,
                ),
                const SizedBox(height: 12),
                _PaymentOptionCard(
                  title: 'PayPal',
                  subtitle:
                      'Requiere backend seguro para crear y capturar pagos',
                  icons: const [Icons.payments_rounded],
                  accent: _paymentSecondary,
                  isLoading: _isLoading,
                  onTap: _showPaypalPendingMessage,
                ),
                const SizedBox(height: 12),
                _PaymentOptionCard(
                  title: 'Codigo de regalo',
                  subtitle: 'Canje interno de MovieWind',
                  icons: const [Icons.card_giftcard_rounded],
                  accent: const Color(0xFFFFC857),
                  isLoading: _isLoading,
                  onTap: _procesarRegistro,
                ),
                const SizedBox(height: 22),
                const _SecurityNote(),
              ],
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withValues(alpha: 0.58),
                child: const Center(
                  child: CircularProgressIndicator(color: _paymentSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _planPrice(String plan) {
    switch (plan.toLowerCase()) {
      case 'premium':
        return 'S/ 44.90';
      case 'estandar':
        return 'S/ 34.90';
      default:
        return 'S/ 24.90';
    }
  }
}

class _StepPill extends StatelessWidget {
  final String label;

  const _StepPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _paymentPrimary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _paymentPrimary.withValues(alpha: 0.35)),
        ),
        child: Text(
          label,
          style: GoogleFonts.geologica(
            color: _paymentPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _PlanSummaryCard extends StatelessWidget {
  final String planLabel;
  final String price;

  const _PlanSummaryCard({required this.planLabel, required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _paymentSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _paymentPrimary.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _paymentPrimary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: _paymentPrimary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan $planLabel',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$price al mes',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.64)),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.montserrat(
          color: Colors.white.withValues(alpha: 0.72),
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PaymentOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<IconData> icons;
  final Color accent;
  final bool isLoading;
  final VoidCallback onTap;

  const _PaymentOptionCard({
    required this.title,
    required this.subtitle,
    required this.icons,
    required this.accent,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _paymentSurface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icons.first, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isLoading
                            ? Colors.white.withValues(alpha: 0.38)
                            : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.54),
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.42),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _paymentSurfaceHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            color: _paymentSecondary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Nunca guardes secretos de pasarela en Flutter. Las llaves privadas de pago deben vivir solo en backend y en Render.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.64),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
