import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import 'data_privacy_screen.dart';
import 'edit_profile.dart';
import 'settings/configuracion_reproduccion.dart';
import 'settings/control_parental.dart';

const Color _manageBackground = Color(0xFF07110F);
const Color _manageSurface = Color(0xFF101817);
const Color _manageSurfaceHigh = Color(0xFF17211F);
const Color _managePrimary = Color(0xFF00C853);
const Color _manageSecondary = Color(0xFF00D8FF);
const Color _manageDanger = Color(0xFFFF5252);

class ManageProfilesScreen extends StatefulWidget {
  final Map<String, dynamic> profileData;

  const ManageProfilesScreen({super.key, required this.profileData});

  @override
  State<ManageProfilesScreen> createState() => _ManageProfilesScreenState();
}

class _ManageProfilesScreenState extends State<ManageProfilesScreen> {
  late String currentName;
  late String currentImg;
  bool _isDeletingAccount = false;

  String get _userId =>
      widget.profileData['id']?.toString() ??
      widget.profileData['userId']?.toString() ??
      '';

  String get _email => widget.profileData['email']?.toString().trim() ?? '';

  @override
  void initState() {
    super.initState();
    currentName = _normalizeText(
      widget.profileData['selectedName'] ?? widget.profileData['name'],
    );
    currentImg = _normalizeImagePath(
      widget.profileData['selectedImage'] ?? widget.profileData['profilePic'],
    );
  }

