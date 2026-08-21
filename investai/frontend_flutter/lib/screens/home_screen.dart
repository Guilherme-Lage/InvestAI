import 'package:flutter/material.dart';
import '../models/usuario.dart';
import '../theme.dart';
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

    return Scaffold(
      body: SafeArea(child: abas[_abaAtual]),
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
