import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:investai/models/usuario.dart';
import 'package:investai/screens/cadastro_screen.dart';
import 'package:investai/screens/dashboard_tab.dart';
import 'package:investai/screens/perfil_tab.dart';

import 'apoio/api_falsa.dart';

Map<String, dynamic> _me(ApiFalsa api) =>
    Map<String, dynamic>.from(api.resposta('/api/usuarios/me') as Map);

/// A conta de demonstração, que abre sempre com o questionário pendente -
/// como fica quem pulou no cadastro.
Usuario _semQuestionario(ApiFalsa api) =>
    Usuario.fromJson(_me(api)..['suitability_respondido'] = false);

/// A mesma conta, com o questionário já respondido.
Usuario _comQuestionario(ApiFalsa api) => Usuario.fromJson(_me(api)
  ..['suitability_respondido'] = true
  ..['perfil_risco'] = 'moderado');

int _totalPerguntas(ApiFalsa api) =>
    (api.resposta('/api/usuarios/suitability')['perguntas'] as List).length;

/// Responde todas as perguntas escolhendo sempre a última opção e toca no
/// botão final ([textoFinal]).
Future<void> _responderTudo(WidgetTester tester, ApiFalsa api, String textoFinal) async {
  final perguntas = api.resposta('/api/usuarios/suitability')['perguntas'] as List;
  for (var i = 0; i < perguntas.length; i++) {
    final opcao = find.text((perguntas[i]['opcoes'] as List).last as String);
    await tester.ensureVisible(opcao);
    await tester.tap(opcao);
    await tester.pumpAndSettle();
    final botao = find.text(i == perguntas.length - 1 ? textoFinal : 'Próxima');
    await tester.ensureVisible(botao);
    await tester.tap(botao);
    await tester.pumpAndSettle();
  }
}

