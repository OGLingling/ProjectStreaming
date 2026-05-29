import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import 'profiles_screen.dart';

// Paleta de colores Premium de MovieWind
const Color _transferBackground = Color(0xFF07110F);
const Color _transferSurface = Color(0xFF101817);
const Color _transferSurfaceHigh = Color(0xFF17211F);
const Color _transferPrimary = Color(0xFF00C853);
const Color _transferTextSecondary = Color(0xFF8E9A97);
const Color _transferDanger = Color(0xFFFF5252);

class TransferProfileScreen extends StatefulWidget {
  final Map<String, dynamic> profileData;

  const TransferProfileScreen({super.key, required this.profileData});

  @override
  State<TransferProfileScreen> createState() => _TransferProfileScreenState();
}

class _TransferProfileScreenState extends State<TransferProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isSubmitting = false;

  String get _profileId =>
      widget.profileData['id']?.toString() ??
      widget.profileData['userId']?.toString() ??
      '';

  String get _currentUserId =>
      widget.profileData['userId']?.toString() ??
      widget.profileData['id']?.toString() ??
      '';

  String get _profileName =>
      widget.profileData['selectedName'] ??
      widget.profileData['name'] ??
      'Perfil';

  String get _profilePic =>
      widget.profileData['selectedImage'] ??
      widget.profileData['profilePic'] ??
      'assets/avatars/usuario5.webp';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _performTransfer() async {
    if (!_formKey.currentState!.validate()) return;
    if (_profileId.isEmpty) {
      _showSnack('Error: No se pudo identificar el ID del perfil.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final success = await ApiService.transferProfile(
        profileId: _profileId,
        targetEmail: _emailController.text.trim(),
        targetPassword: _passwordController.text.trim(),
        currentUserId: _currentUserId,
        profileName: _profileName,
        profilePic: _profilePic,
      );

      if (!mounted) return;

      if (success) {
        // SnackBar de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Perfil e historial transferidos correctamente!'),
            backgroundColor: _transferPrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Redirigir al selector de perfiles inicial (ProfilesScreen)
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => ProfilesScreen(
              user: {
                'id': _currentUserId,
                'email': widget.profileData['email'],
                'name': widget.profileData['name'],
                'profilePic': widget.profileData['profilePic'],
                'plan': widget.profileData['plan'],
              },
            ),
          ),
          (route) => false,
        );
      } else {
        _showSnack('Error en la transferencia. Verifica las credenciales de destino o el límite del plan.', isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Error de red al realizar la transferencia: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? _transferDanger : _transferSurfaceHigh,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _transferBackground,
      appBar: AppBar(
        backgroundColor: _transferBackground,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Transferir Perfil',
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado
                Text(
                  'Transfiere este perfil a otra cuenta',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),

                // Explicación
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _transferSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _transferPrimary.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline, color: _transferPrimary, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            '¿Qué se transferirá?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Al confirmar la transferencia, el perfil de "$_profileName", junto con su Historial de reproducción (WatchHistory) y lista de Favoritos (MyList) se asociarán a la nueva cuenta receptora. Esta acción es inmediata.',
                        style: TextStyle(
                          color: _transferTextSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Formulario de cuenta receptora
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CUENTA DE DESTINO (RECEPTORA)',
                        style: GoogleFonts.montserrat(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Input Email
                      TextFormField(
                        controller: _emailController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Correo electrónico receptor',
                          hintStyle: const TextStyle(color: _transferTextSecondary, fontSize: 13),
                          prefixIcon: const Icon(Icons.mail_outline, color: _transferPrimary),
                          filled: true,
                          fillColor: _transferSurfaceHigh,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white10),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _transferPrimary),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Por favor ingresa el correo de destino';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                            return 'Ingresa un correo electrónico válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Input Password
                      TextFormField(
                        controller: _passwordController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Contraseña de la cuenta destino',
                          hintStyle: const TextStyle(color: _transferTextSecondary, fontSize: 13),
                          prefixIcon: const Icon(Icons.lock_outline, color: _transferPrimary),
                          filled: true,
                          fillColor: _transferSurfaceHigh,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white10),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _transferPrimary),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Por favor ingresa la contraseña de destino';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),

                      // Botón Confirmar Transferencia
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _performTransfer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _transferPrimary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: _transferPrimary.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Confirmar Transferencia',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
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
        ),
      ),
    );
  }
}
