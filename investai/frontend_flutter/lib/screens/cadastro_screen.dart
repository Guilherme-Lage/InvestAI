import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'home_screen.dart';

/// Converte texto digitado em número aceitando os dois formatos que o
/// usuário pode usar: "1.234,56" (padrão brasileiro) e "1234.56".
double? _paraNumero(String texto) {
  final limpo = texto.trim();
  if (limpo.isEmpty) return null;
  // Com vírgula, ela é o separador decimal e os pontos são de milhar.
  final normalizado = limpo.contains(',')
      ? limpo.replaceAll('.', '').replaceAll(',', '.')
      : limpo;
  return double.tryParse(normalizado);
}

/// Fração da renda usada quando o usuário não sabe estimar os gastos.
/// Erra para cima de propósito: subestimar a despesa faria a meta da
/// reserva nascer baixa e liberar investimento cedo demais (RF14/RF15).
const _fracaoDespesaPadrao = 0.7;

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  final _rendaController = TextEditingController();

  final Map<String, TextEditingController> _despesaControllers = {
    for (final campo in _camposDespesa) campo.chave: TextEditingController()
  };

  String _perfilRisco = 'moderado';
  bool _carregando = false;
  String? _erro;

  /// Valor vindo do botão "Não sei estimar agora". Fica fora dos campos de
  /// categoria porque aqui só sabemos o total, não a composição - e afirmar
  /// que tudo é fixo faria o guia concluir que não há o que cortar.
  double? _despesaEstimadaAuto;
  int _etapa = 0; // 0 = dados pessoais, 1 = renda e gastos, 2 = perfil

  static const int _totalEtapas = 3;

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    _rendaController.dispose();
    for (final c in _despesaControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _renda => _paraNumero(_rendaController.text) ?? 0;

  double get _somaCampos => _despesaControllers.values
      .map((c) => _paraNumero(c.text) ?? 0)
      .fold<double>(0, (a, b) => a + b);

  double get _totalDespesas => _despesaEstimadaAuto ?? _somaCampos;

  /// Zero quando a estimativa foi automática: não sabemos a composição.
  double get _despesaFixa {
    if (_despesaEstimadaAuto != null) return 0;
    return _camposDespesa
        .where((campo) => campo.obrigatorio)
        .map((campo) => _paraNumero(_despesaControllers[campo.chave]!.text) ?? 0)
        .fold<double>(0, (a, b) => a + b);
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
    if (_paraNumero(_rendaController.text) == null || _renda < 0) {
      setState(() => _erro = 'Informe uma renda válida.');
      return false;
    }
    if (_totalDespesas <= 0) {
      setState(() => _erro =
          'Preencha ao menos um gasto, ou toque em "Não sei estimar agora".');
      return false;
    }
    return true;
  }

  void _avancar() {
    setState(() => _erro = null);
    if (_etapa == 0 && _validarEtapa0()) {
      setState(() => _etapa = 1);
    } else if (_etapa == 1 && _validarEtapa1()) {
      setState(() => _etapa = 2);
    }
  }

  /// Estima os gastos a partir da renda, para quem não faz ideia de quanto
  /// gasta. É só um ponto de partida: o valor real assume assim que houver
  /// despesas registradas de verdade.
  void _estimarPelaRenda() {
    if (_renda <= 0) {
      setState(() => _erro = 'Informe sua renda primeiro para eu estimar.');
      return;
    }
    setState(() {
      _erro = null;
      _despesaEstimadaAuto = _renda * _fracaoDespesaPadrao;
      for (final c in _despesaControllers.values) {
        c.clear();
      }
    });
  }

  /// Digitar uma categoria descarta a estimativa automática: a partir daí
  /// os valores informados valem mais do que o chute.
  void _aoEditarCategoria() {
    if (_despesaEstimadaAuto != null && _somaCampos > 0) {
      setState(() => _despesaEstimadaAuto = null);
    }
  }

  Future<void> _cadastrar() async {
    setState(() {
      _erro = null;
      _carregando = true;
    });

    final resultado = await ApiService.cadastrar(
      nome: _nomeController.text.trim(),
      email: _emailController.text.trim(),
      senha: _senhaController.text,
      perfilRisco: _perfilRisco,
      rendaMensal: _renda,
      despesaMensalEstimada: _totalDespesas,
      despesaFixaEstimada: _despesaFixa,
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

  String get _subtituloEtapa {
    switch (_etapa) {
      case 0:
        return 'Passo 1 de $_totalEtapas — Seus dados';
      case 1:
        return 'Passo 2 de $_totalEtapas — Renda e gastos';
      default:
        return 'Passo 3 de $_totalEtapas — Perfil de investidor';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
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
                          _subtituloEtapa,
                          style: GoogleFonts.inter(
                              fontSize: 12, color: InvestAITheme.cinza),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_etapa + 1) / _totalEtapas,
                  backgroundColor: InvestAITheme.borda,
                  valueColor: const AlwaysStoppedAnimation(InvestAITheme.verde),
                  minHeight: 3,
                ),
              ),
            ),

            const SizedBox(height: 28),

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
                child: switch (_etapa) {
                  0 => _EtapaDados(
                      key: const ValueKey(0),
                      nomeCtrl: _nomeController,
                      emailCtrl: _emailController,
                      senhaCtrl: _senhaController,
                      confirmarSenhaCtrl: _confirmarSenhaController,
                      erro: _erro,
                      onAvancar: _avancar,
                    ),
                  1 => _EtapaFinanceira(
                      key: const ValueKey(1),
                      rendaCtrl: _rendaController,
                      despesaCtrls: _despesaControllers,
                      estimativaAuto: _despesaEstimadaAuto,
                      erro: _erro,
                      onAvancar: _avancar,
                      onEstimarPelaRenda: _estimarPelaRenda,
                      onEditarCategoria: _aoEditarCategoria,
                    ),
                  _ => _EtapaPerfil(
                      key: const ValueKey(2),
                      perfilSelecionado: _perfilRisco,
                      erro: _erro,
                      carregando: _carregando,
                      onPerfilChange: (v) => setState(() => _perfilRisco = v),
                      onCadastrar: _cadastrar,
                    ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Etapa 0: Dados pessoais ──────────────────────────────────────────────────

class _EtapaDados extends StatefulWidget {
  final TextEditingController nomeCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController senhaCtrl;
  final TextEditingController confirmarSenhaCtrl;
  final String? erro;
  final VoidCallback onAvancar;

  const _EtapaDados({
    super.key,
    required this.nomeCtrl,
    required this.emailCtrl,
    required this.senhaCtrl,
    required this.confirmarSenhaCtrl,
    required this.erro,
    required this.onAvancar,
  });

  @override
  State<_EtapaDados> createState() => _EtapaDadosState();
}

class _EtapaDadosState extends State<_EtapaDados> {
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

// ── Etapa 1: Renda e gastos ──────────────────────────────────────────────────

class _CampoDespesa {
  final String chave;
  final String label;
  final String exemplo;
  final IconData icone;

  /// Gasto que a pessoa não consegue cortar no curto prazo. O guia (RF16)
  /// usa essa separação para não sugerir "corte gastos" a quem só tem
  /// despesa obrigatória.
  final bool obrigatorio;

  const _CampoDespesa({
    required this.chave,
    required this.label,
    required this.exemplo,
    required this.icone,
    required this.obrigatorio,
  });
}

/// Quebrar a despesa em categorias concretas em vez de pedir um total:
/// a pessoa sabe quanto é o aluguel dela, mas raramente sabe quanto gasta
/// no mês inteiro. As chaves seguem as categorias de despesa do app.
const List<_CampoDespesa> _camposDespesa = [
  _CampoDespesa(
    chave: 'contas_fixas',
    label: 'Moradia e contas fixas',
    exemplo: 'aluguel, luz, água, internet',
    icone: Icons.home_outlined,
    obrigatorio: true,
  ),
  _CampoDespesa(
    chave: 'alimentacao',
    label: 'Alimentação',
    exemplo: 'mercado, delivery, restaurante',
    icone: Icons.restaurant_outlined,
    obrigatorio: false,
  ),
  _CampoDespesa(
    chave: 'transporte',
    label: 'Transporte',
    exemplo: 'combustível, ônibus, aplicativo',
    icone: Icons.directions_bus_outlined,
    obrigatorio: true,
  ),
  _CampoDespesa(
    chave: 'saude',
    label: 'Saúde e educação',
    exemplo: 'plano, remédios, curso',
    icone: Icons.favorite_outline,
    obrigatorio: true,
  ),
  _CampoDespesa(
    chave: 'lazer',
    label: 'Lazer e outros',
    exemplo: 'streaming, passeios, compras',
    icone: Icons.sports_esports_outlined,
    obrigatorio: false,
  ),
];

class _EtapaFinanceira extends StatefulWidget {
  final TextEditingController rendaCtrl;
  final Map<String, TextEditingController> despesaCtrls;
  final double? estimativaAuto;
  final String? erro;
  final VoidCallback onAvancar;
  final VoidCallback onEstimarPelaRenda;
  final VoidCallback onEditarCategoria;

  const _EtapaFinanceira({
    super.key,
    required this.rendaCtrl,
    required this.despesaCtrls,
    required this.estimativaAuto,
    required this.erro,
    required this.onAvancar,
    required this.onEstimarPelaRenda,
    required this.onEditarCategoria,
  });

  @override
  State<_EtapaFinanceira> createState() => _EtapaFinanceiraState();
}

class _EtapaFinanceiraState extends State<_EtapaFinanceira> {
  @override
  void initState() {
    super.initState();
    widget.rendaCtrl.addListener(_aoDigitar);
    for (final c in widget.despesaCtrls.values) {
      c.addListener(_aoDigitar);
    }
  }

  @override
  void dispose() {
    widget.rendaCtrl.removeListener(_aoDigitar);
    for (final c in widget.despesaCtrls.values) {
      c.removeListener(_aoDigitar);
    }
    super.dispose();
  }

  void _aoDigitar() {
    widget.onEditarCategoria();
    setState(() {});
  }

  double get _renda => _paraNumero(widget.rendaCtrl.text) ?? 0;

  double get _total =>
      widget.estimativaAuto ??
      widget.despesaCtrls.values
          .map((c) => _paraNumero(c.text) ?? 0)
          .fold<double>(0, (a, b) => a + b);

  String _reais(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quanto entra e quanto sai',
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: InvestAITheme.texto,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Não precisa ser exato. É só para calcularmos sua reserva de '
            'emergência — depois ajustamos com seus gastos reais.',
            style: GoogleFonts.inter(fontSize: 14, color: InvestAITheme.cinza),
          ),
          const SizedBox(height: 32),

          TextFormField(
            controller: widget.rendaCtrl,
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
            ),
          ),

          const SizedBox(height: 28),

          Row(
            children: [
              Expanded(
                child: Text(
                  'Seus gastos do mês',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: InvestAITheme.cinza,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              TextButton(
                onPressed: widget.onEstimarPelaRenda,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Não sei estimar agora',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: InvestAITheme.verde,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          for (final campo in _camposDespesa) ...[
            TextFormField(
              controller: widget.despesaCtrls[campo.chave],
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
              ],
              style: const TextStyle(color: InvestAITheme.texto),
              decoration: InputDecoration(
                labelText: campo.label,
                helperText: campo.exemplo,
                hintText: '0,00',
                prefixIcon:
                    Icon(campo.icone, color: InvestAITheme.cinza, size: 20),
              ),
            ),
            const SizedBox(height: 16),
          ],

          _ResumoDespesas(
            total: _total,
            renda: _renda,
            estimado: widget.estimativaAuto != null,
            reais: _reais,
          ),

          if (widget.erro != null) ...[
            const SizedBox(height: 16),
            _ErroCard(mensagem: widget.erro!),
          ],

          const SizedBox(height: 28),

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

/// Mostra a soma dos gastos e o quanto ela representa da renda. Essa
/// comparação é o que permite a pessoa perceber sozinha que exagerou ou
/// esqueceu alguma conta - sozinho, o número total não diz nada a quem
/// nunca acompanhou os próprios gastos.
class _ResumoDespesas extends StatelessWidget {
  final double total;
  final double renda;
  final bool estimado;
  final String Function(double) reais;

  const _ResumoDespesas({
    required this.total,
    required this.renda,
    required this.estimado,
    required this.reais,
  });

  @override
  Widget build(BuildContext context) {
    if (total <= 0) {
      return const SizedBox.shrink();
    }

    final proporcao = renda > 0 ? total / renda : null;

    String? aviso;
    Color cor = InvestAITheme.verde;
    if (estimado) {
      aviso = 'Estimativa a partir da sua renda, só para começar. Assim que '
          'você registrar seus gastos, ajustamos sozinho.';
    } else if (proporcao != null) {
      if (proporcao > 1) {
        aviso = 'Seus gastos passam da sua renda. Confira se não digitou '
            'algum valor errado.';
        cor = InvestAITheme.vermelho;
      } else if (proporcao < 0.3) {
        aviso = 'Parece baixo para quem ganha ${reais(renda)}. Faltou '
            'mercado, transporte ou alguma conta fixa?';
        cor = InvestAITheme.amarelo;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                estimado ? 'Estimativa por mês' : 'Total por mês',
                style: GoogleFonts.inter(
                    fontSize: 13, color: InvestAITheme.cinza),
              ),
              const Spacer(),
              Text(
                reais(total),
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: cor,
                ),
              ),
            ],
          ),
          if (proporcao != null) ...[
            const SizedBox(height: 4),
            Text(
              '${(proporcao * 100).toStringAsFixed(0)}% da sua renda',
              style:
                  GoogleFonts.inter(fontSize: 12, color: InvestAITheme.cinza),
            ),
          ],
          if (aviso != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: cor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    aviso,
                    style: GoogleFonts.inter(fontSize: 12, color: cor),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Etapa 2: Perfil de investidor ────────────────────────────────────────────

class _EtapaPerfil extends StatelessWidget {
  final String perfilSelecionado;
  final String? erro;
  final bool carregando;
  final ValueChanged<String> onPerfilChange;
  final VoidCallback onCadastrar;

  const _EtapaPerfil({
    super.key,
    required this.perfilSelecionado,
    required this.erro,
    required this.carregando,
    required this.onPerfilChange,
    required this.onCadastrar,
  });

  static const List<_PerfilOpcao> _perfis = [
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
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Perfil de investidor',
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

          ..._perfis.map((perfil) => _PerfilCard(
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
              ? InvestAITheme.verde.withValues(alpha: 0.1)
              : InvestAITheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selecionado ? InvestAITheme.verde : InvestAITheme.borda,
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
                    ? InvestAITheme.verde.withValues(alpha: 0.2)
                    : InvestAITheme.borda,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                perfil.icone,
                color: selecionado ? InvestAITheme.verde : InvestAITheme.cinza,
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
        color: InvestAITheme.vermelho.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: InvestAITheme.vermelho.withValues(alpha: 0.3)),
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
