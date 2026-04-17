import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'edit_profile.dart';

// Imports de la carpeta settings
import 'settings/configuracion_lenguaje.dart';
import 'settings/control_parental.dart';
import 'settings/configuracion_subtitulos.dart';

class ManageProfilesScreen extends StatefulWidget {
  final Map<String, dynamic> profileData;

  const ManageProfilesScreen({super.key, required this.profileData});

  @override
  State<ManageProfilesScreen> createState() => _ManageProfilesScreenState();
}

class _ManageProfilesScreenState extends State<ManageProfilesScreen> {
  late String currentName;
  late String currentImg;

  @override
  void initState() {
    super.initState();
    currentName = _normalizeText(
      widget.profileData['selectedName'] ?? widget.profileData['name'],
    );
    currentImg = _normalizeImagePath(
      widget.profileData['selectedImage'] ?? widget.profileData['profilePic'],
    );
  }

  Future<void> _openEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          name: currentName,
          image: currentImg,
          userId: widget.profileData['userId'],
        ),
      ),
    );

    if (!mounted) return;
    if (result is Map) {
      final nextName = _normalizeText(result['name']);
      final nextImg = _normalizeImagePath(result['image']);
      setState(() {
        currentName = nextName;
        currentImg = nextImg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Administrar perfil y preferencias",
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),

                _buildWhiteCard([
                  _buildListTile(
                    leading: _buildProfileImage(currentImg),
                    title: currentName.toUpperCase(),
                    subtitle: "Editar información personal y de contacto",
                    onTap: _openEditProfile,
                  ),
                  const Divider(color: Colors.black12, height: 1),
                  _buildListTile(
                    leading: const Icon(
                      Icons.lock_outline,
                      color: Colors.black,
                      size: 28,
                    ),
                    title: "Bloqueo de perfil",
                    subtitle: "Solicita un PIN para acceder a este perfil",
                    onTap: () => _navigateTo(
                      context,
                      const Scaffold(
                        body: Center(child: Text("Pantalla de PIN")),
                      ),
                    ),
                  ),
                ]),

                const SizedBox(height: 30),
                _sectionTitle("Preferencias"),

                // SECCIÓN 2: Idiomas y Controles
                _buildWhiteCard([
                  _buildListTile(
                    leading: const Icon(Icons.translate, color: Colors.black),
                    title: "Idiomas",
                    subtitle: "Configura los idiomas de visualización y audio",
                    onTap: () => _openLanguageSettings(context),
                  ),
                  const Divider(color: Colors.black12, height: 1),
                  _buildListTile(
                    leading: const Icon(
                      Icons.error_outline,
                      color: Colors.black,
                    ),
                    title: "Ajustar controles parentales",
                    subtitle:
                        "Edita las clasificaciones por edad y restricciones",
                    onTap: () => _openParentalControls(context),
                  ),
                  const Divider(color: Colors.black12, height: 1),
                  _buildListTile(
                    leading: const Icon(
                      Icons.subtitles_outlined,
                      color: Colors.black,
                    ),
                    title: "Aspecto de los subtítulos",
                    subtitle: "Personaliza el aspecto de los subtítulos",
                    onTap: () => _openSubtitleSettings(context),
                  ),
                ]),

                const SizedBox(height: 20),
                _buildWhiteCard([
                  _buildListTile(
                    leading: const Icon(
                      Icons.play_circle_outline,
                      color: Colors.black,
                    ),
                    title: "Configuración de reproducción",
                    subtitle: "Configura reproducción automática y calidad",
                    onTap: () {},
                  ),
                  const Divider(color: Colors.black12, height: 1),
                  _buildListTile(
                    leading: const Icon(
                      Icons.notifications_none,
                      color: Colors.black,
                    ),
                    title: "Configuración de notificaciones",
                    subtitle: "Administra alertas por email y SMS",
                    onTap: () {},
                  ),
                  const Divider(color: Colors.black12, height: 1),
                  _buildListTile(
                    leading: const Icon(Icons.history, color: Colors.black),
                    title: "Actividad de visualización",
                    subtitle: "Administra el historial y las calificaciones",
                    onTap: () {},
                  ),
                ]),

                const SizedBox(height: 40),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmDeleteProfile(context),
                    icon: const Icon(Icons.delete_outline, color: Colors.grey),
                    label: const Text(
                      "Eliminar perfil",
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.grey),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- MÉTODOS DE APOYO (Normalización y Navegación) ---

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  void _openLanguageSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ConfiguracionLenguajeScreen(),
      ),
    );
  }

  void _openParentalControls(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ControlParentalScreen()),
    );
  }

  void _openSubtitleSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ConfiguracionSubtitulosScreen(),
      ),
    );
  }

  void _confirmDeleteProfile(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Eliminar perfil?"),
        content: const Text("Esta acción no se puede deshacer."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCELAR"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ELIMINAR", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10, left: 5),
    child: Text(
      title,
      style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 18),
    ),
  );
  Widget _buildWhiteCard(List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(children: children),
  );

  Widget _buildListTile({
    required Widget leading,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    leading: leading,
    title: Text(
      title,
      style: const TextStyle(
        color: Colors.black,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    ),
    subtitle: Text(
      subtitle,
      style: const TextStyle(color: Colors.black54, fontSize: 13),
    ),
    trailing: const Icon(
      Icons.arrow_forward_ios,
      color: Colors.black,
      size: 16,
    ),
    onTap: onTap,
  );

  Widget _buildProfileImage(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty || normalized.toLowerCase() == 'null') {
      return Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: Colors.grey[300],
        ),
        child: const Icon(Icons.person, color: Colors.black54),
      );
    }

    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: Colors.grey[300],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: normalized.startsWith('http')
            ? Image.network(
                normalized,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const Icon(Icons.person),
              )
            : (normalized.startsWith('assets/')
                  ? Image.asset(
                      normalized,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const Icon(Icons.person),
                    )
                  : const Icon(Icons.person)),
      ),
    );
  }

  String _normalizeText(dynamic value) {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty || text.toLowerCase() == 'null')
        ? "Usuario"
        : text;
  }

  String _normalizeImagePath(dynamic value) {
    final path = value?.toString().trim();
    return (path == null || path.isEmpty || path.toLowerCase() == 'null')
        ? "assets/avatars/usuario5.webp"
        : path;
  }
}
