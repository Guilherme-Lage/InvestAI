import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../theme.dart';

/// Texto integral do termo de consentimento (LGPD).
///
/// O conteúdo vem do backend, que lê o mesmo arquivo Markdown entregue
/// como documento do projeto — assim a versão lida no app e a entregue ao
/// professor não divergem.
class TermoCompletoScreen extends StatelessWidget {
  const TermoCompletoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: InvestAITheme.card,
        foregroundColor: InvestAITheme.texto,
        title: Text('Termo de consentimento',
            style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: InvestAITheme.texto)),
      ),
      body: FutureBuilder<String>(
        future: ApiService.termoCompleto(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: InvestAITheme.verde),
            );
          }
          if (snap.hasError || snap.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  'Não consegui carregar o termo completo agora. '
                  'Verifique a conexão e tente de novo.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: InvestAITheme.cinza),
                ),
              ),
            );
          }

          return Markdown(
            data: snap.data!,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            styleSheet: MarkdownStyleSheet(
              h1: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: InvestAITheme.texto,
                  height: 1.35),
              h2: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: InvestAITheme.verde,
                  height: 1.5),
              p: GoogleFonts.inter(
                  fontSize: 13,
                  color: InvestAITheme.texto,
                  height: 1.6),
              strong: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: InvestAITheme.texto),
              listBullet: GoogleFonts.inter(
                  fontSize: 13, color: InvestAITheme.texto, height: 1.6),
              tableHead: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: InvestAITheme.verde),
              tableBody: GoogleFonts.inter(
                  fontSize: 12, color: InvestAITheme.texto, height: 1.45),
              tableBorder: TableBorder.all(color: InvestAITheme.borda),
              tableCellsPadding: const EdgeInsets.all(8),
              code: GoogleFonts.robotoMono(
                  fontSize: 12, color: InvestAITheme.cinza),
              horizontalRuleDecoration: const BoxDecoration(
                border: Border(
                    top: BorderSide(color: InvestAITheme.borda, width: 1)),
              ),
              blockquoteDecoration: BoxDecoration(
                color: InvestAITheme.card,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        },
      ),
    );
  }
}
