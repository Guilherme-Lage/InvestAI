import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart' show navigatorKey;
import '../models/usuario.dart';
import '../models/movimentacao.dart';
import '../models/meta.dart';
import '../models/investimento.dart';
import '../models/limite_categoria.dart';
import '../models/recorrencia.dart';
import '../models/transacao_extrato.dart';
import '../screens/chat_ia_screen.dart' show limparConversaIa;
import '../screens/login_screen.dart';

/// Erro de uma chamada à API, com a mensagem já pronta para mostrar ao
/// usuário (a mesma que o Flask devolve em `{"erro": "..."}`).
class ApiException implements Exception {
  final String mensagem;
  ApiException(this.mensagem);
  @override
  String toString() => mensagem;
}

class ApiService {
  /// Endereço do backend Flask.
  ///
  /// Para apontar para outro lugar sem editar o código, compile com
  /// `--dart-define=API_URL=http://192.168.0.10:5000`.
  static final String baseUrl = _resolverBaseUrl();

  static String _resolverBaseUrl() {
    const definida = String.fromEnvironment('API_URL');
    if (definida.isNotEmpty) return definida;

    // Na web, o backend roda na mesma máquina que serviu a página. Usar o
    // endereço da própria página faz o app funcionar tanto no PC
    // (localhost) quanto aberto pelo navegador do celular (IP do PC na
    // rede) - "localhost", no celular, seria o próprio celular.
    if (kIsWeb && Uri.base.host.isNotEmpty) {
      return 'http://${Uri.base.host}:5000';
    }
    return 'http://localhost:5000';
  }

  static const String _userIdKey = 'usuario_id';
  static const String _userNomeKey = 'usuario_nome';
  static const String _userEmailKey = 'usuario_email';
  static const String _userPerfilKey = 'usuario_perfil_risco';
  static const String _userRendaKey = 'usuario_renda_mensal';
  static const String _userDespesaKey = 'usuario_despesa_mensal_estimada';
  static const String _tokenKey = 'auth_token';

  // ─── Persistência local da sessão ───────────────────────────────────────────
  // Guardamos o token JWT junto com os dados do usuário. O token é o que
  // prova, do lado do backend, que o usuário está autenticado (RF02).

  static Future<void> salvarSessao(Usuario usuario, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await _salvarDadosUsuario(usuario);
  }

