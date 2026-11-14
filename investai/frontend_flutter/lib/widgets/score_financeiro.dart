import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';

/// RF20 - score financeiro em escala 0-1000 (padrão score de crédito),
/// com classificação qualitativa (Ruim/Regular/Bom/Excelente), o que
/// compõe a nota e o que mais faria ela subir.
///
/// Aparece em destaque na tela Início e, recolhido, nas ferramentas da aba
/// Investir. Com [semMoldura] o card não desenha a própria borda nem o
/// título, para não ficar card dentro de card numa seção recolhível.
class ScoreFinanceiroCard extends StatelessWidget {
  final Map<String, dynamic> score;
  final Map<String, dynamic>? historico;
  final bool semMoldura;

  const ScoreFinanceiroCard({
    super.key,
    required this.score,
    this.historico,
    this.semMoldura = false,
  });

  static Color corDoScore(int valor) {
    if (valor >= 650) return InvestAITheme.verde;
    if (valor >= 400) return InvestAITheme.amarelo;
    return InvestAITheme.vermelho;
  }

  @override
  Widget build(BuildContext context) {
    final valor = (score['score'] ?? 0) as int;
    final maximo = (score['score_maximo'] ?? 1000) as int;
    final classificacao = '${score['classificacao'] ?? ''}';
    final progresso = maximo > 0 ? (valor / maximo).clamp(0.0, 1.0) : 0.0;
    final cor = corDoScore(valor);
    final detalhes = (score['detalhes'] as Map?)?.cast<String, dynamic>();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(semMoldura ? 0 : 16),
      decoration: semMoldura
          ? null
          : BoxDecoration(
              color: cor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cor.withValues(alpha: 0.35)),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!semMoldura) ...[
            Row(
              children: [
                Icon(Icons.speed_rounded, color: cor, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Seu score financeiro',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
                ),
                if (classificacao.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(classificacao,
                        style: GoogleFonts.inter(
                            fontSize: 11.5, fontWeight: FontWeight.w700, color: cor)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$valor',
                  style: GoogleFonts.inter(
                      fontSize: semMoldura ? 30 : 32, fontWeight: FontWeight.w800, color: cor, height: 1)),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 3, left: 6),
                  child: Text(
                    semMoldura ? 'de $maximo · $classificacao' : 'de $maximo pontos',
                    style: GoogleFonts.inter(
                        fontSize: 12.5, fontWeight: FontWeight.w600, color: InvestAITheme.cinza),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progresso,
              minHeight: 7,
              backgroundColor: InvestAITheme.borda,
              valueColor: AlwaysStoppedAnimation(cor),
            ),
          ),
          if (detalhes != null && detalhes.isNotEmpty) ...[
            const SizedBox(height: 14),
            _ComposicaoScore(detalhes: detalhes),
          ],
          if (historico != null) ...[
            const SizedBox(height: 14),
            _EvolucaoScore(historico: historico!, cor: cor),
          ],
        ],
      ),
    );
  }
}

/// As quatro partes do score (250 pontos cada, ver
/// calcular_score_financeiro_service.py) e uma dica para a parte com mais
/// pontos a ganhar - um número sozinho não diz o que fazer.
class _ComposicaoScore extends StatelessWidget {
  final Map<String, dynamic> detalhes;
  const _ComposicaoScore({required this.detalhes});

  static const _pontosPorParte = 250.0;

  // (chave do backend, rótulo, dica para subir essa parte)
  static const _partes = [
    (
      'saldo',
      'Saldo positivo',
      'Deixe o saldo positivo: registre todas as receitas e segure os gastos '
          'até as contas fecharem no azul.',
    ),
    (
      'reserva_emergencia',
      'Reserva',
      'Faça aportes na sua reserva de emergência, na aba Metas. Cada real '
          'guardado soma pontos.',
    ),
    (
      'cumprimento_metas',
      'Metas',
      'Conclua suas metas na aba Metas. Se ainda não tem nenhuma, crie uma '
          'pequena e alcançável.',
    ),
    (
      'controle_gastos',
      'Gastos no limite',
      'Alguma categoria passou do limite que você definiu. Veja qual na aba '
          'Relatório e ajuste os gastos dela.',
    ),
  ];

  double _pontos(String chave) => ((detalhes[chave] ?? 0) as num).toDouble();

