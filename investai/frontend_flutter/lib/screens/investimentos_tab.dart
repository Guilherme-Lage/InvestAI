import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/investimento.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils/formato_moeda.dart';
import '../widgets/glossario.dart';
import 'chat_ia_screen.dart';

/// Investimentos cadastrados pelo usuário + sugestões de investimento
/// (RF16), liberadas apenas depois da reserva de emergência completa
/// (RF14/RF15), personalizadas pelo perfil de investidor (RF18).
class InvestimentosTab extends StatefulWidget {
  const InvestimentosTab({super.key});

  @override
  State<InvestimentosTab> createState() => _InvestimentosTabState();
}

class _InvestimentosTabState extends State<InvestimentosTab> {
  bool _carregando = true;
  String? _erro;
  List<Investimento> _investimentos = [];
  Map<String, dynamic>? _guia;
  Map<String, dynamic>? _score;
  Map<String, dynamic>? _historicoScore;
  Map<String, dynamic>? _taxas;
  Map<String, dynamic>? _tesouro;
  Map<String, dynamic>? _comparacao;

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
        ApiService.listarInvestimentos(),
        ApiService.guiaFinanceiro(),
        ApiService.scoreFinanceiro(),
      ]);
      if (!mounted) return;
      setState(() {
        _investimentos = resultados[0] as List<Investimento>;
        _guia = resultados[1] as Map<String, dynamic>;
        _score = resultados[2] as Map<String, dynamic>;
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

    // O gráfico de evolução é um complemento do score: se falhar, o score
    // atual continua aparecendo normalmente.
    try {
      final historico = await ApiService.historicoScore();
      if (!mounted) return;
      setState(() => _historicoScore = historico);
    } catch (_) {
      // sem histórico agora
    }

    // Depende das taxas externas, então vai junto do bloco tolerante a falha.
    try {
      final comparacao = await ApiService.compararCarteira();
      if (!mounted) return;
      setState(() => _comparacao = comparacao);
    } catch (_) {
      // sem comparação agora; o resto da aba continua funcionando
    }

    // Taxas de mercado e títulos do Tesouro são dado externo: carregados
    // à parte para uma instabilidade nessas APIs não travar a aba Investir.
    try {
      final taxas = await ApiService.taxasMercado();
      if (!mounted) return;
      setState(() => _taxas = taxas);
    } catch (e) {
      if (!mounted) return;
      setState(() => _taxas = null);
    }

    try {
      final tesouro = await ApiService.titulosTesouro();
      if (!mounted) return;
      setState(() => _tesouro = tesouro);
    } catch (e) {
      if (!mounted) return;
      setState(() => _tesouro = null);
    }
  }

  String _reais(num valor) => 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

  Future<void> _abrirFormulario() async {
    final resultado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FormularioInvestimento(),
    );
    if (resultado == true) _carregar();
  }

  Future<void> _remover(Investimento i) async {
    try {
      await ApiService.deletarInvestimento(i.id!);
      _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: InvestAITheme.verde,
        foregroundColor: InvestAITheme.verdeEscuro,
        onPressed: _abrirFormulario,
        child: const Icon(Icons.add_rounded),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: InvestAITheme.verde))
          : _erro != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_erro!, style: GoogleFonts.inter(color: InvestAITheme.cinza)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _carregar, child: const Text('Tentar novamente')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: InvestAITheme.verde,
                  onRefresh: _carregar,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    children: [
                      Text('Investimentos',
                          style: GoogleFonts.inter(
                              fontSize: 24, fontWeight: FontWeight.w800, color: InvestAITheme.texto)),
                      const SizedBox(height: 16),

                      // 1. O dinheiro do usuário vem primeiro: é o que ele
                      // abre a aba para ver.
                      if (_investimentos.isNotEmpty) ...[
                        _ResumoInvestimentos(investimentos: _investimentos, reais: _reais),
                        const SizedBox(height: 20),

                        Text('Sua carteira',
                            style: GoogleFonts.inter(
                                fontSize: 15, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
                        const SizedBox(height: 12),
                        for (final i in _investimentos)
                          _InvestimentoCard(investimento: i, reais: _reais, onExcluir: () => _remover(i)),

                        if (_comparacao != null &&
                            ((_comparacao!['comparacoes'] as List?) ?? []).isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _ComparacaoCarteira(dados: _comparacao!, reais: _reais),
                        ],
                        const SizedBox(height: 24),
                      ],

                      // 2. Onde ele está na jornada e qual é o próximo passo.
                      _SecaoSugestoes(guia: _guia, reais: _reais),

                      // 3. Ferramenta e referência: ficam fechadas para não
                      // competir com o que é ação.
                      const SizedBox(height: 24),
                      Text('Ferramentas',
                          style: GoogleFonts.inter(
                              fontSize: 15, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
                      const SizedBox(height: 12),

                      _SecaoRecolhivel(
                        icone: Icons.calculate_outlined,
                        titulo: 'E se eu guardasse?',
                        resumo: 'Simule quanto renderia por mês',
                        child: _Simulador(reais: _reais, semMoldura: true),
                      ),

                      if (_score != null)
                        _SecaoRecolhivel(
                          icone: Icons.speed_rounded,
                          titulo: 'Seu score financeiro',
                          resumo: '${_score!['score']} de 1000 · ${_score!['classificacao']}',
                          child: _ScoreCard(
                              score: _score!,
                              historico: _historicoScore,
                              semMoldura: true),
                        ),

                      _SecaoRecolhivel(
                        icone: Icons.show_chart_rounded,
                        titulo: 'Mercado hoje',
                        resumo: _taxas == null
                            ? 'Selic, CDI e IPCA'
                            : 'Selic ${_taxas!['selic']}% · CDI ${_taxas!['cdi']}%',
                        child: _MercadoAgora(taxas: _taxas, semMoldura: true),
                      ),

                      // Lista longa de títulos com nomes técnicos: é consulta
                      // de mercado, não recomendação. Continua só para quem já
                      // passou da reserva (RF15).
                      if (_guia?['passo'] == 'pronto_para_investir')
                        _SecaoRecolhivel(
                          icone: Icons.account_balance_outlined,
                          titulo: 'Tesouro Direto agora',
                          resumo: _tesouro == null
                              ? 'Títulos públicos à venda hoje'
                              : 'Atualizado ${_tesouro!['atualizado_em']}',
                          child: _TitulosTesouro(
                              tesouro: _tesouro, reais: _reais, semMoldura: true),
                        ),

                      if (_investimentos.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Text(
                            'Você ainda não cadastrou nenhum investimento. '
                            'Use o + para adicionar o primeiro.',
                            style: GoogleFonts.inter(fontSize: 12.5, color: InvestAITheme.cinza),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

/// Seção que começa fechada, para a aba não despejar tudo de uma vez.
/// O `resumo` aparece no cabeçalho mesmo fechada, de modo que a informação
/// principal continue visível sem precisar abrir.
class _SecaoRecolhivel extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String? resumo;
  final Widget child;

  const _SecaoRecolhivel({
    required this.icone,
    required this.titulo,
    required this.child,
    this.resumo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: InvestAITheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: InvestAITheme.borda),
      ),
      // O Material dá ao ExpansionTile onde desenhar o efeito de toque; sem
      // ele o fundo do Container cobriria o efeito, e o Flutter acusa erro
      // em modo debug.
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Theme(
        // Remove as linhas divisórias padrão do ExpansionTile, que destoam
        // do resto dos cards.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: InvestAITheme.verde,
          collapsedIconColor: InvestAITheme.cinza,
          leading: Icon(icone, color: InvestAITheme.verde, size: 18),
          title: Text(titulo,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: InvestAITheme.texto)),
          subtitle: resumo == null
              ? null
              : Text(resumo!,
                  style: GoogleFonts.inter(
                      fontSize: 11.5, color: InvestAITheme.cinza)),
          children: [child],
        ),
        ),
      ),
    );
  }
}

/// Quanto o usuário deixa de ganhar por ano mantendo cada investimento
/// onde está. É o mesmo cálculo do simulador, mas apontado para o dinheiro
/// que a pessoa realmente tem - bem mais difícil de ignorar.
class _ComparacaoCarteira extends StatelessWidget {
  final Map<String, dynamic> dados;
  final String Function(num) reais;

  const _ComparacaoCarteira({required this.dados, required this.reais});

  @override
  Widget build(BuildContext context) {
    final comparacoes =
        (dados['comparacoes'] as List).cast<Map<String, dynamic>>();
    final total = (dados['ganho_anual_possivel'] ?? 0) as num;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: InvestAITheme.amarelo.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: InvestAITheme.amarelo.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  color: InvestAITheme.amarelo, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Seu dinheiro pode render mais',
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: InvestAITheme.texto)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          for (final c in comparacoes)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${c['investimento']} · ${reais(c['valor_aplicado'])}',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: InvestAITheme.texto),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Rende ${c['taxa_atual']}% ao ano. Em ${c['alternativa']} '
                    '(${c['taxa_alternativa']}%) renderia '
                    '${reais(c['ganho_anual'])} a mais por ano.',
                    style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: InvestAITheme.cinza,
                        height: 1.4),
                  ),
                ],
              ),
            ),

          if (comparacoes.length > 1) ...[
            const Divider(color: InvestAITheme.borda, height: 18),
            Row(
              children: [
                Expanded(
                  child: Text('Total por ano',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: InvestAITheme.cinza)),
                ),
                Text('+ ${reais(total)}',
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: InvestAITheme.amarelo)),
              ],
            ),
          ],

          const SizedBox(height: 8),
          Text(
            'Comparação apenas entre aplicações de resgate diário, com as '
            'taxas de hoje. Não é recomendação de compra ou venda.',
            style: GoogleFonts.inter(
                fontSize: 10.5, color: InvestAITheme.cinza, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// Simulador de aporte: mostra quanto um valor inicial mais aportes
/// mensais renderiam em cada aplicação, com as taxas oficiais do dia.
/// Serve para tornar o juro composto concreto - a pesquisa do relatório
/// apontou falta de conhecimento como principal barreira para investir.
class _Simulador extends StatefulWidget {
  final String Function(num) reais;
  final bool semMoldura;
  const _Simulador({required this.reais, this.semMoldura = false});

  @override
  State<_Simulador> createState() => _SimuladorState();
}

class _SimuladorState extends State<_Simulador> {
  final _inicialCtrl = TextEditingController();
  final _aporteCtrl = TextEditingController(text: '200');

  bool _carregando = false;
  String? _erro;
  Map<String, dynamic>? _resultado;
  int _prazoSelecionado = 0;

  @override
  void dispose() {
    _inicialCtrl.dispose();
    _aporteCtrl.dispose();
    super.dispose();
  }

  double _valor(TextEditingController c) => valorDigitado(c.text) ?? 0;

  Future<void> _simular() async {
    final inicial = _valor(_inicialCtrl);
    final aporte = _valor(_aporteCtrl);
    if (inicial <= 0 && aporte <= 0) {
      setState(() => _erro = 'Informe um valor inicial ou um aporte mensal.');
      return;
    }

    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final r = await ApiService.simularAporte(
          valorInicial: inicial, aporteMensal: aporte);
      if (!mounted) return;
      setState(() {
        _resultado = r;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não consegui simular agora. Tente de novo.';
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final aplicacoes =
        (_resultado?['aplicacoes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final prazos =
        (_resultado?['prazos_meses'] as List?)?.cast<int>() ?? const <int>[];

    return Container(
      padding: EdgeInsets.all(widget.semMoldura ? 0 : 16),
      decoration: widget.semMoldura
          ? null
          : BoxDecoration(
              color: InvestAITheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: InvestAITheme.borda),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.semMoldura) ...[
            Row(
              children: [
                const Icon(Icons.calculate_outlined,
                    color: InvestAITheme.verde, size: 18),
                const SizedBox(width: 8),
                Text('E se eu guardasse?',
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: InvestAITheme.texto)),
              ],
            ),
            const SizedBox(height: 4),
          ],
          Text('Veja quanto renderia em cada aplicação, com as taxas de hoje.',
              style:
                  GoogleFonts.inter(fontSize: 12, color: InvestAITheme.cinza)),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inicialCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: const [FormatadorMilhar()],
                  style: const TextStyle(color: InvestAITheme.texto),
                  decoration: const InputDecoration(
                    labelText: 'Tenho hoje',
                    hintText: '0,00',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _aporteCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: const [FormatadorMilhar()],
                  style: const TextStyle(color: InvestAITheme.texto),
                  decoration: const InputDecoration(
                    labelText: 'Por mês',
                    hintText: '0,00',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _carregando ? null : _simular,
              child: _carregando
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: InvestAITheme.verdeEscuro))
                  : const Text('Simular'),
            ),
          ),

          if (_erro != null) ...[
            const SizedBox(height: 12),
            Text(_erro!,
                style: GoogleFonts.inter(
                    fontSize: 12, color: InvestAITheme.vermelho)),
          ],

          if (aplicacoes.isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                for (var i = 0; i < prazos.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_rotuloPrazo(prazos[i])),
                      selected: _prazoSelecionado == i,
                      onSelected: (_) =>
                          setState(() => _prazoSelecionado = i),
                      labelStyle: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _prazoSelecionado == i
                            ? InvestAITheme.verdeEscuro
                            : InvestAITheme.cinza,
                      ),
                      selectedColor: InvestAITheme.verde,
                      backgroundColor: InvestAITheme.fundo,
                      side: const BorderSide(color: InvestAITheme.borda),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < aplicacoes.length; i++)
              _LinhaSimulacao(
                aplicacao: aplicacoes[i],
                indicePrazo: _prazoSelecionado,
                destaque: i == 0,
                reais: widget.reais,
              ),
            const SizedBox(height: 10),
            Text(
              'Projeção com as taxas de hoje mantidas constantes. '
              'Rendimento passado ou atual não garante o futuro.',
              style: GoogleFonts.inter(
                  fontSize: 10.5, color: InvestAITheme.cinza, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  String _rotuloPrazo(int meses) {
    if (meses % 12 != 0) return '$meses meses';
    final anos = meses ~/ 12;
    return anos == 1 ? '1 ano' : '$anos anos';
  }
}

class _LinhaSimulacao extends StatelessWidget {
  final Map<String, dynamic> aplicacao;
  final int indicePrazo;
  final bool destaque;
  final String Function(num) reais;

  const _LinhaSimulacao({
    required this.aplicacao,
    required this.indicePrazo,
    required this.destaque,
    required this.reais,
  });

  @override
  Widget build(BuildContext context) {
    final projecoes =
        (aplicacao['projecoes'] as List).cast<Map<String, dynamic>>();
    final p = projecoes[indicePrazo.clamp(0, projecoes.length - 1)];
    final cor = destaque ? InvestAITheme.verde : InvestAITheme.texto;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: destaque
            ? InvestAITheme.verde.withValues(alpha: 0.08)
            : InvestAITheme.fundo,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: destaque
              ? InvestAITheme.verde.withValues(alpha: 0.4)
              : InvestAITheme.borda,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(aplicacao['nome'] as String,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cor)),
                Text('${aplicacao['taxa_anual']}% ao ano',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: InvestAITheme.cinza)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(reais(p['valor_final'] as num),
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: cor)),
              Text('rende ${reais(p['rendimento'] as num)}',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: InvestAITheme.cinza)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResumoInvestimentos extends StatelessWidget {
  final List<Investimento> investimentos;
  final String Function(num) reais;
  const _ResumoInvestimentos({required this.investimentos, required this.reais});

  @override
  Widget build(BuildContext context) {
    final totalAplicado = investimentos.fold<double>(0, (s, i) => s + i.valorAplicado);
    final totalRendimento = investimentos.fold<double>(0, (s, i) => s + i.rendimentoAtual);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: InvestAITheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: InvestAITheme.borda),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total investido', style: GoogleFonts.inter(fontSize: 11, color: InvestAITheme.cinza)),
                const SizedBox(height: 4),
                Text(reais(totalAplicado),
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: InvestAITheme.texto)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rendimento', style: GoogleFonts.inter(fontSize: 11, color: InvestAITheme.cinza)),
                const SizedBox(height: 4),
                Text('+ ${reais(totalRendimento)}',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: InvestAITheme.verde)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InvestimentoCard extends StatelessWidget {
  final Investimento investimento;
  final String Function(num) reais;
  final VoidCallback onExcluir;
  const _InvestimentoCard({required this.investimento, required this.reais, required this.onExcluir});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: InvestAITheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: InvestAITheme.borda),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: InvestAITheme.verde.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.trending_up_rounded, color: InvestAITheme.verde, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(investimento.nome,
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: InvestAITheme.texto)),
                const SizedBox(height: 2),
                Text(
                    investimento.calculadoAutomaticamente
                        ? '${investimento.tipo} · ${investimento.taxaAnual?.toStringAsFixed(2)}% a.a.'
                        : '${investimento.tipo} · liquidez ${investimento.liquidez}',
                    style: GoogleFonts.inter(fontSize: 11, color: InvestAITheme.cinza)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(reais(investimento.valorAtual),
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Deixa claro quando o número se atualiza sozinho, para
                  // o usuário não achar que precisa editar na mão.
                  if (investimento.calculadoAutomaticamente) ...[
                    const Icon(Icons.autorenew_rounded,
                        size: 11, color: InvestAITheme.verde),
                    const SizedBox(width: 3),
                  ],
                  Text('+ ${reais(investimento.rendimentoAtual)}',
                      style: GoogleFonts.inter(fontSize: 11, color: InvestAITheme.verde)),
                ],
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: InvestAITheme.cinza, size: 18),
            onPressed: onExcluir,
          ),
        ],
      ),
    );
  }
}

