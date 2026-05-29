import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';

// Paleta de colores Premium de la app
const Color _changeBackground = Color(0xFF07110F);
const Color _changeSurface = Color(0xFF101817);
const Color _changeSurfaceHigh = Color(0xFF17211F);
const Color _changePrimary = Color(0xFF00C853);
const Color _changeSecondary = Color(0xFF00D8FF);
const Color _changeWarning = Color(0xFFFFC857);
const Color _changeDanger = Color(0xFFFF5252);

class ChangePlanScreen extends StatefulWidget {
  final String currentPlan;
  final Map<String, dynamic>? userData;

  const ChangePlanScreen({
    super.key,
    required this.currentPlan,
    this.userData,
  });

  @override
  State<ChangePlanScreen> createState() => _ChangePlanScreenState();
}

class _ChangePlanScreenState extends State<ChangePlanScreen> {
  late int _selectedPlanIndex;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _plans = [
    {
      'id': 'basico',
      'name': 'Basico',
      'price': 'S/ 24.90',
      'quality': 'Buena',
      'resolution': '720p HD',
      'screens': '1 pantalla',
      'downloads': '1 dispositivo',
      'badge': 'Entrada',
      'icon': Icons.phone_android_rounded,
      'accent': _changeSecondary,
    },
    {
      'id': 'estandar',
      'name': 'Estandar',
      'price': 'S/ 34.90',
      'quality': 'Excelente',
      'resolution': '1080p Full HD',
      'screens': '2 pantallas',
      'downloads': '2 dispositivos',
      'badge': 'Equilibrado',
      'icon': Icons.live_tv_rounded,
      'accent': _changePrimary,
    },
    {
      'id': 'premium',
      'name': 'Premium',
      'price': 'S/ 44.90',
      'quality': 'Excepcional',
      'resolution': '4K Ultra HD + HDR',
      'screens': '4 pantallas',
      'downloads': '6 dispositivos',
      'badge': 'Mas elegido',
      'icon': Icons.workspace_premium_rounded,
      'accent': _changeWarning,
    },
  ];

  @override
  void initState() {
    super.initState();
    // Encontrar el índice del plan actual
    final normalizedCurrent = widget.currentPlan.toLowerCase().trim();
    final index = _plans.indexWhere((p) => p['id'] == normalizedCurrent);
    _selectedPlanIndex = index != -1 ? index : 0;
  }

  String get _userId =>
      widget.userData?['id']?.toString() ??
      widget.userData?['userId']?.toString() ??
      '';

  Future<void> _updatePlan() async {
    if (_isLoading) return;

    final selectedPlan = _plans[_selectedPlanIndex];
    final String selectedPlanId = selectedPlan['id'].toString();

    if (selectedPlanId == widget.currentPlan.toLowerCase().trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ya te encuentras suscrito a este plan.'),
          backgroundColor: _changeSurfaceHigh,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No se encontró la sesión del usuario.'),
          backgroundColor: _changeDanger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await ApiService.updateUser(_userId, {
        'plan': selectedPlanId,
      });

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Plan actualizado correctamente a ${selectedPlan['name']}!'),
            backgroundColor: _changePrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, selectedPlanId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo actualizar el plan. Inténtalo de nuevo.'),
            backgroundColor: _changeDanger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de red: $e'),
            backgroundColor: _changeDanger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedPlan = _plans[_selectedPlanIndex];
    final isCurrentSelected = selectedPlan['id'] == widget.currentPlan.toLowerCase().trim();

    return Scaffold(
      backgroundColor: _changeBackground,
      appBar: AppBar(
        backgroundColor: _changeBackground,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Membresía',
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  Text(
                    'Cambia tu plan de MovieWind',
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Selecciona el nuevo plan de suscripción. El cobro se ajustará automáticamente.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Opciones de Plan
                  for (int i = 0; i < _plans.length; i++) ...[
                    _PlanOptionCard(
                      plan: _plans[i],
                      isSelected: _selectedPlanIndex == i,
                      isActivePlan: _plans[i]['id'] == widget.currentPlan.toLowerCase().trim(),
                      onTap: () => setState(() => _selectedPlanIndex = i),
                    ),
                    if (i != _plans.length - 1) const SizedBox(height: 12),
                  ],
                ],
              ),
            ),

            // Acciones Inferiores
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: BoxDecoration(
                color: _changeBackground,
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedPlan['name'].toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        selectedPlan['price'].toString(),
                        style: const TextStyle(
                          color: _changePrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (_isLoading || isCurrentSelected) ? null : _updatePlan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _changePrimary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: isCurrentSelected 
                            ? _changeSurfaceHigh 
                            : _changePrimary.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              isCurrentSelected ? 'Tu Plan Activo' : 'Confirmar Cambio de Plan',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanOptionCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final bool isSelected;
  final bool isActivePlan;
  final VoidCallback onTap;

  const _PlanOptionCard({
    required this.plan,
    required this.isSelected,
    required this.isActivePlan,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = plan['accent'] as Color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? _changeSurfaceHigh : _changeSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected 
                  ? accent 
                  : (isActivePlan ? _changePrimary.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08)),
              width: isSelected ? 1.6 : 1,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: accent.withValues(alpha: 0.14),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
            ],
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
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(plan['icon'] as IconData, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                plan['name'].toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.montserrat(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isActivePlan)
                              const _SmallBadge(
                                label: 'ACTIVO',
                                color: _changePrimary,
                              )
                            else if (plan['badge'] != null)
                              _SmallBadge(
                                label: plan['badge'].toString(),
                                color: accent,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${plan['price']} al mes',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.68),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: isSelected
                        ? Icon(
                            Icons.check_circle_rounded,
                            key: const ValueKey('selected'),
                            color: accent,
                            size: 24,
                          )
                        : Icon(
                            Icons.radio_button_unchecked_rounded,
                            key: const ValueKey('unselected'),
                            color: Colors.white.withValues(alpha: 0.28),
                            size: 24,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FeatureChip(label: plan['resolution'].toString()),
                  _FeatureChip(label: plan['screens'].toString()),
                  _FeatureChip(label: plan['downloads'].toString()),
                ],
              ),
              const SizedBox(height: 12),
              _PlanMetric(
                label: 'Calidad de video y audio',
                value: plan['quality'].toString(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _SmallBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String label;

  const _FeatureChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.74),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PlanMetric extends StatelessWidget {
  final String label;
  final String value;

  const _PlanMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.52),
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
