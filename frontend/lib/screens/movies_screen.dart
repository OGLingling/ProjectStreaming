import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import '../models/movie_model.dart';
import '../services/api_service.dart';

class MoviesScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  const MoviesScreen({super.key, this.user});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen>
    with TickerProviderStateMixin {
  List<Movie> movies = [];
  bool isLoading = true;
  final ScrollController _scrollController = ScrollController();
  double _headerOpacity = 0.0;
  String _selectedTab = "Inicio";

  final OverlayPortalController _profileMenuController =
      OverlayPortalController();
  final _link = LayerLink();

  @override
  void initState() {
    super.initState();
    _fetchMovies();
    _scrollController.addListener(() {
      if (mounted) {
        setState(() {
          _headerOpacity = (_scrollController.offset / 120).clamp(0.0, 1.0);
        });
      }
    });
  }

  // --- MÉTODOS DE DATOS (Mantenidos igual) ---
  Future<void> _fetchMovies() async {
    try {
      final response = await http
          .get(Uri.parse('${ApiService.baseUrl}/movies'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        if (mounted)
          setState(() {
            movies = data.map((m) => Movie.fromJson(m)).toList();
            isLoading = false;
          });
      } else {
        _loadMockData();
      }
    } catch (e) {
      _loadMockData();
    }
  }

  void _loadMockData() {
    if (!mounted) return;
    setState(() {
      movies = [
        Movie(
          title: "Inception",
          imageUrl:
              "https://image.tmdb.org/t/p/original/qmDpS9ZCCmTv9CsA2HSNAUa5Cbs.jpg",
          category: "Acción",
          description: "Un ladrón...",
          rating: 8.8,
          releaseDate: DateTime.now(),
        ),
        Movie(
          title: "The Avengers",
          imageUrl:
              "https://image.tmdb.org/t/p/w500/RYMX2wcB0MAmueQOcyCr586JmRr.jpg",
          category: "Acción",
          description: "Los héroes...",
          rating: 8.5,
          releaseDate: DateTime.now(),
        ),
      ];
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          color: Colors.black.withOpacity(_headerOpacity),
          child: _buildTopNavbar(),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE50914)),
            )
          : _buildMainContent(),
    );
  }

  Widget _buildTopNavbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SafeArea(
        child: Row(
          children: [
            Text(
              "MOVIEWIND",
              style: GoogleFonts.montserrat(
                color: const Color(0xFFE50914),
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    "Inicio",
                    "Series",
                    "Películas",
                    "Juegos",
                    "Novedades populares",
                    "Mi lista",
                    "Explora por idiomas",
                  ].map((title) => _navOption(title)).toList(),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white, size: 24),
              onPressed: () {},
            ),
            const SizedBox(width: 5),

            // --- AVATAR CON EFECTO HOVER ---
            CompositedTransformTarget(
              link: _link,
              child: OverlayPortal(
                controller: _profileMenuController,
                overlayChildBuilder: (context) => _buildProfileDropdown(),
                child: _hoverWrapper(
                  builder: (isHovered) => GestureDetector(
                    onTap: _profileMenuController.toggle,
                    child: AnimatedScale(
                      scale: isHovered || _profileMenuController.isShowing
                          ? 1.1
                          : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Row(
                        children: [
                          _buildProfileAvatar(
                            isHovered || _profileMenuController.isShowing,
                          ),
                          AnimatedRotation(
                            turns: _profileMenuController.isShowing ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper para detectar Hover fácilmente
  Widget _hoverWrapper({required Widget Function(bool isHovered) builder}) {
    bool isHovered = false;
    return StatefulBuilder(
      builder: (context, setState) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => isHovered = true),
        onExit: (_) => setState(() => isHovered = false),
        child: builder(isHovered),
      ),
    );
  }

  Widget _navOption(String title) {
    return _hoverWrapper(
      builder: (isHovered) {
        bool isActive = _selectedTab == title;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isHovered
                ? Colors.white.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: InkWell(
            onTap: () => setState(() => _selectedTab = title),
            child: Text(
              title,
              style: GoogleFonts.geologica(
                color: isActive || isHovered ? Colors.white : Colors.white70,
                fontSize: 13.5,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileAvatar(bool highlight) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: highlight ? Colors.white : Colors.transparent,
          width: 1.5,
        ),
        image: const DecorationImage(
          image: NetworkImage(
            "https://upload.wikimedia.org/wikipedia/commons/0/0b/Netflix-avatar.png",
          ),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _movieCard(String url) {
    return _hoverWrapper(
      builder: (isHovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        width: 110,
        margin: EdgeInsets.symmetric(
          horizontal: 5,
          vertical: isHovered ? 0 : 5,
        ),
        transform: isHovered
            ? (Matrix4.identity()..scale(1.08))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          boxShadow: isHovered
              ? [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ]
              : [],
          image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _btn(IconData icon, String label, Color bg, Color txt) {
    return _hoverWrapper(
      builder: (isHovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        transform: isHovered
            ? (Matrix4.identity()..translate(0, -2))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: isHovered ? bg.withOpacity(0.8) : bg,
          borderRadius: BorderRadius.circular(4),
          boxShadow: isHovered
              ? [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Icon(icon, color: txt, size: 24),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: txt,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- RESTO DE WIDGETS (Dropdown, Secciones, etc. - Mantenidos con lógica funcional) ---
  Widget _buildProfileDropdown() {
    final List<dynamic> profiles = widget.user?['profiles'] ?? [];
    return Positioned(
      top: 60,
      right: 15,
      child: CompositedTransformFollower(
        link: _link,
        offset: const Offset(-160, 45),
        child: Container(
          width: 220,
          decoration: BoxDecoration(
            color: const Color(0xFF121212).withOpacity(0.98),
            border: Border.all(color: Colors.white10),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              ...profiles
                  .where(
                    (p) => p['id'] != (widget.user?['activeProfileId'] ?? ""),
                  )
                  .map((p) => _profileItem(p['name'], p['profilePic']))
                  .toList(),
              const Divider(color: Colors.white24, height: 20),
              _menuItem(Icons.edit_outlined, "Administrar perfiles"),
              _menuItem(Icons.person_outline, "Cuenta"),
              _menuItem(Icons.help_outline, "Centro de ayuda"),
              const Divider(color: Colors.white24, height: 20),
              _menuItem(null, "Cerrar sesión en MovieWind", isBold: true),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileItem(String name, String? imageUrl) {
    return ListTile(
      onTap: () => _profileMenuController.hide(),
      hoverColor: Colors.white10,
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          image: DecorationImage(
            image: NetworkImage(imageUrl ?? ""),
            fit: BoxFit.cover,
          ),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
      dense: true,
    );
  }

  Widget _menuItem(IconData? icon, String text, {bool isBold = false}) {
    return ListTile(
      hoverColor: Colors.white10,
      minLeadingWidth: 20,
      leading: icon != null
          ? Icon(icon, color: Colors.white70, size: 20)
          : null,
      title: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      dense: true,
      onTap: () {
        _profileMenuController.hide();
        if (text.contains("Cerrar sesión"))
          Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
      },
    );
  }

  Widget _buildMainContent() {
    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildBanner()),
        SliverList(
          delegate: SliverChildListDelegate([
            _buildSection("Mi lista", movies),
            _buildSection("Tendencias", movies.reversed.toList()),
            const SizedBox(height: 50),
          ]),
        ),
      ],
    );
  }

  Widget _buildBanner() {
    return Stack(
      children: [
        Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(movies.isNotEmpty ? movies[0].imageUrl : ""),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black54,
                  Colors.transparent,
                  Colors.transparent,
                  Color(0xFF141414),
                ],
                stops: [0.0, 0.2, 0.8, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Text(
                movies.isNotEmpty ? movies[0].title.toUpperCase() : "",
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _btn(
                    Icons.play_arrow,
                    "Reproducir",
                    Colors.white,
                    Colors.black,
                  ),
                  const SizedBox(width: 12),
                  _btn(
                    Icons.add,
                    "Mi lista",
                    Colors.grey[800]!.withOpacity(0.9),
                    Colors.white,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Movie> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 15, top: 25, bottom: 10),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 165,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: list.length,
            itemBuilder: (context, index) => _movieCard(list[index].imageUrl),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
