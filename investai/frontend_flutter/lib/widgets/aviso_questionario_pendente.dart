import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

/// Aviso mostrado enquanto o questionário de suitability (RF18) não foi
/// respondido - quem pulou no cadastro vê isso no Início e no Perfil.
class AvisoQuestionarioPendente extends StatelessWidget {
  final VoidCallback onResponder;

  const AvisoQuestionarioPendente({super.key, required this.onResponder});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: InvestAITheme.amarelo.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: InvestAITheme.amarelo.withValues(alpha: 0.45)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onResponder,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: InvestAITheme.amarelo.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.assignment_outlined,
                    color: InvestAITheme.amarelo, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Complete seu questionário',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: InvestAITheme.texto,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Responda o questionário para definir seu perfil de '
                      'investidor. Leva menos de 2 minutos.',
                      style: GoogleFonts.inter(
                          fontSize: 12.5, color: InvestAITheme.cinza, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded,
                  color: InvestAITheme.amarelo, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
