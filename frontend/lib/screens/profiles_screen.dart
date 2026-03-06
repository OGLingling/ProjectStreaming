import 'package:flutter/material.dart';
import 'movies_screen.dart';

class ProfilesScreen extends StatelessWidget {
  final Map<String, dynamic> user;

  const ProfilesScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    // 1. Definimos la base de datos de perfiles disponibles
    final List<Map<String, String>> allProfiles = [
      {
        "name": "TOMAS AMAYO",
        "image":
            "https://i.pinimg.com/originals/fb/8e/8a/fb8e8a96f548d23efe74d969f730a20e.jpg",
      },
      {
        "name": "EIMI AMAYO",
        "image":
            "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcR_6uY6E6L1i_Y_vBv_kX0_Z1r_7Z9_X_X_XQ&s",
      },
      {
        "name": "ANTHONY AMAYO",
        "image":
            "https://mir-s3-cdn-cf.behance.net/project_modules/disp/84c20033850498.56ba69ac290ea.png",
      },
      {
        "name": "ESTHER PEREZ",
        "image":
            "https://mir-s3-cdn-cf.behance.net/project_modules/disp/64623633850498.56ba69ac306d5.png",
      },
      {
        "name": "SISSY AMAYO",
        "image":
            "https://mir-s3-cdn-cf.behance.net/project_modules/disp/bb3a8833850498.56ba69ac33fbf.png",
      },
    ];

    // 2. Lógica de restricción dinámica por plan
    // Se extrae el plan del mapa 'user'. Si no existe, se asume 'basico'.
    String plan = (user['plan'] ?? 'basico').toString().toLowerCase();
    int maxProfiles;

    switch (plan) {
      case 'premium':
        maxProfiles = 5;
        break;
      case 'estandar':
        maxProfiles = 3;
        break;
      case 'basico':
      default:
        maxProfiles = 1;
        break;
    }

    // Filtramos la lista: solo tomamos los perfiles permitidos por el plan
    final visibleProfiles = allProfiles.take(maxProfiles).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () {
              // Lógica para editar perfiles en el futuro
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "¿Quién está viendo ahora?",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              // Indicador visual del plan actual
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "PLAN ${plan.toUpperCase()}",
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Wrap(
                  spacing: 25,
                  runSpacing: 25,
                  alignment: WrapAlignment.center,
                  children: visibleProfiles.map((profile) {
                    return _buildProfileItem(context, profile);
                  }).toList(),
                ),
              ),
              const SizedBox(height: 60),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.grey, width: 0.5),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 25,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  "ADMINISTRAR PERFILES",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileItem(BuildContext context, Map<String, String> profile) {
    return GestureDetector(
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MoviesScreen(user: user)),
        );
      },
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              image: DecorationImage(
                image: NetworkImage(profile['image']!),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile['name']!,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
