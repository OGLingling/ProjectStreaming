import 'package:flutter/material.dart';
import 'dart:convert'; // Para json.encode
import 'package:http/http.dart'
    as http; // Necesitas agregar http al pubspec.yaml

class AvatarPickerScreen extends StatefulWidget {
  final String profileName;
  final String? currentAvatar;
  final String userId; // Añadimos el ID del usuario para el backend

  const AvatarPickerScreen({
    super.key,
    this.profileName = "Usuario",
    this.currentAvatar,
    required this.userId, // El ID es obligatorio para actualizar
  });

  @override
  State<AvatarPickerScreen> createState() => _AvatarPickerScreenState();
}

class _AvatarPickerScreenState extends State<AvatarPickerScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isUpdating = false; // Estado para mostrar un cargando

  static const List<String> _avatars = [
    "assets/avatars/usuario4.webp",
    "assets/avatars/usuario3.jpg",
    "assets/avatars/usuario4.webp",
    "assets/avatars/usuario5.webp",
    "assets/avatars/usuario6.webp",
    "assets/avatars/usuarioprueba.jpg",
  ];

  // --- FUNCIÓN PARA GUARDAR EN EL BACKEND ---
  Future<void> _handleAvatarSelection(String avatarPath) async {
    setState(() => _isUpdating = true);

    try {
      // URL de tu API en Railway
      final url = Uri.parse(
        'https://projectstreaming-production.up.railway.app/api/users/update-profile',
      );

      final response = await http.put(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({"id": widget.userId, "profilePic": avatarPath}),
      );

      if (response.statusCode == 200) {
        // Si el backend confirma el cambio, volvemos con la nueva ruta
        if (mounted) Navigator.pop(context, avatarPath);
      } else {
        throw Exception("Error del servidor: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error al actualizar avatar: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se pudo guardar la foto de perfil")),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String displayName = widget.profileName.trim().isEmpty
        ? "Usuario"
        : widget.profileName.trim().toUpperCase();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        // Mostramos un indicador si se está guardando
        actions: _isUpdating
            ? [
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(right: 20),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ]
            : null,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Elige el ícono de perfil",
                  style: TextStyle(
                    color: Colors.grey.shade900,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      "Para $displayName",
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    CircleAvatar(
                      radius: 10,
                      backgroundImage: _getImageProvider(widget.currentAvatar),
                      backgroundColor: Colors.grey.shade200,
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Text(
                  "Los clásicos",
                  style: TextStyle(
                    color: Colors.grey.shade900,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 90,
                  child: Stack(
                    children: [
                      ListView.separated(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        itemCount: _avatars.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final avatar = _avatars[index];
                          return InkWell(
                            onTap: _isUpdating
                                ? null
                                : () => _handleAvatarSelection(avatar),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                avatar,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: InkWell(
                            onTap: () {
                              final next =
                                  ((_scrollController.offset + 200).clamp(
                                    0.0,
                                    _scrollController.position.maxScrollExtent,
                                  )).toDouble();
                              _scrollController.animateTo(
                                next,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                              );
                            },
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.black12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.chevron_right,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  "Historial",
                  style: TextStyle(
                    color: Colors.grey.shade900,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () {
                      if (_isValidPath(widget.currentAvatar)) {
                        _handleAvatarSelection(widget.currentAvatar!);
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 84,
                        height: 84,
                        color: Colors.grey.shade200,
                        child: _isValidPath(widget.currentAvatar)
                            ? Image(
                                image: _getImageProvider(widget.currentAvatar),
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.person, color: Colors.black54),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Capa de bloqueo durante la actualización
          if (_isUpdating)
            Container(
              color: Colors.black12,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  // --- FUNCIONES DE UTILIDAD MANTENIDAS ---
  bool _isValidPath(String? path) {
    final normalized = path?.trim();
    return normalized != null &&
        normalized.isNotEmpty &&
        normalized.toLowerCase() != 'null';
  }

  ImageProvider _getImageProvider(String? path) {
    final normalized = path?.trim();
    if (!_isValidPath(normalized))
      return const AssetImage("assets/avatars/usuario5.webp");
    if (normalized!.startsWith('http')) return NetworkImage(normalized);
    return AssetImage(normalized);
  }
}
