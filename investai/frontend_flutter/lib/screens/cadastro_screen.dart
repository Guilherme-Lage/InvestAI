import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'home_screen.dart';

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  final _rendaController = TextEditingController();

  String _perfilRisco = 'moderado';
  bool _carregando = false;
  bool _senhaVisivel = false;
  bool _confirmarSenhaVisivel = false;
  String? _erro;
  int _etapa = 0; // 0 = dados pessoais, 1 = perfil financeiro

  final List<_PerfilOpcao> _perfis = const [
    _PerfilOpcao(
      valor: 'conservador',
      label: 'Conservador',
      descricao: 'Prefere segurança. Foco em renda fixa e liquidez.',
      icone: Icons.shield_outlined,
    ),
    _PerfilOpcao(
      valor: 'moderado',
      label: 'Moderado',
      descricao: 'Equilibrio entre segurança e crescimento.',
      icone: Icons.balance_outlined,
    ),
    _PerfilOpcao(
      valor: 'arrojado',
      label: 'Arrojado',
      descricao: 'Aceita mais risco em busca de maiores retornos.',
      icone: Icons.rocket_launch_outlined,
    ),
  ];

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    _rendaController.dispose();
    super.dispose();
  }

  bool _validarEtapa0() {
    if (_nomeController.text.trim().length < 2) {
      setState(() => _erro = 'Nome muito curto.');
      return false;
    }
    final email = _emailController.text.trim();
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      setState(() => _erro = 'E-mail inválido.');
      return false;
    }
    if (_senhaController.text.length < 6) {
      setState(() => _erro = 'A senha deve ter pelo menos 6 caracteres.');
      return false;
    }
    if (_senhaController.text != _confirmarSenhaController.text) {
      setState(() => _erro = 'As senhas não coincidem.');
      return false;
    }
    return true;
  }

  bool _validarEtapa1() {
    final renda = double.tryParse(
        _rendaController.text.trim().replaceAll(',', '.'));
    if (renda == null || renda < 0) {
      setState(() => _erro = 'Informe uma renda válida.');
      return false;
    }
    return true;
  }

  void _avancar() {
    setState(() => _erro = null);
    if (_etapa == 0) {
      if (_validarEtapa0()) setState(() => _etapa = 1);
    }
  }

  Future<void> _cadastrar() async {
    setState(() => _erro = null);
    if (!_validarEtapa1()) return;

    setState(() => _carregando = true);

    final renda = double.parse(
        _rendaController.text.trim().replaceAll(',', '.'));

    final resultado = await ApiService.cadastrar(
      nome: _nomeController.text.trim(),
      email: _emailController.text.trim(),
      senha: _senhaController.text,
      perfilRisco: _perfilRisco,
      rendaMensal: renda,
    );

    if (!mounted) return;
    setState(() => _carregando = false);

    if (resultado.sucesso) {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => HomeScreen(usuario: resultado.usuario!),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
        (route) => false,
      );
    } else {
      setState(() => _erro = resultado.mensagemErro);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar customizada ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: InvestAITheme.texto, size: 20),
                    onPressed: () {
                      if (_etapa > 0) {
                        setState(() {
                          _etapa--;
                          _erro = null;
                        });
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Criar conta',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: InvestAITheme.texto,
                          ),
                        ),
                        Text(
                          _etapa == 0
                              ? 'Passo 1 de 2 — Seus dados'
                              : 'Passo 2 de 2 — Perfil financeiro',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: InvestAITheme.cinza),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Barra de progresso ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _etapa == 0 ? 0.5 : 1.0,
                  backgroundColor: InvestAITheme.borda,
                  valueColor: const AlwaysStoppedAnimation(InvestAITheme.verde),
                  minHeight: 3,
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Conteúdo ───────────────────────────────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.15, 0),
                    end: Offset.zero,
                  ).animate(
                      CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: _etapa == 0
                    ? _Etapa0(
                        key: const ValueKey(0),
                        nomeCtrl: _nomeController,
                        emailCtrl: _emailController,
                        senhaCtrl: _senhaController,
                        confirmarSenhaCtrl: _confirmarSenhaController,
                        erro: _erro,
                        onAvancar: _avancar,
                      )
                    : _Etapa1(
                        key: const ValueKey(1),
                        rendaCtrl: _rendaController,
                        perfilSelecionado: _perfilRisco,
                        perfis: _perfis,
                        erro: _erro,
                        carregando: _carregando,
                        onPerfilChange: (v) => setState(() => _perfilRisco = v),
                        onCadastrar: _cadastrar,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Etapa 0: Dados pessoais ──────────────────────────────────────────────────

class _Etapa0 extends StatefulWidget {
  final TextEditingController nomeCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController senhaCtrl;
  final TextEditingController confirmarSenhaCtrl;
  final String? erro;
  final VoidCallback onAvancar;

  const _Etapa0({
    super.key,
    required this.nomeCtrl,
    required this.emailCtrl,
    required this.senhaCtrl,
    required this.confirmarSenhaCtrl,
    required this.erro,
    required this.onAvancar,
  });

  @override
  State<_Etapa0> createState() => _Etapa0State();
}

class _Etapa0State extends State<_Etapa0> {
  bool _senhaVisivel = false;
  bool _confirmarSenhaVisivel = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quem é você?',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: InvestAITheme.texto,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Vamos criar seu perfil de investidor.',
            style: GoogleFonts.inter(fontSize: 14, color: InvestAITheme.cinza),
          ),
          const SizedBox(height: 36),

          // Nome
          TextFormField(
            controller: widget.nomeCtrl,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: InvestAITheme.texto),
            decoration: const InputDecoration(
              labelText: 'Nome completo',
              prefixIcon: Icon(Icons.person_outline_rounded,
                  color: InvestAITheme.cinza, size: 20),
            ),
          ),
          const SizedBox(height: 16),

          // E-mail
          TextFormField(
            controller: widget.emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            style: const TextStyle(color: InvestAITheme.texto),
            decoration: const InputDecoration(
              labelText: 'E-mail',
              prefixIcon: Icon(Icons.mail_outline_rounded,
                  color: InvestAITheme.cinza, size: 20),
            ),
          ),
          const SizedBox(height: 16),

          // Senha
          TextFormField(
            controller: widget.senhaCtrl,
            obscureText: !_senhaVisivel,
            style: const TextStyle(color: InvestAITheme.texto),
            decoration: InputDecoration(
              labelText: 'Senha',
              helperText: 'Mínimo de 6 caracteres',
              prefixIcon: const Icon(Icons.lock_outline_rounded,
                  color: InvestAITheme.cinza, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _senhaVisivel
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: InvestAITheme.cinza,
                  size: 20,
                ),
                onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Confirmar senha
          TextFormField(
            controller: widget.confirmarSenhaCtrl,
            obscureText: !_confirmarSenhaVisivel,
            style: const TextStyle(color: InvestAITheme.texto),
            decoration: InputDecoration(
              labelText: 'Confirmar senha',
              prefixIcon: const Icon(Icons.lock_outline_rounded,
                  color: InvestAITheme.cinza, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _confirmarSenhaVisivel
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: InvestAITheme.cinza,
                  size: 20,
                ),
                onPressed: () => setState(
                    () => _confirmarSenhaVisivel = !_confirmarSenhaVisivel),
              ),
            ),
          ),

          if (widget.erro != null) ...[
            const SizedBox(height: 16),
            _ErroCard(mensagem: widget.erro!),
          ],

          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: widget.onAvancar,
            child: const Text('Continuar'),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Etapa 1: Perfil financeiro ───────────────────────────────────────────────

class _Etapa1 extends StatelessWidget {
  final TextEditingController rendaCtrl;
  final String perfilSelecionado;
  final List<_PerfilOpcao> perfis;
  final String? erro;
  final bool carregando;
  final ValueChanged<String> onPerfilChange;
  final VoidCallback onCadastrar;

  const _Etapa1({
    super.key,
    required this.rendaCtrl,
    required this.perfilSelecionado,
    required this.perfis,
    required this.erro,
    required this.carregando,
    required this.onPerfilChange,
    required this.onCadastrar,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Perfil financeiro',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: InvestAITheme.texto,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Usamos isso para personalizar sua trilha de investimentos.',
            style: GoogleFonts.inter(fontSize: 14, color: InvestAITheme.cinza),
          ),
          const SizedBox(height: 32),

          // Renda mensal
          TextFormField(
            controller: rendaCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
            ],
            style: const TextStyle(color: InvestAITheme.texto),
            decoration: const InputDecoration(
              labelText: 'Renda mensal líquida',
              prefixIcon: Icon(Icons.attach_money_rounded,
                  color: InvestAITheme.cinza, size: 20),
              hintText: '0,00',
              prefixText: 'RS ',
              prefixStyle: TextStyle(color: InvestAITheme.cinza),
            ),
          ),

          const SizedBox(height: 28),

          Text(
            'Seu perfil de investidor',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: InvestAITheme.cinza,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),

          // Cards de perfil
          ...perfis.map((perfil) => _PerfilCard(
                perfil: perfil,
                selecionado: perfilSelecionado == perfil.valor,
                onTap: () => onPerfilChange(perfil.valor),
              )),

          if (erro != null) ...[
            const SizedBox(height: 16),
            _ErroCard(mensagem: erro!),
          ],

          const SizedBox(height: 28),

          ElevatedButton(
            onPressed: carregando ? null : onCadastrar,
            child: carregando
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: InvestAITheme.verdeEscuro,
                    ),
                  )
                : const Text('Criar minha conta'),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Card de perfil de risco ──────────────────────────────────────────────────

class _PerfilCard extends StatelessWidget {
  final _PerfilOpcao perfil;
  final bool selecionado;
  final VoidCallback onTap;

  const _PerfilCard({
    required this.perfil,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selecionado
              ? InvestAITheme.verde.withOpacity(0.1)
              : InvestAITheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selecionado
                ? InvestAITheme.verde
                : InvestAITheme.borda,
            width: selecionado ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selecionado
                    ? InvestAITheme.verde.withOpacity(0.2)
                    : InvestAITheme.borda,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                perfil.icone,
                color: selecionado
                    ? InvestAITheme.verde
                    : InvestAITheme.cinza,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    perfil.label,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: selecionado
                          ? InvestAITheme.verde
                          : InvestAITheme.texto,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    perfil.descricao,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: InvestAITheme.cinza),
                  ),
                ],
              ),
            ),
            if (selecionado)
              const Icon(Icons.check_circle_rounded,
                  color: InvestAITheme.verde, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Dados da opção de perfil ─────────────────────────────────────────────────

class _PerfilOpcao {
  final String valor;
  final String label;
  final String descricao;
  final IconData icone;
  const _PerfilOpcao({
    required this.valor,
    required this.label,
    required this.descricao,
    required this.icone,
  });
}

// ── Componente de erro ───────────────────────────────────────────────────────

class _ErroCard extends StatelessWidget {
  final String mensagem;
  const _ErroCard({required this.mensagem});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: InvestAITheme.vermelho.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: InvestAITheme.vermelho.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: InvestAITheme.vermelho, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensagem,
              style: GoogleFonts.inter(
                  fontSize: 13, color: InvestAITheme.vermelho),
            ),
          ),
        ],
      ),
    );
  }
}
