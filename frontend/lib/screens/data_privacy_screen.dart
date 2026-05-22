import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _privacyBackground = Color(0xFF07110F);
const Color _privacySurface = Color(0xFF101817);
const Color _privacySurfaceHigh = Color(0xFF17211F);
const Color _privacyPrimary = Color(0xFF00C853);
const Color _privacySecondary = Color(0xFF00D8FF);

class DataPrivacyScreen extends StatelessWidget {
  final String name;
  final String email;
  final String? phone;

  const DataPrivacyScreen({
    super.key,
    required this.name,
    required this.email,
    this.phone,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedName = _normalize(name, fallback: 'Usuario');
    final normalizedEmail = _normalize(email, fallback: 'Email no disponible');
    final normalizedPhone = _normalize(phone, fallback: 'No registrado');

    return Scaffold(
      backgroundColor: _privacyBackground,
      appBar: AppBar(
        backgroundColor: _privacyBackground,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Datos y privacidad',
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
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _privacySurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _privacySecondary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _privacyPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(
                      Icons.privacy_tip_outlined,
                      color: _privacyPrimary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Administra la informacion asociada a tu cuenta MovieWind.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _SectionTitle('Informacion de contacto'),
            _ContactGroup(
              children: [
                _ContactTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Nombre',
                  value: normalizedName,
                  accent: _privacyPrimary,
                  onTap: () => _showInfo(
                    context,
                    'Edita tu nombre desde Editar perfil.',
                  ),
                ),
                _ContactTile(
                  icon: Icons.mail_outline_rounded,
                  title: 'Email',
                  value: normalizedEmail,
                  accent: _privacySecondary,
                  onTap: () => _showInfo(
                    context,
                    'El email esta vinculado a Firebase y no se cambia desde esta seccion.',
                  ),
                ),
                _ContactTile(
                  icon: Icons.phone_android_rounded,
                  title: 'Telefono celular',
                  value: normalizedPhone,
                  accent: _privacyPrimary,
                  onTap: () => _showInfo(
                    context,
                    normalizedPhone == 'No registrado'
                        ? 'Aun no existe campo telefono en el modelo de usuario.'
                        : 'Telefono registrado correctamente.',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _normalize(String? value, {required String fallback}) {
    final text = value?.trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return fallback;
    }
    return text;
  }

  static void _showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _privacySurfaceHigh,
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
          color: Colors.white.withValues(alpha: 0.74),
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ContactGroup extends StatelessWidget {
  final List<Widget> children;

  const _ContactGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _privacySurface,
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

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color accent;
  final VoidCallback onTap;

  const _ContactTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minLeadingWidth: 38,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.62),
          fontSize: 13,
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