/// RF20 - score financeiro em escala 0-1000 (padrão score de crédito),
/// com classificação qualitativa (Ruim/Regular/Bom/Excelente).
class _ScoreCard extends StatelessWidget {
  final Map<String, dynamic> score;
  final Map<String, dynamic>? historico;
  final bool semMoldura;
  const _ScoreCard({required this.score, this.historico, this.semMoldura = false});

  Color get _cor {
    final valor = (score['score'] ?? 0) as int;
    if (valor >= 650) return InvestAITheme.verde;
    if (valor >= 400) return const Color(0xFFFFB020);
    return InvestAITheme.vermelho;
  }

  @override
  Widget build(BuildContext context) {
    final valor = (score['score'] ?? 0) as int;
    final maximo = (score['score_maximo'] ?? 1000) as int;
    final classificacao = score['classificacao'] ?? '';
    final progresso = maximo > 0 ? (valor / maximo).clamp(0.0, 1.0) : 0.0;

    return Container(
      width: double.infinity,
      // Sem moldura quando está dentro de uma seção recolhível, que já
      // desenha o card - senão fica card dentro de card.
      padding: EdgeInsets.all(semMoldura ? 0 : 18),
      decoration: semMoldura
          ? null
          : BoxDecoration(
              color: InvestAITheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: InvestAITheme.borda),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!semMoldura) ...[
            Text('Score financeiro',
                style: GoogleFonts.inter(fontSize: 12, color: InvestAITheme.cinza)),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$valor',
                  style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w800, color: _cor)),
              Padding(
                padding: const EdgeInsets.only(bottom: 5, left: 4),
                child: Text('de $maximo · $classificacao',
                    style: GoogleFonts.inter(
                        fontSize: 12.5, fontWeight: FontWeight.w600, color: InvestAITheme.cinza)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progresso,
              minHeight: 8,
              backgroundColor: InvestAITheme.borda,
              valueColor: AlwaysStoppedAnimation(_cor),
            ),
          ),
          if (historico != null) ...[
            const SizedBox(height: 18),
            _EvolucaoScore(historico: historico!, cor: _cor),
          ],
        ],
      ),
    );
  }
}

