import 'package:flutter/material.dart';
import '../models/usuario.dart';
import '../theme.dart';
import '../widgets/robo_assistente.dart';
import 'chat_ia_screen.dart';
import 'dashboard_tab.dart';
import 'report_tab.dart';
import 'metas_tab.dart';
import 'investimentos_tab.dart';
import 'perfil_tab.dart';

/// Shell da Home: navegação em abas — Início, Metas, Relatório, Investir e
/// Perfil — no mesmo agrupamento do protótipo de referência do projeto.
class HomeScreen extends StatefulWidget {
  final Usuario usuario;

  const HomeScreen({super.key, required this.usuario});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _abaAtual = 0;
  late Usuario _usuario;

  @override
  void initState() {
    super.initState();
    _usuario = widget.usuario;
  }

  void _atualizarUsuario(Usuario usuario) {
    setState(() => _usuario = usuario);
  }

  void _irParaAba(int indice) {
    setState(() => _abaAtual = indice);
  }

  @override
  Widget build(BuildContext context) {
    final abas = [
      DashboardTab(usuario: _usuario, onVerTodasMetas: () => _irParaAba(1)),
      const MetasTab(),
      const ReportTab(),
      const InvestimentosTab(),
      PerfilTab(usuario: _usuario, aoAtualizarUsuario: _atualizarUsuario),
    ];

    // Metas, Relatório e Investir têm o próprio "+" ocupando a base do
    // canto (de 16 a 72); nessas o assistente fica acima dele. Nas outras
    // ele desce para o lugar do "+", para não sobrar um vão vazio embaixo.
    const abasComBotaoAdicionar = {1, 2, 3};
    final alturaAssistente = abasComBotaoAdicionar.contains(_abaAtual) ? 84.0 : 16.0;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            abas[_abaAtual],
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              right: 16,
              bottom: alturaAssistente,
              child: Tooltip(
                message: 'Falar com o assistente',
                child: Semantics(
                  button: true,
                  label: 'Falar com o assistente',
                  // O próprio balão é o botão: sem fundo nem borda em volta,
                  // só uma sombra para destacá-lo do conteúdo da tela.
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 3)),
                      ],
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ChatIaScreen()),
                        ),
                        child: const RoboAssistente(tamanho: 56),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _abaAtual,
        onDestinationSelected: _irParaAba,
        backgroundColor: InvestAITheme.card,
        indicatorColor: InvestAITheme.verde.withOpacity(0.18),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: InvestAITheme.cinza),
            selectedIcon: Icon(Icons.home_rounded, color: InvestAITheme.verde),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined, color: InvestAITheme.cinza),
            selectedIcon: Icon(Icons.flag_rounded, color: InvestAITheme.verde),
            label: 'Metas',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined, color: InvestAITheme.cinza),
            selectedIcon: Icon(Icons.bar_chart_rounded, color: InvestAITheme.verde),
            label: 'Relatório',
          ),
          NavigationDestination(
            icon: Icon(Icons.trending_up_rounded, color: InvestAITheme.cinza),
            selectedIcon: Icon(Icons.trending_up_rounded, color: InvestAITheme.verde),
            label: 'Investir',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded, color: InvestAITheme.cinza),
            selectedIcon: Icon(Icons.person_rounded, color: InvestAITheme.verde),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
