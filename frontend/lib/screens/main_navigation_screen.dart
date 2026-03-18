import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Tus imports de pantallas
import 'movies_screen.dart';
import 'peliculas_screen.dart';
import 'series_screen.dart';
import 'games_screen.dart';
import 'novedades_screen.dart';
import 'manage_profiles_screen.dart';
import 'search_screen.dart';
import 'my_list_screen.dart';
import 'profiles_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const MainNavigationScreen({super.key, this.userData});

  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  late Map<String, dynamic> _currentProfile;

  final OverlayPortalController _tooltipController = OverlayPortalController();
  final _linkLayer = LayerLink();

  @override
  void initState() {
    super.initState();
    // Inicializamos con el perfil que vino por argumentos (normalmente el principal)
    _currentProfile = widget.userData ?? {};
  }

  void _switchProfile(Map<String, dynamic> newProfile) {
    _tooltipController.hide();
    setState(() {
      // Actualizamos el perfil activo manteniendo la base de userData (plan, id, etc)
      _currentProfile = {
        ...widget.userData!,
        'selectedName': newProfile['name'],
        'selectedImage': newProfile['image'],
      };
      _selectedIndex = 0; // Regresamos a la pestaña de Inicio al cambiar perfil
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. Lógica de visibilidad por Plan
    final String plan = (_currentProfile['plan'] ?? 'basico')
        .toString()
        .toLowerCase();
    int maxProfiles = plan == 'premium' ? 4 : (plan == 'estandar' ? 2 : 1);

    final List<Map<String, String>> allProfiles = [
      {
        "name":
            widget.userData?['name']?.toString().toUpperCase() ?? "USUARIO 1",
        "image":
            widget.userData?['profilePic'] ?? "assets/avatars/usuario5.webp",
      },
      {"name": "USUARIO 2", "image": "assets/avatars/usuario6.webp"},
      {"name": "USUARIO 3", "image": "assets/avatars/usuario2.jpg"},
      {"name": "USUARIO 4", "image": "assets/avatars/usuario3.jpg"},
    ];

    final visibleProfiles = allProfiles.take(maxProfiles).toList();

    // 2. Definición de pantallas principales (Navegación por pestañas)
    final List<Widget> screens = [
      MoviesScreen(user: _currentProfile), // 0: Inicio
      const SeriesScreen(), // 1: Series
      const PeliculasScreen(), // 2: Películas
      const GamesScreen(), // 3: Juegos
      const NovedadesScreen(), // 4: Novedades
      MyListScreen(favoriteMovies: []), // 5: Mi lista
      const SearchScreen(), // 6: Búsqueda
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.9),
        elevation: 0,
        title: Row(
          children: [
            // Logo
            Text(
              "MOVIEWIND",
              style: GoogleFonts.montserrat(
                color: const Color(0xFFE50914),
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            const SizedBox(width: 40),
            // Navbar Items
            _navItem("Inicio", 0),
            _navItem("Series", 1),
            _navItem("Películas", 2),
            _navItem("Juegos", 3),
            _navItem("Novedades populares", 4),
            _navItem("Mi lista", 5),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white, size: 26),
            onPressed: () => _onItemTapped(6),
          ),
          const SizedBox(width: 15),
          // Menú de Perfil
          CompositedTransformTarget(
            link: _linkLayer,
            child: OverlayPortal(
              controller: _tooltipController,
              overlayChildBuilder: (context) =>
                  _buildDropdownMenu(visibleProfiles),
              child: GestureDetector(
                onTap: _tooltipController.toggle,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    margin: const EdgeInsets.only(right: 40),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      image: DecorationImage(
                        image: _getImageProvider(
                          _currentProfile['selectedImage'] ??
                              _currentProfile['profilePic'],
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: screens),
    );
  }

  Widget _buildDropdownMenu(List<Map<String, String>> availableProfiles) {
    // Filtrar para no mostrar el perfil que se está usando actualmente
    final String currentActiveName =
        (_currentProfile['selectedName'] ??
                widget.userData?['name'] ??
                "USUARIO 1")
            .toString()
            .toUpperCase();

    final otherProfiles = availableProfiles
        .where((p) => p['name']!.toUpperCase() != currentActiveName)
        .toList();

    return Positioned(
      width: 200,
      child: CompositedTransformFollower(
        link: _linkLayer,
        showWhenUnlinked: false,
        offset: const Offset(-160, 45),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.95),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              // Otros perfiles
              ...otherProfiles.map(
                (profile) => _profileDropdownItem(
                  profile['name']!,
                  profile['image']!,
                  () => _switchProfile(profile),
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              // Botón Administrar (Navegación corregida con Navigator.push)
              _dropdownItem(Icons.edit_outlined, "Administrar perfiles", () {
                _tooltipController.hide();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ManageProfilesScreen(profileData: _currentProfile),
                  ),
                );
              }),
              _dropdownItem(Icons.swap_horiz, "Transferir perfil", () {}),
              _dropdownItem(Icons.account_circle_outlined, "Cuenta", () {}),
              _dropdownItem(Icons.help_outline, "Centro de ayuda", () {}),
              const Divider(color: Colors.white24, height: 1),
              _dropdownItem(null, "Cerrar sesión en MovieWind", () {
                Navigator.pushReplacementNamed(context, '/login');
              }, isBold: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileDropdownItem(
    String name,
    String imagePath,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                image: DecorationImage(
                  image: _getImageProvider(imagePath),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              name,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  ImageProvider _getImageProvider(dynamic path) {
    String imagePath = path.toString();
    if (imagePath.startsWith('http')) return NetworkImage(imagePath);
    return AssetImage(imagePath);
  }

  Widget _dropdownItem(
    IconData? icon,
    String text,
    VoidCallback onTap, {
    bool isBold = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            if (icon != null) Icon(icon, color: Colors.white70, size: 20),
            if (icon != null) const SizedBox(width: 10),
            Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(String title, int index) {
    bool isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: InkWell(
        onTap: () => _onItemTapped(index),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade400,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
