import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfilesSettingsScreen extends StatelessWidget {
  final List<Map<String, String>> profiles; // Recibe la lista filtrada por plan
  final String
  userPlan; // Recibe el nombre del plan (Básico, Estándar, Premium)

  const ProfilesSettingsScreen({
    super.key,
    required this.profiles,
    required this.userPlan,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading:
            false, // Quitamos la flecha para usar la del sidebar
        title: Text(
          "MOVIEWIND",
          style: GoogleFonts.bebasNeue(
            color: const Color(0xFFE50914),
            fontSize: 30,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: CircleAvatar(
              radius: 18,
              backgroundImage: AssetImage(profiles[0]['image']!),
              backgroundColor: Colors.grey.shade200,
            ),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. SIDEBAR IZQUIERDO
          _buildSidebar(context),

          // 2. CONTENIDO PRINCIPAL
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Perfiles",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "Controles parentales y permisos • Plan ${userPlan.toUpperCase()}",
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 25),

                    // SECCIÓN DE CONTROLES
                    _buildSectionBox([
                      _buildActionTile(
                        Icons.security_outlined,
                        "Ajustar controles parentales",
                        "Configura la clasificación por edad y bloquea títulos",
                      ),
                      const Divider(height: 1),
                      _buildActionTile(
                        Icons.account_circle_outlined,
                        "Transferir un perfil",
                        "Copia un perfil a otra cuenta",
                      ),
                    ]),

                    const SizedBox(height: 35),
                    const Text(
                      "Configuración de perfil",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // LISTA DINÁMICA DE PERFILES SEGÚN EL PLAN
                    _buildSectionBox(
                      profiles.asMap().entries.map((entry) {
                        int index = entry.key;
                        var profile = entry.value;
                        return Column(
                          children: [
                            _buildProfileTile(
                              profile['name']!,
                              profile['image']!,
                              isFirst: index == 0,
                            ),
                            if (index != profiles.length - 1)
                              const Divider(height: 1),
                          ],
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 40),
                    Center(
                      child: Text(
                        "¿Preguntas? Contáctanos",
                        style: TextStyle(
                          color: Colors.grey[600],
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS DE SOPORTE ---

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
            label: const Text(
              "Regresar",
              style: TextStyle(color: Colors.black, fontSize: 16),
            ),
          ),
          const SizedBox(height: 30),
          _sidebarItem(Icons.home_outlined, "Descripción general"),
          _sidebarItem(Icons.card_membership, "Membresía"),
          _sidebarItem(Icons.verified_user_outlined, "Seguridad"),
          _sidebarItem(Icons.devices, "Dispositivos"),
          _sidebarItem(Icons.people, "Perfiles", isSelected: true),
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String label, {bool isSelected = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.black : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionBox(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8), // Gris muy claro como el de la imagen
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildActionTile(IconData icon, String title, String subtitle) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      leading: Icon(icon, color: Colors.black, size: 28),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600])),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.black,
      ),
      onTap: () {},
    );
  }

  Widget _buildProfileTile(
    String name,
    String imagePath, {
    bool isFirst = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      leading: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          image: DecorationImage(
            image: AssetImage(imagePath),
            fit: BoxFit.cover,
          ),
        ),
      ),
      title: Text(
        name.toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black,
          fontSize: 18,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFirst)
            const Text(
              "Tu perfil  ",
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500),
            ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black),
        ],
      ),
      onTap: () {},
    );
  }
}
