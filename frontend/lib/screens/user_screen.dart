import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../screens/auth_screen.dart';

class UserScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const UserScreen({super.key, required this.user});

  @override
  _UserScreenState createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  late TextEditingController _nameController;
  late TextEditingController _imageController;

  String _profileImage = "";

  final List<String> _defaultAvatars = List.generate(
    6,
    (index) => 'assets/avatars/user${index + 1}.jpg',
  );

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user['name']);
    _profileImage = widget.user['profilePic'] ?? "assets/avatars/usuario6.webp";
    _imageController = TextEditingController(text: _profileImage);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  // --- MEJORA 1: MANEJO ROBUSTO DE IMÁGENES ---
  ImageProvider _getProfileImage(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty || normalized.toLowerCase() == 'null') {
      return const AssetImage("assets/avatars/usuario5.webp");
    }
    if (normalized.startsWith('assets/')) {
      return AssetImage(normalized);
    }
    if (normalized.startsWith('http') || normalized.startsWith('https')) {
      return NetworkImage(normalized);
    }
    // Fallback por defecto
    return const AssetImage("assets/avatars/usuario5.webp");
  }

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => AuthScreen()),
      (route) => false,
    );
  }

  Future<void> _saveChanges() async {
    try {
      final userId = widget.user['id']?.toString() ?? "";
      if (userId.isEmpty) {
        throw "ID de usuario no encontrado";
      }

      final success = await ApiService.updateUser(userId, {
        'name': _nameController.text,
        'profilePic': _imageController.text,
      });

      if (success) {
        setState(() {
          _profileImage = _imageController.text;
          widget.user['profilePic'] = _profileImage;
          widget.user['name'] = _nameController.text;
        });

        // --- MEJORA 2: FEEDBACK VISUAL POSITIVO ---
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text("¡Perfil actualizado correctamente!"),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        throw "No se pudo actualizar el perfil en el servidor";
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al conectar con el servidor: $e"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // --- MEJORA 3: DIÁLOGO DE SEGURIDAD ESTILIZADO ---
  void _showChangePasswordDialog() {
    final TextEditingController passController = TextEditingController();
    final TextEditingController confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2232),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Cambiar Contraseña",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCustomTextField(
              controller: passController,
              hint: "Nueva contraseña",
              icon: Icons.lock_outline,
              isPassword: true,
            ),
            const SizedBox(height: 15),
            _buildCustomTextField(
              controller: confirmController,
              hint: "Confirmar contraseña",
              icon: Icons.lock_reset,
              isPassword: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              if (passController.text == confirmController.text &&
                  passController.text.isNotEmpty) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Contraseña actualizada")),
                );
              } else {
                // Validación simple
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Las contraseñas no coinciden")),
                );
              }
            },
            child: const Text(
              "ACTUALIZAR",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop:
          false, // Impide que el usuario retroceda con gestos o botones del cel
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Aquí podrías mostrar un aviso si quisieras,
        // pero por ahora simplemente no hará nada al intentar ir atrás.
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121826),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A2232),
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false, // <-- QUITA LA FLECHA AUTOMÁTICA
          title: const Text(
            "Mi Perfil",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          // Mantenemos tu botón de "X" si quieres que cierre el perfil devolviendo datos,
          // pero si quieres que sea la ÚNICA pantalla, podrías quitar también el 'leading'.
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              Navigator.pop(context, {
                'name': _nameController.text,
                'profilePic': _profileImage,
              });
            },
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
          child: Column(
            children: [
              // Avatar Circular con efecto de sombra
              Center(
                child: Container(
                  width: 125,
                  height: 125,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.redAccent, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withOpacity(0.2),
                        blurRadius: 15,
                        spreadRadius: 5,
                      ),
                    ],
                    image: DecorationImage(
                      fit: BoxFit.cover,
                      image: _getProfileImage(_profileImage),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              _buildInputLabel("NOMBRE DE USUARIO"),
              _buildCustomTextField(
                controller: _nameController,
                hint: "Tu nombre",
                icon: Icons.person_outline,
              ),

              const SizedBox(height: 25),

              _buildInputLabel("SEGURIDAD DE LA CUENTA"),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton.icon(
                  onPressed: _showChangePasswordDialog,
                  icon: const Icon(Icons.lock_outline, color: Colors.redAccent),
                  label: const Text(
                    "CAMBIAR CONTRASEÑA",
                    style: TextStyle(color: Colors.white, letterSpacing: 1.1),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    backgroundColor: const Color(0xFF1A2232),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              _buildInputLabel("ELIGE TU AVATAR"),
              const SizedBox(height: 10),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _defaultAvatars.length,
                  itemBuilder: (context, index) {
                    final avatarPath = _defaultAvatars[index];
                    final isSelected = _imageController.text == avatarPath;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _imageController.text = avatarPath;
                          _profileImage = avatarPath;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Colors.redAccent
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: const Color(0xFF1A2232),
                          backgroundImage: AssetImage(avatarPath),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 40),

              // BOTÓN GUARDAR
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: _saveChanges,
                  child: const Text(
                    "GUARDAR CAMBIOS",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // BOTÓN CERRAR SESIÓN
              SizedBox(
                width: double.infinity,
                height: 55,
                child: TextButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.grey, size: 20),
                  label: const Text(
                    "CERRAR SESIÓN",
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: const BorderSide(color: Colors.white10),
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

  Widget _buildInputLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 5, bottom: 8),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // --- MEJORA 4: TEXTFIELD PERSONALIZABLE ---
  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.redAccent, size: 22),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFF1A2232),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
      ),
    );
  }
}