/// Evolução do score ao longo do tempo. Cada ponto é um dia em que o
/// usuário abriu esta aba, então o gráfico começa vazio e vai se formando
/// com o uso - não há como calcular o score de datas passadas.
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
        const SizedBox(height: 10),
        SizedBox(
          height: 80,
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
                  belowBarData: BarAreaData(show: true, color: cor.withOpacity(0.12)),
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

/// Taxas oficiais atuais (Selic, CDI e IPCA acumulado em 12 meses), direto
/// do Banco Central — dado real usado para contextualizar as sugestões de
/// investimento (RF16), já que o app não executa investimentos de verdade.
class _MercadoAgora extends StatelessWidget {
  final Map<String, dynamic>? taxas;
  final bool semMoldura;
  const _MercadoAgora({required this.taxas, this.semMoldura = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(semMoldura ? 0 : 18),
      decoration: semMoldura
          ? null
          : BoxDecoration(
              color: InvestAITheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: InvestAITheme.borda),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!semMoldura) ...[
            Row(
              children: [
                const Icon(Icons.public_rounded, color: InvestAITheme.verde, size: 16),
                const SizedBox(width: 6),
                Text('Mercado agora',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
                const Spacer(),
                if (taxas != null)
                  Text('Banco Central · ${taxas!['atualizado_em']}',
                      style: GoogleFonts.inter(fontSize: 10, color: InvestAITheme.cinza)),
              ],
            ),
            const SizedBox(height: 14),
          ],
          if (taxas == null)
            Text('Taxas indisponíveis no momento.',
                style: GoogleFonts.inter(fontSize: 12.5, color: InvestAITheme.cinza))
          else
            Row(
              children: [
                Expanded(child: _taxaItem('Selic', taxas!['selic'])),
                Expanded(child: _taxaItem('CDI', taxas!['cdi'])),
                Expanded(child: _taxaItem('IPCA 12m', taxas!['ipca'])),
              ],
            ),
        ],
      ),
    );
  }

  Widget _taxaItem(String label, num valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: InvestAITheme.cinza)),
        const SizedBox(height: 3),
        Text('${valor.toStringAsFixed(2)}%',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: InvestAITheme.verde)),
      ],
    );
  }
}

