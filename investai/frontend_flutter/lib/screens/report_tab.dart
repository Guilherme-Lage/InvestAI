import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/movimentacao.dart';
import '../services/api_service.dart';
import '../theme.dart';

/// Relatório: RF10 (resumo mensal), RF11 (gráfico por categoria), RF12/RF13
/// (alertas de inatividade e de limite) e RF19 (histórico com filtro).
class ReportTab extends StatefulWidget {
  const ReportTab({super.key});

  @override
  State<ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends State<ReportTab> {
  bool _carregando = true;
  String? _erro;
  List<Movimentacao> _itens = [];
  Map<String, dynamic>? _relatorio;
  List<Map<String, dynamic>> _gastosPorCategoria = [];
  Map<String, dynamic> _alertas = {};

  String? _filtroTipo;
  String? _filtroCategoria;
  DateTimeRange? _filtroPeriodo;

  static const _coresGrafico = [
    InvestAITheme.verde,
    Color(0xFFFFB020),
    Color(0xFF5B9BFF),
    InvestAITheme.vermelho,
    Color(0xFFB57BFF),
    Color(0xFF7ADFC7),
  ];

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
        ApiService.listarMovimentacoes(
          tipo: _filtroTipo,
          categoria: _filtroCategoria,
          dataInicio: _formatarData(_filtroPeriodo?.start),
          dataFim: _formatarData(_filtroPeriodo?.end),
        ),
        ApiService.relatorioMensal(),
        ApiService.gastosPorCategoria(),
        ApiService.alertas(),
      ]);
      if (!mounted) return;
      setState(() {
        _itens = resultados[0] as List<Movimentacao>;
        _relatorio = resultados[1] as Map<String, dynamic>;
        _gastosPorCategoria = resultados[2] as List<Map<String, dynamic>>;
        _alertas = resultados[3] as Map<String, dynamic>;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.toString();
        _carregando = false;
      });
    }
  }

  String _reais(num valor) => 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

  String? _formatarData(DateTime? data) {
    if (data == null) return null;
    return '${data.year.toString().padLeft(4, '0')}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')}';
  }

  Future<void> _abrirFormulario({Movimentacao? existente}) async {
    final resultado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormularioMovimentacao(existente: existente),
    );
    if (resultado == true) _carregar();
  }

  Future<void> _remover(Movimentacao m) async {
    try {
      await ApiService.deletarMovimentacao(m.id!);
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
        onPressed: () => _abrirFormulario(),
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
                      Text('Relatório',
                          style: GoogleFonts.inter(
                              fontSize: 24, fontWeight: FontWeight.w800, color: InvestAITheme.texto)),
                      const SizedBox(height: 16),

                      if (_relatorio != null) _ResumoMensal(relatorio: _relatorio!, reais: _reais),
                      const SizedBox(height: 20),

                      // RF12/RF13 - notificações de comportamento financeiro
                      ..._construirAlertas(),

                      // RF11 - gráfico de gastos por categoria
                      Text('Gastos por categoria',
                          style: GoogleFonts.inter(
                              fontSize: 15, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
                      const SizedBox(height: 12),
                      _GraficoGastos(dados: _gastosPorCategoria, cores: _coresGrafico, reais: _reais),
                      const SizedBox(height: 24),

                      // RF19 - histórico completo com filtro
                      Text('Histórico de transações',
                          style: GoogleFonts.inter(
                              fontSize: 15, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
                      const SizedBox(height: 12),
                      _FiltroBar(
                        tipo: _filtroTipo,
                        categoria: _filtroCategoria,
                        periodo: _filtroPeriodo,
                        onTipoChange: (v) {
                          setState(() {
                            _filtroTipo = v;
                            _filtroCategoria = null;
                          });
                          _carregar();
                        },
                        onCategoriaChange: (v) {
                          setState(() => _filtroCategoria = v);
                          _carregar();
                        },
                        onPeriodoChange: (v) {
                          setState(() => _filtroPeriodo = v);
                          _carregar();
                        },
                      ),
                      const SizedBox(height: 16),

                      if (_itens.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text('Nenhuma movimentação encontrada.',
                                style: GoogleFonts.inter(fontSize: 13, color: InvestAITheme.cinza)),
                          ),
                        )
                      else
                        for (final m in _itens)
                          _ItemMovimentacao(
                            m: m,
                            reais: _reais,
                            onEditar: () => _abrirFormulario(existente: m),
                            onExcluir: () => _remover(m),
                          ),
                    ],
                  ),
                ),
    );
  }

  List<Widget> _construirAlertas() {
    final alertaInatividade = _alertas['alerta_inatividade'] == true;
    final alertasCategoria = (_alertas['alertas_categoria'] as List?) ?? [];
    final diasSemRegistrar = _alertas['dias_sem_registrar_gasto'];

    if (!alertaInatividade && alertasCategoria.isEmpty) return [];

    return [
      Text('Notificações',
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
      const SizedBox(height: 12),
      if (alertaInatividade)
        _AlertaCard(
          icone: Icons.notifications_active_outlined,
          titulo: 'Você sumiu um pouco',
          mensagem: 'Nenhuma despesa registrada há $diasSemRegistrar dias.',
        ),
      for (final a in alertasCategoria)
        _AlertaCard(
          icone: Icons.warning_amber_rounded,
          titulo: '${Categorias.rotulo(a['categoria'])} no limite',
          mensagem: '${_reais(a['gasto_atual'])} de ${_reais(a['limite'])} '
              '(${((a['gasto_atual'] as num) / (a['limite'] as num) * 100).toStringAsFixed(0)}% do limite)',
        ),
      const SizedBox(height: 20),
    ];
  }
}

