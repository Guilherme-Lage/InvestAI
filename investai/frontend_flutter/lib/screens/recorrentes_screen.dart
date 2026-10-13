import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/movimentacao.dart' show Categorias;
import '../models/recorrencia.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils/formato_moeda.dart';

/// Receitas e despesas que se repetem todo mês. O backend lança cada uma
/// sozinho no dia combinado; aqui o usuário cadastra, edita, pausa e
/// exclui.
class RecorrentesScreen extends StatefulWidget {
  const RecorrentesScreen({super.key});

  @override
  State<RecorrentesScreen> createState() => _RecorrentesScreenState();
}

class _RecorrentesScreenState extends State<RecorrentesScreen> {
  bool _carregando = true;
  String? _erro;
  List<Recorrencia> _itens = [];

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
      final itens = await ApiService.listarRecorrencias();
      if (!mounted) return;
      setState(() {
        _itens = itens;
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

  void _avisar(Object erro) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$erro')));
  }

  Future<void> _abrirFormulario({Recorrencia? existente}) async {
    final resultado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormularioRecorrencia(existente: existente),
    );
    if (resultado == true) _carregar();
  }

  Future<void> _alternarAtiva(Recorrencia r, bool ativa) async {
    try {
      await ApiService.atualizarRecorrencia(r.id!, {'ativa': ativa});
    } catch (e) {
      _avisar(e);
    }
    _carregar();
  }

  Future<void> _excluir(Recorrencia r) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: InvestAITheme.card,
        title: Text('Excluir "${r.descricao}"?',
            style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
        content: Text(
          'Ela deixa de ser lançada. O que já foi lançado continua no seu histórico.',
          style: GoogleFonts.inter(fontSize: 13, color: InvestAITheme.cinza),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: InvestAITheme.vermelho),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmou != true) return;
    try {
      await ApiService.deletarRecorrencia(r.id!);
    } catch (e) {
      _avisar(e);
    }
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: InvestAITheme.card,
        foregroundColor: InvestAITheme.texto,
        title: Text('Recorrentes',
            style: GoogleFonts.inter(
                fontSize: 17, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
      ),
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
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  children: [
                    Text(
                      'Contas e receitas que se repetem todo mês. O InvestAI lança '
                      'cada uma sozinho no dia combinado.',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: InvestAITheme.cinza, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    if (_itens.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            'Nenhuma recorrência ainda.\nUse o + para cadastrar o aluguel, '
                            'uma assinatura ou o salário.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                                fontSize: 13, color: InvestAITheme.cinza, height: 1.4),
                          ),
                        ),
                      )
                    else ...[
                      _ResumoFixos(itens: _itens, reais: _reais),
                      const SizedBox(height: 16),
                      for (final r in _itens)
                        _ItemRecorrencia(
                          r: r,
                          reais: _reais,
                          onEditar: () => _abrirFormulario(existente: r),
                          onAlternar: (ativa) => _alternarAtiva(r, ativa),
                          onExcluir: () => _excluir(r),
                        ),
                    ],
                  ],
                ),
    );
  }
}

/// Quanto do mês já está comprometido antes de qualquer gasto do dia a dia.
class _ResumoFixos extends StatelessWidget {
  final List<Recorrencia> itens;
  final String Function(num) reais;
  const _ResumoFixos({required this.itens, required this.reais});

  @override
  Widget build(BuildContext context) {
    final ativas = itens.where((r) => r.ativa);
    final despesas = ativas.where((r) => !r.isRenda).fold<double>(0, (s, r) => s + r.valor);
    final receitas = ativas.where((r) => r.isRenda).fold<double>(0, (s, r) => s + r.valor);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: InvestAITheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: InvestAITheme.borda),
      ),
      child: Row(
        children: [
          Expanded(child: _coluna('Receitas fixas/mês', reais(receitas), InvestAITheme.verde)),
          Container(width: 1, height: 32, color: InvestAITheme.borda),
          Expanded(child: _coluna('Despesas fixas/mês', reais(despesas), InvestAITheme.vermelho)),
        ],
      ),
    );
  }

  Widget _coluna(String titulo, String valor, Color cor) {
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

class _ItemRecorrencia extends StatelessWidget {
  final Recorrencia r;
  final String Function(num) reais;
  final VoidCallback onEditar;
  final ValueChanged<bool> onAlternar;
  final VoidCallback onExcluir;

  const _ItemRecorrencia({
    required this.r,
    required this.reais,
    required this.onEditar,
    required this.onAlternar,
    required this.onExcluir,
  });

  @override
  Widget build(BuildContext context) {
    final cor = r.isRenda ? InvestAITheme.verde : InvestAITheme.vermelho;
    return Opacity(
      opacity: r.ativa ? 1 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        decoration: BoxDecoration(
          color: InvestAITheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: InvestAITheme.borda),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onEditar,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.descricao,
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w600, color: InvestAITheme.texto)),
                    const SizedBox(height: 2),
                    Text(
                      '${Categorias.rotulo(r.categoria)} · todo dia ${r.diaMes}'
                      '${r.ativa ? '' : ' · pausada'}',
                      style: GoogleFonts.inter(fontSize: 11, color: InvestAITheme.cinza),
                    ),
                    const SizedBox(height: 4),
                    Text('${r.isRenda ? '+' : '-'} ${reais(r.valor)}',
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w700, color: cor)),
                  ],
                ),
              ),
            ),
            Switch(
              value: r.ativa,
              activeThumbColor: InvestAITheme.verde,
              onChanged: onAlternar,
            ),
            IconButton(
              tooltip: 'Excluir',
              icon: const Icon(Icons.delete_outline_rounded, color: InvestAITheme.cinza, size: 20),
              onPressed: onExcluir,
            ),
          ],
        ),
      ),
    );
  }
}