/// RF14/RF15/RF16 - trilha de investimento, na mesma ordem do guia
/// financeiro: saldo no positivo, depois a reserva de emergência, e só
/// então as sugestões personalizadas (RF18) para o perfil do usuário.
class _SecaoSugestoes extends StatelessWidget {
  final Map<String, dynamic>? guia;
  final String Function(num) reais;
  const _SecaoSugestoes({required this.guia, required this.reais});

  @override
  Widget build(BuildContext context) {
    final liberado = guia?['passo'] == 'pronto_para_investir';
    final saldoNegativo = guia?['passo'] == 'saldo_negativo';
    final reserva = guia?['reserva'] as Map<String, dynamic>?;
    // A reserva pode estar completa mesmo com as sugestões bloqueadas: o
    // saldo negativo vem antes dela no guia.
    final reservaCompleta = reserva?['sugestoes_investimento_liberadas'] == true;
    final sugestoes = (guia?['sugestoes_investimento'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sua trilha de investimento',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
        const SizedBox(height: 12),

        _PassoTrilha(
          concluido: !saldoNegativo,
          titulo: 'Saldo no positivo',
          subtitulo: saldoNegativo
              ? 'Saldo atual: ${reais(guia?['saldo'] ?? 0)}'
              : 'Suas receitas cobrem seus gastos',
        ),
        _PassoTrilha(
          concluido: reservaCompleta,
          titulo: 'Reserva de emergência',
          subtitulo: reservaCompleta
              ? 'Concluída'
              : reserva == null || ((reserva['valor_ideal_reserva'] ?? 0) as num) <= 0
                  ? 'Registre uma despesa (aba Relatório) para calcularmos sua meta'
                  : '${reais(reserva['valor_guardado'] ?? 0)} de ${reais(reserva['valor_ideal_reserva'] ?? 0)}',
        ),
        _PassoTrilha(
          concluido: liberado,
          titulo: 'Sugestões personalizadas',
          subtitulo: liberado
              ? 'Liberadas para o seu perfil'
              : 'Libera automaticamente quando os passos acima estiverem concluídos (RF15)',
        ),
        const SizedBox(height: 8),

        if (!liberado)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: InvestAITheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: InvestAITheme.borda),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded, color: InvestAITheme.cinza, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    saldoNegativo
                        ? 'Seu saldo no app está negativo: os gastos registrados passam das '
                            'receitas. Antes de investir, as contas precisam fechar no positivo. '
                            'Se você importou um extrato, pode faltar o dinheiro que já estava na '
                            'conta antes do período: registre-o como receita (ex.: "Saldo inicial").'
                        : 'Continue guardando na sua reserva de emergência (aba Metas) para desbloquear as sugestões.',
                    style: GoogleFonts.inter(fontSize: 12.5, color: InvestAITheme.cinza, height: 1.4),
                  ),
                ),
              ],
            ),
          )
        else
          _SugestoesPerfil(
              sugestoes: sugestoes.cast<Map<String, dynamic>>()),
      ],
    );
  }
}

