import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/meta.dart';
import '../services/api_service.dart';
import '../theme.dart';

/// RF06 - criar metas; RF07 - acompanhar progresso; RF14/RF15 - reserva
/// de emergência antes de liberar sugestões de investimento; RF17 -
/// aporte mensal sugerido ajustado à capacidade de economia do usuário.
class MetasTab extends StatefulWidget {
  const MetasTab({super.key});

  @override
  State<MetasTab> createState() => _MetasTabState();
}

class _MetasTabState extends State<MetasTab> {
  bool _carregando = true;
  String? _erro;
  List<Meta> _metas = [];
  Map<String, dynamic>? _reserva;

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
        ApiService.listarMetas(),
        ApiService.reservaEmergencia(),
      ]);
      if (!mounted) return;
      setState(() {
        _metas = (resultados[0] as List<Meta>).where((m) => !m.isReservaEmergencia).toList();
        _reserva = resultados[1] as Map<String, dynamic>;
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

  Future<void> _criarReserva() async {
    final alvo = (_reserva?['valor_ideal_reserva'] ?? 0.0) as num;
    final prazo = DateTime.now().add(const Duration(days: 365));
    try {
      await ApiService.criarMeta(Meta(
        titulo: 'Reserva de emergência',
        valorAlvo: alvo > 0 ? alvo.toDouble() : 1000,
        valorAtual: 0,
        prazo: '${prazo.year}-${prazo.month.toString().padLeft(2, '0')}-${prazo.day.toString().padLeft(2, '0')}',
        tipo: 'reserva_emergencia',
      ));
      _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _abrirFormularioMeta({Meta? existente}) async {
    final resultado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormularioMeta(existente: existente),
    );
    if (resultado == true) _carregar();
  }

  Future<void> _adicionarAporte(Meta meta) async {
    final controlador = TextEditingController();
    final valor = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: InvestAITheme.card,
        title: Text('Adicionar aporte', style: GoogleFonts.inter(color: InvestAITheme.texto)),
        content: TextField(
          controller: controlador,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: const TextStyle(color: InvestAITheme.texto),
          decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R\$ '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(controlador.text.replaceAll(',', '.'));
              Navigator.pop(context, v);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    if (valor == null || valor <= 0) return;

    try {
      await ApiService.atualizarMeta(
        meta.id!,
        Meta(
          titulo: meta.titulo,
          valorAlvo: meta.valorAlvo,
          valorAtual: meta.valorAtual + valor,
          prazo: meta.prazo,
          tipo: meta.tipo,
        ),
      );
      _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _remover(Meta m) async {
    try {
      await ApiService.deletarMeta(m.id!);
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
        onPressed: () => _abrirFormularioMeta(),
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
                      Text('Metas',
                          style: GoogleFonts.inter(
                              fontSize: 24, fontWeight: FontWeight.w800, color: InvestAITheme.texto)),
                      const SizedBox(height: 16),

                      if (_reserva != null)
                        _ReservaEmergenciaCard(
                          reserva: _reserva!,
                          reais: _reais,
                          onCriar: _criarReserva,
                          onAporte: _reserva!['reserva'] != null
                              ? () => _adicionarAporte(Meta.fromJson(_reserva!['reserva']))
                              : null,
                        ),
                      const SizedBox(height: 20),

                      Text('Suas metas',
                          style: GoogleFonts.inter(
                              fontSize: 15, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
                      const SizedBox(height: 12),

                      if (_metas.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          child: Center(
                            child: Text('Você ainda não criou nenhuma meta.',
                                style: GoogleFonts.inter(fontSize: 13, color: InvestAITheme.cinza)),
                          ),
                        )
                      else
                        for (final m in _metas)
                          _MetaCard(
                            meta: m,
                            reais: _reais,
                            onEditar: () => _abrirFormularioMeta(existente: m),
                            onExcluir: () => _remover(m),
                            onAporte: () => _adicionarAporte(m),
                          ),
                    ],
                  ),
                ),
    );
  }
}

class _ReservaEmergenciaCard extends StatelessWidget {
  final Map<String, dynamic> reserva;
  final String Function(num) reais;
  final VoidCallback onCriar;
  final VoidCallback? onAporte;

  const _ReservaEmergenciaCard({
    required this.reserva,
    required this.reais,
    required this.onCriar,
    this.onAporte,
  });

  @override
  Widget build(BuildContext context) {
    final possui = reserva['possui_reserva'] == true;
    final liberado = reserva['sugestoes_investimento_liberadas'] == true;
    final guardado = (reserva['valor_guardado'] ?? 0) as num;
    final ideal = (reserva['valor_ideal_reserva'] ?? 0) as num;
    final progresso = ideal > 0 ? (guardado / ideal).clamp(0.0, 1.0) : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: liberado ? InvestAITheme.verde.withOpacity(0.08) : InvestAITheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: liberado ? InvestAITheme.verde.withOpacity(0.3) : InvestAITheme.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(liberado ? Icons.verified_rounded : Icons.shield_outlined,
                  color: liberado ? InvestAITheme.verde : InvestAITheme.cinza, size: 20),
              const SizedBox(width: 8),
              Text('Reserva de emergência',
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
            ],
          ),
          const SizedBox(height: 12),
          if (!possui) ...[
            Text(
              'RF14 - Recomendamos guardar ${reais(ideal)} (3x sua despesa média mensal) antes de investir.',
              style: GoogleFonts.inter(fontSize: 12.5, color: InvestAITheme.cinza, height: 1.4),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onCriar,
                style: OutlinedButton.styleFrom(
                  foregroundColor: InvestAITheme.verde,
                  side: const BorderSide(color: InvestAITheme.verde),
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Começar minha reserva'),
              ),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(reais(guardado),
                    style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.w800, color: InvestAITheme.texto)),
                Text('meta: ${reais(ideal)}',
                    style: GoogleFonts.inter(fontSize: 12, color: InvestAITheme.cinza)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progresso,
                minHeight: 8,
                backgroundColor: InvestAITheme.borda,
                valueColor: AlwaysStoppedAnimation(liberado ? InvestAITheme.verde : const Color(0xFFFFB020)),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              liberado
                  ? 'Reserva completa! Sugestões de investimento liberadas na aba Investir.'
                  : 'Faltam ${reais((ideal - guardado).clamp(0, double.infinity))} para liberar sugestões de investimento (RF15).',
              style: GoogleFonts.inter(fontSize: 12, color: InvestAITheme.cinza),
            ),
            if (!liberado && onAporte != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onAporte,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: InvestAITheme.verde,
                    side: const BorderSide(color: InvestAITheme.borda),
                    minimumSize: const Size(double.infinity, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Adicionar aporte'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _MetaCard extends StatelessWidget {
  final Meta meta;
  final String Function(num) reais;
  final VoidCallback onEditar;
  final VoidCallback onExcluir;
  final VoidCallback onAporte;

  const _MetaCard({
    required this.meta,
    required this.reais,
    required this.onEditar,
    required this.onExcluir,
    required this.onAporte,
  });

  static const _meses = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];

  String _prazoFormatado(String prazo) {
    final data = DateTime.tryParse(prazo);
    if (data == null) return prazo;
    return '${_meses[data.month - 1]}/${data.year}';
  }

  @override
  Widget build(BuildContext context) {
    final progresso = (meta.progresso / 100).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(meta.titulo,
                        style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
                    if (meta.prazo.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(_prazoFormatado(meta.prazo),
                          style: GoogleFonts.inter(fontSize: 11, color: InvestAITheme.cinza)),
                    ],
                  ],
                ),
              ),
              if (meta.concluida)
                const Icon(Icons.check_circle_rounded, color: InvestAITheme.verde, size: 20)
              else
                PopupMenuButton<String>(
                  color: InvestAITheme.card,
                  icon: const Icon(Icons.more_vert_rounded, color: InvestAITheme.cinza, size: 18),
                  onSelected: (v) {
                    if (v == 'editar') onEditar();
                    if (v == 'excluir') onExcluir();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'editar', child: Text('Editar', style: GoogleFonts.inter(color: InvestAITheme.texto))),
                    PopupMenuItem(value: 'excluir', child: Text('Excluir', style: GoogleFonts.inter(color: InvestAITheme.vermelho))),
                  ],
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
              valueColor: AlwaysStoppedAnimation(meta.concluida ? InvestAITheme.verde : InvestAITheme.verde.withOpacity(0.7)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${reais(meta.valorAtual)} de ${reais(meta.valorAlvo)}',
                  style: GoogleFonts.inter(fontSize: 12, color: InvestAITheme.cinza)),
              Text('${meta.progresso.toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: InvestAITheme.verde)),
            ],
          ),
          if (!meta.concluida && meta.aporteSugerido > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: InvestAITheme.verde.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Aporte sugerido: ${reais(meta.aporteSugerido)}/mês',
                style: GoogleFonts.inter(fontSize: 11.5, color: InvestAITheme.verde, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          if (!meta.concluida) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onAporte,
                style: OutlinedButton.styleFrom(
                  foregroundColor: InvestAITheme.verde,
                  side: const BorderSide(color: InvestAITheme.borda),
                  minimumSize: const Size(double.infinity, 40),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Adicionar aporte'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FormularioMeta extends StatefulWidget {
  final Meta? existente;
  const _FormularioMeta({this.existente});

  @override
  State<_FormularioMeta> createState() => _FormularioMetaState();
}

class _FormularioMetaState extends State<_FormularioMeta> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _valorAlvoCtrl = TextEditingController();
  final _valorAtualCtrl = TextEditingController();
  DateTime _prazo = DateTime.now().add(const Duration(days: 180));
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    final m = widget.existente;
    _tituloCtrl.text = m?.titulo ?? '';
    _valorAlvoCtrl.text = m != null ? m.valorAlvo.toStringAsFixed(2) : '';
    _valorAtualCtrl.text = m != null ? m.valorAtual.toStringAsFixed(2) : '0';
    if (m != null) _prazo = DateTime.tryParse(m.prazo) ?? _prazo;
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _valorAlvoCtrl.dispose();
    _valorAtualCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });

    final meta = Meta(
      id: widget.existente?.id,
      titulo: _tituloCtrl.text.trim(),
      valorAlvo: double.parse(_valorAlvoCtrl.text.replaceAll(',', '.')),
      valorAtual: double.tryParse(_valorAtualCtrl.text.replaceAll(',', '.')) ?? 0,
      prazo: '${_prazo.year}-${_prazo.month.toString().padLeft(2, '0')}-${_prazo.day.toString().padLeft(2, '0')}',
      tipo: widget.existente?.tipo ?? 'geral',
    );

    try {
      if (widget.existente != null) {
        await ApiService.atualizarMeta(widget.existente!.id!, meta);
      } else {
        await ApiService.criarMeta(meta);
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
              Text(widget.existente != null ? 'Editar meta' : 'Nova meta',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _tituloCtrl,
                style: const TextStyle(color: InvestAITheme.texto),
                decoration: const InputDecoration(labelText: 'Título da meta'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe um título' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _valorAlvoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: InvestAITheme.texto),
                decoration: const InputDecoration(labelText: 'Valor-alvo', prefixText: 'R\$ '),
                validator: (v) {
                  final valor = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (valor == null || valor <= 0) return 'Informe um valor válido';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _valorAtualCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: InvestAITheme.texto),
                decoration: const InputDecoration(labelText: 'Já guardado (opcional)', prefixText: 'R\$ '),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () async {
                  final selecionada = await showDatePicker(
                    context: context,
                    initialDate: _prazo,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (selecionada != null) setState(() => _prazo = selecionada);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Prazo'),
                  child: Text(
                    '${_prazo.day.toString().padLeft(2, '0')}/${_prazo.month.toString().padLeft(2, '0')}/${_prazo.year}',
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
                    : Text(widget.existente != null ? 'Salvar alterações' : 'Criar meta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
