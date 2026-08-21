import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/usuario.dart';
import '../models/meta.dart';
import '../services/api_service.dart';
import '../theme.dart';

/// Início: RF05 (saldo em tempo real), RF08 (capacidade de economia),
/// RF09 (tempo de sobrevivência), prévia das metas (RF06/RF07) e o guia
/// financeiro (RF16) em destaque, como um assistente/treinador financeiro.
class DashboardTab extends StatefulWidget {
  final Usuario usuario;
  final VoidCallback onVerTodasMetas;

  const DashboardTab({super.key, required this.usuario, required this.onVerTodasMetas});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  bool _carregando = true;
  String? _erro;

  double _saldo = 0;
  double _capacidadeEconomia = 0;
  double? _mesesSobrevivencia;
  List<Meta> _metas = [];
  Map<String, dynamic>? _guia;
  Map<String, dynamic>? _dolar;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final resultados = await Future.wait([
        ApiService.saldo(),
        ApiService.capacidadeEconomiaMensal(),
        ApiService.tempoSobrevivenciaMeses(),
        ApiService.listarMetas(),
        ApiService.guiaFinanceiro(),
      ]);
      if (!mounted) return;
      setState(() {
        _saldo = resultados[0] as double;
        _capacidadeEconomia = resultados[1] as double;
        _mesesSobrevivencia = resultados[2] as double?;
        _metas = (resultados[3] as List<Meta>).where((m) => !m.isReservaEmergencia).toList();
        _guia = resultados[4] as Map<String, dynamic>;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.toString();
        _carregando = false;
      });
      return;
    }

    // Cotação do dólar é dado de mercado externo: carregada à parte para
    // uma instabilidade nessa API não travar o resto da tela Início.
    try {
      final dolar = await ApiService.cotacaoDolar();
      if (!mounted) return;
      setState(() => _dolar = dolar);
    } catch (e) {
      if (!mounted) return;
      setState(() => _dolar = null);
    }
  }

  String _reais(num valor) => 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator(color: InvestAITheme.verde));
    }
    if (_erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, color: InvestAITheme.cinza, size: 40),
              const SizedBox(height: 12),
              Text(_erro!, textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: InvestAITheme.cinza)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _carregar, child: const Text('Tentar novamente')),
            ],
          ),
        ),
      );
    }

    final metasPreview = _metas.take(2).toList();

    return RefreshIndicator(
      color: InvestAITheme.verde,
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('Olá, ${widget.usuario.nome.split(' ').first} 👋',
              style: GoogleFonts.inter(
                  fontSize: 24, fontWeight: FontWeight.w800, color: InvestAITheme.texto)),
          const SizedBox(height: 4),
          Text('Aqui está o seu raio-x financeiro.',
              style: GoogleFonts.inter(fontSize: 13, color: InvestAITheme.cinza)),
          const SizedBox(height: 20),

          // RF05 - saldo disponível
          _SaldoCard(saldo: _saldo, reais: _reais),
          const SizedBox(height: 12),

          // RF08 - capacidade de economia mensal + RF09 - sobrevivência
          Row(
            children: [
              Expanded(
                child: _MetricaCard(
                  titulo: 'Economia do mês',
                  valor: _reais(_capacidadeEconomia),
                  icone: Icons.savings_outlined,
                  destaque: _capacidadeEconomia >= 0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricaCard(
                  titulo: 'Sobrevivência s/ renda',
                  valor: _mesesSobrevivencia == null
                      ? '—'
                      : '${_mesesSobrevivencia!.toStringAsFixed(1)} meses',
                  icone: Icons.timelapse_rounded,
                  destaque: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Cotação do dólar (USD/BRL), com histórico dos últimos 30 dias
          _GraficoDolar(dolar: _dolar),
          const SizedBox(height: 20),

          // RF16 - guia financeiro, com cara de assistente/treinador
          if (_guia != null) _AssistenteCard(guia: _guia!),
          const SizedBox(height: 20),

          // RF06/RF07 - prévia das metas
          Row(
            children: [
              Expanded(
                child: Text('Suas metas',
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
              ),
              TextButton(onPressed: widget.onVerTodasMetas, child: const Text('Ver todas')),
            ],
          ),
          if (metasPreview.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Você ainda não criou nenhuma meta.',
                  style: GoogleFonts.inter(fontSize: 13, color: InvestAITheme.cinza)),
            )
          else
            for (final m in metasPreview) _MetaPreview(meta: m, reais: _reais),
        ],
      ),
    );
  }
}

class _SaldoCard extends StatelessWidget {
  final double saldo;
  final String Function(num) reais;
  const _SaldoCard({required this.saldo, required this.reais});

  @override
  Widget build(BuildContext context) {
    final positivo = saldo >= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: InvestAITheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: InvestAITheme.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, color: InvestAITheme.verde, size: 18),
              const SizedBox(width: 6),
              Text('Saldo disponível',
                  style: GoogleFonts.inter(fontSize: 12, color: InvestAITheme.cinza)),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              reais(saldo),
              style: GoogleFonts.inter(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: positivo ? InvestAITheme.texto : InvestAITheme.vermelho,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('já descontando as despesas registradas',
              style: GoogleFonts.inter(fontSize: 11, color: InvestAITheme.cinza)),
        ],
      ),
    );
  }
}