/// Mostra uma sugestão em destaque com o motivo em linguagem comum, e
/// guarda as demais atrás de um link. Uma lista com três produtos de renda
/// fixa não ajuda quem nunca investiu a decidir - só informa.
class _SugestoesPerfil extends StatefulWidget {
  final List<Map<String, dynamic>> sugestoes;
  const _SugestoesPerfil({required this.sugestoes});

  @override
  State<_SugestoesPerfil> createState() => _SugestoesPerfilState();
}

class _SugestoesPerfilState extends State<_SugestoesPerfil> {
  bool _mostrarOutras = false;

  @override
  Widget build(BuildContext context) {
    if (widget.sugestoes.isEmpty) return const SizedBox.shrink();

    final principal = widget.sugestoes.first;
    final outras = widget.sugestoes.skip(1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: InvestAITheme.verde.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: InvestAITheme.verde.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Para começar, considere',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: InvestAITheme.verde)),
              const SizedBox(height: 6),
              Text(principal['nome'] ?? '',
                  style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: InvestAITheme.texto)),
              const SizedBox(height: 8),
              TextoComGlossario(
                  principal['motivo'] ?? principal['descricao'] ?? '',
                  estilo: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: InvestAITheme.texto,
                      height: 1.5)),
              if (principal['motivo'] != null &&
                  (principal['descricao'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                TextoComGlossario(principal['descricao'],
                    estilo: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: InvestAITheme.cinza,
                        height: 1.4)),
              ],
              const SizedBox(height: 12),
              // Atalho para a IA, que já conhece a situação financeira da
              // pessoa e pode explicar com os números dela.
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ChatIaScreen(
                    perguntaInicial:
                        'Me explica o que é ${principal['nome']} como se eu '
                        'nunca tivesse investido, e por que isso faz sentido '
                        'pra minha situação.',
                  ),
                )),
                icon: const Icon(Icons.auto_awesome_rounded, size: 15),
                label: const Text('Me explica isso'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: InvestAITheme.verde,
                  side: BorderSide(
                      color: InvestAITheme.verde.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        if (outras.isNotEmpty) ...[
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => setState(() => _mostrarOutras = !_mostrarOutras),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _mostrarOutras
                  ? 'Esconder outras opções'
                  : 'Ver outras ${outras.length} opções do seu perfil',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: InvestAITheme.verde),
            ),
          ),
          if (_mostrarOutras)
            for (final s in outras)
              Container(
                margin: const EdgeInsets.only(top: 8),
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
                          child: Text(s['nome'] ?? '',
                              style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: InvestAITheme.texto)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: InvestAITheme.verde.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(s['tipo'] ?? '',
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: InvestAITheme.verde,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(s['descricao'] ?? '',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: InvestAITheme.cinza,
                            height: 1.4)),
                  ],
                ),
              ),
        ],
      ],
    );
  }
}

