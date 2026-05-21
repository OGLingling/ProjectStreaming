import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'profiles_settings_screen.dart';

const Color _accountBackground = Color(0xFF07110F);
const Color _accountSurface = Color(0xFF101817);
const Color _accountSurfaceHigh = Color(0xFF17211F);
const Color _accountPrimary = Color(0xFF00C853);
const Color _accountSecondary = Color(0xFF00D8FF);

class AccountScreen extends StatelessWidget {
  final Map<String, dynamic>? userData;

  const AccountScreen({super.key, this.userData});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final String plan = (userData?['plan'] ?? 'basico')
        .toString()
        .toLowerCase();
    final int maxProfiles = switch (plan) {
      'premium' => 4,
      'estandar' => 2,
      _ => 1,
    };

    final String displayName =
        (userData?['selectedName'] ??
                userData?['name'] ??
                userData?['userName'] ??
                userData?['email']?.toString().split('@').first ??
                'Usuario')
            .toString();

    final List<Map<String, String>> allProfiles = [
      {
        'name': displayName.toUpperCase(),
        'image': _normalizeImagePath(
          userData?['selectedImage'] ?? userData?['profilePic'],
        ),
      },
      {'name': 'USUARIO 2', 'image': 'assets/avatars/usuario6.webp'},
      {'name': 'USUARIO 3', 'image': 'assets/avatars/usuario2.jpg'},
      {'name': 'USUARIO 4', 'image': 'assets/avatars/usuario3.jpg'},
    ];

    final visibleProfiles = allProfiles.take(maxProfiles).toList();
    final planLabel = plan.toUpperCase();

    return Scaffold(
      backgroundColor: _accountBackground,
      appBar: AppBar(
        backgroundColor: _accountBackground,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Cuenta',
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: _accountSurfaceHigh,
              backgroundImage: _imageProvider(visibleProfiles.first['image']),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _AccountHeader(
                    displayName: displayName,
                    planLabel: planLabel,
                    profileImage: visibleProfiles.first['image']!,
                  ),
                  const SizedBox(height: 18),
                  _SectionTitle('Informacion de la membresia'),
                  _MembershipCard(planLabel: planLabel),
                  const SizedBox(height: 20),
                  _SectionTitle('Vinculos rapidos'),
                  _ActionGroup(
                    children: [
                      _AccountActionTile(
                        icon: Icons.dashboard_customize_outlined,
                        title: 'Cambiar de plan',
                        accent: colorScheme.primary,
                      ),
                      _AccountActionTile(
                        icon: Icons.payment_rounded,
                        title: 'Administrar forma de pago',
                        accent: colorScheme.secondary,
                      ),
                      _AccountActionTile(
                        icon: Icons.devices_rounded,
                        title: 'Acceso y dispositivos',
                        accent: colorScheme.secondary,
                      ),
                      _AccountActionTile(
                        icon: Icons.lock_outline_rounded,
                        title: 'Actualizar contrasena',
                        accent: colorScheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SectionTitle('Seguridad'),
                  _ActionGroup(
                    children: [
                      _AccountActionTile(
                        icon: Icons.security_rounded,
                        title: 'Controles parentales',
                        subtitle: 'Clasificacion por edad y bloqueos',
                        accent: colorScheme.primary,
                      ),
                      _AccountActionTile(
                        icon: Icons.tune_rounded,
                        title: 'Configuracion',
                        subtitle: 'Idiomas, subtitulos y notificaciones',
                        accent: colorScheme.secondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _ProfilesCard(
                    profiles: visibleProfiles,
                    plan: plan,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfilesSettingsScreen(
                            profiles: visibleProfiles,
                            userPlan: plan,
                          ),
                        ),
                      );
                    },
                  ),
                ]),
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

class _AccountHeader extends StatelessWidget {
  final String displayName;
  final String planLabel;
  final String profileImage;

  const _AccountHeader({
    required this.displayName,
    required this.planLabel,
    required this.profileImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _accountSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: _accountSurfaceHigh,
            backgroundImage: AccountScreen._imageProvider(profileImage),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusPill(
                      label: 'PLAN $planLabel',
                      color: _accountSecondary,
                    ),
                    const _StatusPill(label: 'ACTIVA', color: _accountPrimary),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
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
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MembershipCard extends StatelessWidget {
  final String planLabel;

  const _MembershipCard({required this.planLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _accountSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _accountPrimary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _accountPrimary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: _accountPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plan $planLabel',
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Miembro desde marzo de 2026',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _accountSurfaceHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Proximo pago: 25 de abril de 2026',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
            ),
          ),
          const SizedBox(height: 10),
          _InlineAction(
            label: 'Administrar membresia',
            icon: Icons.arrow_forward_ios_rounded,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ],
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
        color: _accountSurface,
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
                indent: 58,
              ),
          ],
        ],
      ),
    );
  }
}

class _AccountActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color accent;

  const _AccountActionTile({
    required this.icon,
    required this.title,
    required this.accent,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minLeadingWidth: 34,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: accent, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.56)),
            )
          : null,
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 15,
        color: Colors.white.withValues(alpha: 0.42),
      ),
      onTap: () {},
    );
  }
}

class _ProfilesCard extends StatelessWidget {
  final List<Map<String, String>> profiles;
  final String plan;
  final VoidCallback onTap;

  const _ProfilesCard({
    required this.profiles,
    required this.plan,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _accountSurface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _accountSecondary.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.people_alt_rounded,
                    color: _accountSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Administrar perfiles',
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 15,
                    color: Colors.white.withValues(alpha: 0.46),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${profiles.length} perfiles disponibles en plan ${plan.toUpperCase()}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 34,
                    width: 34.0 + ((profiles.length - 1) * 22.0),
                    child: Stack(
                      children: [
                        for (int i = 0; i < profiles.length; i++)
                          Positioned(
                            left: i * 22,
                            child: CircleAvatar(
                              radius: 17,
                              backgroundColor: _accountBackground,
                              child: CircleAvatar(
                                radius: 15,
                                backgroundImage: AccountScreen._imageProvider(
                                  profiles[i]['image'],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _InlineAction({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ),
            Icon(icon, size: 15, color: color),
          ],
        ),
      ),
    );
  }
}