  Future<void> _openEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          name: currentName,
          image: currentImg,
          userId: _userId,
        ),
      ),
    );

    if (!mounted) return;

    if (result is Map) {
      setState(() {
        currentName = _normalizeText(result['name']);
        currentImg = _normalizeImagePath(result['image']);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, {'name': currentName, 'image': currentImg});
      },
      child: Scaffold(
        backgroundColor: _manageBackground,
        appBar: AppBar(
          backgroundColor: _manageBackground,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context, {
              'name': currentName,
              'image': currentImg,
            }),
          ),
          title: Text(
            'Administrar perfiles',
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
            children: [
              _ProfileHeroCard(
                name: currentName,
                imagePath: currentImg,
                email: _email,
                onTap: _openEditProfile,
              ),
              const SizedBox(height: 22),
              const _SectionTitle('Perfil'),
              _ActionGroup(
                children: [
                  _ManageActionTile(
                    icon: Icons.edit_outlined,
                    title: 'Editar informacion del perfil',
                    subtitle: 'Nombre, avatar y datos visibles',
                    accent: _manageSecondary,
                    onTap: _openEditProfile,
                  ),
                  _ManageActionTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Bloqueo de perfil',
                    subtitle: 'Solicita un PIN para acceder',
                    accent: _managePrimary,
                    onTap: () => _showPendingFeature('Bloqueo de perfil'),
                  ),
                  _ManageActionTile(
                    icon: Icons.switch_account_outlined,
                    title: 'Transferencia de perfiles',
                    subtitle: 'Copia este perfil a otra cuenta',
                    accent: _manageSecondary,
                    onTap: () =>
                        _showPendingFeature('Transferencia de perfiles'),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const _SectionTitle('Preferencias'),
              _ActionGroup(
                children: [
                  _ManageActionTile(
                    icon: Icons.translate_rounded,
                    title: 'Idioma y subtitulos',
                    subtitle: 'Configura idioma, audio y apariencia',
                    accent: _manageSecondary,
                    onTap: _openLanguageSettings,
                  ),
                  _ManageActionTile(
                    icon: Icons.security_rounded,
                    title: 'Controles parentales',
                    subtitle: 'Edita clasificaciones y restricciones',
                    accent: _managePrimary,
                    onTap: _openParentalControls,
                  ),
                  _ManageActionTile(
                    icon: Icons.play_circle_outline_rounded,
                    title: 'Configuracion de reproduccion',
                    subtitle: 'Autoplay, calidad y descargas',
                    accent: _manageSecondary,
                    onTap: () =>
                        _showPendingFeature('Configuracion de reproduccion'),
                  ),
                  _ManageActionTile(
                    icon: Icons.notifications_none_rounded,
                    title: 'Configuracion de notificaciones',
                    subtitle: 'Alertas por email y actividad',
                    accent: _managePrimary,
                    onTap: () =>
                        _showPendingFeature('Configuracion de notificaciones'),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const _SectionTitle('Datos'),
              _ActionGroup(
                children: [
                  _ManageActionTile(
                    icon: Icons.history_rounded,
                    title: 'Actividad de visualizacion',
                    subtitle: 'Administra historial y calificaciones',
                    accent: _manageSecondary,
                    onTap: () =>
                        _showPendingFeature('Actividad de visualizacion'),
                  ),
                  _ManageActionTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Configuracion de datos y privacidad',
                    subtitle: 'Administra tu informacion personal',
                    accent: _managePrimary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DataPrivacyScreen(
                          name: currentName,
                          email: _email,
                          phone: widget.profileData['phone']?.toString(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _DeleteAccountCard(
                isLoading: _isDeletingAccount,
                onTap: _confirmDeleteAccount,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openLanguageSettings() {
    if (!_hasValidUserId()) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConfiguracionReproduccionScreen(userId: _userId),
      ),
    );
  }

  void _openParentalControls() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ControlParentalScreen()),
    );
  }

  bool _hasValidUserId() {
    if (_userId.isEmpty || _userId == 'null' || _userId == 'undefined') {
      _showSnack(
        'No se encontro el ID de usuario. Cierra sesion y vuelve a entrar.',
        isError: true,
      );
      return false;
    }
    return true;
  }

  void _showPendingFeature(String feature) {
    _showSnack('$feature estara disponible en una proxima version.');
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? _manageDanger : _manageSurfaceHigh,
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    if (_isDeletingAccount) return;
    if (!_hasValidUserId()) return;

    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    final accountEmail = _email.isNotEmpty ? _email : firebaseUser?.email ?? '';

    if (accountEmail.isEmpty) {
      _showSnack(
        'No se encontro el correo de la cuenta para validar la eliminacion.',
        isError: true,
      );
      return;
    }

    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _manageSurface,
        title: const Text(
          'Eliminar cuenta',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Esta accion eliminara tu usuario de Firebase y luego de Neon/Prisma. Escribe tu correo para confirmar:',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
            ),
            const SizedBox(height: 12),
            Text(
              accountEmail,
              style: const TextStyle(
                color: _manageSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(hintText: 'correo@dominio.com'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final typed = controller.text.trim().toLowerCase();
              Navigator.pop(
                dialogContext,
                typed == accountEmail.trim().toLowerCase(),
              );
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(color: _manageDanger),
            ),
          ),
        ],
      ),
    );
    controller.dispose();

    if (confirmed != true) {
      if (confirmed == false) {
        _showSnack('El correo no coincide. No se elimino la cuenta.');
      }
      return;
    }

    await _deleteAccount(accountEmail);
  }

  Future<void> _deleteAccount(String accountEmail) async {
    setState(() => _isDeletingAccount = true);

    try {
      final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (firebaseUser == null ||
          firebaseUser.email?.toLowerCase() != accountEmail.toLowerCase()) {
        throw Exception('FIREBASE_SESSION_REQUIRED');
      }

      await firebaseUser.delete();

      final deletedFromDb = await ApiService.deleteUser(_userId);
      if (!deletedFromDb) {
        throw Exception('DB_DELETE_FAILED');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
    } on firebase_auth.FirebaseAuthException catch (e) {
      final message = e.code == 'requires-recent-login'
          ? 'Por seguridad, vuelve a iniciar sesion antes de eliminar la cuenta.'
          : 'No se pudo eliminar la cuenta de Firebase: ${e.code}';
      if (mounted) _showSnack(message, isError: true);
    } catch (e) {
      final message = e.toString().contains('FIREBASE_SESSION_REQUIRED')
          ? 'No hay una sesion Firebase activa para este correo. Inicia sesion nuevamente antes de eliminar la cuenta.'
          : 'No se pudo completar la eliminacion. Intenta de nuevo.';
      if (mounted) _showSnack(message, isError: true);
    } finally {
      if (mounted) setState(() => _isDeletingAccount = false);
    }
  }

  String _normalizeText(dynamic value) {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty || text.toLowerCase() == 'null')
        ? 'Usuario'
        : text;
  }

  String _normalizeImagePath(dynamic value) {
    final path = value?.toString().trim();
    return (path == null || path.isEmpty || path.toLowerCase() == 'null')
        ? 'assets/avatars/usuario5.webp'
        : path;
  }
}

class _ProfileHeroCard extends StatelessWidget {
  final String name;
  final String imagePath;
  final String email;
  final VoidCallback onTap;

  const _ProfileHeroCard({
    required this.name,
    required this.imagePath,
    required this.email,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _manageSurface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _manageSecondary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image(
                  image: _imageProvider(imagePath),
                  width: 62,
                  height: 62,
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
                    const SizedBox(height: 5),
                    Text(
                      email.isEmpty ? 'Perfil principal' : email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.edit_rounded, color: _manageSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.montserrat(
          color: Colors.white.withValues(alpha: 0.72),
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ActionGroup extends StatelessWidget {
  final List<Widget> children;

  const _ActionGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _manageSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.08),
                indent: 68,
              ),
          ],
        ],
      ),
    );
  }
}

class _ManageActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _ManageActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minLeadingWidth: 38,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, color: accent, size: 21),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.56),
          fontSize: 13,
          height: 1.25,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        color: Colors.white.withValues(alpha: 0.38),
        size: 16,
      ),
      onTap: onTap,
    );
  }
}

class _DeleteAccountCard extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _DeleteAccountCard({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: isLoading ? null : onTap,
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.delete_forever_outlined),
      label: Text(isLoading ? 'Eliminando...' : 'Eliminar cuenta'),
      style: OutlinedButton.styleFrom(
        foregroundColor: _manageDanger,
        side: BorderSide(color: _manageDanger.withValues(alpha: 0.55)),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
