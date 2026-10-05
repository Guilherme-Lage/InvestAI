import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/usuario.dart';
import '../theme.dart';
import 'home_screen.dart';

const _chavePreferencia = 'onboarding_visto';

/// Apresenta a lógica do app logo no primeiro acesso: organizar, proteger
/// e só então crescer.
///
/// Sem isso a pessoa entra, encontra a aba Investir bloqueada e não sabe
/// por quê. A pesquisa do relatório apontou "orientação passo a passo"
/// como o que os usuários mais querem - o passo a passo existia no código,
/// mas nunca era apresentado.
class OnboardingScreen extends StatefulWidget {
  final Usuario usuario;
  const OnboardingScreen({super.key, required this.usuario});

  /// Já foi visto neste aparelho?
  static Future<bool> jaVisto() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_chavePreferencia) ?? false;
    } catch (_) {
      return true; // na dúvida não interrompe quem já usa o app
    }
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Passo {
  final IconData icone;
  final String etapa;
  final String titulo;
  final String texto;
  const _Passo({
    required this.icone,
    required this.etapa,
    required this.titulo,
    required this.texto,
  });
}

const List<_Passo> _passos = [
  _Passo(
    icone: Icons.receipt_long_rounded,
    etapa: 'Passo 1',
    titulo: 'Organizar',
    texto: 'Primeiro a gente descobre para onde seu dinheiro está indo. '
        'Você registra o que entra e o que sai, e o app mostra quanto sobra '
        'por mês de verdade.',
  ),
  _Passo(
    icone: Icons.shield_outlined,
    etapa: 'Passo 2',
    titulo: 'Proteger',
    texto: 'Depois vem a reserva de emergência: o equivalente a 3 meses das '
        'suas despesas, guardado para imprevistos. É por isso que as '
        'sugestões de investimento ficam bloqueadas até aqui — investir sem '
        'reserva costuma virar dívida quando algo dá errado.',
  ),
  _Passo(
    icone: Icons.trending_up_rounded,
    etapa: 'Passo 3',
    titulo: 'Crescer',
    texto: 'Com a reserva pronta, o app libera sugestões de acordo com o seu '
        'perfil, usando as taxas reais do Banco Central. E a IA fica '
        'disponível o tempo todo para explicar o que você não entender.',
  ),
];

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controlador = PageController();
  int _pagina = 0;

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  Future<void> _concluir() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_chavePreferencia, true);
    } catch (_) {
      // Sem preferências o onboarding reaparece, o que é melhor do que
      // travar a entrada no app.
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => HomeScreen(usuario: widget.usuario)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ultima = _pagina == _passos.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _concluir,
                child: Text('Pular',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: InvestAITheme.cinza)),
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _controlador,
                itemCount: _passos.length,
                onPageChanged: (i) => setState(() => _pagina = i),
                itemBuilder: (_, i) => _PaginaPasso(passo: _passos[i]),
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _passos.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _pagina ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _pagina
                          ? InvestAITheme.verde
                          : InvestAITheme.borda,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (ultima) {
                      _concluir();
                    } else {
                      _controlador.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  child: Text(ultima ? 'Começar' : 'Continuar'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaginaPasso extends StatelessWidget {
  final _Passo passo;
  const _PaginaPasso({required this.passo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: InvestAITheme.verde.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(passo.icone, color: InvestAITheme.verde, size: 30),
          ),
          const SizedBox(height: 28),
          Text(passo.etapa,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: InvestAITheme.verde,
                  letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text(passo.titulo,
              style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: InvestAITheme.texto,
                  letterSpacing: -1)),
          const SizedBox(height: 14),
          Text(passo.texto,
              style: GoogleFonts.inter(
                  fontSize: 14.5,
                  color: InvestAITheme.cinza,
                  height: 1.6)),
        ],
      ),
    );
  }
}
