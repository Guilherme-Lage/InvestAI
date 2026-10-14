import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/movimentacao.dart' show Categorias;
import '../models/transacao_extrato.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils/escolher_arquivo.dart';

/// Importação de extrato bancário (arquivo OFX), em três momentos:
///
/// 1. o usuário escolhe o arquivo exportado do banco;
/// 2. o backend devolve as transações e o usuário revisa: desmarca o que
///    não quer e corrige a categoria sugerida;
/// 3. as marcadas viram movimentações comuns.
///
/// Ao terminar, a tela fecha devolvendo a mensagem de confirmação.
class ImportarExtratoScreen extends StatefulWidget {
  /// Abre o seletor de arquivos. É um parâmetro para os testes poderem
  /// entregar um arquivo sem depender do navegador.
  final Future<ArquivoEscolhido?> Function() escolher;

  const ImportarExtratoScreen({super.key, this.escolher = _escolherOfx});

  static Future<ArquivoEscolhido?> _escolherOfx() => escolherArquivo('.ofx');

  @override
  State<ImportarExtratoScreen> createState() => _ImportarExtratoScreenState();
}

class _ImportarExtratoScreenState extends State<ImportarExtratoScreen> {
  /// `null` enquanto nenhum extrato foi lido.
  List<TransacaoExtrato>? _transacoes;
  String? _nomeArquivo;
  bool _ocupado = false; // lendo o arquivo ou gravando a importação
  String? _erro;

  /// As que já entraram numa importação anterior nem aparecem na lista.
  List<TransacaoExtrato> get _paraRevisar =>
      (_transacoes ?? []).where((t) => !t.jaImportada).toList();

  List<TransacaoExtrato> get _selecionadas =>
      _paraRevisar.where((t) => t.selecionada).toList();

  int get _jaImportadas => (_transacoes ?? []).where((t) => t.jaImportada).length;

  String _reais(num valor) => 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

  Future<void> _escolherEAnalisar() async {
    setState(() => _erro = null);

    final ArquivoEscolhido? arquivo;
    try {
      arquivo = await widget.escolher();
    } on SeletorIndisponivel {
      setState(() => _erro =
          'Por enquanto a importação só funciona na versão web do app (pelo navegador).');
      return;
    }
    if (arquivo == null || !mounted) return; // o usuário cancelou

    setState(() => _ocupado = true);
    try {
      final transacoes = await ApiService.analisarExtrato(arquivo.bytes);
      if (!mounted) return;
      setState(() {
        _transacoes = transacoes;
        _nomeArquivo = arquivo!.nome;
        _ocupado = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = '$e';
        _ocupado = false;
      });
    }
  }

  Future<void> _confirmar() async {
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      final importadas = await ApiService.confirmarImportacao(_selecionadas);
      if (!mounted) return;
      Navigator.pop(
        context,
        importadas == 1 ? '1 transação importada.' : '$importadas transações importadas.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = '$e';
        _ocupado = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: InvestAITheme.card,
        foregroundColor: InvestAITheme.texto,
        title: Text('Importar extrato',
            style: GoogleFonts.inter(
                fontSize: 17, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
      ),
      body: _transacoes == null ? _construirInicio() : _construirRevisao(),
      bottomNavigationBar: _transacoes == null ? null : _construirRodape(),
    );
  }

  // ── Momento 1: escolher o arquivo ──────────────────────────────────────

  Widget _construirInicio() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Traga as transações direto do seu banco, sem digitar uma por uma.',
          style: GoogleFonts.inter(fontSize: 14, color: InvestAITheme.texto, height: 1.4),
        ),
        const SizedBox(height: 16),
        const _Passo(
          numero: '1',
          texto: 'No app ou site do seu banco, abra o extrato e escolha exportar '
              'no formato OFX (às vezes aparece como "Money").',
        ),
        const _Passo(numero: '2', texto: 'Escolha aqui o arquivo que o banco gerou.'),
        const _Passo(
          numero: '3',
          texto: 'Confira a lista: você decide o que entra e pode corrigir as categorias.',
        ),
        const SizedBox(height: 8),
        Text(
          'O arquivo é só lido: guardamos apenas as transações que você confirmar. '
          'Repetir a importação a cada 15 dias ou todo mês não duplica nada.',
          style: GoogleFonts.inter(fontSize: 12, color: InvestAITheme.cinza, height: 1.4),
        ),
        if (_erro != null) ...[
          const SizedBox(height: 16),
          Text(_erro!, style: GoogleFonts.inter(fontSize: 13, color: InvestAITheme.vermelho)),
        ],
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _ocupado ? null : _escolherEAnalisar,
          icon: _ocupado
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: InvestAITheme.verdeEscuro))
              : const Icon(Icons.upload_file_rounded),
          label: Text(_ocupado ? 'Lendo o extrato...' : 'Escolher arquivo .ofx'),
        ),
      ],
    );
  }

  // ── Momento 2: revisar ─────────────────────────────────────────────────

  Widget _construirRevisao() {
    final paraRevisar = _paraRevisar;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(_nomeArquivo ?? '',
            style: GoogleFonts.inter(fontSize: 12, color: InvestAITheme.cinza),
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(
          paraRevisar.isEmpty
              ? 'Nada novo neste extrato'
              : 'Confira antes de importar',
          style: GoogleFonts.inter(
              fontSize: 18, fontWeight: FontWeight.w700, color: InvestAITheme.texto),
        ),
        const SizedBox(height: 6),
        Text(
          paraRevisar.isEmpty
              ? 'Todas as transações deste arquivo já foram importadas antes.'
              : 'Desmarque o que não quiser e toque na categoria para trocar.',
          style: GoogleFonts.inter(fontSize: 12.5, color: InvestAITheme.cinza, height: 1.4),
        ),
        if (_jaImportadas > 0 && paraRevisar.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            _jaImportadas == 1
                ? '1 transação já importada antes ficou de fora.'
                : '$_jaImportadas transações já importadas antes ficaram de fora.',
            style: GoogleFonts.inter(fontSize: 12, color: InvestAITheme.cinza),
          ),
        ],
        const SizedBox(height: 16),
        for (final transacao in paraRevisar)
          _ItemRevisao(
            transacao: transacao,
            reais: _reais,
            habilitado: !_ocupado,
            onMarcar: (marcada) => setState(() => transacao.selecionada = marcada),
            onCategoria: (categoria) => setState(() => transacao.categoria = categoria),
          ),
      ],
    );
  }

  Widget _construirRodape() {
    final quantidade = _selecionadas.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_erro != null) ...[
              Text(_erro!, style: GoogleFonts.inter(fontSize: 12, color: InvestAITheme.vermelho)),
              const SizedBox(height: 8),
            ],
            ElevatedButton(
              onPressed: _ocupado || quantidade == 0 ? null : _confirmar,
              child: _ocupado
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: InvestAITheme.verdeEscuro))
                  : Text(switch (quantidade) {
                      0 => 'Nenhuma transação marcada',
                      1 => 'Importar 1 transação',
                      _ => 'Importar $quantidade transações',
                    }),
            ),
          ],
        ),
      ),
    );
  }
}

