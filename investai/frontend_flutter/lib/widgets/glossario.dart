import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/chat_ia_screen.dart';
import '../theme.dart';

/// Explicações curtas dos termos que aparecem nas telas de investimento.
///
/// A pesquisa do relatório apontou que 85% dos participantes têm pouco ou
/// nenhum conhecimento sobre investimentos. Mostrar "CDI" sem explicar o
/// que é transforma a tela em catálogo para iniciado - por isso cada termo
/// é tocável, com a explicação escrita como se fosse para alguém que nunca
/// investiu.
class Glossario {
  static const Map<String, String> termos = {
    'selic': 'É a taxa básica de juros do país, definida pelo Banco Central. '
        'Ela serve de referência para quase tudo: quando a Selic sobe, a '
        'maioria dos investimentos de renda fixa rende mais.',
    'cdi': 'É a taxa que os bancos cobram ao emprestar dinheiro uns aos '
        'outros. Na prática ela anda quase colada na Selic, e é usada como '
        'régua: um CDB que paga "100% do CDI" rende mais ou menos isso.',
    'ipca': 'É o índice oficial da inflação no Brasil. Se ele está em 4% ao '
        'ano, significa que o que custava R\$ 100 passou a custar R\$ 104 — e '
        'seu dinheiro precisa render pelo menos isso para não encolher.',
    'fgc': 'Fundo Garantidor de Créditos. Se o banco onde você investiu '
        'quebrar, ele devolve o seu dinheiro até R\$ 250 mil por banco. É uma '
        'proteção que vale para poupança, CDB, LCI e LCA.',
    'liquidez': 'É a rapidez com que você consegue transformar o investimento '
        'em dinheiro na conta. Liquidez diária significa que dá para sacar em '
        'qualquer dia útil; no vencimento, só na data combinada.',
    'carência': 'É um período em que o dinheiro fica preso e você não pode '
        'resgatar. Investimentos com carência costumam render um pouco mais '
        'justamente por isso.',
    'renda fixa': 'São investimentos em que você sabe desde o começo como o '
        'rendimento é calculado. O valor não fica oscilando como na bolsa — '
        'por isso é o tipo indicado para reserva e para quem está começando.',
    'renda variável': 'São investimentos cujo valor sobe e desce o tempo todo, '
        'como ações. Podem render mais no longo prazo, mas você pode ver o '
        'valor cair no meio do caminho.',
    'tesouro selic': 'É um título público que acompanha a taxa Selic. Você '
        'empresta dinheiro para o governo e pode resgatar em qualquer dia '
        'útil sem perder o que já rendeu — por isso é o mais usado para '
        'reserva de emergência.',
    'tesouro ipca+': 'É um título público que paga a inflação mais um juro '
        'fixo. Garante que seu dinheiro cresça acima da alta dos preços, mas '
        'o ideal é deixar até a data de vencimento.',
    'cdb': 'Certificado de Depósito Bancário. Você empresta dinheiro ao banco '
        'e recebe com juros. Tem proteção do FGC até R\$ 250 mil.',
    'juro real': 'É o quanto o seu dinheiro rende de verdade, já descontando '
        'a inflação. Render 10% com inflação de 4% significa um juro real de '
        'cerca de 6%.',
    'reserva de emergência': 'É o dinheiro guardado para imprevistos — perder '
        'o emprego, consertar o carro, uma emergência de saúde. O recomendado '
        'é ter o equivalente a 3 meses das suas despesas antes de investir em '
        'outras coisas.',
  };

  /// Procura o termo ignorando maiúsculas e acentos simples.
  static String? explicacao(String palavra) =>
      termos[palavra.toLowerCase().trim()];
}

/// Texto comum, mas com os termos do glossário sublinhados e tocáveis.
/// Tocar abre a explicação; de lá dá para pedir mais detalhe à IA.
class TextoComGlossario extends StatelessWidget {
  final String texto;
  final TextStyle? estilo;

  const TextoComGlossario(this.texto, {super.key, this.estilo});

  @override
  Widget build(BuildContext context) {
    final base = estilo ??
        GoogleFonts.inter(
            fontSize: 12.5, color: InvestAITheme.texto, height: 1.5);

    // Termos maiores primeiro, para "tesouro selic" ganhar de "selic".
    final chaves = Glossario.termos.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final padrao = RegExp(
      chaves.map(RegExp.escape).join('|'),
      caseSensitive: false,
    );

    final trechos = <InlineSpan>[];
    var indice = 0;

    for (final achado in padrao.allMatches(texto)) {
      if (achado.start > indice) {
        trechos.add(TextSpan(text: texto.substring(indice, achado.start)));
      }
      final palavra = texto.substring(achado.start, achado.end);
      trechos.add(TextSpan(
        text: palavra,
        style: base.copyWith(
          color: InvestAITheme.verde,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.dotted,
          decorationColor: InvestAITheme.verde.withValues(alpha: 0.5),
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => _abrirExplicacao(context, palavra),
      ));
      indice = achado.end;
    }

    if (indice < texto.length) {
      trechos.add(TextSpan(text: texto.substring(indice)));
    }

    return RichText(
      text: TextSpan(style: base, children: trechos),
    );
  }

  void _abrirExplicacao(BuildContext context, String palavra) {
    final explicacao = Glossario.explicacao(palavra);
    if (explicacao == null) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _FichaTermo(termo: palavra, explicacao: explicacao),
    );
  }
}

class _FichaTermo extends StatelessWidget {
  final String termo;
  final String explicacao;

  const _FichaTermo({required this.termo, required this.explicacao});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
      decoration: const BoxDecoration(
        color: InvestAITheme.fundo,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: InvestAITheme.borda),
          left: BorderSide(color: InvestAITheme.borda),
          right: BorderSide(color: InvestAITheme.borda),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: InvestAITheme.borda,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 18),
          Text(termo,
              style: GoogleFonts.inter(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: InvestAITheme.texto)),
          const SizedBox(height: 10),
          Text(explicacao,
              style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: InvestAITheme.texto,
                  height: 1.55)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ChatIaScreen(
                    perguntaInicial:
                        'Me explica o que é $termo como se eu nunca tivesse '
                        'investido, e se faz sentido pra minha situação.',
                  ),
                ));
              },
              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
              label: const Text('Perguntar mais à IA'),
              style: OutlinedButton.styleFrom(
                foregroundColor: InvestAITheme.verde,
                side: const BorderSide(color: InvestAITheme.verde),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
