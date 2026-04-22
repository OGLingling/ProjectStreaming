import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'manage_profiles_screen.dart';

class ProfilesScreen extends StatefulWidget {
  final Map<String, dynamic>? user;

  const ProfilesScreen({super.key, this.user});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  Map<String, dynamic>? _localUserData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_localUserData == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _localUserData = Map<String, dynamic>.from(args);
      } else if (widget.user != null) {
        _localUserData = Map<String, dynamic>.from(widget.user!);
      } else {
        _localUserData = {};
      }
    }
  }

  // Navegación directa al main
  void _navigateToMovies(
    BuildContext context,
    Map<String, String> profile,
    Map<String, dynamic> userData,
  ) {
    final selectedUserData = {
      ...userData,
      'selectedName': profile['name'],
      'selectedImage': profile['image'],
    };
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/main',
      (route) => false,
      arguments: selectedUserData,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> userData = _localUserData ?? {};

    final String plan = (userData['plan'] ?? 'basico').toString().toLowerCase();

    final String realName =
        (userData['name'] ??
                userData['userName'] ??
                (userData['email']?.toString().split('@')[0] ?? "Usuario"))
            .toString();

    final String realProfilePic = _normalizeImagePath(userData['profilePic']);

    int maxProfiles;
    switch (plan) {
      case 'premium':
        maxProfiles = 4;
        break;
      case 'estandar':
        maxProfiles = 2;
        break;
      default:
        maxProfiles = 1;
    }

    final List<Map<String, String>> dynamicProfiles = [
      {"name": realName.toUpperCase(), "image": realProfilePic},
      {"name": "USUARIO 2", "image": "assets/avatars/usuario6.webp"},
      {"name": "USUARIO 3", "image": "assets/avatars/usuario2.jpg"},
      {"name": "USUARIO 4", "image": "assets/avatars/usuario3.jpg"},
    ];

    final visibleProfiles = dynamicProfiles.take(maxProfiles).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "MOVIEWIND",
          style: GoogleFonts.montserrat(
            color: const Color(0xFFE50914),
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "¿Quién está viendo ahora?",
                style: GoogleFonts.geologica(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 40),
              Wrap(
                spacing: 25,
                runSpacing: 25,
                alignment: WrapAlignment.center,
                children: visibleProfiles.map((profile) {
                  return ProfileItem(
                    profile: profile,
                    onTap: () => _navigateToMovies(context, profile, userData),
                  );
                }).toList(),
              ),
              const SizedBox(height: 50),
              ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ManageProfilesScreen(profileData: visibleProfiles[0]),
                    ),
                  );

                  // Si recibimos datos actualizados de ManageProfilesScreen, recargamos UI global
                  if (result != null && result is Map) {
                    setState(() {
                      userData['name'] = result['name'];
                      userData['userName'] = result['name'];
                      userData['profilePic'] = result['image'];
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  side: const BorderSide(color: Colors.white24),
                ),
                child: const Text(
                  "Administrar perfiles",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 60),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "PLAN ${plan.toUpperCase()}",
                  style: GoogleFonts.geologica(
                    color: Colors.grey,
                    fontSize: 12,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _normalizeImagePath(dynamic value) {
    final path = value?.toString().trim();
    if (path == null || path.isEmpty || path.toLowerCase() == 'null') {
      return "assets/avatars/usuario5.webp";
    }
    return path;
  }
}

// --- COMPONENTE CON EFECTO HOVER ---
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
    String imagePath = (widget.profile['image'] ?? "").trim();
    if (imagePath.isEmpty || imagePath.toLowerCase() == 'null') {
      imagePath = "assets/avatars/usuario5.webp";
    }

    ImageProvider imageProvider;
    if (imagePath.startsWith('http')) {
      imageProvider = NetworkImage(imagePath);
    } else {
      imageProvider = imagePath.startsWith('assets/')
          ? AssetImage(imagePath)
          : const AssetImage("assets/avatars/usuario5.webp");
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.grey[900],
                // Borde blanco en hover
                border: Border.all(
                  color: _isHovered ? Colors.white : Colors.transparent,
                  width: 3,
                ),
                image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
              ),
              // Efecto de agrandado suave (Scale)
              transform: _isHovered
                  ? (Matrix4.identity()..scale(1.08))
                  : Matrix4.identity(),
              transformAlignment: Alignment.center,
            ),
            const SizedBox(height: 12),
            // Cambio de color del texto en hover
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.geologica(
                color: _isHovered ? Colors.white : Colors.grey.shade400,
                fontSize: 14,
                fontWeight: _isHovered ? FontWeight.bold : FontWeight.normal,
              ),
              child: Text(widget.profile['name']!),
            ),
          ],
        ),
      ),
    );
  }
}