class _FormularioRecorrencia extends StatefulWidget {
  final Recorrencia? existente;
  const _FormularioRecorrencia({this.existente});

  @override
  State<_FormularioRecorrencia> createState() => _FormularioRecorrenciaState();
}

class _FormularioRecorrenciaState extends State<_FormularioRecorrencia> {
  final _formKey = GlobalKey<FormState>();
  late String _tipo;
  late String _categoria;
  late int _diaMes;
  final _descricaoCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final e = widget.existente;
    _tipo = e?.tipo ?? 'gasto';
    _categoria = e?.categoria ?? 'contas_fixas';
    _diaMes = e?.diaMes ?? DateTime.now().day;
    _descricaoCtrl.text = e?.descricao ?? '';
    _valorCtrl.text = e != null ? e.valor.toStringAsFixed(2).replaceAll('.', ',') : '';
  }

  @override
  void dispose() {
    _descricaoCtrl.dispose();
    _valorCtrl.dispose();
    super.dispose();
  }

  List<String> get _categorias => _tipo == 'renda' ? Categorias.receita : Categorias.despesa;

  void _trocarTipo(String tipo) {
    setState(() {
      _tipo = tipo;
      _categoria = tipo == 'renda' ? Categorias.receita.first : 'contas_fixas';
    });
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });

    final recorrencia = Recorrencia(
      descricao: _descricaoCtrl.text.trim(),
      tipo: _tipo,
      valor: valorDigitado(_valorCtrl.text) ?? 0,
      categoria: _categoria,
      diaMes: _diaMes,
    );

    try {
      if (widget.existente != null) {
        await ApiService.atualizarRecorrencia(widget.existente!.id!, recorrencia.toJson());
      } else {
        await ApiService.criarRecorrencia(recorrencia);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: InvestAITheme.borda, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Text(widget.existente != null ? 'Editar recorrência' : 'Nova recorrência',
                    style: GoogleFonts.inter(
                        fontSize: 18, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
                const SizedBox(height: 20),

                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'gasto', label: Text('Despesa')),
                    ButtonSegment(value: 'renda', label: Text('Receita')),
                  ],
                  selected: {_tipo},
                  showSelectedIcon: false,
                  onSelectionChanged: (selecao) => _trocarTipo(selecao.first),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _descricaoCtrl,
                  style: const TextStyle(color: InvestAITheme.texto),
                  decoration: const InputDecoration(
                      labelText: 'Descrição', hintText: 'Ex.: Aluguel, Internet, Salário'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe uma descrição' : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _valorCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: const [FormatadorMilhar()],
                  style: const TextStyle(color: InvestAITheme.texto),
                  decoration: const InputDecoration(labelText: 'Valor por mês', prefixText: 'R\$ '),
                  validator: (v) {
                    final valor = valorDigitado(v ?? '');
                    if (valor == null || valor <= 0) return 'Informe um valor válido';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  // A chave recria o campo ao trocar despesa/receita, já que
                  // a lista de categorias muda junto.
                  key: ValueKey(_tipo),
                  initialValue: _categorias.contains(_categoria) ? _categoria : _categorias.first,
                  dropdownColor: InvestAITheme.card,
                  style: const TextStyle(color: InvestAITheme.texto),
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: [
                    for (final c in _categorias)
                      DropdownMenuItem(value: c, child: Text(Categorias.rotulo(c))),
                  ],
                  onChanged: (v) => setState(() => _categoria = v!),
                ),
                const SizedBox(height: 14),

                DropdownButtonFormField<int>(
                  initialValue: _diaMes,
                  dropdownColor: InvestAITheme.card,
                  style: const TextStyle(color: InvestAITheme.texto),
                  decoration: const InputDecoration(
                    labelText: 'Dia do mês',
                    helperText: 'Em meses mais curtos, vale o último dia.',
                    helperStyle: TextStyle(color: InvestAITheme.cinza),
                  ),
                  items: [
                    for (var dia = 1; dia <= 31; dia++)
                      DropdownMenuItem(value: dia, child: Text('Dia $dia')),
                  ],
                  onChanged: (v) => setState(() => _diaMes = v!),
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
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: InvestAITheme.verdeEscuro))
                      : Text(widget.existente != null ? 'Salvar alterações' : 'Adicionar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
