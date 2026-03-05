import 'package:flutter/material.dart';
import 'movies_screen.dart'; // Importación única y limpia

class ProfilesScreen extends StatelessWidget {
  final Map<String, dynamic> user;

  const ProfilesScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    // Datos exactos de tu imagen
    final List<Map<String, String>> profiles = [
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "¿Quién está viendo ahora?",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 40),
              Wrap(
                spacing: 20,
                runSpacing: 30,
                alignment: WrapAlignment.center,
                children: profiles.map((profile) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MoviesScreen(user: user),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 120, // Un poco más grandes para que luzcan
                          height: 120,
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
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 80),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.grey, width: 0.5),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                child: const Text(
                  "ADMINISTRAR PERFILES",
                  style: TextStyle(color: Colors.grey, letterSpacing: 2.0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
