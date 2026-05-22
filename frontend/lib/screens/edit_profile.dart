import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import 'avatar_picker_screen.dart';

const Color _editBackground = Color(0xFF07110F);
const Color _editSurface = Color(0xFF101817);
const Color _editSurfaceHigh = Color(0xFF17211F);
const Color _editSecondary = Color(0xFF00D8FF);
const Color _editDanger = Color(0xFFFF5252);

class EditProfileScreen extends StatefulWidget {
  final String name;
  final String image;
  final String userId;

  const EditProfileScreen({
    super.key,
    required this.name,
    required this.image,
    required this.userId,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late String _selectedImage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _selectedImage = widget.image;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfileChanges() async {
    if (_isSaving) return;

    if (widget.userId.isEmpty ||
        widget.userId == 'null' ||
        widget.userId == 'undefined') {
      _showSnack(
        'ID de usuario no encontrado. Cierra sesion y vuelve a entrar.',
        isError: true,
      );
      return;
    }

    final String newName = _nameController.text.trim();
    if (newName.length < 2) {
      _showSnack('El nombre debe tener al menos 2 caracteres.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final success = await ApiService.updateUser(widget.userId, {
        'name': newName,
        'profilePic': _selectedImage,
      });

      if (!success) {
        throw Exception('UPDATE_FAILED');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', newName);
      await prefs.setString('user_profilePic', _selectedImage);

      if (!mounted) return;
      Navigator.pop(context, {'name': newName, 'image': _selectedImage});
    } catch (e) {
      if (mounted) {
        _showSnack(
          'No se pudo guardar el perfil. Intenta de nuevo.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openAvatarPicker() async {
    final nameForPicker = _nameController.text.trim().isEmpty
        ? 'Usuario'
        : _nameController.text.trim();

    final String? selectedPath = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AvatarPickerScreen(
          profileName: nameForPicker,
          currentAvatar: _selectedImage,
          userId: widget.userId,
        ),
      ),
    );

    if (!mounted) return;

    if (selectedPath != null && selectedPath.trim().isNotEmpty) {
      setState(() => _selectedImage = selectedPath);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? _editDanger : _editSurfaceHigh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _editBackground,
      appBar: AppBar(
        backgroundColor: _editBackground,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _isSaving ? null : () => Navigator.pop(context),
        ),
        title: Text(
          'Editar perfil',
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isSaving ? null : _saveProfileChanges,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Guardar',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: [
            _ProfileEditorCard(
              imagePath: _selectedImage,
              nameController: _nameController,
              onAvatarTap: _openAvatarPicker,
            ),
            const SizedBox(height: 22),
            _InfoCard(
              icon: Icons.sports_esports_outlined,
              title: 'Alias de juegos',
              description:
                  'Tu alias es un nombre unico para jugar con otros miembros en Juegos MovieWind.',
              actionLabel: 'Crear alias de juegos',
              onTap: () =>
                  _showSnack('Alias de juegos estara disponible pronto.'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileEditorCard extends StatelessWidget {
  final String imagePath;
  final TextEditingController nameController;
  final VoidCallback onAvatarTap;

  const _ProfileEditorCard({
    required this.imagePath,
    required this.nameController,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _editSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _editSecondary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informacion del perfil',
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onAvatarTap,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image(
                        image: _getImage(imagePath),
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: _editSecondary,
                          shape: BoxShape.circle,
                          border: Border.all(color: _editBackground, width: 2),
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          color: Colors.black,
                          size: 17,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nombre del perfil',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      cursorColor: _editSecondary,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: _editSurfaceHigh,
                        hintText: 'Nombre',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.38),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: _editSecondary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Minimo 2 caracteres.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.46),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onTap;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _editSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.64),
              fontSize: 14,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Material(
            color: _editSurfaceHigh,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(icon, color: _editSecondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        actionLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white.withValues(alpha: 0.38),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

ImageProvider _getImage(String path) {
  final normalized = path.trim();
  if (normalized.isEmpty || normalized.toLowerCase() == 'null') {
    return const AssetImage('assets/avatars/usuario5.webp');
  }
  if (normalized.startsWith('http')) return NetworkImage(normalized);
  return AssetImage(normalized);
}