class _MetricaCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icone;
  final bool destaque;
  const _MetricaCard({
    required this.titulo,
    required this.valor,
    required this.icone,
    required this.destaque,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: InvestAITheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: InvestAITheme.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: InvestAITheme.verde, size: 18),
          const SizedBox(height: 8),
          Text(titulo, style: GoogleFonts.inter(fontSize: 11, color: InvestAITheme.cinza)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: destaque ? InvestAITheme.texto : InvestAITheme.vermelho,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cartão do guia financeiro (RF16) com apresentação de "assistente" —
/// pequeno avatar de IA e legenda, no espírito de treinador digital
/// descrito no relatório do projeto, sem simular um chat de verdade.
class _AssistenteCard extends StatelessWidget {
  final Map<String, dynamic> guia;
  const _AssistenteCard({required this.guia});

  IconData get _icone {
    switch (guia['passo']) {
      case 'saldo_negativo':
        return Icons.report_gmailerrorred_rounded;
      case 'construir_reserva':
        return Icons.savings_rounded;
      default:
        return Icons.rocket_launch_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: InvestAITheme.verde.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: InvestAITheme.verde.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: InvestAITheme.verde,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: InvestAITheme.verdeEscuro, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Seu guia financeiro',
                        style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w700, color: InvestAITheme.verde)),
                    Text('atualizado agora',
                        style: GoogleFonts.inter(fontSize: 10.5, color: InvestAITheme.cinza)),
                  ],
                ),
              ),
              Icon(_icone, color: InvestAITheme.verde, size: 18),
            ],
          ),
          const SizedBox(height: 14),
          Text(guia['titulo'] ?? '',
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
          const SizedBox(height: 6),
          Text(guia['mensagem'] ?? '',
              style: GoogleFonts.inter(fontSize: 13, color: InvestAITheme.texto, height: 1.4)),
        ],
      ),
    );
  }
}

/// Gráfico do dólar (USD/BRL) com histórico dos últimos 30 dias, via
/// AwesomeAPI (dado público, atualizado periodicamente pelo backend).
class _GraficoDolar extends StatelessWidget {
  final Map<String, dynamic>? dolar;
  const _GraficoDolar({required this.dolar});

  @override
  Widget build(BuildContext context) {
    if (dolar == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: InvestAITheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: InvestAITheme.borda),
        ),
        child: Row(
          children: [
            const Icon(Icons.attach_money_rounded, color: InvestAITheme.cinza, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Cotação do dólar indisponível no momento.',
                  style: GoogleFonts.inter(fontSize: 12.5, color: InvestAITheme.cinza)),
            ),
          ],
        ),
      );
    }

    final atual = (dolar!['atual'] as num).toDouble();
    final variacao = (dolar!['variacao_pct'] as num).toDouble();
    final historico = (dolar!['historico'] as List).cast<Map<String, dynamic>>();
    final valores = historico.map((p) => (p['valor'] as num).toDouble()).toList();
    final minimo = valores.reduce((a, b) => a < b ? a : b);
    final maximo = valores.reduce((a, b) => a > b ? a : b);
    final positiva = variacao >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: InvestAITheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: InvestAITheme.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dólar hoje', style: GoogleFonts.inter(fontSize: 12, color: InvestAITheme.cinza)),
                    const SizedBox(height: 4),
                    Text('R\$ ${atual.toStringAsFixed(4).replaceAll('.', ',')}',
                        style: GoogleFonts.inter(
                            fontSize: 22, fontWeight: FontWeight.w800, color: InvestAITheme.texto)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (positiva ? InvestAITheme.verde : InvestAITheme.vermelho).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(positiva ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        size: 13, color: positiva ? InvestAITheme.verde : InvestAITheme.vermelho),
                    Text('${variacao.abs().toStringAsFixed(2)}%',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: positiva ? InvestAITheme.verde : InvestAITheme.vermelho,
                        )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 80,
            child: LineChart(
              LineChartData(
                minY: minimo - (maximo - minimo) * 0.1 - 0.001,
                maxY: maximo + (maximo - minimo) * 0.1 + 0.001,
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < valores.length; i++) FlSpot(i.toDouble(), valores[i]),
                    ],
                    isCurved: true,
                    barWidth: 2.5,
                    color: InvestAITheme.verde,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: InvestAITheme.verde.withOpacity(0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(historico.first['data'], style: GoogleFonts.inter(fontSize: 10, color: InvestAITheme.cinza)),
              Text('últimos 30 dias', style: GoogleFonts.inter(fontSize: 10, color: InvestAITheme.cinza)),
              Text(historico.last['data'], style: GoogleFonts.inter(fontSize: 10, color: InvestAITheme.cinza)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaPreview extends StatelessWidget {
  final Meta meta;
  final String Function(num) reais;
  const _MetaPreview({required this.meta, required this.reais});

  @override
  Widget build(BuildContext context) {
    final progresso = (meta.progresso / 100).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: InvestAITheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: InvestAITheme.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(meta.titulo,
                    style: GoogleFonts.inter(
                        fontSize: 13.5, fontWeight: FontWeight.w600, color: InvestAITheme.texto)),
              ),
              Text('${meta.progresso.toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w700, color: InvestAITheme.verde)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progresso,
              minHeight: 6,
              backgroundColor: InvestAITheme.borda,
              valueColor: const AlwaysStoppedAnimation(InvestAITheme.verde),
            ),
          ),
        ],
      ),
    );
  }
}
