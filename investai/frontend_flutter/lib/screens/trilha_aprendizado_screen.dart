import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../conteudo/licoes.dart';
import '../services/progresso_licoes.dart';
import '../theme.dart';
import '../widgets/glossario.dart';
import '../widgets/robo_assistente.dart';
import 'chat_ia_screen.dart';

/// Trilha "Aprenda a investir": lista das lições, com o que já foi
/// concluído e o que ainda está fechado (e por quê). O conteúdo fica em
/// lib/conteudo/licoes.dart.
class TrilhaAprendizadoScreen extends StatefulWidget {
  final ContextoLicao contexto;
  const TrilhaAprendizadoScreen({super.key, required this.contexto});

  @override
  State<TrilhaAprendizadoScreen> createState() => _TrilhaAprendizadoScreenState();
}

class _TrilhaAprendizadoScreenState extends State<TrilhaAprendizadoScreen> {
  Set<String> _concluidas = {};

  @override
  void initState() {
    super.initState();
    _carregarProgresso();
  }

  Future<void> _carregarProgresso() async {
    final concluidas = await ProgressoLicoes.concluidas();
    if (!mounted) return;
    setState(() => _concluidas = concluidas);
  }

  Future<void> _abrir(int indice) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LicaoScreen(indice: indice, contexto: widget.contexto),
    ));
    _carregarProgresso();
  }

  @override
  Widget build(BuildContext context) {
    final feitas = licoes.where((l) => _concluidas.contains(l.id)).length;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: InvestAITheme.card,
        foregroundColor: InvestAITheme.texto,
        title: Text('Aprenda a investir',
            style: GoogleFonts.inter(
                fontSize: 17, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            'Lições curtas, na ordem em que você vai precisar delas. As próximas '
            'abrem conforme você avança no seu guia financeiro.',
            style: GoogleFonts.inter(fontSize: 13, color: InvestAITheme.cinza, height: 1.4),
          ),
          const SizedBox(height: 14),
          _BarraProgresso(feitas: feitas, total: licoes.length),
          const SizedBox(height: 18),
          for (var i = 0; i < licoes.length; i++)
            _ItemLicao(
              numero: i + 1,
              licao: licoes[i],
              liberada: widget.contexto.libera(licoes[i].nivel),
              concluida: _concluidas.contains(licoes[i].id),
              onTap: () => _abrir(i),
            ),
        ],
      ),
    );
  }
}

class _BarraProgresso extends StatelessWidget {
  final int feitas;
  final int total;
  const _BarraProgresso({required this.feitas, required this.total});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$feitas de $total lições concluídas',
            style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w600, color: InvestAITheme.verde)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : feitas / total,
            minHeight: 6,
            backgroundColor: InvestAITheme.borda,
            valueColor: const AlwaysStoppedAnimation(InvestAITheme.verde),
          ),
        ),
      ],
    );
  }
}

class _ItemLicao extends StatelessWidget {
  final int numero;
  final Licao licao;
  final bool liberada;
  final bool concluida;
  final VoidCallback onTap;

