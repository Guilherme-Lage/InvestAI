import 'package:flutter_test/flutter_test.dart';

import 'package:investai/screens/chat_ia_screen.dart';

import 'apoio/api_falsa.dart';

void main() {
  testeDeTela('a resposta do assistente aparece formatada, sem os asteriscos',
      (tester, api) async {
    // Resposta no formato real do agente: negrito e lista numerada.
    api.responder('POST /api/ia/perguntar', {
      'resposta': 'Para comprar, siga estes passos:\n\n'
          '1. **Abra uma conta** numa corretora.\n'
          '2. **Transfira o dinheiro** por Pix.\n\n'
          'Quer ajuda para escolher a corretora?',
    });
    await montarTela(
      tester,
      api,
      const ChatIaScreen(perguntaInicial: 'como compro Tesouro Selic?'),
      tamanho: telaPequena,
    );

    expect(find.text('como compro Tesouro Selic?'), findsOneWidget);
    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('Abra uma conta', findRichText: true), findsOneWidget);
    expect(find.textContaining('Quer ajuda para escolher', findRichText: true), findsOneWidget);
  });
}
