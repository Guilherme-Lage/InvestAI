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
  AjusteSaldo? _ajuste;
  String? _nomeArquivo;
  bool _ocupado = false; // lendo o arquivo ou gravando a importação
  String? _erro;

  /// As que já entraram numa importação anterior nem aparecem na lista.
  List<TransacaoExtrato> get _paraRevisar =>
      (_transacoes ?? []).where((t) => !t.jaImportada).toList();

  List<TransacaoExtrato> get _selecionadas =>
      _paraRevisar.where((t) => t.selecionada).toList();

  int get _jaImportadas => (_transacoes ?? []).where((t) => t.jaImportada).length;

  /// Valor do ajuste com a seleção de agora (muda a cada linha marcada).
  double get _valorAjuste => _ajuste?.valorPara(_selecionadas) ?? 0;

  /// O ajuste só aparece quando o saldo do app não bateria com o do banco.
  bool get _mostrarAjuste => _ajuste != null && _valorAjuste.abs() >= 0.01;

  bool get _enviarAjuste => _mostrarAjuste && _ajuste!.marcado;

  int get _quantidadeParaImportar => _selecionadas.length + (_enviarAjuste ? 1 : 0);

  /// Marcadas para importar que ainda estão sem categoria definida.
  int get _semCategoria => _selecionadas.where((t) => t.categoria == 'outros').length;

  /// Troca a categoria de uma linha e de todas as outras de mesmo nome.
  ///
  /// Extrato costuma repetir o mesmo favorecido várias vezes (a mesma
  /// padaria, o mesmo Pix); sem isso a pessoa teria de corrigir uma a uma.
  void _trocarCategoria(TransacaoExtrato alterada, String categoria) {
    setState(() {
      for (final transacao in _paraRevisar) {
        if (transacao.descricao == alterada.descricao && transacao.tipo == alterada.tipo) {
          transacao.categoria = categoria;
        }
      }
    });
  }

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
      final analise = await ApiService.analisarExtrato(arquivo.bytes);
      if (!mounted) return;
      setState(() {
        _transacoes = analise.transacoes;
        _ajuste = analise.ajuste;
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
      final importadas = await ApiService.confirmarImportacao(
        _selecionadas,
        ajuste: _enviarAjuste ? _ajuste!.toJson(_valorAjuste) : null,
      );
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
    final nadaNovo = paraRevisar.isEmpty && !_mostrarAjuste;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(_nomeArquivo ?? '',
            style: GoogleFonts.inter(fontSize: 12, color: InvestAITheme.cinza),
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(
          nadaNovo ? 'Nada novo neste extrato' : 'Confira antes de importar',
          style: GoogleFonts.inter(
              fontSize: 18, fontWeight: FontWeight.w700, color: InvestAITheme.texto),
        ),
        const SizedBox(height: 6),
        Text(
          nadaNovo
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
        if (_semCategoria > 0) ...[
          const SizedBox(height: 12),
          _AvisoSemCategoria(quantidade: _semCategoria),
        ],
        const SizedBox(height: 16),
        if (_mostrarAjuste)
          _CartaoAjuste(
            ajuste: _ajuste!,
            valor: _valorAjuste,
            reais: _reais,
            habilitado: !_ocupado,
            onMarcar: (marcado) => setState(() => _ajuste!.marcado = marcado),
          ),
        for (final transacao in paraRevisar)
          _ItemRevisao(
            transacao: transacao,
            reais: _reais,
            habilitado: !_ocupado,
            onMarcar: (marcada) => setState(() => transacao.selecionada = marcada),
            onCategoria: (categoria) => _trocarCategoria(transacao, categoria),
          ),
      ],
    );
  }

  Widget _construirRodape() {
    final quantidade = _quantidadeParaImportar;
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

/// Chama a atenção para o que vai entrar como "Outros". O app só reconhece
/// a categoria por palavras conhecidas; Pix para uma pessoa, por exemplo,
/// só o próprio usuário sabe do que se trata.
class _AvisoSemCategoria extends StatelessWidget {
  final int quantidade;
  const _AvisoSemCategoria({required this.quantidade});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: InvestAITheme.amarelo.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: InvestAITheme.amarelo.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.label_off_outlined, color: InvestAITheme.amarelo, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              (quantidade == 1
                      ? '1 transação está sem categoria ("Outros"). '
                      : '$quantidade transações estão sem categoria ("Outros"). ') +
                  'Toque na categoria para definir: as de mesmo nome mudam juntas, '
                  'e o app lembra da sua escolha nas próximas importações.',
              style: GoogleFonts.inter(fontSize: 12, color: InvestAITheme.amarelo, height: 1.35),
            ),
          ),
        ],
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

/// O ajuste de saldo, no topo da revisão. O valor muda conforme as linhas
/// marcadas, para o saldo do app terminar igual ao que o banco informa.
class _CartaoAjuste extends StatelessWidget {
  final AjusteSaldo ajuste;
  final double valor;
  final String Function(num) reais;
  final bool habilitado;
  final ValueChanged<bool> onMarcar;

  const _CartaoAjuste({
    required this.ajuste,
    required this.valor,
    required this.reais,
    required this.habilitado,
    required this.onMarcar,
  });

  String _dataBr(String iso) {
    final data = DateTime.tryParse(iso);
    if (data == null) return iso;
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final entrada = valor > 0;
    // Na primeira importação é o passo normal (verde); nas seguintes, a
    // diferença é um sinal de que algo não bate (amarelo).
    final cor = ajuste.primeiraImportacao ? InvestAITheme.verde : InvestAITheme.amarelo;
    final saldoBanco = '${reais(ajuste.saldoBanco)} em ${_dataBr(ajuste.dataBanco)}';
    final explicacao = ajuste.primeiraImportacao
        ? 'O banco informa saldo de $saldoBanco. Este ajuste inclui o dinheiro que já '
            'estava na conta antes do extrato e o que você deixar de fora (como uma '
            'aplicação), para o saldo do app ficar igual ao do banco. O valor muda '
            'conforme você marca as linhas. Dinheiro aplicado, registre na aba Investir.'
        : 'Depois desta importação, o saldo do app ficaria ${reais(valor.abs())} '
            'diferente do banco ($saldoBanco). Pode ser algo registrado só no app ou só '
            'no banco: confira antes. Marque só se quiser igualar ao banco.';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(4, 8, 14, 12),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: ajuste.marcado,
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
                      child: Text(ajuste.descricao,
                          style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: InvestAITheme.texto)),
                    ),
                    const SizedBox(width: 8),
                    Text('${entrada ? '+' : '-'} ${reais(valor.abs())}',
                        style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: entrada ? InvestAITheme.verde : InvestAITheme.vermelho)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  explicacao,
                  style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: ajuste.primeiraImportacao ? InvestAITheme.cinza : InvestAITheme.amarelo,
                      height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