  const _ItemLicao({
    required this.numero,
    required this.licao,
    required this.liberada,
    required this.concluida,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cor = concluida
        ? InvestAITheme.verde
        : liberada
            ? InvestAITheme.texto
            : InvestAITheme.cinza;
    return Opacity(
      opacity: liberada ? 1 : 0.6,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: InvestAITheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: concluida ? InvestAITheme.verde.withValues(alpha: 0.4) : InvestAITheme.borda),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: liberada ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: (concluida ? InvestAITheme.verde : InvestAITheme.borda)
                          .withValues(alpha: concluida ? 0.18 : 1),
                      shape: BoxShape.circle,
                    ),
                    child: concluida
                        ? const Icon(Icons.check_rounded, color: InvestAITheme.verde, size: 20)
                        : liberada
                            ? Text('$numero',
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: InvestAITheme.texto))
                            : const Icon(Icons.lock_outline_rounded,
                                color: InvestAITheme.cinza, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(licao.titulo,
                            style: GoogleFonts.inter(
                                fontSize: 13.5, fontWeight: FontWeight.w600, color: cor)),
                        const SizedBox(height: 3),
                        Text(
                          liberada ? licao.resumo : motivoDoBloqueio(licao.nivel),
                          style: GoogleFonts.inter(fontSize: 11.5, color: InvestAITheme.cinza),
                        ),
                      ],
                    ),
                  ),
                  if (liberada)
                    const Icon(Icons.chevron_right_rounded, color: InvestAITheme.cinza, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Uma lição: texto (com os termos do glossário tocáveis), passo a passo,
/// os números da própria pessoa, atalho para o assistente e o botão de
/// concluir, que leva à próxima lição liberada.
class LicaoScreen extends StatefulWidget {
  final int indice;
  final ContextoLicao contexto;
  const LicaoScreen({super.key, required this.indice, required this.contexto});

  @override
  State<LicaoScreen> createState() => _LicaoScreenState();
}

class _LicaoScreenState extends State<LicaoScreen> {
  bool _concluida = false;

  Licao get _licao => licoes[widget.indice];

  @override
  void initState() {
    super.initState();
    ProgressoLicoes.concluidas().then((ids) {
      if (mounted) setState(() => _concluida = ids.contains(_licao.id));
    });
  }

  /// Próxima lição já liberada, para seguir a trilha sem voltar à lista.
  int? get _proxima {
    for (var i = widget.indice + 1; i < licoes.length; i++) {
      if (widget.contexto.libera(licoes[i].nivel)) return i;
    }
    return null;
  }

  Future<void> _concluir() async {
    await ProgressoLicoes.concluir(_licao.id);
    if (!mounted) return;
    final proxima = _proxima;
    if (proxima == null) {
      Navigator.pop(context);
      return;
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => LicaoScreen(indice: proxima, contexto: widget.contexto),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final licao = _licao;
    final numeros = licao.comSeusNumeros?.call(widget.contexto);
    final estiloTexto = GoogleFonts.inter(fontSize: 14, color: InvestAITheme.texto, height: 1.55);
    final proxima = _proxima;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: InvestAITheme.card,
        foregroundColor: InvestAITheme.texto,
        title: Text('Lição ${widget.indice + 1} de ${licoes.length}',
            style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w600, color: InvestAITheme.texto)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Icon(licao.icone, color: InvestAITheme.verde, size: 30),
          const SizedBox(height: 10),
          Text(licao.titulo,
              style: GoogleFonts.inter(
                  fontSize: 21, fontWeight: FontWeight.w800, color: InvestAITheme.texto, height: 1.25)),
          const SizedBox(height: 18),
          for (final paragrafo in licao.paragrafos) ...[
            TextoComGlossario(paragrafo, estilo: estiloTexto),
            const SizedBox(height: 14),
          ],

          if (numeros != null) ...[
            _CaixaSeusNumeros(texto: numeros),
            const SizedBox(height: 18),
          ],

          if (licao.passos.isNotEmpty) ...[
            Text(licao.tituloPassos ?? 'Passo a passo',
                style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
            const SizedBox(height: 12),
            for (var i = 0; i < licao.passos.length; i++)
              _Passo(numero: i + 1, texto: licao.passos[i]),
            const SizedBox(height: 6),
          ],

          if (licao.observacao != null) ...[
            Text(licao.observacao!,
                style: GoogleFonts.inter(fontSize: 12, color: InvestAITheme.cinza, height: 1.45)),
            const SizedBox(height: 18),
          ],

          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ChatIaScreen(perguntaInicial: licao.perguntaParaIa),
            )),
            icon: const RoboAssistente(tamanho: 18),
            label: const Text('Me explica isso'),
            style: OutlinedButton.styleFrom(
              foregroundColor: InvestAITheme.verde,
              side: BorderSide(color: InvestAITheme.verde.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _concluir,
            child: Text(proxima != null
                ? (_concluida ? 'Próxima lição' : 'Concluir e ir para a próxima')
                : (_concluida ? 'Voltar para a trilha' : 'Concluir lição')),
          ),
        ],
      ),
    );
  }
}

class _CaixaSeusNumeros extends StatelessWidget {
  final String texto;
  const _CaixaSeusNumeros({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: InvestAITheme.verde.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: InvestAITheme.verde.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Com os seus números',
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w700, color: InvestAITheme.verde)),
          const SizedBox(height: 6),
          Text(texto,
              style: GoogleFonts.inter(fontSize: 13.5, color: InvestAITheme.texto, height: 1.5)),
        ],
      ),
    );
  }
}

class _Passo extends StatelessWidget {
  final int numero;
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
              color: InvestAITheme.verde.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text('$numero',
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w700, color: InvestAITheme.verde)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextoComGlossario(texto,
                estilo: GoogleFonts.inter(fontSize: 13.5, color: InvestAITheme.texto, height: 1.45)),
          ),
        ],
      ),
    );
  }
}
