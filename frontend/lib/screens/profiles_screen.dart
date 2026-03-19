import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'manage_profiles_screen.dart';

class ProfilesScreen extends StatefulWidget {
  // Los datos del usuario pueden venir de los argumentos de la ruta o del constructor
  final Map<String, dynamic>? user;

  const ProfilesScreen({super.key, this.user});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  // FUNCIÓN ACTUALIZADA: Navegación directa sin pedir PIN
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
    // Intentamos obtener el usuario del constructor o de los argumentos de navegación
    final Map<String, dynamic> userData =
        widget.user ??
        (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
            {});

    final String plan = (userData['plan'] ?? 'basico').toString().toLowerCase();

    // Lógica de nombres y fotos de perfil
    final String realName =
        (userData['name'] ??
                userData['userName'] ??
                (userData['email']?.toString().split('@')[0] ?? "Usuario"))
            .toString();

    final String realProfilePic =
        (userData['profilePic'] ?? "assets/avatars/usuarioprueba.jpg")
            .toString();

    // Determinamos el número de perfiles según el plan
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

              // Los perfiles se generan dinámicamente según el plan
              Wrap(
                spacing: 25,
                runSpacing: 25,
                alignment: WrapAlignment.center,
                children: visibleProfiles.map((profile) {
                  return ProfileItem(
                    profile: profile,
                    // Llamamos a la navegación directa
                    onTap: () => _navigateToMovies(context, profile, userData),
                  );
                }).toList(),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ManageProfilesScreen(profileData: visibleProfiles[0]),
                    ),
                  );
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

              // Botón de Plan
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
}

class ProfileItem extends StatelessWidget {
  final Map<String, String> profile;
  final VoidCallback onTap;

  const ProfileItem({super.key, required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    String imagePath = profile['image'] ?? "";

    ImageProvider imageProvider;
    if (imagePath.startsWith('http')) {
      imageProvider = NetworkImage(imagePath);
    } else {
      // Si no empieza con http, asumimos que es un asset local
      imageProvider = AssetImage(imagePath);
    }
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.grey[900],
              image: DecorationImage(
                image: imageProvider,
                fit: BoxFit.cover,
                onError: (exception, stackTrace) {
                  debugPrint("Error cargando imagen: $imagePath");
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile['name']!,
            style: GoogleFonts.geologica(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
