import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';

// Paleta de colores Premium de la app
const Color _helpBackground = Color(0xFF07110F);
const Color _helpSurface = Color(0xFF101817);
const Color _helpSurfaceHigh = Color(0xFF17211F);
const Color _helpPrimary = Color(0xFF00C853);
const Color _helpTextSecondary = Color(0xFF8E9A97);

class HelpCenterScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const HelpCenterScreen({super.key, this.userData});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  
  String _selectedCategory = 'Problema de reproducción';
  bool _isSubmitting = false;
  String _searchQuery = '';

  final List<String> _categories = [
    'Problema de reproducción',
    'Cuenta y membresía',
    'Facturación',
    'Sugerencia',
    'Otro',
  ];

  // FAQs Estáticas
  final List<Map<String, String>> _faqs = [
    {
      'question': '¿Cómo puedo cambiar o cancelar mi plan?',
      'answer': 'Puedes actualizar o cancelar tu membresía en cualquier momento desde la sección de "Cuenta". Solo selecciona "Cambiar de plan" y elige la opción que mejor se adapte a tus necesidades.'
    },
    {
      'question': '¿Por qué el video tarda en cargar o se detiene?',
      'answer': 'Esto suele ocurrir por inestabilidad en la conexión a internet. Te sugerimos cambiar el servidor en la configuración de reproducción (ajustes del reproductor) o usar la opción "Nativo" para mayor estabilidad.'
    },
    {
      'question': '¿Cómo puedo actualizar mi información de perfil?',
      'answer': 'Dirígete a tu menú de "Cuenta", selecciona la opción "Administrar perfiles" y presiona sobre el perfil que deseas editar. Podrás cambiar tu nombre y foto de avatar en segundos.'
    },
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    final String? userId = widget.userData?['id']?.toString() ?? widget.userData?['userId']?.toString();
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No se encontró la sesión del usuario. Por favor, reincia sesión.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final success = await ApiService.submitHelpTicket(
        userId: userId,
        category: _selectedCategory,
        message: _messageController.text.trim(),
      );

      if (mounted) {
        if (success) {
          _messageController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reporte enviado correctamente. Nos comunicaremos contigo por correo.'),
              backgroundColor: _helpPrimary,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al enviar el reporte. Inténtalo de nuevo más tarde.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inesperado: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filtrar FAQs según búsqueda simulada
    final filteredFaqs = _faqs.where((faq) {
      final query = _searchQuery.toLowerCase();
      return faq['question']!.toLowerCase().contains(query) ||
          faq['answer']!.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: _helpBackground,
      appBar: AppBar(
        backgroundColor: _helpBackground,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Centro de Ayuda',
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A) Barra de búsqueda simulada / real
                Container(
                  decoration: BoxDecoration(
                    color: _helpSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: '¿En qué podemos ayudarte?',
                      hintStyle: const TextStyle(color: _helpTextSecondary),
                      prefixIcon: const Icon(Icons.search, color: _helpPrimary),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // B) FAQs Expandibles
                Text(
                  'Preguntas frecuentes',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                if (filteredFaqs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No encontramos resultados para tu búsqueda.',
                        style: TextStyle(color: _helpTextSecondary),
                      ),
                    ),
                  )
                else
                  ...filteredFaqs.map((faq) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: _helpSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        iconColor: _helpPrimary,
                        collapsedIconColor: Colors.white70,
                        title: Text(
                          faq['question']!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Text(
                              faq['answer']!,
                              style: const TextStyle(
                                color: _helpTextSecondary,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
                
                const SizedBox(height: 28),

                // C) Formulario de Soporte
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _helpSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _helpPrimary.withValues(alpha: 0.2)),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.support_agent_rounded, color: _helpPrimary),
                            const SizedBox(width: 8),
                            Text(
                              '¿No encontraste solución?',
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Envíanos un reporte detallando tu problema y te ayudaremos.',
                          style: TextStyle(
                            color: _helpTextSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Dropdown Categoría
                        const Text(
                          'Categoría del problema',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: _helpSurfaceHigh,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCategory,
                              isExpanded: true,
                              dropdownColor: _helpSurfaceHigh,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              icon: const Icon(Icons.arrow_drop_down, color: _helpPrimary),
                              items: _categories.map((String cat) {
                                return DropdownMenuItem<String>(
                                  value: cat,
                                  child: Text(cat),
                                );
                              }).toList(),
                              onChanged: (String? val) {
                                if (val != null) {
                                  setState(() => _selectedCategory = val);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Campo de Mensaje
                        const Text(
                          'Describe el problema',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _messageController,
                          maxLines: 4,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Describe con detalles lo que sucede...',
                            hintStyle: const TextStyle(color: _helpTextSecondary, fontSize: 13),
                            filled: true,
                            fillColor: _helpSurfaceHigh,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: _helpPrimary),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Por favor ingresa un mensaje descriptivo';
                            }
                            if (val.trim().length < 10) {
                              return 'Por favor da más detalles del problema (mínimo 10 caracteres)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Botón de Envío
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitReport,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _helpPrimary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: _helpPrimary.withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Enviar reporte',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