  /// Cópia local dos dados do usuário, usada quando o app abre sem
  /// conexão. Precisa ser regravada sempre que o backend devolver o
  /// usuário (login, abertura do app, edição do perfil), senão o app
  /// offline mostraria um perfil de investidor desatualizado.
  static Future<void> _salvarDadosUsuario(Usuario usuario) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userIdKey, usuario.id!);
    await prefs.setString(_userNomeKey, usuario.nome);
    await prefs.setString(_userEmailKey, usuario.email);
    await prefs.setString(_userPerfilKey, usuario.perfilRisco);
    await prefs.setDouble(_userRendaKey, usuario.rendaMensal);
    await prefs.setDouble(_userDespesaKey, usuario.despesaMensalEstimada);
  }

  static Future<Map<String, dynamic>?> carregarSessao() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_userIdKey);
    final token = prefs.getString(_tokenKey);
    if (id == null || token == null) return null;
    return {
      'id': id,
      'nome': prefs.getString(_userNomeKey) ?? '',
      'email': prefs.getString(_userEmailKey) ?? '',
      // Sessões gravadas por versões antigas do app não têm estes campos.
      // Sem saber o perfil, vale o mais cauteloso (o mesmo padrão do
      // backend), nunca um que sugira mais risco do que a pessoa escolheu.
      'perfil_risco': prefs.getString(_userPerfilKey) ?? 'conservador',
      'renda_mensal': prefs.getDouble(_userRendaKey) ?? 0.0,
      'despesa_mensal_estimada': prefs.getDouble(_userDespesaKey) ?? 0.0,
      'token': token,
    };
  }

  static Future<void> limparSessao() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_userNomeKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userPerfilKey);
    await prefs.remove(_userRendaKey);
    await prefs.remove(_userDespesaKey);
    await prefs.remove(_tokenKey);
    // A conversa com a IA fala de dinheiro: não pode sobrar para quem
    // entrar depois no mesmo aparelho.
    await limparConversaIa();
  }

  static Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Confere junto ao backend se o token salvo localmente ainda é válido
  /// (não expirou e não foi revogado por um logout). Usado na tela de
  /// splash para não confiar cegamente numa sessão salva no aparelho.
  static Future<Usuario?> verificarSessao() async {
    final sessao = await carregarSessao();
    if (sessao == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/usuarios/me'),
        headers: {'Authorization': 'Bearer ${sessao['token']}'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final usuario = Usuario.fromJson(jsonDecode(response.body));
        await _salvarDadosUsuario(usuario);
        return usuario;
      }
      // Token expirado, revogado ou inválido: encerra a sessão local.
      await limparSessao();
      return null;
    } catch (e) {
      // Sem conexão: abre com a última cópia dos dados que o backend
      // devolveu, para não travar o app offline.
      return Usuario.fromJson(sessao);
    }
  }

  // ─── Login (RF02): e-mail + senha, autenticado via JWT ──────────────────────

  static Future<LoginResult> login(String email, String senha) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/usuarios/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'senha': senha}),
      ).timeout(const Duration(seconds: 10));

      final corpo = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final usuario = Usuario.fromJson(corpo['usuario']);
        final token = corpo['token'] as String;
        await salvarSessao(usuario, token);
        return LoginResult.sucesso(usuario);
      }

      return LoginResult.erro(
        corpo['erro'] ?? 'Erro ao entrar (${response.statusCode}).',
      );
    } catch (e) {
      return LoginResult.erro('Não foi possível conectar ao servidor. Verifique sua conexão.');
    }
  }

  // ─── Logout (RF02): revoga o token no backend e limpa a sessão local ────────

  static Future<void> logout() async {
    final sessao = await carregarSessao();
    if (sessao != null) {
      try {
        await http.post(
          Uri.parse('$baseUrl/api/usuarios/logout'),
          headers: {'Authorization': 'Bearer ${sessao['token']}'},
        ).timeout(const Duration(seconds: 10));
      } catch (e) {
        // Mesmo sem conexão, seguimos e limpamos a sessão local abaixo —
        // o usuário não pode ficar "preso" logado por falta de rede.
      }
    }
    await limparSessao();
  }

  // ─── Cadastro (RF01) ─────────────────────────────────────────────────────────

  static Future<CadastroResult> cadastrar({
    required String nome,
    required String email,
    required String senha,
    required String perfilRisco,
    required double rendaMensal,
    required double despesaMensalEstimada,
    required double despesaFixaEstimada,
    required bool consentimentoAceito,
  }) async {
    try {
      final body = jsonEncode({
        'nome': nome,
        'email': email,
        'senha': senha,
        'perfil_risco': perfilRisco,
        'renda_mensal': rendaMensal,
        'despesa_mensal_estimada': despesaMensalEstimada,
        'despesa_fixa_estimada': despesaFixaEstimada,
        'consentimento_aceito': consentimentoAceito,
      });

      final response = await http.post(
        Uri.parse('$baseUrl/api/usuarios'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 10));

      final corpo = jsonDecode(response.body);

      if (response.statusCode == 201) {
        final usuario = Usuario.fromJson(corpo['usuario']);
        final token = corpo['token'] as String;
        await salvarSessao(usuario, token);
        return CadastroResult.sucesso(usuario);
      }

      return CadastroResult.erro(
        corpo['erro'] ?? 'Erro ao criar conta (${response.statusCode}).',
      );
    } catch (e) {
      return CadastroResult.erro('Não foi possível conectar ao servidor. Verifique sua conexão.');
    }
  }

  // ─── RF18 - atualizar perfil (perfil de investidor / renda) ─────────────────

  /// Exclui a conta e todos os dados dela (direito de eliminação prometido
  /// no termo de consentimento). Pede a senha de novo para confirmar; se
  /// der certo, encerra a sessão local também.
  static Future<void> excluirConta(int id, String senha) async {
    await _delete('/api/usuarios/$id', {'senha': senha});
    await limparSessao();
  }

  static Future<Usuario> atualizarUsuario(int id, Map<String, dynamic> dados) async {
    final corpo = await _put('/api/usuarios/$id', dados);
    final usuario = Usuario.fromJson(corpo);
    await _salvarDadosUsuario(usuario);
    return usuario;
  }

  // ─── Requisição autenticada genérica ────────────────────────────────────────
  // Todas as rotas de movimentações, metas, investimentos, limites e
  // orientação exigem 'Authorization: Bearer <token>' (RF02).

  static Future<Map<String, String>> _headers() async {
    final token = await _token();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static dynamic _decodir(http.Response response) {
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  static Future<dynamic> _tratarResposta(http.Response response) async {
    final corpo = _decodir(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return corpo;
    }
    final mensagem = (corpo is Map && corpo['erro'] != null)
        ? corpo['erro'] as String
        : 'Erro inesperado (${response.statusCode}).';

    // 401 numa chamada autenticada só acontece quando a sessão não é mais
    // válida (token expirado/revogado ou usuário excluído) - nesses casos,
    // não adianta mostrar "tentar novamente": a sessão local é limpa e o
    // usuário volta para o login automaticamente, de qualquer tela do app.
    if (response.statusCode == 401) {
      await limparSessao();
      final navegador = navigatorKey.currentState;
      if (navegador != null) {
        navegador.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }

    throw ApiException(mensagem);
  }

  static Future<dynamic> _get(String caminho, [Map<String, String>? query, Duration? timeout]) async {
    try {
      final uri = Uri.parse('$baseUrl$caminho').replace(queryParameters: query);
      final response = await http.get(uri, headers: await _headers())
          .timeout(timeout ?? const Duration(seconds: 10));
      return await _tratarResposta(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Não foi possível conectar ao servidor.');
    }
  }

  static Future<dynamic> _post(String caminho, Map<String, dynamic> corpo, [Duration? timeout]) async {
    try {
      final response = await http
          .post(Uri.parse('$baseUrl$caminho'), headers: await _headers(), body: jsonEncode(corpo))
          .timeout(timeout ?? const Duration(seconds: 10));
      return await _tratarResposta(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Não foi possível conectar ao servidor.');
    }
  }

  static Future<dynamic> _put(String caminho, Map<String, dynamic> corpo) async {
    try {
      final response = await http
          .put(Uri.parse('$baseUrl$caminho'), headers: await _headers(), body: jsonEncode(corpo))
          .timeout(const Duration(seconds: 10));
      return await _tratarResposta(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Não foi possível conectar ao servidor.');
    }
  }

  static Future<dynamic> _delete(String caminho, [Map<String, dynamic>? corpo]) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl$caminho'),
            headers: await _headers(),
            body: corpo == null ? null : jsonEncode(corpo),
          )
          .timeout(const Duration(seconds: 10));
      return await _tratarResposta(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Não foi possível conectar ao servidor.');
    }
  }

  // ─── Movimentações: RF03/RF04/RF05/RF08/RF09/RF10/RF11/RF12/RF13/RF19 ──────

  static Future<List<Movimentacao>> listarMovimentacoes({
    String? tipo,
    String? categoria,
    String? dataInicio,
    String? dataFim,
    String ordenar = 'data_desc',
  }) async {
    final query = <String, String>{'ordenar': ordenar};
    if (tipo != null) query['tipo'] = tipo;
    if (categoria != null) query['categoria'] = categoria;
    if (dataInicio != null) query['data_inicio'] = dataInicio;
    if (dataFim != null) query['data_fim'] = dataFim;
    final lista = await _get('/api/movimentacoes', query) as List;
    return lista.map((e) => Movimentacao.fromJson(e)).toList();
  }

  static Future<Movimentacao> criarMovimentacao(Movimentacao m) async {
    final corpo = await _post('/api/movimentacoes', m.toJson());
    return Movimentacao.fromJson(corpo);
  }

  static Future<Movimentacao> atualizarMovimentacao(int id, Movimentacao m) async {
    final corpo = await _put('/api/movimentacoes/$id', m.toJson());
    return Movimentacao.fromJson(corpo);
  }

  static Future<void> deletarMovimentacao(int id) => _delete('/api/movimentacoes/$id');

  static Future<double> saldo() async {
    final corpo = await _get('/api/movimentacoes/saldo');
    return (corpo['saldo'] ?? 0).toDouble();
  }

  static Future<double> capacidadeEconomiaMensal() async {
    final corpo = await _get('/api/movimentacoes/capacidade-economia');
    return (corpo['capacidade_economia_mensal'] ?? 0).toDouble();
  }

  static Future<double?> tempoSobrevivenciaMeses() async {
    final corpo = await _get('/api/movimentacoes/sobrevivencia');
    final valor = corpo['meses_sobrevivencia'];
    return valor == null ? null : (valor as num).toDouble();
  }

  static Future<Map<String, dynamic>> relatorioMensal({int? ano, int? mes}) async {
    final query = <String, String>{};
    if (ano != null) query['ano'] = '$ano';
    if (mes != null) query['mes'] = '$mes';
    return await _get('/api/movimentacoes/relatorio-mensal', query) as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> gastosPorCategoria({String? dataInicio, String? dataFim}) async {
    final query = <String, String>{};
    if (dataInicio != null) query['data_inicio'] = dataInicio;
    if (dataFim != null) query['data_fim'] = dataFim;
    final lista = await _get('/api/movimentacoes/gastos-por-categoria', query) as List;
    return lista.cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> alertas() async {
    return await _get('/api/movimentacoes/alertas') as Map<String, dynamic>;
  }

  /// Relatório mensal (RF10) como arquivo. `formato` é 'pdf' ou 'csv'.
  /// Devolve os bytes em vez de JSON, por isso não passa pelo `_get`.
  static Future<Uint8List> exportarRelatorio({
    required String formato,
    required int ano,
    required int mes,
  }) async {
    final http.Response response;
    try {
      final uri = Uri.parse('$baseUrl/api/movimentacoes/relatorio-mensal/exportar')
          .replace(queryParameters: {'formato': formato, 'ano': '$ano', 'mes': '$mes'});
      response = await http.get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      throw ApiException('Não foi possível conectar ao servidor.');
    }
    if (response.statusCode != 200) {
      await _tratarResposta(response); // sempre lança, com a mensagem do backend
    }
    return response.bodyBytes;
  }

  // ─── Importação de extrato bancário (OFX) ───────────────────────────────────
  // Em dois passos: analisar devolve as transações para revisão, sem
  // gravar nada; confirmar grava as que o usuário deixou marcadas.

  static Future<AnaliseExtrato> analisarExtrato(Uint8List arquivo) async {
    final corpo = await _post(
      '/api/importacao/analisar',
      {'arquivo_base64': base64Encode(arquivo)},
      const Duration(seconds: 30),
    ) as Map<String, dynamic>;
    final ajuste = corpo['ajuste_saldo'];
    return AnaliseExtrato(
      transacoes: (corpo['transacoes'] as List).map((e) => TransacaoExtrato.fromJson(e)).toList(),
      ajuste: ajuste == null ? null : AjusteSaldo.fromJson(ajuste),
    );
  }

  /// Devolve quantas transações foram de fato importadas. [ajuste] é o
  /// lançamento de ajuste de saldo, já com o valor calculado na revisão.
  static Future<int> confirmarImportacao(List<TransacaoExtrato> transacoes,
      {Map<String, dynamic>? ajuste}) async {
    final corpo = await _post(
      '/api/importacao/confirmar',
      {
        'transacoes': [
          ...transacoes.map((t) => t.toJson()),
          if (ajuste != null) ajuste,
        ],
      },
      const Duration(seconds: 30),
    ) as Map<String, dynamic>;
    return (corpo['importadas'] ?? 0) as int;
  }

  // ─── Recorrências: receitas e despesas lançadas automaticamente ─────────────

  static Future<List<Recorrencia>> listarRecorrencias() async {
    final lista = await _get('/api/recorrencias') as List;
    return lista.map((e) => Recorrencia.fromJson(e)).toList();
  }

  /// `dataInicio` ('AAAA-MM-DD') é a partir de quando lançar; sem ela, hoje.
  static Future<Recorrencia> criarRecorrencia(Recorrencia r, {String? dataInicio}) async {
    final corpo = await _post('/api/recorrencias', {
      ...r.toJson(),
      if (dataInicio != null) 'data_inicio': dataInicio,
    });
    return Recorrencia.fromJson(corpo);
  }

  static Future<Recorrencia> atualizarRecorrencia(int id, Map<String, dynamic> dados) async {
    final corpo = await _put('/api/recorrencias/$id', dados);
    return Recorrencia.fromJson(corpo);
  }

  static Future<void> deletarRecorrencia(int id) => _delete('/api/recorrencias/$id');

  // ─── Metas: RF06/RF07/RF14/RF15/RF17 ────────────────────────────────────────

  static Future<List<Meta>> listarMetas() async {
    final lista = await _get('/api/metas') as List;
    return lista.map((e) => Meta.fromJson(e)).toList();
  }

  static Future<Meta> criarMeta(Meta m) async {
    final corpo = await _post('/api/metas', m.toJson());
    return Meta.fromJson(corpo);
  }

  static Future<Meta> atualizarMeta(int id, Meta m) async {
    final corpo = await _put('/api/metas/$id', m.toJson());
    return Meta.fromJson(corpo);
  }

  static Future<void> deletarMeta(int id) => _delete('/api/metas/$id');

  static Future<Map<String, dynamic>> reservaEmergencia() async {
    return await _get('/api/metas/reserva-emergencia') as Map<String, dynamic>;
  }

  // ─── Investimentos ───────────────────────────────────────────────────────────

  static Future<List<Investimento>> listarInvestimentos() async {
    final lista = await _get('/api/investimentos') as List;
    return lista.map((e) => Investimento.fromJson(e)).toList();
  }

  static Future<Investimento> criarInvestimento(Investimento i) async {
    final corpo = await _post('/api/investimentos', i.toJson());
    return Investimento.fromJson(corpo);
  }

  static Future<void> deletarInvestimento(int id) => _delete('/api/investimentos/$id');

  // ─── Limites por categoria: RF13 ────────────────────────────────────────────

  static Future<List<LimiteCategoria>> listarLimites() async {
    final lista = await _get('/api/limites') as List;
    return lista.map((e) => LimiteCategoria.fromJson(e)).toList();
  }

  static Future<LimiteCategoria> definirLimite(String categoria, double valorLimite) async {
    final corpo = await _post('/api/limites', {
      'categoria': categoria,
      'valor_limite': valorLimite,
    });
    return LimiteCategoria.fromJson(corpo);
  }

  static Future<void> deletarLimite(int id) => _delete('/api/limites/$id');

  // ─── Orientação financeira: RF16/RF20 ───────────────────────────────────────

  static Future<Map<String, dynamic>> guiaFinanceiro() async {
    return await _get('/api/orientacao/guia') as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> scoreFinanceiro() async {
    return await _get('/api/orientacao/score') as Map<String, dynamic>;
  }

  /// Evolução do score: um ponto por dia em que o usuário consultou.
  static Future<Map<String, dynamic>> historicoScore({int dias = 90}) async {
    return await _get('/api/orientacao/score/historico', {'dias': '$dias'})
        as Map<String, dynamic>;
  }

  // ─── Mercado: cotação do dólar e taxas oficiais (Selic/CDI/IPCA) ────────────

  static Future<Map<String, dynamic>> cotacaoDolar() async {
    return await _get('/api/mercado/dolar') as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> taxasMercado() async {
    return await _get('/api/mercado/taxas') as Map<String, dynamic>;
  }

  /// Termos de uso dos dados. Sem autenticação: precisam poder ser lidos
  /// antes de criar a conta.
  static Future<Map<String, dynamic>> termosConsentimento() async {
    final resposta = await http
        .get(Uri.parse('$baseUrl/api/usuarios/termos'))
        .timeout(const Duration(seconds: 10));
    return jsonDecode(resposta.body) as Map<String, dynamic>;
  }

  /// Texto integral do termo (LGPD), em Markdown.
  static Future<String> termoCompleto() async {
    final resposta = await http
        .get(Uri.parse('$baseUrl/api/usuarios/termos/completo'))
        .timeout(const Duration(seconds: 15));
    final corpo = jsonDecode(resposta.body) as Map<String, dynamic>;
    if (resposta.statusCode != 200) {
      throw ApiException(corpo['erro'] ?? 'Termo indisponível.');
    }
    return corpo['texto'] as String;
  }

  /// Quanto o usuário deixa de ganhar por ano mantendo cada investimento
  /// onde está, frente à melhor alternativa de liquidez equivalente.
  static Future<Map<String, dynamic>> compararCarteira() async {
    return await _get('/api/investimentos/comparar', null,
        const Duration(seconds: 20)) as Map<String, dynamic>;
  }

  /// Projeta quanto o valor inicial + aportes mensais renderiam em cada
  /// aplicação, com as taxas oficiais do dia.
  static Future<Map<String, dynamic>> simularAporte({
    required double valorInicial,
    required double aporteMensal,
  }) async {
    final corpo = await _post('/api/investimentos/simular', {
      'valor_inicial': valorInicial,
      'aporte_mensal': aporteMensal,
    }, const Duration(seconds: 20));
    return corpo as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> titulosTesouro() async {
    // O backend pré-aquece esse cache em segundo plano, mas na pior
    // hipótese (cache ainda frio logo após o servidor subir) a primeira
    // busca pode levar dezenas de segundos - daí o timeout maior aqui.
    return await _get('/api/mercado/tesouro', null, const Duration(seconds: 40)) as Map<String, dynamic>;
  }

  // ─── Assistente de IA (n8n) ─────────────────────────────────────────────────

  static Future<String> perguntarIa(String pergunta) async {
    // A resposta passa por um modelo de linguagem, que costuma demorar
    // bem mais que uma consulta comum ao banco.
    final corpo = await _post(
      '/api/ia/perguntar',
      {'pergunta': pergunta},
      const Duration(seconds: 60),
    ) as Map<String, dynamic>;
    return corpo['resposta'] as String;
  }
}

// ─── Result types simples ──────────────────────────────────────────────────

class LoginResult {
  final bool sucesso;
  final Usuario? usuario;
  final String? mensagemErro;

  LoginResult._({required this.sucesso, this.usuario, this.mensagemErro});

  factory LoginResult.sucesso(Usuario u) => LoginResult._(sucesso: true, usuario: u);
  factory LoginResult.erro(String msg) => LoginResult._(sucesso: false, mensagemErro: msg);
}

class CadastroResult {
  final bool sucesso;
  final Usuario? usuario;
  final String? mensagemErro;

  CadastroResult._({required this.sucesso, this.usuario, this.mensagemErro});

  factory CadastroResult.sucesso(Usuario u) => CadastroResult._(sucesso: true, usuario: u);
  factory CadastroResult.erro(String msg) => CadastroResult._(sucesso: false, mensagemErro: msg);
}