class _AlertaCard extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String mensagem;
  const _AlertaCard({required this.icone, required this.titulo, required this.mensagem});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: InvestAITheme.vermelho.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: InvestAITheme.vermelho.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: InvestAITheme.vermelho, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w700, color: InvestAITheme.vermelho)),
                const SizedBox(height: 2),
                Text(mensagem,
                    style: GoogleFonts.inter(fontSize: 12, color: InvestAITheme.vermelho)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumoMensal extends StatelessWidget {
  final Map<String, dynamic> relatorio;
  final String Function(num) reais;
  const _ResumoMensal({required this.relatorio, required this.reais});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: InvestAITheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: InvestAITheme.borda),
      ),
      child: Row(
        children: [
          Expanded(
            child: _colunaResumo('Entradas', reais(relatorio['total_entradas'] ?? 0), InvestAITheme.verde),
          ),
          Container(width: 1, height: 32, color: InvestAITheme.borda),
          Expanded(
            child: _colunaResumo('Saídas', reais(relatorio['total_saidas'] ?? 0), InvestAITheme.vermelho),
          ),
          Container(width: 1, height: 32, color: InvestAITheme.borda),
          Expanded(
            child: _colunaResumo('Saldo do mês', reais(relatorio['saldo_periodo'] ?? 0), InvestAITheme.texto),
          ),
        ],
      ),
    );
  }

  Widget _colunaResumo(String titulo, String valor, Color cor) {
    return Column(
      children: [
        Text(titulo, style: GoogleFonts.inter(fontSize: 11, color: InvestAITheme.cinza)),
        const SizedBox(height: 4),
        FittedBox(
          child: Text(valor,
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: cor)),
        ),
      ],
    );
  }
}

class _GraficoGastos extends StatelessWidget {
  final List<Map<String, dynamic>> dados;
  final List<Color> cores;
  final String Function(num) reais;
  const _GraficoGastos({required this.dados, required this.cores, required this.reais});