class _Passo extends StatelessWidget {
  final String numero;
  final String texto;
  const _Passo({required this.numero, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: InvestAITheme.verde.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Text(numero,
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w700, color: InvestAITheme.verde)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(texto,
                style: GoogleFonts.inter(fontSize: 13, color: InvestAITheme.texto, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

/// Uma linha do extrato na revisão: caixa de marcar, descrição, data,
/// categoria (tocável) e valor. Linhas suspeitas trazem um aviso.
class _ItemRevisao extends StatelessWidget {
  final TransacaoExtrato transacao;
  final String Function(num) reais;
  final bool habilitado;
  final ValueChanged<bool> onMarcar;
  final ValueChanged<String> onCategoria;

  const _ItemRevisao({
    required this.transacao,
    required this.reais,
    required this.habilitado,
    required this.onMarcar,
    required this.onCategoria,
  });

  String get _dataCurta {
    final data = DateTime.tryParse(transacao.data);
    if (data == null) return transacao.data;
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cor = transacao.isRenda ? InvestAITheme.verde : InvestAITheme.vermelho;
    final categorias = transacao.isRenda ? Categorias.receita : Categorias.despesa;

    return Opacity(
      opacity: transacao.selecionada ? 1 : 0.6,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(4, 8, 14, 10),
        decoration: BoxDecoration(
          color: InvestAITheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: InvestAITheme.borda),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: transacao.selecionada,
              activeColor: InvestAITheme.verde,
              checkColor: InvestAITheme.verdeEscuro,
              onChanged: habilitado ? (v) => onMarcar(v ?? false) : null,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(transacao.descricao,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: InvestAITheme.texto)),
                      ),
                      const SizedBox(width: 8),
                      Text('${transacao.isRenda ? '+' : '-'} ${reais(transacao.valor)}',
                          style: GoogleFonts.inter(
                              fontSize: 13.5, fontWeight: FontWeight.w700, color: cor)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('$_dataCurta · ',
                          style: GoogleFonts.inter(fontSize: 11.5, color: InvestAITheme.cinza)),
                      PopupMenuButton<String>(
                        enabled: habilitado,
                        tooltip: 'Trocar categoria',
                        color: InvestAITheme.card,
                        onSelected: onCategoria,
                        itemBuilder: (_) => [
                          for (final c in categorias)
                            PopupMenuItem(
                              value: c,
                              child: Text(Categorias.rotulo(c),
                                  style: GoogleFonts.inter(color: InvestAITheme.texto)),
                            ),
                        ],
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(Categorias.rotulo(transacao.categoria),
                                style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: InvestAITheme.verde)),
                            const Icon(Icons.arrow_drop_down_rounded,
                                size: 16, color: InvestAITheme.verde),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (transacao.aviso != null) ...[
                    const SizedBox(height: 6),
                    Text(transacao.aviso!,
                        style: GoogleFonts.inter(
                            fontSize: 11.5, color: InvestAITheme.amarelo, height: 1.35)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
