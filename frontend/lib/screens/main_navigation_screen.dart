import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'movies_screen.dart';
import 'peliculas_screen.dart';
import 'series_screen.dart';
import 'novedades_screen.dart';
import 'manage_profiles_screen.dart';
import 'search_screen.dart';
import 'my_list_screen.dart';
import 'account_screen.dart';

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
    _currentProfile = widget.userData ?? {};
  }

  // --- LÓGICA DE PERFILES ---
  List<Map<String, String>> _getVisibleProfiles() {
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

    return allProfiles.take(maxProfiles).toList();
  }

  void _switchProfile(Map<String, dynamic> newProfile) {
    _tooltipController.hide();
    setState(() {
      _currentProfile = {
        ...widget.userData!,
        'selectedName': newProfile['name'],
        'selectedImage': newProfile['image'],
      };
      _selectedIndex = 0;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 800;
    final visibleProfiles = _getVisibleProfiles();

    // ORDEN DE ÍNDICES CORREGIDO:
    // 0: Inicio, 1: Series, 2: Películas, 3: Novedades, 4: Mi lista, 5: Buscador
    final List<Widget> screens = [
      MoviesScreen(user: _currentProfile),
      SeriesScreen(isActive: _selectedIndex == 1),
      PeliculasScreen(isActive: _selectedIndex == 2),
      const NovedadesScreen(),
      const MyListScreen(), // Sin parámetros si usas Provider
      const SearchScreen(),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: _buildAdaptiveAppBar(isMobile, visibleProfiles),
      body: IndexedStack(
        index: _selectedIndex >= screens.length ? 0 : _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: isMobile ? _buildMobileBottomNav() : null,
    );
  }

  PreferredSizeWidget _buildAdaptiveAppBar(
    bool isMobile,
    List<Map<String, String>> visibleProfiles,
  ) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
          ),
        ),
      ),
      title: Row(
        children: [
          Text(
            "MOVIEWIND",
            style: GoogleFonts.montserrat(
              color: const Color(0xFFE50914),
              fontWeight: FontWeight.w900,
              fontSize: isMobile ? 18 : 22,
            ),
          ),
          if (!isMobile) ...[
            const SizedBox(width: 30),
            _navItem("Inicio", 0),
            _navItem("Series", 1),
            _navItem("Películas", 2),
            _navItem("Novedades", 3), // Antes era 4 (incorrecto)
            _navItem("Mi lista", 4), // Antes era 5 (incorrecto)
          ],
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white, size: 26),
          onPressed: () => _onItemTapped(5), // Buscador es el índice 5
        ),
        const SizedBox(width: 10),
        _buildProfileIcon(visibleProfiles),
        SizedBox(width: isMobile ? 10 : 40),
      ],
    );
  }

  Widget _buildMobileBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex >= 5
          ? 0
          : _selectedIndex, // Reset si está en buscador
      onTap: _onItemTapped,
      backgroundColor: Colors.black.withOpacity(0.95),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.grey,
      selectedFontSize: 10,
      unselectedFontSize: 10,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          label: "Inicio",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.video_library_outlined),
          label: "Series",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.movie_outlined),
          label: "Películas",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.auto_awesome_motion_outlined),
          label: "Novedades",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bookmark_border),
          label: "Mi lista",
        ),
      ],
    );
  }

  // --- PERFIL Y MENÚ POPUP (Sin cambios mayores, solo corregida la lógica de paso de datos) ---
  Widget _buildProfileIcon(List<Map<String, String>> visibleProfiles) {
    return CompositedTransformTarget(
      link: _linkLayer,
      child: OverlayPortal(
        controller: _tooltipController,
        overlayChildBuilder: (context) => _buildDropdownMenu(visibleProfiles),
        child: GestureDetector(
          onTap: _tooltipController.toggle,
          child: Container(
            width: 30,
            height: 30,
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
    );
  }

  Widget _buildDropdownMenu(List<Map<String, String>> availableProfiles) {
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
      width: 220,
      child: CompositedTransformFollower(
        link: _linkLayer,
        offset: const Offset(-180, 40),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.95),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              ...otherProfiles.map(
                (profile) => _profileDropdownItem(
                  profile['name']!,
                  profile['image']!,
                  () => _switchProfile(profile),
                ),
              ),
              const Divider(color: Colors.white24),
              _dropdownItem(Icons.edit_outlined, "Administrar perfiles", () {
                _tooltipController.hide();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (c) =>
                        ManageProfilesScreen(profileData: _currentProfile),
                  ),
                );
              }),
              _dropdownItem(Icons.account_circle_outlined, "Cuenta", () {
                _tooltipController.hide();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (c) => const AccountScreen()),
                );
              }),
              const Divider(color: Colors.white24),
              _dropdownItem(null, "Cerrar sesión en MovieWind", () {
                Navigator.pushReplacementNamed(context, '/auth');
              }, isBold: true),
            ],
          ),
        ),
      ),
    );
  }

  // --- MÉTODOS AUXILIARES ---
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
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
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
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        onTap: () => _onItemTapped(index),
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

  ImageProvider _getImageProvider(dynamic path) {
    final imagePath = path?.toString().trim();
    if (imagePath == null || imagePath.isEmpty || imagePath == 'null') {
      return const AssetImage("assets/avatars/usuario5.webp");
    }
    if (imagePath.startsWith('http')) return NetworkImage(imagePath);
    return AssetImage(imagePath);
  }
}
