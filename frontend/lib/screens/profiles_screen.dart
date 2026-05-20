import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'manage_profiles_screen.dart';

const Color _profileBackground = Color(0xFF07110F);
const Color _profileSurface = Color(0xFF101817);
const Color _profileAccent = Color(0xFF00D46A);
const Color _profileCyan = Color(0xFF22D3EE);

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
      backgroundColor: _profileBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "MOVIEWIND",
          style: GoogleFonts.montserrat(
            color: _profileAccent,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "¿Quién está viendo ahora?",
                textAlign: TextAlign.center,
                style: GoogleFonts.geologica(
                  color: Colors.white.withValues(alpha: 0.94),
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

                  if (result != null && result is Map) {
                    setState(() {
                      userData['name'] = result['name'];
                      userData['userName'] = result['name'];
                      userData['profilePic'] = result['image'];
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _profileSurface,
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: _profileAccent.withValues(alpha: 0.38),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text(
                  "Administrar perfiles",
                  style: GoogleFonts.geologica(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 60),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _profileSurface,
                  border: Border.all(
                    color: _profileCyan.withValues(alpha: 0.34),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "PLAN ${plan.toUpperCase()}",
                  style: GoogleFonts.geologica(
                    color: _profileCyan,
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

class ProfileItem extends StatefulWidget {
  final Map<String, String> profile;
  final VoidCallback onTap;

  const ProfileItem({super.key, required this.profile, required this.onTap});

  @override
  State<ProfileItem> createState() => _ProfileItemState();
}

class _ProfileItemState extends State<ProfileItem> {
  bool _isHovered = false;
  bool _isPressed = false;

  Future<void> _handleTap() async {
    setState(() => _isPressed = true);
    await Future<void>.delayed(const Duration(milliseconds: 160));
    if (!mounted) return;
    widget.onTap();
  }

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

    final isActive = _isHovered || _isPressed;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapCancel: () => setState(() => _isPressed = false),
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTap: _handleTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: _profileSurface,
                border: Border.all(
                  color: isActive ? Colors.white : Colors.transparent,
                  width: 3,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.32),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ]
                    : const [],
                image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
              ),
              transform: isActive
                  ? Matrix4.diagonal3Values(1.08, 1.08, 1)
                  : Matrix4.identity(),
              transformAlignment: Alignment.center,
            ),
            const SizedBox(height: 12),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.geologica(
                color: isActive ? Colors.white : Colors.grey.shade400,
                fontSize: 14,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
              child: Text(widget.profile['name']!),
            ),
          ],
        ),
      ),
    );
  }
}
