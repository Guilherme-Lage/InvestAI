import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:investai/screens/login_screen.dart';

import 'apoio/api_falsa.dart';

EditableText _campo(WidgetTester tester, int indice) =>
    tester.widgetList<EditableText>(find.byType(EditableText)).elementAt(indice);

void main() {
  testeDeTela('a conta salva só aparece ao tocar no campo, sem mostrar a senha',
      (tester, api) async {
    await montarTela(tester, api, const LoginScreen(), tamanho: telaPequena);

    // Antes de tocar em nada, nenhuma sugestão nem dado da demo na tela.
    expect(find.text(emailContaDemo), findsNothing);
    expect(find.textContaining(senhaContaDemo), findsNothing);

    await tester.tap(find.widgetWithText(TextFormField, 'E-mail'));
    await tester.pumpAndSettle();

    expect(find.text(emailContaDemo), findsOneWidget);
    expect(find.text('••••••••'), findsOneWidget);
    expect(find.textContaining(senhaContaDemo), findsNothing);
  });

  testeDeTela('escolher a conta salva preenche e-mail e senha mascarada', (tester, api) async {
    // Login recusado de propósito: o teste só confere o que foi enviado.
    api.responder('POST /api/usuarios/login', {'erro': 'parar aqui'}, status: 401);
    await montarTela(tester, api, const LoginScreen());

    await tester.tap(find.widgetWithText(TextFormField, 'E-mail'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(emailContaDemo));
    await tester.pumpAndSettle();

    expect(_campo(tester, 0).controller.text, emailContaDemo);
    expect(_campo(tester, 1).controller.text, senhaContaDemo);
    expect(_campo(tester, 1).obscureText, isTrue);
    // A sugestão some depois de escolhida.
    expect(find.text('••••••••'), findsNothing);

    await tester.ensureVisible(find.text('Entrar'));
    await tester.tap(find.text('Entrar'));
    await tester.pump();
    final envio = api.escritas.single;
    expect(jsonDecode(envio.body), {'email': emailContaDemo, 'senha': senhaContaDemo});
  });

  testeDeTela('o campo de senha também oferece a conta salva', (tester, api) async {
    await montarTela(tester, api, const LoginScreen());

    await tester.tap(find.widgetWithText(TextFormField, 'Senha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(emailContaDemo));
    await tester.pumpAndSettle();

    expect(_campo(tester, 0).controller.text, emailContaDemo);
    expect(_campo(tester, 1).controller.text, senhaContaDemo);
  });

  testeDeTela('digitando outro e-mail, a sugestão some', (tester, api) async {
    await montarTela(tester, api, const LoginScreen());

    await tester.tap(find.widgetWithText(TextFormField, 'E-mail'));
    await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), 'maria@');
    await tester.pumpAndSettle();

    expect(find.text('••••••••'), findsNothing);
  });
}
