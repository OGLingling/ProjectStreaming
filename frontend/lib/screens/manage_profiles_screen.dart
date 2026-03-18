import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'edit_profile.dart';

class ManageProfilesScreen extends StatelessWidget {
  final Map<String, dynamic> profileData;

  const ManageProfilesScreen({super.key, required this.profileData});

  @override
  Widget build(BuildContext context) {
    // Lógica dinámica: detecta quién es el usuario actual
    final String currentName =
        (profileData['selectedName'] ?? profileData['name'] ?? "Usuario")
            .toString();

    final String currentImg =
        (profileData['selectedImage'] ??
                profileData['profilePic'] ??
                "assets/avatars/usuario5.webp")
            .toString();

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

                // SECCIÓN 1: Info de Perfil (DINÁMICO)
                _buildWhiteCard([
                  _buildListTile(
                    leading: _buildProfileImage(currentImg),
                    title: currentName.toUpperCase(),
                    subtitle: "Editar información personal y de contacto",
                    onTap: () {
                      // Navega a la pantalla de edición (la del lápiz)
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProfileScreen(
                            name: currentName,
                            image: currentImg,
                          ),
                        ),
                      );
                    },
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
                    onTap: () {},
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
                    onTap: () {},
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
                    onTap: () {},
                  ),
                  const Divider(color: Colors.black12, height: 1),
                  _buildListTile(
                    leading: const Icon(
                      Icons.subtitles_outlined,
                      color: Colors.black,
                    ),
                    title: "Aspecto de los subtítulos",
                    subtitle: "Personaliza el aspecto de los subtítulos",
                    onTap: () {},
                  ),
                ]),

                const SizedBox(height: 20),

                // SECCIÓN 3: Reproducción e Historial
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
                  const Divider(color: Colors.black12, height: 1),
                  _buildListTile(
                    leading: const Icon(Icons.security, color: Colors.black),
                    title: "Configuración de datos y privacidad",
                    subtitle: "Administra el uso de tu información personal",
                    onTap: () {},
                  ),
                ]),

                const SizedBox(height: 20),

                // SECCIÓN 4: Transferencia
                _buildWhiteCard([
                  _buildListTile(
                    leading: const Icon(Icons.swap_horiz, color: Colors.black),
                    title: "Transferencia de perfiles",
                    subtitle: "Copia este perfil a otra cuenta",
                    onTap: () {},
                  ),
                ]),

                const SizedBox(height: 40),

                // BOTÓN ELIMINAR PERFIL
                Center(
                  child: Column(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          // Lógica para eliminar perfil
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.grey,
                        ),
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
                      const SizedBox(height: 10),
                      const Text(
                        "El perfil principal no se puede eliminar.",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
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

  // --- WIDGETS DE APOYO ---

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 5),
      child: Text(
        title,
        style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 18),
      ),
    );
  }

  Widget _buildWhiteCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildListTile({
    required Widget leading,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
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
  }

  Widget _buildProfileImage(String path) {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: Colors.grey[300],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: path.startsWith('http')
            ? Image.network(
                path,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const Icon(Icons.person),
              )
            : Image.asset(
                path,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) =>
                    const Icon(Icons.person, color: Colors.black54),
              ),
      ),
    );
  }
}