  @override
  Widget build(BuildContext context) {
    if (dados.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: InvestAITheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: InvestAITheme.borda),
        ),
        child: Center(
          child: Text('Nenhum gasto registrado ainda.',
              style: GoogleFonts.inter(fontSize: 13, color: InvestAITheme.cinza)),
        ),
      );
    }

    final total = dados.fold<double>(0, (soma, d) => soma + (d['total'] as num));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: InvestAITheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: InvestAITheme.borda),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 32,
                sections: [
                  for (var i = 0; i < dados.length; i++)
                    PieChartSectionData(
                      value: (dados[i]['total'] as num).toDouble(),
                      color: cores[i % cores.length],
                      showTitle: false,
                      radius: 22,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < dados.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: cores[i % cores.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            Categorias.rotulo(dados[i]['categoria']),
                            style: GoogleFonts.inter(fontSize: 12, color: InvestAITheme.texto),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          total > 0
                              ? '${((dados[i]['total'] as num) / total * 100).toStringAsFixed(0)}%'
                              : '0%',
                          style: GoogleFonts.inter(
                              fontSize: 12, fontWeight: FontWeight.w700, color: InvestAITheme.cinza),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FiltroBar extends StatelessWidget {
  final String? tipo;
  final String? categoria;
  final DateTimeRange? periodo;
  final ValueChanged<String?> onTipoChange;
  final ValueChanged<String?> onCategoriaChange;
  final ValueChanged<DateTimeRange?> onPeriodoChange;

  const _FiltroBar({
    required this.tipo,
    required this.categoria,
    required this.periodo,
    required this.onTipoChange,
    required this.onCategoriaChange,
    required this.onPeriodoChange,
  });

  String _dataCurta(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final categorias = tipo == 'renda' ? Categorias.receita : Categorias.despesa;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _ChipFiltro(label: 'Todos', selecionado: tipo == null, onTap: () => onTipoChange(null)),
          _ChipFiltro(label: 'Receitas', selecionado: tipo == 'renda', onTap: () => onTipoChange('renda')),
          _ChipFiltro(label: 'Despesas', selecionado: tipo == 'gasto', onTap: () => onTipoChange('gasto')),
          Container(width: 1, height: 20, color: InvestAITheme.borda, margin: const EdgeInsets.symmetric(horizontal: 8)),
          _ChipFiltro(label: 'Categoria', selecionado: categoria != null, icone: Icons.arrow_drop_down_rounded,
              onTap: () async {
            final selecionada = await showModalBottomSheet<String?>(
              context: context,
              backgroundColor: InvestAITheme.card,
              builder: (_) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: Text('Todas as categorias', style: GoogleFonts.inter(color: InvestAITheme.texto)),
                      onTap: () => Navigator.pop(context, null),
                    ),
                    for (final c in categorias)
                      ListTile(
                        title: Text(Categorias.rotulo(c), style: GoogleFonts.inter(color: InvestAITheme.texto)),
                        onTap: () => Navigator.pop(context, c),
                      ),
                  ],
                ),
              ),
            );
            onCategoriaChange(selecionada);
          }),
          Container(width: 1, height: 20, color: InvestAITheme.borda, margin: const EdgeInsets.symmetric(horizontal: 8)),
          _ChipFiltro(
            label: periodo == null ? 'Período' : '${_dataCurta(periodo!.start)} - ${_dataCurta(periodo!.end)}',
            selecionado: periodo != null,
            icone: periodo == null ? Icons.calendar_today_rounded : Icons.close_rounded,
            onTap: () async {
              if (periodo != null) {
                onPeriodoChange(null);
                return;
              }
              final hoje = DateTime.now();
              final selecionado = await showDateRangePicker(
                context: context,
                firstDate: DateTime(hoje.year - 5),
                lastDate: hoje,
                initialDateRange: DateTimeRange(start: hoje.subtract(const Duration(days: 30)), end: hoje),
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: InvestAITheme.verde,
                      onPrimary: InvestAITheme.verdeEscuro,
                      surface: InvestAITheme.card,
                      onSurface: InvestAITheme.texto,
                    ),
                  ),
                  child: child!,
                ),
              );
              onPeriodoChange(selecionado);
            },
          ),
        ],
      ),
    );
  }
}

class _ChipFiltro extends StatelessWidget {
  final String label;
  final bool selecionado;
  final VoidCallback onTap;
  final IconData? icone;
  const _ChipFiltro({required this.label, required this.selecionado, required this.onTap, this.icone});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selecionado ? InvestAITheme.verde.withOpacity(0.15) : InvestAITheme.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selecionado ? InvestAITheme.verde : InvestAITheme.borda),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selecionado ? InvestAITheme.verde : InvestAITheme.cinza)),
              if (icone != null) Icon(icone, size: 16, color: selecionado ? InvestAITheme.verde : InvestAITheme.cinza),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemMovimentacao extends StatelessWidget {
  final Movimentacao m;
  final String Function(num) reais;
  final VoidCallback onEditar;
  final VoidCallback onExcluir;

  const _ItemMovimentacao({
    required this.m,
    required this.reais,
    required this.onEditar,
    required this.onExcluir,
  });

  @override
  Widget build(BuildContext context) {
    final cor = m.isRenda ? InvestAITheme.verde : InvestAITheme.vermelho;
    return Dismissible(
      key: ValueKey(m.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onExcluir(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: InvestAITheme.vermelho.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: InvestAITheme.vermelho),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: InvestAITheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: InvestAITheme.borda),
        ),
        child: InkWell(
          onTap: onEditar,
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: cor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(m.isRenda ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                    color: cor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.descricao,
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w600, color: InvestAITheme.texto)),
                    const SizedBox(height: 2),
                    Text('${Categorias.rotulo(m.categoria)} · ${m.data}',
                        style: GoogleFonts.inter(fontSize: 11, color: InvestAITheme.cinza)),
                  ],
                ),
              ),
              Text('${m.isRenda ? '+' : '-'} ${reais(m.valor)}',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: cor)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormularioMovimentacao extends StatefulWidget {
  final Movimentacao? existente;
  const _FormularioMovimentacao({this.existente});

  @override
  State<_FormularioMovimentacao> createState() => _FormularioMovimentacaoState();
}

