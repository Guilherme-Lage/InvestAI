import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/suitability.dart';
import '../theme.dart';

/// Questionário de suitability (RF18), uma pergunta por vez.
///
/// Usado no cadastro (com a opção de pular) e na aba Perfil. Não fala com
/// o backend: só devolve as respostas em [aoConcluir], e quem o usa decide
/// para onde enviá-las.
class QuestionarioSuitability extends StatefulWidget {
  final List<PerguntaSuitability> perguntas;
  final ValueChanged<Map<String, int>> aoConcluir;

  /// Quando informado, mostra o botão "Pular por enquanto".
  final VoidCallback? aoPular;

  /// Texto do botão da última pergunta.
  final String textoConcluir;

  /// Enquanto true, o botão de concluir mostra um indicador de progresso.
  final bool enviando;

  /// Respostas já dadas antes (ex.: a pessoa voltou da tela seguinte do
  /// cadastro). Com todas preenchidas, o questionário reabre na última
  /// pergunta, pronto para ela revisar voltando uma a uma.
  final Map<String, int>? respostasIniciais;

  const QuestionarioSuitability({
    super.key,
    required this.perguntas,
    required this.aoConcluir,
    this.aoPular,
    this.textoConcluir = 'Ver meu perfil',
    this.enviando = false,
    this.respostasIniciais,
  });

  @override
  State<QuestionarioSuitability> createState() => _QuestionarioSuitabilityState();
}

class _QuestionarioSuitabilityState extends State<QuestionarioSuitability> {
  final Map<String, int> _respostas = {};
  int _atual = 0;

  @override
  void initState() {
    super.initState();
    final iniciais = widget.respostasIniciais;
    if (iniciais != null) {
      _respostas.addAll(iniciais);
      final primeiraSemResposta =
          widget.perguntas.indexWhere((p) => !_respostas.containsKey(p.id));
      _atual = primeiraSemResposta == -1
          ? widget.perguntas.length - 1
          : primeiraSemResposta;
    }
  }

  PerguntaSuitability get _pergunta => widget.perguntas[_atual];
  bool get _ultima => _atual == widget.perguntas.length - 1;
  int? get _escolhida => _respostas[_pergunta.id];

  void _escolher(int indice) {
    setState(() => _respostas[_pergunta.id] = indice);
  }

  void _avancar() {
    if (_escolhida == null) return;
    if (_ultima) {
      widget.aoConcluir(Map.unmodifiable(_respostas));
    } else {
      setState(() => _atual++);
    }
  }

  void _voltar() {
    if (_atual > 0) setState(() => _atual--);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.perguntas.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Pergunta ${_atual + 1} de $total',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: InvestAITheme.verde,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              if (widget.aoPular != null)
                TextButton(
                  onPressed: widget.enviando ? null : widget.aoPular,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Pular por enquanto',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: InvestAITheme.cinza,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_atual + 1) / total,
              backgroundColor: InvestAITheme.borda,
              valueColor: const AlwaysStoppedAnimation(InvestAITheme.verde),
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Column(
              key: ValueKey(_atual),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _pergunta.texto,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: InvestAITheme.texto,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 20),
                for (var i = 0; i < _pergunta.opcoes.length; i++)
                  _OpcaoCard(
                    texto: _pergunta.opcoes[i],
                    selecionada: _escolhida == i,
                    onTap: widget.enviando ? null : () => _escolher(i),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // "Voltar" ao lado de "Próxima": quem marcou errado volta para a
          // pergunta anterior, e a resposta dada lá continua marcada.
          Row(
            children: [
              if (_atual > 0) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.enviando ? null : _voltar,
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Voltar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: InvestAITheme.texto,
                      side: const BorderSide(color: InvestAITheme.borda),
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _escolhida == null || widget.enviando ? null : _avancar,
                  child: widget.enviando
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: InvestAITheme.verdeEscuro,
                          ),
                        )
                      : Text(_ultima ? widget.textoConcluir : 'Próxima'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _OpcaoCard extends StatelessWidget {
  final String texto;
  final bool selecionada;
  final VoidCallback? onTap;

  const _OpcaoCard({required this.texto, required this.selecionada, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selecionada
            ? InvestAITheme.verde.withValues(alpha: 0.1)
            : InvestAITheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selecionada ? InvestAITheme.verde : InvestAITheme.borda,
            width: selecionada ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  selecionada
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selecionada ? InvestAITheme.verde : InvestAITheme.cinza,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    texto,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: selecionada ? FontWeight.w600 : FontWeight.w500,
                      color: selecionada ? InvestAITheme.verde : InvestAITheme.texto,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
