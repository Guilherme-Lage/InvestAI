import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'cadastro_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _carregando = false;
  bool _senhaVisivel = false;
  String? _erro;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });

    final resultado = await ApiService.login(
      _emailController.text.trim(),
      _senhaController.text,
    );

    if (!mounted) return;
    setState(() => _carregando = false);

    if (resultado.sucesso) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => HomeScreen(usuario: resultado.usuario!),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } else {
      setState(() => _erro = resultado.mensagemErro);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),

                // ── Logo ──────────────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: InvestAITheme.verde,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.trending_up,
                          color: InvestAITheme.verdeEscuro, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'InvestAI',
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: InvestAITheme.verde,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 56),

                // ── Headline ──────────────────────────────────────────────────
                Text(
                  'Bem-vindo\nde volta.',
                  style: GoogleFonts.inter(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: InvestAITheme.texto,
                    height: 1.15,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Seu dinheiro está esperando por você.',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: InvestAITheme.cinza,
                  ),
                ),

                const SizedBox(height: 44),

                // ── Formulário ────────────────────────────────────────────────
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Campo e-mail
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        style: const TextStyle(color: InvestAITheme.texto),
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: Icon(Icons.mail_outline_rounded,
                              color: InvestAITheme.cinza, size: 20),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Informe seu e-mail';
                          }
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                            return 'E-mail inválido';
                          }
                          return null;
                        },
                      ),

                      // Campo senha
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _senhaController,
                        obscureText: !_senhaVisivel,
                        style: const TextStyle(color: InvestAITheme.texto),
                        decoration: InputDecoration(
                          labelText: 'Senha',
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
                            onPressed: () =>
                                setState(() => _senhaVisivel = !_senhaVisivel),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Informe sua senha';
                          }
                          return null;
                        },
                      ),

                      // Mensagem de erro
                      if (_erro != null) ...[
                        const SizedBox(height: 16),
                        _ErroCard(mensagem: _erro!),
                      ],

                      const SizedBox(height: 28),

                      // Botão entrar
                      ElevatedButton(
                        onPressed: _carregando ? null : _entrar,
                        child: _carregando
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: InvestAITheme.verdeEscuro,
                                ),
                              )
                            : const Text('Entrar'),
                      ),

                      const SizedBox(height: 20),

                      // Divider
                      Row(
                        children: [
                          const Expanded(
                              child: Divider(color: InvestAITheme.borda)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'ou',
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: InvestAITheme.cinza),
                            ),
                          ),
                          const Expanded(
                              child: Divider(color: InvestAITheme.borda)),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Botão criar conta
                      OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            PageRouteBuilder(
                              pageBuilder: (_, __, ___) =>
                                  const CadastroScreen(),
                              transitionsBuilder: (_, anim, __, child) =>
                                  SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(1, 0),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                    parent: anim,
                                    curve: Curves.easeOutCubic)),
                                child: child,
                              ),
                              transitionDuration:
                                  const Duration(milliseconds: 350),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: InvestAITheme.verde,
                          side: const BorderSide(color: InvestAITheme.borda),
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          textStyle: GoogleFonts.inter(
                              fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        child: const Text('Criar conta'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Rodapé
                Center(
                  child: Text(
                    'InvestAI © 2025',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: InvestAITheme.cinza.withOpacity(0.5)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
        border:
            Border.all(color: InvestAITheme.vermelho.withOpacity(0.3)),
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