/// Títulos do Tesouro Direto sendo ofertados agora de verdade — nome,
/// taxa e preço reais, direto do Tesouro Transparente (dado público do
/// governo). Diferente das sugestões educativas acima, isto é o mercado
/// real no momento em que a tela foi aberta.
class _TitulosTesouro extends StatelessWidget {
  final Map<String, dynamic>? tesouro;
  final String Function(num) reais;
  final bool semMoldura;
  const _TitulosTesouro(
      {required this.tesouro, required this.reais, this.semMoldura = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!semMoldura) ...[
          Row(
            children: [
              Expanded(
                child: Text('Tesouro Direto agora',
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
              ),
              if (tesouro != null)
                Text('atualizado ${tesouro!['atualizado_em']}',
                    style: GoogleFonts.inter(fontSize: 10, color: InvestAITheme.cinza)),
            ],
          ),
          const SizedBox(height: 4),
        ],
        Text('Títulos públicos reais sendo vendidos neste momento (Tesouro Transparente).',
            style: GoogleFonts.inter(fontSize: 11.5, color: InvestAITheme.cinza)),
        const SizedBox(height: 12),
        if (tesouro == null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: InvestAITheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: InvestAITheme.borda),
            ),
            child: Text('Indisponível no momento. Puxe a tela pra baixo pra tentar de novo.',
                style: GoogleFonts.inter(fontSize: 12.5, color: InvestAITheme.cinza)),
          )
        else
          for (final t in (tesouro!['titulos'] as List).cast<Map<String, dynamic>>())
            _TituloTesouroCard(titulo: t, reais: reais),
      ],
    );
  }
}

