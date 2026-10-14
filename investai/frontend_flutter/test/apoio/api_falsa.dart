import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:investai/theme.dart';

/// Backend de mentira para os testes de tela.
///
/// As respostas de leitura (GET) vêm de `respostas_api.json`, que é
/// gravado a partir do backend de verdade - ver
/// `backend/tests/gerar_respostas_para_flutter.py`. Escritas (POST, PUT,
/// DELETE) são só registradas em [chamadas], para o teste conferir o que
/// o app mandou.
class ApiFalsa {
  final Map<String, dynamic> _respostas;
  final List<http.Request> chamadas = [];

  ApiFalsa()
      : _respostas = jsonDecode(
          File('test/apoio/respostas_api.json').readAsStringSync(),
        ) as Map<String, dynamic>;

  /// Resposta gravada de uma rota, para o teste comparar com a tela.
  dynamic resposta(String rota) => _respostas[rota];

  /// Define o que o backend falso devolve para uma rota neste teste.
  /// Para escritas a chave leva o método: `'POST /api/importacao/confirmar'`.
  void responder(String rota, dynamic corpo) => _respostas[rota] = corpo;

  /// Chamadas de escrita feitas pelo app, na ordem.
  List<http.Request> get escritas =>
      chamadas.where((c) => c.method != 'GET').toList();

  http.Client get cliente => MockClient((requisicao) async {
        chamadas.add(requisicao);

        if (requisicao.method != 'GET') {
          // Escritas com resposta definida (gravada do backend ou combinada
          // pelo teste via [responder]); as demais devolvem o que receberam.
          final definida = _respostas['${requisicao.method} ${requisicao.url.path}'];
          final corpo = definida != null
              ? jsonEncode(definida)
              : (requisicao.body.isEmpty ? '{}' : requisicao.body);
          return _json(corpo, requisicao.method == 'POST' ? 201 : 200);
        }

        final gravada = _respostas[requisicao.url.path];
        if (gravada == null) {
          // Rotas que dependem de internet (dólar, Tesouro) e as fontes do
          // Google: o app precisa seguir funcionando sem elas.
          return _json('{"erro": "indisponível no teste"}', 503);
        }
        return _json(jsonEncode(gravada), 200);
      });

  http.Response _json(String corpo, int status) => http.Response.bytes(
        utf8.encode(corpo),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
}

/// Tamanhos de tela usados nos testes: um celular comum e um pequeno, que
/// é onde texto estourando e botão cortado costumam aparecer.
const telaComum = Size(390, 844);
const telaPequena = Size(320, 568);

/// A fonte dos testes desenha toda letra como um quadrado do tamanho da
/// fonte, bem mais larga que a Inter de verdade (cerca de 0,6 disso). O
/// texto é encolhido nessa proporção; sem isso, linhas que cabem com folga
/// no aparelho acusariam estouro aqui.
const _larguraRealDaLetra = 0.6;

/// Monta [tela] como se estivesse dentro do app, num celular de [tamanho],
/// com um usuário logado e todas as chamadas HTTP indo para [api].
///
/// O Flutter falha o teste sozinho quando um widget não cabe na tela
/// (overflow), então só montar a tela já é uma verificação de layout -
/// aproximada, pelo motivo explicado em [_larguraRealDaLetra].
Future<void> montarTela(
  WidgetTester tester,
  ApiFalsa api,
  Widget tela, {
  Size tamanho = telaComum,
}) async {
  SharedPreferences.setMockInitialValues({'auth_token': 'token-de-teste'});

  tester.view.physicalSize = tamanho;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: InvestAITheme.theme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: const TextScaler.linear(_larguraRealDaLetra)),
      child: child!,
    ),
    home: Scaffold(body: SafeArea(child: tela)),
  ));
  await tester.pumpAndSettle();
}

/// Rola a lista principal da tela até [alvo] aparecer. As abas são listas
/// longas, e o Flutter só constrói o que está perto da área visível.
Future<void> rolarAte(WidgetTester tester, Finder alvo) async {
  await tester.scrollUntilVisible(alvo, 200, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

/// Declara um teste de tela cujas chamadas HTTP vão para uma [ApiFalsa].
void testeDeTela(
  String descricao,
  Future<void> Function(WidgetTester tester, ApiFalsa api) corpo,
) {
  testWidgets(descricao, (tester) {
    final api = ApiFalsa();
    return http.runWithClient(() => corpo(tester, api), () => api.cliente);
  });
}