class _FormularioMovimentacaoState extends State<_FormularioMovimentacao> {
  final _formKey = GlobalKey<FormState>();
  late String _tipo;
  late String _categoria;
  final _descricaoCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  DateTime _data = DateTime.now();
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final e = widget.existente;
    _tipo = e?.tipo ?? 'gasto';
    _categoria = e?.categoria ?? Categorias.despesa.first;
    _descricaoCtrl.text = e?.descricao ?? '';
    _valorCtrl.text = e != null ? e.valor.toStringAsFixed(2) : '';
    if (e != null) {
      _data = DateTime.tryParse(e.data) ?? DateTime.now();
    }
  }

  @override
  void dispose() {
    _descricaoCtrl.dispose();
    _valorCtrl.dispose();
    super.dispose();
  }

  List<String> get _categorias => _tipo == 'renda' ? Categorias.receita : Categorias.despesa;

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });

    final movimentacao = Movimentacao(
      id: widget.existente?.id,
      descricao: _descricaoCtrl.text.trim(),
      tipo: _tipo,
      valor: double.parse(_valorCtrl.text.replaceAll(',', '.')),
      data:
          '${_data.year.toString().padLeft(4, '0')}-${_data.month.toString().padLeft(2, '0')}-${_data.day.toString().padLeft(2, '0')}',
      categoria: _categoria,
    );

    try {
      if (widget.existente != null) {
        await ApiService.atualizarMovimentacao(widget.existente!.id!, movimentacao);
      } else {
        await ApiService.criarMovimentacao(movimentacao);
      }
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
              Text(widget.existente != null ? 'Editar transação' : 'Nova transação',
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
              const SizedBox(height: 20),

              // Tipo: renda ou gasto (RF03/RF04)
              Row(
                children: [
                  Expanded(
                    child: _BotaoTipo(
                      label: 'Despesa',
                      icone: Icons.arrow_upward_rounded,
                      cor: InvestAITheme.vermelho,
                      selecionado: _tipo == 'gasto',
                      onTap: () => setState(() {
                        _tipo = 'gasto';
                        _categoria = Categorias.despesa.first;
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _BotaoTipo(
                      label: 'Receita',
                      icone: Icons.arrow_downward_rounded,
                      cor: InvestAITheme.verde,
                      selecionado: _tipo == 'renda',
                      onTap: () => setState(() {
                        _tipo = 'renda';
                        _categoria = Categorias.receita.first;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descricaoCtrl,
                style: const TextStyle(color: InvestAITheme.texto),
                decoration: const InputDecoration(labelText: 'Descrição'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe uma descrição' : null,
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _valorCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: InvestAITheme.texto),
                decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R\$ '),
                validator: (v) {
                  final valor = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (valor == null || valor <= 0) return 'Informe um valor válido';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Categoria (RF03/RF04/RF11/RF13)
              DropdownButtonFormField<String>(
                initialValue: _categoria,
                dropdownColor: InvestAITheme.card,
                style: const TextStyle(color: InvestAITheme.texto),
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: [
                  for (final c in _categorias) DropdownMenuItem(value: c, child: Text(Categorias.rotulo(c))),
                ],
                onChanged: (v) => setState(() => _categoria = v!),
              ),
              const SizedBox(height: 14),

              InkWell(
                onTap: () async {
                  final selecionada = await showDatePicker(
                    context: context,
                    initialDate: _data,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (selecionada != null) setState(() => _data = selecionada);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Data'),
                  child: Text(
                    '${_data.day.toString().padLeft(2, '0')}/${_data.month.toString().padLeft(2, '0')}/${_data.year}',
                    style: const TextStyle(color: InvestAITheme.texto),
                  ),
                ),
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
                    : Text(widget.existente != null ? 'Salvar alterações' : 'Adicionar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotaoTipo extends StatelessWidget {
  final String label;
  final IconData icone;
  final Color cor;
  final bool selecionado;
  final VoidCallback onTap;

  const _BotaoTipo({
    required this.label,
    required this.icone,
    required this.cor,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selecionado ? cor.withOpacity(0.15) : InvestAITheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selecionado ? cor : InvestAITheme.borda),
        ),
        child: Column(
          children: [
            Icon(icone, color: selecionado ? cor : InvestAITheme.cinza, size: 18),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selecionado ? cor : InvestAITheme.cinza)),
          ],
        ),
      ),
    );
  }
}
