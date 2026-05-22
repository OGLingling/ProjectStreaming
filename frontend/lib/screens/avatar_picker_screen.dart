import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _avatarBackground = Color(0xFF07110F);
const Color _avatarSurface = Color(0xFF101817);
const Color _avatarSurfaceHigh = Color(0xFF17211F);
const Color _avatarPrimary = Color(0xFF00C853);
const Color _avatarSecondary = Color(0xFF00D8FF);

class AvatarPickerScreen extends StatefulWidget {
  final String profileName;
  final String? currentAvatar;
  final String userId;

  const AvatarPickerScreen({
    super.key,
    this.profileName = 'Usuario',
    this.currentAvatar,
    required this.userId,
  });

  @override
  State<AvatarPickerScreen> createState() => _AvatarPickerScreenState();
}

class _AvatarPickerScreenState extends State<AvatarPickerScreen> {
  static const List<String> _avatars = [
    'assets/avatars/usuario2.jpg',
    'assets/avatars/usuario3.jpg',
    'assets/avatars/usuario4.webp',
    'assets/avatars/usuario5.webp',
    'assets/avatars/usuario6.webp',
    'assets/avatars/usuarioprueba.jpg',
  ];

  late String _selectedAvatar;

  @override
  void initState() {
    super.initState();
    _selectedAvatar = _normalizePath(widget.currentAvatar);
  }

  void _confirmSelection() {
    if (!_isValidPath(_selectedAvatar)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un avatar valido.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.pop(context, _selectedAvatar);
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.profileName.trim().isEmpty
        ? 'Usuario'
        : widget.profileName.trim();

    return Scaffold(
      backgroundColor: _avatarBackground,
      appBar: AppBar(
        backgroundColor: _avatarBackground,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Elegir avatar',
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                children: [
                  _SelectedPreview(
                    name: displayName,
                    avatarPath: _selectedAvatar,
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Avatares disponibles',
                    style: GoogleFonts.montserrat(
                      color: Colors.white.withValues(alpha: 0.74),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _avatars.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemBuilder: (context, index) {
                      final avatar = _avatars[index];
                      final isSelected = avatar == _selectedAvatar;
                      return _AvatarTile(
                        avatarPath: avatar,
                        isSelected: isSelected,
                        onTap: () => setState(() => _selectedAvatar = avatar),
                      );
                    },
                  ),
                  if (_isValidPath(widget.currentAvatar)) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Avatar actual',
                      style: GoogleFonts.montserrat(
                        color: Colors.white.withValues(alpha: 0.74),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 104,
                        height: 104,
                        child: _AvatarTile(
                          avatarPath: widget.currentAvatar!,
                          isSelected: widget.currentAvatar == _selectedAvatar,
                          onTap: () => setState(
                            () => _selectedAvatar = widget.currentAvatar!,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: BoxDecoration(
                color: _avatarBackground,
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _confirmSelection,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Usar este avatar'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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

  bool _isValidPath(String? path) {
    final normalized = path?.trim();
    return normalized != null &&
        normalized.isNotEmpty &&
        normalized.toLowerCase() != 'null';
  }

  String _normalizePath(String? path) {
    return _isValidPath(path) ? path!.trim() : 'assets/avatars/usuario5.webp';
  }
}

class _SelectedPreview extends StatelessWidget {
  final String name;
  final String avatarPath;

  const _SelectedPreview({required this.name, required this.avatarPath});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _avatarSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _avatarSecondary.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image(
              image: _imageProvider(avatarPath),
              width: 68,
              height: 68,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Vista previa del perfil',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarTile extends StatelessWidget {
  final String avatarPath;
  final bool isSelected;
  final VoidCallback onTap;

  const _AvatarTile({
    required this.avatarPath,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? _avatarSurfaceHigh : _avatarSurface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? _avatarPrimary
                  : Colors.white.withValues(alpha: 0.08),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image(
                  image: _imageProvider(avatarPath),
                  fit: BoxFit.cover,
                ),
              ),
              if (isSelected)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: _avatarPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.black,
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

ImageProvider _imageProvider(String? path) {
  final normalized = path?.trim();
  if (normalized == null ||
      normalized.isEmpty ||
      normalized.toLowerCase() == 'null') {
    return const AssetImage('assets/avatars/usuario5.webp');
  }
  if (normalized.startsWith('http')) return NetworkImage(normalized);
  return AssetImage(normalized);
}