  @override
  Widget build(BuildContext context) {
    // Parte com mais pontos a ganhar; em empate, vale a ordem da lista.
    (String, String, String)? maisAGanhar;
    var maiorFalta = 0.0;
    for (final parte in _partes) {
      final falta = _pontosPorParte - _pontos(parte.$1);
      if (falta > maiorFalta + 0.5) {
        maiorFalta = falta;
        maisAGanhar = parte;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('O que compõe sua nota',
            style: GoogleFonts.inter(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
        const SizedBox(height: 8),
        // Grade 2x2: as quatro partes ocupam metade da altura de uma lista.
        for (var linha = 0; linha < _partes.length; linha += 2)
          Row(
            children: [
              for (var i = linha; i < linha + 2 && i < _partes.length; i++) ...[
                if (i > linha) const SizedBox(width: 14),
                Expanded(
                  child: _LinhaParte(
                      rotulo: _partes[i].$2,
                      pontos: _pontos(_partes[i].$1),
                      maximo: _pontosPorParte),
                ),
              ],
            ],
          ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: InvestAITheme.fundo,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: InvestAITheme.borda),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                maisAGanhar == null ? Icons.emoji_events_outlined : Icons.trending_up_rounded,
                color: InvestAITheme.verde,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  maisAGanhar == null
                      ? 'Nota máxima em todas as partes. Agora é manter o ritmo!'
                      : 'Para subir até ${maiorFalta.round()} pontos: ${maisAGanhar.$3}',
                  style: GoogleFonts.inter(fontSize: 11.5, color: InvestAITheme.texto, height: 1.35),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LinhaParte extends StatelessWidget {
  final String rotulo;
  final double pontos;
  final double maximo;
  const _LinhaParte({required this.rotulo, required this.pontos, required this.maximo});

  @override
  Widget build(BuildContext context) {
    final fracao = maximo > 0 ? (pontos / maximo).clamp(0.0, 1.0) : 0.0;
    final cor = fracao >= 0.999
        ? InvestAITheme.verde
        : fracao >= 0.5
            ? InvestAITheme.amarelo
            : InvestAITheme.vermelho;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(rotulo,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 11, color: InvestAITheme.cinza)),
              ),
              Text('${pontos.round()}/${maximo.round()}',
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fracao,
              minHeight: 4,
              backgroundColor: InvestAITheme.borda,
              valueColor: AlwaysStoppedAnimation(cor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Evolução do score ao longo do tempo. Cada ponto é um dia em que o
/// usuário consultou o score (tela Início ou aba Investir), então o gráfico
/// começa vazio e vai se formando com o uso - não há como calcular o score
/// de datas passadas.
class _EvolucaoScore extends StatelessWidget {
  final Map<String, dynamic> historico;
  final Color cor;
  const _EvolucaoScore({required this.historico, required this.cor});

  String _dataCurta(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final pontos = ((historico['historico'] as List?) ?? [])
        .cast<Map<String, dynamic>>()
        .map((p) => (DateTime.tryParse(p['data'] ?? ''), (p['score'] as num).toDouble()))
        .where((p) => p.$1 != null)
        .map((p) => (p.$1!, p.$2))
        .toList();

    final titulo = Text('Evolução',
        style: GoogleFonts.inter(
            fontSize: 12.5, fontWeight: FontWeight.w700, color: InvestAITheme.texto));

    if (pontos.length < 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titulo,
          const SizedBox(height: 4),
          Text(
            'Seu histórico começa hoje. Volte nos próximos dias para ver '
            'como o score evolui.',
            style: GoogleFonts.inter(fontSize: 12, color: InvestAITheme.cinza, height: 1.4),
          ),
        ],
      );
    }

    final variacao = ((historico['variacao'] ?? 0) as num).round();
    final corVariacao = variacao > 0
        ? InvestAITheme.verde
        : variacao < 0
            ? InvestAITheme.vermelho
            : InvestAITheme.cinza;
    final textoVariacao = variacao == 0
        ? 'estável'
        : '${variacao > 0 ? '+' : ''}$variacao pontos';

    final inicio = pontos.first.$1;
    final valores = pontos.map((p) => p.$2).toList();
    final minimo = valores.reduce((a, b) => a < b ? a : b);
    final maximo = valores.reduce((a, b) => a > b ? a : b);
    // Folga para a linha não encostar nas bordas (e para um score que não
    // mudou não virar um gráfico de altura zero).
    final folga = (maximo - minimo) * 0.15 + 20;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: titulo),
            Text('$textoVariacao desde ${_dataCurta(inicio)}',
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w700, color: corVariacao)),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 60,
          child: LineChart(
            LineChartData(
              minY: minimo - folga,
              maxY: maximo + folga,
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: [
                LineChartBarData(
                  // Eixo X em dias corridos: dias sem consulta viram um
                  // trecho mais longo, em vez de parecerem dias seguidos.
                  spots: [
                    for (final p in pontos)
                      FlSpot(p.$1.difference(inicio).inDays.toDouble(), p.$2),
                  ],
                  barWidth: 2.5,
                  color: cor,
                  dotData: FlDotData(show: pontos.length <= 15),
                  belowBarData: BarAreaData(show: true, color: cor.withValues(alpha: 0.12)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_dataCurta(inicio),
                style: GoogleFonts.inter(fontSize: 10, color: InvestAITheme.cinza)),
            Text('hoje', style: GoogleFonts.inter(fontSize: 10, color: InvestAITheme.cinza)),
          ],
        ),
      ],
    );
  }
}
