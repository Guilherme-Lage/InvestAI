import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/usuario.dart';
import '../models/movimentacao.dart';
import '../models/limite_categoria.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'login_screen.dart';

/// RF18 - perfil de investidor; RF13 - limites de gasto por categoria;
/// dados da conta e logout (RF02). Layout em menu com avatar, no mesmo
/// espírito da tela de perfil do protótipo de referência.
class PerfilTab extends StatefulWidget {
  final Usuario usuario;
  final ValueChanged<Usuario> aoAtualizarUsuario;

  const PerfilTab({super.key, required this.usuario, required this.aoAtualizarUsuario});

  @override
  State<PerfilTab> createState() => _PerfilTabState();
}

class _PerfilTabState extends State<PerfilTab> {
  List<LimiteCategoria> _limites = [];

  static const _perfis = [
    ('conservador', 'Conservador', Icons.shield_outlined),
    ('moderado', 'Moderado', Icons.balance_outlined),
    ('arrojado', 'Arrojado', Icons.rocket_launch_outlined),
  ];

  static const _rotulosPerfil = {
    'conservador': 'Conservador',
    'moderado': 'Moderado',
    'arrojado': 'Arrojado',
  };

  @override
  void initState() {
    super.initState();
    _carregarLimites();
  }

  Future<void> _carregarLimites() async {
    try {
      final limites = await ApiService.listarLimites();
      if (!mounted) return;
      setState(() => _limites = limites);
    } catch (e) {
      // Silencioso: o contador de limites só é exibido se a carga funcionar.
    }
  }

  String get _iniciais {
    final partes = widget.usuario.nome.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    final primeira = partes.first[0];
    final ultima = partes.length > 1 ? partes.last[0] : '';
    return (primeira + ultima).toUpperCase();
  }

  Future<void> _abrirPerfilInvestidor() async {
    String perfilSelecionado = widget.usuario.perfilRisco;
    final rendaCtrl = TextEditingController(text: widget.usuario.rendaMensal.toStringAsFixed(2));
    bool salvando = false;
    String? erro;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Perfil de investidor',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
                const SizedBox(height: 6),
                Text('Usado para personalizar suas recomendações (RF18).',
                    style: GoogleFonts.inter(fontSize: 12.5, color: InvestAITheme.cinza)),
                const SizedBox(height: 20),
                for (final (valor, label, icone) in _perfis)
                  GestureDetector(
                    onTap: () => setModalState(() => perfilSelecionado = valor),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: perfilSelecionado == valor
                            ? InvestAITheme.verde.withOpacity(0.1)
                            : InvestAITheme.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: perfilSelecionado == valor ? InvestAITheme.verde : InvestAITheme.borda),
                      ),
                      child: Row(
                        children: [
                          Icon(icone,
                              color: perfilSelecionado == valor ? InvestAITheme.verde : InvestAITheme.cinza,
                              size: 20),
                          const SizedBox(width: 12),
                          Text(label,
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: perfilSelecionado == valor ? InvestAITheme.verde : InvestAITheme.texto)),
                          const Spacer(),
                          if (perfilSelecionado == valor)
                            const Icon(Icons.check_circle_rounded, color: InvestAITheme.verde, size: 18),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: rendaCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: InvestAITheme.texto),
                  decoration: const InputDecoration(labelText: 'Renda mensal', prefixText: 'R\$ '),
                ),
                if (erro != null) ...[
                  const SizedBox(height: 12),
                  Text(erro!, style: GoogleFonts.inter(fontSize: 12, color: InvestAITheme.vermelho)),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: salvando
                      ? null
                      : () async {
                          setModalState(() {
                            salvando = true;
                            erro = null;
                          });
                          try {
                            final renda =
                                double.tryParse(rendaCtrl.text.replaceAll(',', '.')) ?? widget.usuario.rendaMensal;
                            final usuario = await ApiService.atualizarUsuario(widget.usuario.id!, {
                              'perfil_risco': perfilSelecionado,
                              'renda_mensal': renda,
                            });
                            widget.aoAtualizarUsuario(usuario);
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            setModalState(() {
                              erro = '$e';
                              salvando = false;
                            });
                          }
                        },
                  child: salvando
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: InvestAITheme.verdeEscuro))
                      : const Text('Salvar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _abrirLimites() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PainelLimites(limitesIniciais: _limites),
    );
    _carregarLimites();
  }

  Future<void> _sair() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        Text('Perfil',
            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: InvestAITheme.texto)),
        const SizedBox(height: 20),

        Center(
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(color: InvestAITheme.verde, shape: BoxShape.circle),
                child: Center(
                  child: Text(_iniciais,
                      style: GoogleFonts.inter(
                          fontSize: 24, fontWeight: FontWeight.w800, color: InvestAITheme.verdeEscuro)),
                ),
              ),
              const SizedBox(height: 12),
              Text(widget.usuario.nome,
                  style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
              const SizedBox(height: 2),
              Text(widget.usuario.email, style: GoogleFonts.inter(fontSize: 13, color: InvestAITheme.cinza)),
            ],
          ),
        ),
        const SizedBox(height: 28),

        _ItemMenu(
          icone: Icons.trending_up_rounded,
          titulo: 'Perfil de investidor',
          subtitulo: _rotulosPerfil[widget.usuario.perfilRisco] ?? widget.usuario.perfilRisco,
          onTap: _abrirPerfilInvestidor,
        ),
        _ItemMenu(
          icone: Icons.notifications_outlined,
          titulo: 'Alertas e limites por categoria',
          subtitulo: _limites.isEmpty ? 'Nenhum limite definido' : '${_limites.length} categoria(s)',
          onTap: _abrirLimites,
        ),
        _ItemMenu(
          icone: Icons.lock_outline_rounded,
          titulo: 'Segurança',
          subtitulo: 'Em breve',
          habilitado: false,
        ),
        _ItemMenu(
          icone: Icons.workspace_premium_outlined,
          titulo: 'Plano Premium',
          subtitulo: 'Em breve',
          habilitado: false,
        ),
        _ItemMenu(
          icone: Icons.account_balance_outlined,
          titulo: 'Corretoras conectadas',
          subtitulo: 'Em breve',
          habilitado: false,
        ),

        const SizedBox(height: 20),
        _ItemMenu(
          icone: Icons.logout_rounded,
          titulo: 'Sair',
          cor: InvestAITheme.vermelho,
          onTap: _sair,
        ),
      ],
    );
  }
}

