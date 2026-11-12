import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/suitability.dart';
import '../models/usuario.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/questionario_suitability.dart';

/// RF18 - questionário de suitability para quem já tem conta: quem pulou
/// no cadastro ou quer refazer. Fecha devolvendo o [Usuario] atualizado,
/// ou null se a pessoa sair sem concluir.
class QuestionarioSuitabilityScreen extends StatefulWidget {
  final Usuario usuario;

  const QuestionarioSuitabilityScreen({super.key, required this.usuario});

  @override
  State<QuestionarioSuitabilityScreen> createState() =>
      _QuestionarioSuitabilityScreenState();
}

class _QuestionarioSuitabilityScreenState
    extends State<QuestionarioSuitabilityScreen> {
  late Future<List<PerguntaSuitability>> _perguntas;
  bool _enviando = false;
  String? _erro;
  ResultadoSuitability? _resultado;

  @override
  void initState() {
    super.initState();
    _perguntas = ApiService.questionarioSuitability();
  }

  Future<void> _enviar(Map<String, int> respostas) async {
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      final resultado =
          await ApiService.responderSuitability(widget.usuario.id!, respostas);
      if (!mounted) return;
      setState(() {
        _resultado = resultado;
        _enviando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = '$e';
        _enviando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil de investidor'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context, _resultado?.usuario),
        ),
      ),
      body: SafeArea(
        child: _resultado != null
            ? _Resultado(
                resultado: _resultado!,
                aoConcluir: () => Navigator.pop(context, _resultado!.usuario),
              )
            : FutureBuilder<List<PerguntaSuitability>>(
                future: _perguntas,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(color: InvestAITheme.verde),
                    );
                  }
                  if (snap.hasError || snap.data == null) {
                    return _FalhaAoCarregar(
                      aoTentarDeNovo: () => setState(() {
                        _perguntas = ApiService.questionarioSuitability();
                      }),
                    );
                  }
                  return Column(
                    children: [
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Text(
                          'Responda com sinceridade: não há resposta certa. '
                          'Seu perfil define quais investimentos sugerimos.',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: InvestAITheme.cinza, height: 1.4),
                        ),
                      ),
                      if (_erro != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
                          child: Text(_erro!,
                              style: GoogleFonts.inter(
                                  fontSize: 12.5, color: InvestAITheme.vermelho)),
                        ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: QuestionarioSuitability(
                          perguntas: snap.data!,
                          aoConcluir: _enviar,
                          enviando: _enviando,
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _Resultado extends StatelessWidget {
  final ResultadoSuitability resultado;
  final VoidCallback aoConcluir;

  const _Resultado({required this.resultado, required this.aoConcluir});

  @override
  Widget build(BuildContext context) {
    return CartaoPerfilCalculado(
      perfil: resultado.perfil,
      descricao: resultado.descricao,
      rodape: ElevatedButton(onPressed: aoConcluir, child: const Text('Concluir')),
    );
  }
}

/// Mostra o perfil que saiu do questionário. Também usado no cadastro.
class CartaoPerfilCalculado extends StatelessWidget {
  final String perfil;
  final String descricao;
  final Widget? rodape;

  const CartaoPerfilCalculado({
    super.key,
    required this.perfil,
    required this.descricao,
    this.rodape,
  });

  static const _icones = {
    'conservador': Icons.shield_outlined,
    'moderado': Icons.balance_outlined,
    'arrojado': Icons.rocket_launch_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: InvestAITheme.verde.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(_icones[perfil] ?? Icons.person_outline,
                  color: InvestAITheme.verde, size: 34),
            ),
          ),
          const SizedBox(height: 18),
          Text('Seu perfil é',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: InvestAITheme.cinza)),
          const SizedBox(height: 4),
          Text(rotulosPerfilInvestidor[perfil] ?? perfil,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 28, fontWeight: FontWeight.w800, color: InvestAITheme.verde)),
          const SizedBox(height: 12),
          Text(descricao,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 14, color: InvestAITheme.texto, height: 1.5)),
          const SizedBox(height: 10),
          Text('Você pode refazer o questionário quando quiser, na aba Perfil.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: InvestAITheme.cinza)),
          if (rodape != null) ...[
            const SizedBox(height: 28),
            rodape!,
          ],
        ],
      ),
    );
  }
}

class _FalhaAoCarregar extends StatelessWidget {
  final VoidCallback aoTentarDeNovo;
  const _FalhaAoCarregar({required this.aoTentarDeNovo});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: InvestAITheme.cinza, size: 40),
            const SizedBox(height: 12),
            Text('Não consegui carregar o questionário. Verifique a conexão.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: InvestAITheme.cinza)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: aoTentarDeNovo, child: const Text('Tentar novamente')),
          ],
        ),
      ),
    );
  }
}
