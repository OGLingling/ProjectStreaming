import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'profiles_settings_screen.dart'; // Importa la nueva pantalla que creaste

class AccountScreen extends StatelessWidget {
  // Añadimos userData para recibir la información del usuario y su plan
  final Map<String, dynamic>? userData;

  const AccountScreen({super.key, this.userData});

  @override
  Widget build(BuildContext context) {
    // 1. Lógica dinámica: Determinamos el plan y cuántos perfiles mostrar
    final String plan = (userData?['plan'] ?? 'basico')
        .toString()
        .toLowerCase();
    int maxProfiles = plan == 'premium' ? 4 : (plan == 'estandar' ? 2 : 1);

    // Creamos la lista de perfiles que se mostrará en la vista previa y se pasará a la siguiente pantalla
    final List<Map<String, String>> allProfiles = [
      {
        "name": userData?['name']?.toString().toUpperCase() ?? "USUARIO 1",
        "image": userData?['profilePic'] ?? "assets/avatars/usuario1.webp",
      },
      {"name": "USUARIO 2", "image": "assets/avatars/usuario2.webp"},
      {"name": "USUARIO 3", "image": "assets/avatars/usuario3.webp"},
      {"name": "USUARIO 4", "image": "assets/avatars/usuario4.webp"},
    ];

    // Esta es la lista real según el plan
    final visibleProfiles = allProfiles.take(maxProfiles).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          "MOVIEWIND",
          style: GoogleFonts.bebasNeue(color: Colors.red, fontSize: 30),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: CircleAvatar(
              radius: 18,
              backgroundImage: AssetImage(visibleProfiles[0]['image']!),
              backgroundColor: Colors.grey.shade200,
            ),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSidebar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Cuenta",
                      style: GoogleFonts.montserrat(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _sectionTitle("Información de la membresía"),

                    // TARJETA DE PLAN DINÁMICA
                    _buildMembershipCard(plan),

                    const SizedBox(height: 30),
                    _sectionTitle("Vínculos rápidos"),

                    _buildWhiteCard([
                      _buildActionTile(
                        "Cambiar de plan",
                        Icons.dashboard_customize_outlined,
                      ),
                      const Divider(height: 1),
                      _buildActionTile(
                        "Administrar forma de pago",
                        Icons.payment,
                      ),
                      const Divider(height: 1),
                      _buildActionTile(
                        "Administrar acceso y dispositivos",
                        Icons.devices,
                      ),
                      const Divider(height: 1),
                      _buildActionTile(
                        "Actualizar contraseña",
                        Icons.lock_outline,
                      ),
                      const Divider(height: 1),
                      _buildActionTile(
                        "Transferir un perfil",
                        Icons.switch_account_outlined,
                      ),
                    ]),

                    const SizedBox(height: 30),
                    _sectionTitle("Seguridad"),
                    _buildWhiteCard([
                      _buildActionTile(
                        "Ajustar controles parentales",
                        Icons.security,
                      ),
                      const Divider(height: 1),
                      _buildActionTile(
                        "Editar configuración",
                        Icons.settings_outlined,
                        subtitle: "Idiomas, subtítulos, notificaciones y más",
                      ),
                    ]),

                    const SizedBox(height: 30),
                    // SECCIÓN DE PERFILES DINÁMICA
                    _buildProfilesSection(context, visibleProfiles, plan),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS DE APOYO ACTUALIZADOS ---

  Widget _buildSidebar() {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sidebarItem(
            Icons.home_outlined,
            "Descripción general",
            isSelected: true,
          ),
          _sidebarItem(Icons.card_membership, "Membresía"),
          _sidebarItem(Icons.verified_user_outlined, "Seguridad"),
          _sidebarItem(Icons.devices, "Dispositivos"),
          _sidebarItem(Icons.people_outline, "Perfiles"),
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String label, {bool isSelected = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.black : Colors.grey[600],
            size: 24,
          ),
          const SizedBox(width: 15),
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.black : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      title,
      style: const TextStyle(color: Colors.grey, fontSize: 16),
    ),
  );

  Widget _buildMembershipCard(String planName) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.deepPurple,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: const Text(
              "Miembro desde marzo de 2026",
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Plan ${planName.toUpperCase()}",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  "Próximo pago: 25 de abril de 2026",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildActionTile("Administrar membresía", null),
        ],
      ),
    );
  }

  Widget _buildWhiteCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildActionTile(String title, IconData? icon, {String? subtitle}) {
    return ListTile(
      leading: icon != null ? Icon(icon, color: Colors.black) : null,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 12))
          : null,
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.black,
      ),
    );
  }

  Widget _buildProfilesSection(
    BuildContext context,
    List<Map<String, String>> profiles,
    String plan,
  ) {
    return InkWell(
      onTap: () {
        // NAVEGACIÓN DINÁMICA: Pasamos los datos correctos
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ProfilesSettingsScreen(profiles: profiles, userPlan: plan),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Administrar perfiles",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  "${profiles.length} perfiles",
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            Row(
              children: [
                ...profiles.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: CircleAvatar(
                      radius: 15,
                      backgroundImage: AssetImage(p['image']!),
                      backgroundColor: Colors.grey.shade200,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.black,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
