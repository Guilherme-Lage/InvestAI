import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:investai/models/usuario.dart';
import 'package:investai/screens/perfil_tab.dart';
import 'package:investai/utils/validacao_senha.dart';

import 'apoio/api_falsa.dart';

void main() {
  group('regra de senha (a mesma do backend)', () {
    test('recusa a senha e diz o que falta', () {
      expect(problemaNaSenha('a1@'), contains('6 caracteres'));
      expect(problemaNaSenha('123456@#'), contains('letra'));
      expect(problemaNaSenha('senha@abc'), contains('número'));
      expect(problemaNaSenha('senha123'), contains('caractere especial'));
      expect(problemaNaSenha('senha 123'), contains('caractere especial'));
    });

    test('aceita senha com letra, número e caractere especial', () {
      for (final senha in ['Senha@123', 'abc_123', 'ção#9x', 'a1-b2c3']) {
        expect(problemaNaSenha(senha), isNull, reason: senha);
      }
    });
  });

  group('excluir conta pelo Perfil', () {
    Usuario usuario(ApiFalsa api) => Usuario.fromJson(api.resposta('/api/usuarios/me'));

    Future<void> abrirConfirmacao(WidgetTester tester, ApiFalsa api) async {
      await montarTela(
        tester,
        api,
        PerfilTab(usuario: usuario(api), aoAtualizarUsuario: (_) {}),
      );
      await rolarAte(tester, find.text('Excluir conta'));
      await tester.tap(find.text('Excluir conta'));
      await tester.pumpAndSettle();
    }

    testeDeTela('pede a senha, exclui e volta para o login sem sessão', (tester, api) async {
      final id = usuario(api).id;
      await abrirConfirmacao(tester, api);

      expect(find.text('Excluir sua conta?'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Senha@123');
      await tester.tap(find.widgetWithText(TextButton, 'Excluir conta'));
      await tester.pumpAndSettle();

      final pedido = api.escritas.single;
      expect(pedido.method, 'DELETE');
      expect(pedido.url.path, '/api/usuarios/$id');
      expect(jsonDecode(pedido.body), {'senha': 'Senha@123'});

      expect(find.text('Entrar'), findsOneWidget); // tela de login
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), isNull);
    });

    testeDeTela('senha errada mostra o erro e mantém a pessoa logada', (tester, api) async {
      api.responder('DELETE /api/usuarios/${usuario(api).id}', {'erro': 'Senha incorreta.'},
          status: 400);
      await abrirConfirmacao(tester, api);

      await tester.enterText(find.byType(TextField), 'errada');
      await tester.tap(find.widgetWithText(TextButton, 'Excluir conta'));
      await tester.pumpAndSettle();

      expect(find.text('Senha incorreta.'), findsOneWidget);
      expect(find.text('Excluir sua conta?'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), isNotNull);
    });

    testeDeTela('cancelar não apaga nada', (tester, api) async {
      await abrirConfirmacao(tester, api);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(api.escritas, isEmpty);
      expect(find.text('Excluir sua conta?'), findsNothing);
    });
  });
}
