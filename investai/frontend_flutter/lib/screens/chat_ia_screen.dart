import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../theme.dart';

/// Guarda a conversa no aparelho. Sem isso a tela abria em branco a cada
/// visita, enquanto a memória do agente continuava lembrando de tudo - a
/// pessoa repetia a pergunta e recebia "como eu disse antes...".
const _chaveConversa = 'conversa_ia';
const _limiteMensagens = 60;

class _Mensagem {
  final String texto;
  final bool doUsuario;
  final bool erro;

  const _Mensagem(this.texto, {required this.doUsuario, this.erro = false});

  Map<String, dynamic> paraJson() =>
      {'t': texto, 'u': doUsuario, 'e': erro};

  factory _Mensagem.doJson(Map<String, dynamic> json) => _Mensagem(
        json['t'] ?? '',
        doUsuario: json['u'] == true,
        erro: json['e'] == true,
      );
}

/// Apaga a conversa salva. Chamado no logout para a conversa de um usuário
/// não aparecer para quem entrar depois no mesmo aparelho.
Future<void> limparConversaIa() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chaveConversa);
  } catch (_) {
    // Sem preferências não há o que limpar.
  }
}

/// Chat com o assistente de IA do InvestAI. A inteligência em si roda num
/// agente externo (n8n); aqui só enviamos a pergunta e mostramos a resposta.
class ChatIaScreen extends StatefulWidget {
  /// Pergunta já enviada ao abrir a tela. Usada pelos botões "me explica"
  /// espalhados pelo app, para a pessoa não precisar formular a dúvida.
  final String? perguntaInicial;

  const ChatIaScreen({super.key, this.perguntaInicial});

  @override
  State<ChatIaScreen> createState() => _ChatIaScreenState();
}

const _saudacao = _Mensagem(
  'Oi! Sou o assistente do InvestAI. Posso te ajudar a entender seus '
  'gastos, sua reserva de emergência e o que faz sentido pro seu perfil. '
  'O que você quer saber?',
  doUsuario: false,
);

class _ChatIaScreenState extends State<ChatIaScreen> {
  final _controlador = TextEditingController();
  final _rolagem = ScrollController();
  final List<_Mensagem> _mensagens = [_saudacao];
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _restaurarConversa();
  }

  Future<void> _restaurarConversa() async {
    List<_Mensagem> salvas = const [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final bruto = prefs.getString(_chaveConversa);
      if (bruto != null) {
        salvas = (jsonDecode(bruto) as List)
            .map((m) => _Mensagem.doJson(m as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Conversa corrompida ou sem acesso ao armazenamento: começa limpa.
    }

    if (!mounted) return;
    if (salvas.isNotEmpty) {
      setState(() {
        _mensagens
          ..clear()
          ..addAll(salvas);
      });
      _rolarParaFim();
    }

    final inicial = widget.perguntaInicial?.trim();
    if (inicial != null && inicial.isNotEmpty) {
      _controlador.text = inicial;
      _enviar();
    }
  }

  Future<void> _salvarConversa() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Guarda só o fim da conversa: o histórico completo quem mantém é a
      // memória do agente, aqui é só o que a tela precisa mostrar.
      final recorte = _mensagens.length > _limiteMensagens
          ? _mensagens.sublist(_mensagens.length - _limiteMensagens)
          : _mensagens;
      await prefs.setString(_chaveConversa,
          jsonEncode(recorte.map((m) => m.paraJson()).toList()));
    } catch (_) {
      // Não conseguir salvar não pode atrapalhar a conversa em andamento.
    }
  }

  @override
  void dispose() {
    _controlador.dispose();
    _rolagem.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final pergunta = _controlador.text.trim();
    if (pergunta.isEmpty || _enviando) return;

    setState(() {
      _mensagens.add(_Mensagem(pergunta, doUsuario: true));
      _enviando = true;
      _controlador.clear();
    });
    _rolarParaFim();

    try {
      final resposta = await ApiService.perguntarIa(pergunta);
      if (!mounted) return;
      setState(() => _mensagens.add(_Mensagem(resposta, doUsuario: false)));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _mensagens.add(_Mensagem(e.mensagem, doUsuario: false, erro: true)));
    } finally {
      if (mounted) setState(() => _enviando = false);
      _rolarParaFim();
      _salvarConversa();
    }
  }

  void _rolarParaFim() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_rolagem.hasClients) return;
      _rolagem.animateTo(
        _rolagem.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InvestAITheme.fundo,
      appBar: AppBar(
        backgroundColor: InvestAITheme.card,
        foregroundColor: InvestAITheme.texto,
        title: const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: InvestAITheme.verde, size: 20),
            SizedBox(width: 8),
            Text('Assistente InvestAI'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _rolagem,
              padding: const EdgeInsets.all(16),
              itemCount: _mensagens.length + (_enviando ? 1 : 0),
              itemBuilder: (context, indice) {
                if (indice == _mensagens.length) return const _BalaoDigitando();
                return _Balao(mensagem: _mensagens[indice]);
              },
            ),
          ),
          _CampoPergunta(
            controlador: _controlador,
            habilitado: !_enviando,
            aoEnviar: _enviar,
          ),
        ],
      ),
    );
  }
}

class _Balao extends StatelessWidget {
  final _Mensagem mensagem;

  const _Balao({required this.mensagem});

  @override
  Widget build(BuildContext context) {
    final doUsuario = mensagem.doUsuario;
    return Align(
      alignment: doUsuario ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: doUsuario
              ? InvestAITheme.verde
              : (mensagem.erro ? InvestAITheme.vermelho.withOpacity(0.12) : InvestAITheme.card),
          borderRadius: BorderRadius.circular(14),
          border: doUsuario
              ? null
              : Border.all(
                  color: mensagem.erro ? InvestAITheme.vermelho : InvestAITheme.borda,
                ),
        ),
        child: Text(
          mensagem.texto,
          style: TextStyle(
            color: doUsuario
                ? InvestAITheme.verdeEscuro
                : (mensagem.erro ? InvestAITheme.vermelho : InvestAITheme.texto),
            height: 1.4,
            fontWeight: doUsuario ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _BalaoDigitando extends StatelessWidget {
  const _BalaoDigitando();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: InvestAITheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: InvestAITheme.borda),
        ),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: InvestAITheme.verde),
        ),
      ),
    );
  }
}

class _CampoPergunta extends StatelessWidget {
  final TextEditingController controlador;
  final bool habilitado;
  final VoidCallback aoEnviar;

  const _CampoPergunta({
    required this.controlador,
    required this.habilitado,
    required this.aoEnviar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: InvestAITheme.card,
        border: Border(top: BorderSide(color: InvestAITheme.borda)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controlador,
                enabled: habilitado,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => aoEnviar(),
                style: const TextStyle(color: InvestAITheme.texto),
                decoration: const InputDecoration(
                  hintText: 'Pergunte sobre suas finanças...',
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: habilitado ? aoEnviar : null,
              style: IconButton.styleFrom(
                backgroundColor: InvestAITheme.verde,
                foregroundColor: InvestAITheme.verdeEscuro,
                minimumSize: const Size(48, 48),
              ),
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