class _ItemMenu extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String? subtitulo;
  final VoidCallback? onTap;
  final bool habilitado;
  final Color? cor;

  const _ItemMenu({
    required this.icone,
    required this.titulo,
    this.subtitulo,
    this.onTap,
    this.habilitado = true,
    this.cor,
  });

  @override
  Widget build(BuildContext context) {
    final corPrincipal = cor ?? InvestAITheme.texto;
    return Opacity(
      opacity: habilitado ? 1 : 0.5,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: InvestAITheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: InvestAITheme.borda),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: habilitado ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icone, color: cor ?? InvestAITheme.cinza, size: 20),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(titulo,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: corPrincipal)),
                ),
                if (subtitulo != null)
                  Text(subtitulo!, style: GoogleFonts.inter(fontSize: 12, color: InvestAITheme.cinza)),
                if (habilitado && onTap != null) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded, color: InvestAITheme.cinza, size: 18),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Painel de limites por categoria (RF13), aberto como bottom sheet a
/// partir do menu de Perfil.
class _PainelLimites extends StatefulWidget {
  final List<LimiteCategoria> limitesIniciais;
  const _PainelLimites({required this.limitesIniciais});

  @override
  State<_PainelLimites> createState() => _PainelLimitesState();
}

class _PainelLimitesState extends State<_PainelLimites> {
  late List<LimiteCategoria> _limites;

  @override
  void initState() {
    super.initState();
    _limites = widget.limitesIniciais;
  }

  Future<void> _recarregar() async {
    final limites = await ApiService.listarLimites();
    if (!mounted) return;
    setState(() => _limites = limites);
  }

  Future<void> _adicionar() async {
    String categoria = Categorias.despesa.first;
    final valorCtrl = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Definir limite mensal',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: categoria,
                  dropdownColor: InvestAITheme.card,
                  style: const TextStyle(color: InvestAITheme.texto),
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: [
                    for (final c in Categorias.despesa)
                      DropdownMenuItem(value: c, child: Text(Categorias.rotulo(c))),
                  ],
                  onChanged: (v) => setModalState(() => categoria = v!),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: valorCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  style: const TextStyle(color: InvestAITheme.texto),
                  decoration: const InputDecoration(labelText: 'Limite mensal', prefixText: 'R\$ '),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    final valor = double.tryParse(valorCtrl.text.replaceAll(',', '.'));
                    if (valor == null || valor <= 0) return;
                    try {
                      await ApiService.definirLimite(categoria, valor);
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  },
                  child: const Text('Salvar limite'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    _recarregar();
  }

  Future<void> _remover(LimiteCategoria l) async {
    try {
      await ApiService.deletarLimite(l.id!);
      _recarregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, controlador) => Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Limites por categoria',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: InvestAITheme.texto)),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, color: InvestAITheme.verde),
                  onPressed: _adicionar,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('RF13 - você recebe um alerta quando o gasto do mês passar do limite.',
                style: GoogleFonts.inter(fontSize: 12, color: InvestAITheme.cinza)),
            const SizedBox(height: 16),
            Expanded(
              child: _limites.isEmpty
                  ? Center(
                      child: Text('Nenhum limite definido ainda.',
                          style: GoogleFonts.inter(fontSize: 13, color: InvestAITheme.cinza)),
                    )
                  : ListView.builder(
                      controller: controlador,
                      itemCount: _limites.length,
                      itemBuilder: (context, i) {
                        final l = _limites[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: InvestAITheme.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: InvestAITheme.borda),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(Categorias.rotulo(l.categoria),
                                    style: GoogleFonts.inter(fontSize: 13, color: InvestAITheme.texto)),
                              ),
                              Text('R\$ ${l.valorLimite.toStringAsFixed(2).replaceAll('.', ',')}/mês',
                                  style: GoogleFonts.inter(
                                      fontSize: 13, fontWeight: FontWeight.w700, color: InvestAITheme.verde)),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: InvestAITheme.cinza, size: 18),
                                onPressed: () => _remover(l),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
