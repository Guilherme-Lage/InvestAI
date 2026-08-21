import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/investimento.dart';
import '../services/api_service.dart';
import '../theme.dart';

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
  Map<String, dynamic>? _taxas;
  Map<String, dynamic>? _tesouro;

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

                      // RF20 - score financeiro
                      if (_score != null) ...[
                        _ScoreCard(score: _score!),
                        const SizedBox(height: 20),
                      ],

                      // Taxas oficiais atuais (Selic/CDI/IPCA), Banco Central
                      _MercadoAgora(taxas: _taxas),
                      const SizedBox(height: 20),

                      if (_investimentos.isNotEmpty) ...[
                        _ResumoInvestimentos(investimentos: _investimentos, reais: _reais),
                        const SizedBox(height: 20),
                      ],

                      Text('Sua carteira',
                          style: GoogleFonts.inter(
                              fontSize: 15, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
                      const SizedBox(height: 12),
                      if (_investimentos.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text('Você ainda não cadastrou nenhum investimento.',
                              style: GoogleFonts.inter(fontSize: 13, color: InvestAITheme.cinza)),
                        )
                      else
                        for (final i in _investimentos)
                          _InvestimentoCard(investimento: i, reais: _reais, onExcluir: () => _remover(i)),

                      const SizedBox(height: 24),
                      _SecaoSugestoes(guia: _guia, reais: _reais),

                      if (_guia?['passo'] == 'pronto_para_investir') ...[
                        const SizedBox(height: 24),
                        _TitulosTesouro(tesouro: _tesouro, reais: _reais),
                      ],
                    ],
                  ),
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
                Text('${investimento.tipo} · liquidez ${investimento.liquidez}',
                    style: GoogleFonts.inter(fontSize: 11, color: InvestAITheme.cinza)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(reais(investimento.valorAplicado),
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
              Text('+ ${reais(investimento.rendimentoAtual)}',
                  style: GoogleFonts.inter(fontSize: 11, color: InvestAITheme.verde)),
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
  const _ScoreCard({required this.score});

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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: InvestAITheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: InvestAITheme.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Score financeiro',
              style: GoogleFonts.inter(fontSize: 12, color: InvestAITheme.cinza)),
          const SizedBox(height: 8),
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
        ],
      ),
    );
  }
}

/// Taxas oficiais atuais (Selic, CDI e IPCA acumulado em 12 meses), direto
/// do Banco Central — dado real usado para contextualizar as sugestões de
/// investimento (RF16), já que o app não executa investimentos de verdade.
class _MercadoAgora extends StatelessWidget {
  final Map<String, dynamic>? taxas;
  const _MercadoAgora({required this.taxas});

  @override
  Widget build(BuildContext context) {
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

/// RF14/RF15/RF16 - trilha de investimento: a reserva de emergência é o
/// primeiro passo obrigatório antes de liberar as sugestões personalizadas
/// (RF18) para o perfil de investidor do usuário.
class _SecaoSugestoes extends StatelessWidget {
  final Map<String, dynamic>? guia;
  final String Function(num) reais;
  const _SecaoSugestoes({required this.guia, required this.reais});

  @override
  Widget build(BuildContext context) {
    final liberado = guia?['passo'] == 'pronto_para_investir';
    final reserva = guia?['reserva'] as Map<String, dynamic>?;
    final sugestoes = (guia?['sugestoes_investimento'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sua trilha de investimento',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
        const SizedBox(height: 12),

        _PassoTrilha(
          concluido: liberado,
          titulo: 'Reserva de emergência',
          subtitulo: liberado
              ? 'Concluída'
              : reserva == null
                  ? 'Em andamento'
                  : '${reais(reserva['valor_guardado'] ?? 0)} de ${reais(reserva['valor_ideal_reserva'] ?? 0)}',
        ),
        _PassoTrilha(
          concluido: liberado,
          titulo: 'Sugestões personalizadas',
          subtitulo: liberado
              ? 'Liberadas para o seu perfil'
              : 'Libera automaticamente ao completar a reserva (RF15)',
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
                    'Continue guardando na sua reserva de emergência (aba Metas) para desbloquear as sugestões.',
                    style: GoogleFonts.inter(fontSize: 12.5, color: InvestAITheme.cinza, height: 1.4),
                  ),
                ),
              ],
            ),
          )
        else
          for (final s in sugestoes)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: InvestAITheme.verde.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: InvestAITheme.verde.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(s['nome'] ?? '',
                            style: GoogleFonts.inter(
                                fontSize: 13.5, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: InvestAITheme.verde.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(s['tipo'] ?? '',
                            style: GoogleFonts.inter(fontSize: 10, color: InvestAITheme.verde, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(s['descricao'] ?? '',
                      style: GoogleFonts.inter(fontSize: 12, color: InvestAITheme.cinza, height: 1.4)),
                ],
              ),
            ),
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
  const _TitulosTesouro({required this.tesouro, required this.reais});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        valorAplicado: double.parse(_valorAplicadoCtrl.text.replaceAll(',', '.')),
        rendimentoAtual: double.tryParse(_rendimentoCtrl.text.replaceAll(',', '.')) ?? 0,
        liquidez: _liquidez,
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
                style: const TextStyle(color: InvestAITheme.texto),
                decoration: const InputDecoration(labelText: 'Valor aplicado', prefixText: 'R\$ '),
                validator: (v) {
                  final valor = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (valor == null || valor <= 0) return 'Informe um valor válido';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _rendimentoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: InvestAITheme.texto),
                decoration: const InputDecoration(labelText: 'Rendimento atual', prefixText: 'R\$ '),
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
