import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'payment_method_screen.dart';

const Color _planBackground = Color(0xFF07110F);
const Color _planSurface = Color(0xFF101817);
const Color _planSurfaceHigh = Color(0xFF17211F);
const Color _planPrimary = Color(0xFF00C853);
const Color _planSecondary = Color(0xFF00D8FF);

class PlanSelectionScreen extends StatefulWidget {
  final String userEmail;
  final String userName;
  final String password;

  const PlanSelectionScreen({
    super.key,
    required this.userEmail,
    required this.userName,
    required this.password,
  });

  @override
  State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends State<PlanSelectionScreen> {
  int _selectedPlanIndex = 2;
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
      'accent': const Color(0xFF00D8FF),
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
      'accent': const Color(0xFF00C853),
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
      'accent': const Color(0xFFFFC857),
    },
  ];

  Future<void> _handleNextStep() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final String planId = _plans[_selectedPlanIndex]['id'].toString();

    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentMethodScreen(
          userEmail: widget.userEmail,
          userName: widget.userName,
          selectedPlan: planId,
          password: widget.password,
        ),
      ),
    );

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedPlan = _plans[_selectedPlanIndex];

    return Scaffold(
      backgroundColor: _planBackground,
      appBar: AppBar(
        backgroundColor: _planBackground,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  _StepPill(label: 'Paso 2 de 3'),
                  const SizedBox(height: 16),
                  Text(
                    'Elige como quieres ver MovieWind',
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1.12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Puedes cambiar el plan cuando quieras desde tu cuenta.',
                    style: GoogleFonts.geologica(
                      color: Colors.white.withValues(alpha: 0.64),
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 22),
                  for (int i = 0; i < _plans.length; i++) ...[
                    _PlanOptionCard(
                      plan: _plans[i],
                      isSelected: _selectedPlanIndex == i,
                      onTap: () => setState(() => _selectedPlanIndex = i),
                    ),
                    if (i != _plans.length - 1) const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 18),
                  _PlanNote(planName: selectedPlan['name'].toString()),
                ],
              ),
            ),
            _BottomActionBar(
              isLoading: _isLoading,
              selectedPlan: selectedPlan,
              onPressed: _handleNextStep,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepPill extends StatelessWidget {
  final String label;

  const _StepPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _planPrimary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _planPrimary.withValues(alpha: 0.35)),
        ),
        child: Text(
          label,
          style: GoogleFonts.geologica(
            color: _planPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _PlanOptionCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanOptionCard({
    required this.plan,
    required this.isSelected,
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
            color: isSelected ? _planSurfaceHigh : _planSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? accent : Colors.white.withValues(alpha: 0.08),
              width: isSelected ? 1.6 : 1,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: accent.withValues(alpha: 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
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
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (plan['badge'] != null)
                              _SmallBadge(
                                label: plan['badge'].toString(),
                                color: accent,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${plan['price']} al mes',
                          style: GoogleFonts.geologica(
                            color: Colors.white.withValues(alpha: 0.68),
                            fontSize: 13,
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
                            size: 26,
                          )
                        : Icon(
                            Icons.radio_button_unchecked_rounded,
                            key: const ValueKey('unselected'),
                            color: Colors.white.withValues(alpha: 0.28),
                            size: 26,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FeatureChip(label: plan['resolution'].toString()),
                  _FeatureChip(label: plan['screens'].toString()),
                  _FeatureChip(label: plan['downloads'].toString()),
                ],
              ),
              const SizedBox(height: 14),
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
          fontSize: 10,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.78),
          fontSize: 12,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.54),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanNote extends StatelessWidget {
  final String planName;

  const _PlanNote({required this.planName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _planSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _planSecondary.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: _planSecondary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'El plan $planName se activara despues de confirmar el metodo de pago.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.64),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final bool isLoading;
  final Map<String, dynamic> selectedPlan;
  final VoidCallback onPressed;

  const _BottomActionBar({
    required this.isLoading,
    required this.selectedPlan,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: BoxDecoration(
        color: _planBackground,
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
                  color: _planPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : onPressed,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_rounded),
              label: Text(isLoading ? 'Preparando...' : 'Continuar'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