class _TituloTesouroCard extends StatelessWidget {
  final Map<String, dynamic> titulo;
  final String Function(num) reais;
  const _TituloTesouroCard({required this.titulo, required this.reais});

  String _vencimentoFormatado(String iso) {
    final data = DateTime.tryParse(iso);
    if (data == null) return iso;
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  @override
  Widget build(BuildContext context) {
    final taxa = (titulo['taxa_ano'] as num).toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: InvestAITheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: InvestAITheme.borda),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo['nome'],
                    style: GoogleFonts.inter(
                        fontSize: 13.5, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
                const SizedBox(height: 2),
                Text('vence em ${_vencimentoFormatado(titulo['vencimento'])} · a partir de ${reais(titulo['investimento_minimo'])}',
                    style: GoogleFonts.inter(fontSize: 11, color: InvestAITheme.cinza)),
              ],
            ),
          ),
          Text('${taxa.toStringAsFixed(2)}%',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: InvestAITheme.verde)),
        ],
      ),
    );
  }
}

class _PassoTrilha extends StatelessWidget {
  final bool concluido;
  final String titulo;
  final String subtitulo;
  const _PassoTrilha({required this.concluido, required this.titulo, required this.subtitulo});

  @override
  Widget build(BuildContext context) {
    final cor = concluido ? InvestAITheme.verde : InvestAITheme.cinza;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(concluido ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: cor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: GoogleFonts.inter(
                        fontSize: 13.5, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
                Text(subtitulo, style: GoogleFonts.inter(fontSize: 11.5, color: InvestAITheme.cinza)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormularioInvestimento extends StatefulWidget {
  const _FormularioInvestimento();

  @override
  State<_FormularioInvestimento> createState() => _FormularioInvestimentoState();
}

class _FormularioInvestimentoState extends State<_FormularioInvestimento> {
  final _formKey = GlobalKey<FormState>();
  final _nomeCtrl = TextEditingController();
  final _tipoCtrl = TextEditingController();
  final _valorAplicadoCtrl = TextEditingController();
  final _rendimentoCtrl = TextEditingController(text: '0');
  String _liquidez = 'diaria';
  String? _indexador = 'selic';
  DateTime _dataAplicacao = DateTime.now();
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _tipoCtrl.dispose();
    _valorAplicadoCtrl.dispose();
    _rendimentoCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });

    try {
      await ApiService.criarInvestimento(Investimento(
        nome: _nomeCtrl.text.trim(),
        tipo: _tipoCtrl.text.trim(),
        valorAplicado: valorDigitado(_valorAplicadoCtrl.text) ?? 0,
        rendimentoAtual: valorDigitado(_rendimentoCtrl.text) ?? 0,
        liquidez: _liquidez,
        indexador: _indexador,
        dataAplicacao:
            '${_dataAplicacao.year}-${_dataAplicacao.month.toString().padLeft(2, '0')}-${_dataAplicacao.day.toString().padLeft(2, '0')}',
      ));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _erro = '$e';
        _salvando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: const BoxDecoration(
          color: InvestAITheme.fundo,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: InvestAITheme.borda),
            left: BorderSide(color: InvestAITheme.borda),
            right: BorderSide(color: InvestAITheme.borda),
          ),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: InvestAITheme.borda, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text('Novo investimento',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nomeCtrl,
                style: const TextStyle(color: InvestAITheme.texto),
                decoration: const InputDecoration(labelText: 'Nome (ex.: Tesouro Selic)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe um nome' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _tipoCtrl,
                style: const TextStyle(color: InvestAITheme.texto),
                decoration: const InputDecoration(labelText: 'Tipo (ex.: CDB, LCI, Ações)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o tipo' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _valorAplicadoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: const [FormatadorMilhar()],
                style: const TextStyle(color: InvestAITheme.texto),
                decoration: const InputDecoration(labelText: 'Valor aplicado', prefixText: 'R\$ '),
                validator: (v) {
                  final valor = valorDigitado(v ?? '');
                  if (valor == null || valor <= 0) return 'Informe um valor válido';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              // Escolhendo o índice, o app calcula o rendimento sozinho a
              // partir das taxas do dia - o campo manual some.
              DropdownButtonFormField<String?>(
                initialValue: _indexador,
                dropdownColor: InvestAITheme.card,
                isExpanded: true,
                style: const TextStyle(color: InvestAITheme.texto),
                decoration: const InputDecoration(
                  labelText: 'Acompanha qual índice?',
                  helperText: 'O rendimento se atualiza sozinho',
                ),
                items: [
                  for (final e in Indexadores.rotulos.entries)
                    DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis)),
                  const DropdownMenuItem(
                      value: null,
                      child: Text('Informar o rendimento na mão',
                          style: TextStyle(fontSize: 13))),
                ],
                onChanged: (v) => setState(() => _indexador = v),
              ),
              const SizedBox(height: 14),
              if (_indexador == null)
                TextFormField(
                  controller: _rendimentoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: const [FormatadorMilhar()],
                  style: const TextStyle(color: InvestAITheme.texto),
                  decoration: const InputDecoration(labelText: 'Rendimento atual', prefixText: 'R\$ '),
                )
              else
                InkWell(
                  onTap: () async {
                    final escolhida = await showDatePicker(
                      context: context,
                      initialDate: _dataAplicacao,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (escolhida != null) {
                      setState(() => _dataAplicacao = escolhida);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Aplicado em',
                      helperText: 'Usado para calcular quanto já rendeu',
                    ),
                    child: Text(
                      '${_dataAplicacao.day.toString().padLeft(2, '0')}/'
                      '${_dataAplicacao.month.toString().padLeft(2, '0')}/'
                      '${_dataAplicacao.year}',
                      style: const TextStyle(color: InvestAITheme.texto),
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _liquidez,
                dropdownColor: InvestAITheme.card,
                style: const TextStyle(color: InvestAITheme.texto),
                decoration: const InputDecoration(labelText: 'Liquidez'),
                items: const [
                  DropdownMenuItem(value: 'diaria', child: Text('Diária')),
                  DropdownMenuItem(value: 'carencia', child: Text('Com carência')),
                  DropdownMenuItem(value: 'no vencimento', child: Text('No vencimento')),
                ],
                onChanged: (v) => setState(() => _liquidez = v!),
              ),
              if (_erro != null) ...[
                const SizedBox(height: 14),
                Text(_erro!, style: GoogleFonts.inter(fontSize: 12, color: InvestAITheme.vermelho)),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _salvando ? null : _salvar,
                child: _salvando
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: InvestAITheme.verdeEscuro))
                    : const Text('Adicionar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
