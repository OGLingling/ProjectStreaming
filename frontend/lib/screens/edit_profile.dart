import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'avatar_picker_screen.dart';

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

  // --- LÓGICA CORREGIDA PARA GUARDAR CAMBIOS ---
  Future<void> _saveProfileChanges() async {
    // Validación de seguridad para evitar enviar "null" al servidor
    if (widget.userId.isEmpty || widget.userId == "null") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: ID de usuario no válido")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final String newName = _nameController.text.trim();

      // CORRECCIÓN: URL dinámica que incluye el ID al final según tu backend
      final url = Uri.parse(
        'https://projectstreaming-production.up.railway.app/api/users/${widget.userId}',
      );

      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({"name": newName, "profilePic": _selectedImage}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          // Retornamos los datos a la pantalla anterior
          Navigator.pop(context, {'name': newName, 'image': _selectedImage});
        }
      } else {
        debugPrint(
          "Fallo del servidor: ${response.statusCode} - ${response.body}",
        );
        throw Exception("Error al guardar");
      }
    } catch (e) {
      debugPrint("Excepción en el guardado: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al conectar con el servidor")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openAvatarPicker() async {
    final nameForPicker = _nameController.text.trim().isEmpty
        ? "Usuario"
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "MOVIEWIND",
          style: GoogleFonts.montserrat(
            color: const Color(0xFFE50914),
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          _isSaving
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _saveProfileChanges,
                  child: const Text(
                    "GUARDAR",
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Editar perfil",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _openAvatarPicker,
                      child: Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: _getImage(_selectedImage),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Nombre del perfil",
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _nameController,
                            cursorColor: Colors.black,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                            ),
                            decoration: const InputDecoration(
                              filled: true,
                              fillColor: Color(0xFFF0F0F0),
                              contentPadding: EdgeInsets.all(15),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.transparent,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.black,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 50),
                const Divider(color: Colors.black12),
                const SizedBox(height: 20),
                const Text(
                  "Alias de juegos",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Tu alias es un nombre único que se usará para jugar con otros miembros en Juegos MovieWind.",
                  style: TextStyle(color: Colors.black87, fontSize: 14),
                ),
                const SizedBox(height: 20),
                _actionButton(
                  Icons.sports_esports_outlined,
                  "Crear alias de juegos",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, String text) {
    return InkWell(
      onTap: () {},
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.black),
            const SizedBox(width: 15),
            Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  ImageProvider _getImage(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty || normalized.toLowerCase() == 'null') {
      return const AssetImage("assets/avatars/usuario5.webp");
    }
    if (normalized.startsWith('http')) return NetworkImage(normalized);
    return AssetImage(normalized);
  }
}