void main() {
  group('aviso de questionário pendente', () {
    testeDeTela('Início lembra quem pulou o questionário', (tester, api) async {
      await montarTela(
        tester,
        api,
        DashboardTab(usuario: _semQuestionario(api), onVerTodasMetas: () {}),
        tamanho: telaPequena,
      );
      expect(find.text('Complete seu questionário'), findsOneWidget);
    });

    testeDeTela('Início não mostra o aviso para quem já respondeu', (tester, api) async {
      await montarTela(
        tester,
        api,
        DashboardTab(usuario: _comQuestionario(api), onVerTodasMetas: () {}),
      );
      expect(find.text('Complete seu questionário'), findsNothing);
    });

    testeDeTela('Perfil mostra o perfil como pendente', (tester, api) async {
      await montarTela(
        tester,
        api,
        PerfilTab(usuario: _semQuestionario(api), aoAtualizarUsuario: (_) {}),
      );
      expect(find.text('Complete seu questionário'), findsOneWidget);
      expect(find.text('Pendente'), findsOneWidget);
    });
  });

  group('questionário pela aba Perfil', () {
    testeDeTela('o seletor manual de perfil não existe mais', (tester, api) async {
      await montarTela(
        tester,
        api,
        PerfilTab(usuario: _comQuestionario(api), aoAtualizarUsuario: (_) {}),
      );
      await tester.tap(find.text('Perfil de investidor'));
      await tester.pumpAndSettle();
      // Abre o questionário, e não uma lista para escolher o perfil.
      expect(find.text('Pergunta 1 de ${_totalPerguntas(api)}'), findsOneWidget);
      expect(find.text('Arrojado'), findsNothing);
    });

    testeDeTela('"Voltar" leva à pergunta anterior e deixa trocar a resposta',
        (tester, api) async {
      final usuario = _semQuestionario(api);
      await montarTela(
        tester,
        api,
        PerfilTab(usuario: usuario, aoAtualizarUsuario: (_) {}),
        tamanho: telaPequena,
      );
      await tester.tap(find.text('Complete seu questionário'));
      await tester.pumpAndSettle();

      final perguntas = api.resposta('/api/usuarios/suitability')['perguntas'] as List;
      final opcoes1 = (perguntas[0]['opcoes'] as List).cast<String>();
      final total = perguntas.length;

      // Na primeira pergunta não há para onde voltar.
      expect(find.text('Voltar'), findsNothing);

      await tester.tap(find.text(opcoes1.first));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Próxima'));
      await tester.tap(find.text('Próxima'));
      await tester.pumpAndSettle();
      expect(find.text('Pergunta 2 de $total'), findsOneWidget);

      await tester.ensureVisible(find.text('Voltar'));
      await tester.tap(find.text('Voltar'));
      await tester.pumpAndSettle();
      expect(find.text('Pergunta 1 de $total'), findsOneWidget);

      // A escolha anterior continua marcada, e dá para trocar.
      final marcada = find.ancestor(
        of: find.byIcon(Icons.radio_button_checked_rounded),
        matching: find.byType(Row),
      );
      expect(find.descendant(of: marcada.first, matching: find.text(opcoes1.first)),
          findsOneWidget);
      await tester.ensureVisible(find.text(opcoes1.last));
      await tester.tap(find.text(opcoes1.last));
      await tester.pumpAndSettle();
      expect(find.descendant(of: marcada.first, matching: find.text(opcoes1.last)),
          findsOneWidget);
    });

    testeDeTela('responder envia todas as respostas e atualiza o perfil', (tester, api) async {
      final usuario = _semQuestionario(api);
      final atualizado = _me(api)
        ..['perfil_risco'] = 'arrojado'
        ..['suitability_respondido'] = true;
      api.responder('POST /api/usuarios/${usuario.id}/suitability', {
        'usuario': atualizado,
        'resultado': {
          'perfil': 'arrojado',
          'pontuacao': 28,
          'descricao': 'Você aceita oscilações no caminho.',
        },
      });
      Usuario? recebido;

      await montarTela(
        tester,
        api,
        PerfilTab(usuario: usuario, aoAtualizarUsuario: (u) => recebido = u),
        tamanho: telaPequena,
      );
      await tester.tap(find.text('Complete seu questionário'));
      await tester.pumpAndSettle();
      await _responderTudo(tester, api, 'Ver meu perfil');

      final envio = api.escritas.single;
      expect(envio.url.path, '/api/usuarios/${usuario.id}/suitability');
      final respostas = jsonDecode(envio.body)['respostas'] as Map;
      expect(respostas.length, _totalPerguntas(api));

      expect(find.text('Arrojado'), findsOneWidget);
      await tester.tap(find.text('Concluir'));
      await tester.pumpAndSettle();
      expect(recebido?.perfilRisco, 'arrojado');
      expect(recebido?.suitabilityRespondido, isTrue);
    });
  });

  group('questionário no cadastro', () {
    Future<void> preencherAteOQuestionario(WidgetTester tester) async {
      await tester.enterText(find.widgetWithText(TextFormField, 'Nome completo'), 'Ana Teste');
      await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), 'ana@exemplo.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), 'Senha@123');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirmar senha'), 'Senha@123');
      await tester.ensureVisible(find.text('Continuar'));
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Renda mensal líquida'), '3000');
      await tester.tap(find.text('Não sei estimar agora'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continuar'));
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
    }

    Future<Map<String, dynamic>> criarConta(WidgetTester tester, ApiFalsa api) async {
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.ensureVisible(find.text('Criar minha conta'));
      await tester.tap(find.text('Criar minha conta'));
      await tester.pump();
      final envio = api.escritas.firstWhere((c) => c.url.path == '/api/usuarios');
      return jsonDecode(envio.body) as Map<String, dynamic>;
    }

    void prepararCadastro(ApiFalsa api) {
      // Resposta com erro: o teste só precisa do que foi enviado, sem
      // seguir para a tela de boas-vindas.
      api.responder('POST /api/usuarios', {'erro': 'parar aqui'}, status: 400);
    }

    testeDeTela('dá para pular, e a conta é criada sem respostas', (tester, api) async {
      prepararCadastro(api);
      await montarTela(tester, api, const CadastroScreen());
      await preencherAteOQuestionario(tester);

      expect(find.text('Pergunta 1 de ${_totalPerguntas(api)}'), findsOneWidget);
      await tester.tap(find.text('Pular por enquanto'));
      await tester.pumpAndSettle();

      expect(find.text('Questionário pendente'), findsOneWidget);
      final corpo = await criarConta(tester, api);
      expect(corpo.containsKey('respostas_suitability'), isFalse);
      expect(corpo.containsKey('perfil_risco'), isFalse);
    });

    testeDeTela('respondido, as respostas vão junto com o cadastro', (tester, api) async {
      prepararCadastro(api);
      await montarTela(tester, api, const CadastroScreen(), tamanho: telaPequena);
      await preencherAteOQuestionario(tester);
      await _responderTudo(tester, api, 'Continuar');

      expect(find.text('Questionário respondido'), findsOneWidget);
      final corpo = await criarConta(tester, api);
      expect((corpo['respostas_suitability'] as Map).length, _totalPerguntas(api));
    });

    testeDeTela('voltar da confirmação reabre o questionário com as respostas',
        (tester, api) async {
      prepararCadastro(api);
      await montarTela(tester, api, const CadastroScreen());
      await preencherAteOQuestionario(tester);
      await _responderTudo(tester, api, 'Continuar');
      expect(find.text('Questionário respondido'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      final total = _totalPerguntas(api);
      expect(find.text('Pergunta $total de $total'), findsOneWidget);
      // A última resposta continua marcada: dá para seguir sem refazer tudo.
      await tester.ensureVisible(find.text('Continuar'));
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Questionário respondido'), findsOneWidget);
    });
  });
}
