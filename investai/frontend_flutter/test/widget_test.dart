import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:investai/theme.dart';
import 'package:investai/screens/login_screen.dart';

void main() {
  // Testa a LoginScreen isolada (sem a Splash, que dispara timers e uma
  // chamada de rede em segundo plano incompatíveis com um teste síncrono).
  testWidgets('Tela de login mostra os campos e o botão Entrar', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: InvestAITheme.theme,
      home: const LoginScreen(),
    ));

    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Criar conta'), findsOneWidget);
  });
}
