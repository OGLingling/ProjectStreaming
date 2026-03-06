import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'movies_screen.dart';

class ProfilesScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const ProfilesScreen({super.key, required this.user});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  @override
  Widget build(BuildContext context) {
    // Lógica de restricción por plan
    String plan = (widget.user['plan'] ?? 'basico').toString().toLowerCase();
    int maxProfiles = plan == 'premium' ? 5 : (plan == 'estandar' ? 3 : 1);

    final List<Map<String, String>> allProfiles = [
      {
        "name": "TOMAS AMAYO",
        "image":
            "https://wallpapers.com/images/hd/netflix-profile-pictures-1000-x-1000-qo9h82134t9nv0j0.jpg",
      },
      {
        "name": "EIMI AMAYO",
        "image":
            "https://wallpapers.com/images/hd/netflix-profile-pictures-1000-x-1000-v98z09sh9u527l6y.jpg",
      },
      {
        "name": "ANTHONY AMAYO",
        "image":
            "https://wallpapers.com/images/hd/netflix-profile-pictures-1000-x-1000-dy7st87fb36y39bc.jpg",
      },
      {
        "name": "ESTHER PEREZ",
        "image":
            "https://wallpapers.com/images/hd/netflix-profile-pictures-1000-x-1000-2fg93wnp9y929nu9.jpg",
      },
      {
        "name": "SISSY AMAYO",
        "image":
            "https://wallpapers.com/images/hd/netflix-profile-pictures-512-x-512-880696767n5isdjt.jpg",
      },
    ];

    final visibleProfiles = allProfiles.take(maxProfiles).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF141414), // Negro Netflix
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {},
            child: Text(
              "Editar",
              style: GoogleFonts.geologica(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "¿Quién está viendo ahora?",
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              // Badge de Plan Estilizado
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  "PLAN ${plan.toUpperCase()}",
                  style: GoogleFonts.geologica(
                    color: Colors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 50),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Wrap(
                  spacing: 30,
                  runSpacing: 40,
                  alignment: WrapAlignment.center,
                  children: visibleProfiles.map((profile) {
                    return ProfileItem(
                      profile: profile,
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                MoviesScreen(user: widget.user),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 80),
              _buildAdminButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminButton() {
    return OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.grey, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      child: Text(
        "ADMINISTRAR PERFILES",
        style: GoogleFonts.geologica(
          color: Colors.grey,
          fontSize: 14,
          letterSpacing: 3,
        ),
      ),
    );
  }
}

// Widget Interno para manejar el efecto Hover de cada perfil
class ProfileItem extends StatefulWidget {
  final Map<String, String> profile;
  final VoidCallback onTap;

  const ProfileItem({super.key, required this.profile, required this.onTap});

  @override
  State<ProfileItem> createState() => _ProfileItemState();
}

class _ProfileItemState extends State<ProfileItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: _isHovered ? 125 : 115, // Aumenta de tamaño
              height: _isHovered ? 125 : 115,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _isHovered ? Colors.white : Colors.transparent,
                  width: 3,
                ),
                image: DecorationImage(
                  image: NetworkImage(widget.profile['image']!),
                  fit: BoxFit.cover,
                ),
                boxShadow: _isHovered
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ]
                    : [],
              ),
            ),
            const SizedBox(height: 15),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.geologica(
                color: _isHovered ? Colors.white : Colors.grey,
                fontSize: 16,
                fontWeight: _isHovered ? FontWeight.bold : FontWeight.w400,
              ),
              child: Text(widget.profile['name']!),
            ),
          ],
        ),
      ),
    );
  }
}
