import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Tus imports existentes
import 'movies_screen.dart';
import 'peliculas_screen.dart';
import 'series_screen.dart';
import 'games_screen.dart';
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
    final bool isMobile = size.width < 800; // Breakpoint para móvil

    final List<Widget> screens = [
      MoviesScreen(user: _currentProfile),
      SeriesScreen(isActive: _selectedIndex == 1),
      PeliculasScreen(isActive: _selectedIndex == 2),
      const GamesScreen(),
      const NovedadesScreen(),
      MyListScreen(favoriteMovies: const []),
      const SearchScreen(),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true, // Esto hace que el banner suba hasta arriba
      backgroundColor: Colors.black,
      appBar: _buildAppBar(isMobile),
      body: IndexedStack(index: _selectedIndex, children: screens),
      // Solo mostramos navegación inferior en móviles
      bottomNavigationBar: isMobile ? _buildBottomNavBar() : null,
    );
  }

  // --- APPBAR ADAPTATIVO ---
  PreferredSizeWidget _buildAppBar(bool isMobile) {
    return AppBar(
      backgroundColor: Colors.transparent, // Transparente para ver el banner
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
          ),
        ),
      ),
      elevation: 0,
      title: isMobile
          ? Image.asset(
              'assets/logo_moviewind.png', // Usa tu logo pequeño aquí
              height: 30,
              errorBuilder: (c, e, s) => Text(
                "MW",
                style: GoogleFonts.montserrat(
                  color: const Color(0xFFE50914),
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : Row(
              children: [
                Text(
                  "MOVIEWIND",
                  style: GoogleFonts.montserrat(
                    color: const Color(0xFFE50914),
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(width: 30),
                _navItem("Inicio", 0),
                _navItem("Series", 1),
                _navItem("Películas", 2),
                _navItem("Mi lista", 5),
              ],
            ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white, size: 24),
          onPressed: () => _onItemTapped(6),
        ),
        _buildProfileAvatar(),
      ],
    );
  }

  // --- NAVIGATION BAR PARA MÓVIL ---
  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex > 4
          ? 0
          : _selectedIndex, // Reset si está en búsqueda
      onTap: _onItemTapped,
      backgroundColor: Colors.black.withOpacity(0.9),
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
          icon: Icon(Icons.grid_view_rounded),
          label: "Novedades",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.download_for_offline_outlined),
          label: "Descargas",
        ),
      ],
    );
  }

  Widget _buildProfileAvatar() {
    return CompositedTransformTarget(
      link: _linkLayer,
      child: OverlayPortal(
        controller: _tooltipController,
        overlayChildBuilder: (context) => _buildDropdownMenu(),
        child: GestureDetector(
          onTap: _tooltipController.toggle,
          child: Container(
            margin: const EdgeInsets.only(right: 15, left: 10),
            width: 28,
            height: 28,
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

  // --- REUTILIZACIÓN DE TUS MÉTODOS EXISTENTES ---
  Widget _navItem(String title, int index) {
    bool isSelected = _selectedIndex == index;
    return TextButton(
      onPressed: () => _onItemTapped(index),
      child: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey.shade400,
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildDropdownMenu() {
    // Aquí puedes pegar toda la lógica de tu _buildDropdownMenu original
    // incluyendo la lista de perfiles y el botón de Cerrar Sesión.
    return Positioned(
      width: 200,
      child: CompositedTransformFollower(
        link: _linkLayer,
        offset: const Offset(-160, 45),
        child: Container(
          color: Colors.black.withOpacity(0.95),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dropdownItem(Icons.account_circle_outlined, "Cuenta", () {
                _tooltipController.hide();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (c) => const AccountScreen()),
                );
              }),
              _dropdownItem(null, "Cerrar sesión", () {
                Navigator.pushReplacementNamed(context, '/auth');
              }, isBold: true),
            ],
          ),
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
    return ListTile(
      leading: icon != null ? Icon(icon, color: Colors.white, size: 20) : null,
      title: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: onTap,
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
