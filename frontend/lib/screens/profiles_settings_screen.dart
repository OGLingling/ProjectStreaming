import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _settingsBackground = Color(0xFF07110F);
const Color _settingsSurface = Color(0xFF101817);
const Color _settingsSurfaceHigh = Color(0xFF17211F);
const Color _settingsPrimary = Color(0xFF00C853);
const Color _settingsSecondary = Color(0xFF00D8FF);

class ProfilesSettingsScreen extends StatelessWidget {
  final List<Map<String, String>> profiles;
  final String userPlan;

  const ProfilesSettingsScreen({
    super.key,
    required this.profiles,
    required this.userPlan,
  });

  @override
  Widget build(BuildContext context) {
    final firstProfile = profiles.isNotEmpty
        ? profiles.first
        : {'name': 'USUARIO', 'image': 'assets/avatars/usuario5.webp'};

    return Scaffold(
      backgroundColor: _settingsBackground,
      appBar: AppBar(
        backgroundColor: _settingsBackground,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Perfiles',
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: _settingsSurfaceHigh,
              backgroundImage: _imageProvider(firstProfile['image']),
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
            _HeaderCard(
              plan: userPlan,
              profileCount: profiles.length,
              profileImage: firstProfile['image']!,
            ),
            const SizedBox(height: 22),
            const _SectionTitle('Cuenta'),
            _ActionGroup(
              children: const [
                _SettingsActionTile(
                  icon: Icons.home_outlined,
                  title: 'Descripcion general',
                  subtitle: 'Estado de tu cuenta y resumen del servicio',
                  accent: _settingsPrimary,
                ),
                _SettingsActionTile(
                  icon: Icons.card_membership_rounded,
                  title: 'Membresia',
                  subtitle: 'Plan, facturacion y beneficios activos',
                  accent: _settingsSecondary,
                ),
                _SettingsActionTile(
                  icon: Icons.payment_rounded,
                  title: 'Forma de pago',
                  subtitle: 'Administra tarjetas, PayPal o codigos',
                  accent: _settingsSecondary,
                ),
                _SettingsActionTile(
                  icon: Icons.devices_rounded,
                  title: 'Acceso y dispositivos',
                  subtitle: 'Sesiones abiertas y equipos autorizados',
                  accent: _settingsPrimary,
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _SectionTitle('Seguridad'),
            _ActionGroup(
              children: const [
                _SettingsActionTile(
                  icon: Icons.lock_outline_rounded,
                  title: 'Actualizar contrasena',
                  subtitle: 'Refuerza el acceso a tu cuenta',
                  accent: _settingsPrimary,
                ),
                _SettingsActionTile(
                  icon: Icons.security_rounded,
                  title: 'Controles parentales',
                  subtitle: 'Clasificacion por edad y bloqueos',
                  accent: _settingsPrimary,
                ),
                _SettingsActionTile(
                  icon: Icons.verified_user_outlined,
                  title: 'Verificacion y privacidad',
                  subtitle: 'Correo, PIN y preferencias de seguridad',
                  accent: _settingsSecondary,
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _SectionTitle('Preferencias de app'),
            _ActionGroup(
              children: const [
                _SettingsActionTile(
                  icon: Icons.language_rounded,
                  title: 'Idioma y subtitulos',
                  subtitle: 'Audio, subtitulos y tamano de texto',
                  accent: _settingsSecondary,
                ),
                _SettingsActionTile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notificaciones',
                  subtitle: 'Avisos de estrenos y actividad',
                  accent: _settingsPrimary,
                ),
                _SettingsActionTile(
                  icon: Icons.play_circle_outline_rounded,
                  title: 'Reproduccion',
                  subtitle: 'Autoplay, calidad y descargas',
                  accent: _settingsSecondary,
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _SectionTitle('Configuracion de perfiles'),
            _ActionGroup(
              children: [
                const _SettingsActionTile(
                  icon: Icons.switch_account_outlined,
                  title: 'Transferir un perfil',
                  subtitle: 'Copia un perfil a otra cuenta',
                  accent: _settingsSecondary,
                ),
                for (int i = 0; i < profiles.length; i++)
                  _ProfileActionTile(
                    name: profiles[i]['name'] ?? 'Usuario',
                    imagePath: profiles[i]['image'] ?? '',
                    isFirst: i == 0,
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Preguntas? Contactanos',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.54),
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white.withValues(alpha: 0.38),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _normalizeImagePath(dynamic value) {
    final path = value?.toString().trim();
    if (path == null || path.isEmpty || path.toLowerCase() == 'null') {
      return 'assets/avatars/usuario5.webp';
    }
    return path;
  }

  static ImageProvider _imageProvider(dynamic value) {
    final path = _normalizeImagePath(value);
    if (path.startsWith('http')) return NetworkImage(path);
    return AssetImage(path);
  }
}

class _HeaderCard extends StatelessWidget {
  final String plan;
  final int profileCount;
  final String profileImage;

  const _HeaderCard({
    required this.plan,
    required this.profileCount,
    required this.profileImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _settingsSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _settingsSecondary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: _settingsSurfaceHigh,
            backgroundImage: ProfilesSettingsScreen._imageProvider(
              profileImage,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Administrar perfiles',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$profileCount perfiles disponibles en plan ${plan.toUpperCase()}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 13,
                    height: 1.3,
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
        color: _settingsSurface,
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

class _SettingsActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  const _SettingsActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
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
      onTap: () {},
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  final String name;
  final String imagePath;
  final bool isFirst;

  const _ProfileActionTile({
    required this.name,
    required this.imagePath,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: _settingsSurfaceHigh,
        backgroundImage: ProfilesSettingsScreen._imageProvider(imagePath),
      ),
      title: Text(
        name.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: isFirst
          ? const Text('Tu perfil', style: TextStyle(color: _settingsSecondary))
          : Text(
              'Perfil secundario',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.54)),
            ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        color: Colors.white.withValues(alpha: 0.38),
        size: 16,
      ),
      onTap: () {},
    );
  }
}
