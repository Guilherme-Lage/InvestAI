import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'cadastro_screen.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

/// Conta de demonstração (criada por backend/criar_conta_demo.py; os mesmos
/// dados estão em backend/services/usuario/conta_demo.py). Aparece como
/// conta salva ao tocar nos campos do login, como o preenchimento automático
/// do navegador, para apresentar o app sem precisar digitar o acesso.
const emailContaDemo = 'demo@investai.com';
const senhaContaDemo = 'Demo@1234';

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
  final _emailFoco = FocusNode();
  final _senhaFoco = FocusNode();
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
    _emailFoco.dispose();
    _senhaFoco.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  /// Preenche e-mail e senha com a conta salva (a demo), como o
  /// preenchimento automático do navegador, e fecha o teclado.
  void _preencherContaDemo() {
    setState(() {
      _emailController.text = emailContaDemo;
      _senhaController.text = senhaContaDemo;
      _senhaVisivel = false;
      _erro = null;
    });
    FocusScope.of(context).unfocus();
  }

  /// A sugestão aparece no campo de e-mail enquanto o que foi digitado
  /// ainda pode ser o e-mail da demo, e some quando ele já está completo.
  Iterable<String> _sugestoesEmail(String digitado) {
    final texto = digitado.trim().toLowerCase();
    if (texto == emailContaDemo) return const [];
    return emailContaDemo.startsWith(texto) ? const [emailContaDemo] : const [];
  }

  /// No campo de senha, só com a senha vazia e o e-mail vazio ou da demo.
  Iterable<String> _sugestoesSenha(String digitado) {
    final email = _emailController.text.trim().toLowerCase();
    if (digitado.isNotEmpty) return const [];
    return email.isEmpty || email == emailContaDemo ? const [emailContaDemo] : const [];
  }

  Widget _listaSugestao(
    AutocompleteOnSelected<String> aoEscolher,
    Iterable<String> opcoes,
    double largura,
  ) {
    return Align(
      alignment: Alignment.topLeft,
      child: _SugestaoContaSalva(
        largura: largura,
        email: opcoes.first,
        aoEscolher: () => aoEscolher(opcoes.first),
      ),
    );
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
      // Quem nunca viu a explicação da jornada vê agora, uma única vez.
      final usuario = resultado.usuario!;
      final destino = await OnboardingScreen.jaVisto()
          ? HomeScreen(usuario: usuario)
          : OnboardingScreen(usuario: usuario);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => destino,
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
                      // Campo e-mail. Ao tocar nele, a conta salva (demo)
                      // aparece embaixo, como o preenchimento automático do
                      // navegador; escolhê-la preenche e-mail e senha.
                      LayoutBuilder(
                        builder: (context, limites) => RawAutocomplete<String>(
                          textEditingController: _emailController,
                          focusNode: _emailFoco,
                          optionsBuilder: (valor) => _sugestoesEmail(valor.text),
                          displayStringForOption: (_) => emailContaDemo,
                          onSelected: (_) => _preencherContaDemo(),
                          optionsViewBuilder: (context, aoEscolher, opcoes) =>
                              _listaSugestao(aoEscolher, opcoes, limites.maxWidth),
                          fieldViewBuilder: (context, controller, foco, _) =>
                              TextFormField(
                            controller: controller,
                            focusNode: foco,
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
                        ),
                      ),

                      // Campo senha. Também oferece a conta salva enquanto
                      // estiver vazio; a senha entra mascarada (bolinhas).
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, limites) => RawAutocomplete<String>(
                          textEditingController: _senhaController,
                          focusNode: _senhaFoco,
                          optionsBuilder: (valor) => _sugestoesSenha(valor.text),
                          displayStringForOption: (_) => senhaContaDemo,
                          onSelected: (_) => _preencherContaDemo(),
                          optionsViewBuilder: (context, aoEscolher, opcoes) =>
                              _listaSugestao(aoEscolher, opcoes, limites.maxWidth),
                          fieldViewBuilder: (context, controller, foco, _) =>
                              TextFormField(
                            controller: controller,
                            focusNode: foco,
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
                        ),
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

/// A conta salva que aparece embaixo do campo, como no preenchimento
/// automático do navegador: mostra o e-mail e a senha só como bolinhas.
class _SugestaoContaSalva extends StatelessWidget {
  final double largura;
  final String email;
  final VoidCallback aoEscolher;

  const _SugestaoContaSalva({
    required this.largura,
    required this.email,
    required this.aoEscolher,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: InvestAITheme.card,
        elevation: 8,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: InvestAITheme.borda),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: largura,
          child: InkWell(
            onTap: aoEscolher,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: InvestAITheme.verde.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.key_rounded,
                        color: InvestAITheme.verde, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(email,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: InvestAITheme.texto)),
                        const SizedBox(height: 2),
                        Text('••••••••',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                letterSpacing: 1.5,
                                color: InvestAITheme.cinza)),
                      ],
                    ),
                  ),
                ],
              ),
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
