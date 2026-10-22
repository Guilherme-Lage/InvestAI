import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:investai/models/transacao_extrato.dart';
import 'package:investai/screens/importar_extrato_screen.dart';
import 'package:investai/utils/escolher_arquivo.dart';

import 'apoio/api_falsa.dart';

/// Faz o papel do seletor de arquivos: "o usuário escolheu este arquivo".
/// O conteúdo não importa, porque quem responde é o backend falso.
Future<ArquivoEscolhido?> _arquivo() async =>
    ArquivoEscolhido('extrato_exemplo.ofx', Uint8List.fromList(utf8.encode('<OFX>')));

/// Tela com um botão que abre a importação e guarda a mensagem com que
/// ela fechou - é assim que a aba Relatório a usa.
class _Abridor extends StatelessWidget {
  final ValueChanged<String?> aoFechar;
  const _Abridor({required this.aoFechar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () async => aoFechar(await Navigator.of(context).push<String>(
          MaterialPageRoute(builder: (_) => const ImportarExtratoScreen(escolher: _arquivo)),
        )),
        child: const Text('abrir'),
      ),
    );
  }
}

List<Map<String, dynamic>> _transacoes(ApiFalsa api) =>
    (api.resposta('POST /api/importacao/analisar')['transacoes'] as List)
        .cast<Map<String, dynamic>>();

void main() {
  test('só as transações novas já vêm marcadas para importar', () {
    TransacaoExtrato com(String situacao) => TransacaoExtrato.fromJson({
          'identificador': 'x', 'data': '2026-03-05', 'descricao': 'Teste',
          'tipo': 'gasto', 'valor': 10, 'categoria': 'outros', 'situacao': situacao,
        });

    expect(com('nova').selecionada, isTrue);
    expect(com('possivel_duplicata').selecionada, isFalse);
    expect(com('movimentacao_interna').selecionada, isFalse);
    expect(com('ja_importada').selecionada, isFalse);
    expect(com('ja_importada').jaImportada, isTrue);
  });

  for (final (nome, tamanho) in [('comum', telaComum), ('pequena', telaPequena)]) {
    testeDeTela('a tela inicial e a revisão cabem em tela $nome', (tester, api) async {
      await montarTela(tester, api, const ImportarExtratoScreen(escolher: _arquivo),
          tamanho: tamanho);
      expect(find.text('Escolher arquivo .ofx'), findsOneWidget);

      await tester.tap(find.text('Escolher arquivo .ofx'));
      await tester.pumpAndSettle();

      expect(find.text('Confira antes de importar'), findsOneWidget);
      // Percorre a lista inteira, para toda linha ser desenhada ao menos uma vez.
      await rolarAte(tester, find.text(_transacoes(api).last['descricao']));
    });
  }

  testeDeTela('a revisão mostra os avisos e conta só o que está marcado', (tester, api) async {
    final novas = _transacoes(api).where((t) => t['situacao'] == 'nova').length;
    await montarTela(tester, api, const ImportarExtratoScreen(escolher: _arquivo));

    await tester.tap(find.text('Escolher arquivo .ofx'));
    await tester.pumpAndSettle();

    expect(find.text('extrato_exemplo.ofx'), findsOneWidget);
    expect(find.text('Importar $novas transações'), findsOneWidget);
    // O salário já lançado pela recorrência vem com a explicação.
    expect(find.textContaining('já está no seu histórico'), findsWidgets);

    // Desmarcar a primeira linha tira uma da contagem.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('Importar ${novas - 1} transações'), findsOneWidget);
  });

  testeDeTela('confirmar envia só as marcadas, com a categoria corrigida', (tester, api) async {
    final novas = _transacoes(api).where((t) => t['situacao'] == 'nova').toList();
    api.responder('POST /api/importacao/confirmar', {'importadas': novas.length, 'ja_existiam': 0});
    String? mensagem;
    await montarTela(tester, api, _Abridor(aoFechar: (m) => mensagem = m));

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escolher arquivo .ofx'));
    await tester.pumpAndSettle();

    // Troca a categoria da primeira linha (supermercado, sugerido como
    // Alimentação) para Outros.
    await tester.tap(find.byTooltip('Trocar categoria').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Outros').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Importar ${novas.length} transações'));
    await tester.pumpAndSettle();

    final confirmacao = api.escritas.last;
    expect(confirmacao.url.path, '/api/importacao/confirmar');
    final enviadas = (jsonDecode(confirmacao.body)['transacoes'] as List).cast<Map>();
    expect(enviadas.map((t) => t['identificador']), novas.map((t) => t['identificador']));
    expect(enviadas.first['categoria'], 'outros');
    expect(enviadas.first.keys, containsAll(['data', 'descricao', 'tipo', 'valor']));

    // A tela fecha e devolve a mensagem para a aba Relatório mostrar.
    expect(find.text('Confira antes de importar'), findsNothing);
    expect(mensagem, '${novas.length} transações importadas.');
  });

  testeDeTela('trocar a categoria de uma linha muda as outras de mesmo nome',
      (tester, api) async {
    Map<String, dynamic> pix(String id, String nome) => {
          'identificador': id, 'data': '2026-03-05', 'descricao': 'Pix enviado: $nome',
          'tipo': 'gasto', 'valor': 30, 'categoria': 'outros', 'situacao': 'nova', 'aviso': null,
        };
    api.responder('POST /api/importacao/analisar', {
      'transacoes': [pix('a', 'FULANO'), pix('b', 'BELTRANO'), pix('c', 'FULANO')],
    });
    api.responder('POST /api/importacao/confirmar', {'importadas': 3, 'ja_existiam': 0});
    await montarTela(tester, api, const ImportarExtratoScreen(escolher: _arquivo));

    await tester.tap(find.text('Escolher arquivo .ofx'));
    await tester.pumpAndSettle();
    // As três estão sem categoria, e a tela avisa.
    expect(find.textContaining('3 transações estão sem categoria'), findsOneWidget);

    await tester.tap(find.byTooltip('Trocar categoria').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lazer').last);
    await tester.pumpAndSettle();

    // Sobrou só o BELTRANO sem categoria: as duas do FULANO mudaram juntas.
    expect(find.textContaining('1 transação está sem categoria'), findsOneWidget);
    expect(find.text('Lazer'), findsNWidgets(2));

    await tester.tap(find.text('Importar 3 transações'));
    await tester.pumpAndSettle();
    final enviadas = (jsonDecode(api.escritas.last.body)['transacoes'] as List).cast<Map>();
    expect(
      {for (final t in enviadas) t['identificador']: t['categoria']},
      {'a': 'lazer', 'b': 'outros', 'c': 'lazer'},
    );
  });

  Map<String, dynamic> linha(String id, String descricao, double valor, String situacao,
          {bool marcada = true}) =>
      {
        'identificador': id, 'data': '2026-10-05', 'descricao': descricao,
        'tipo': valor > 0 ? 'renda' : 'gasto', 'valor': valor.abs(), 'categoria': 'outros',
        'situacao': situacao, 'marcada': marcada, 'aviso': null,
      };

  Map<String, dynamic> ajuste({double saldoApp = 0, bool primeira = true}) => {
        'identificador': 'ajuste-saldo:077:123:2026-10-13', 'data': '2026-09-30',
        'descricao': 'Ajuste para bater com o saldo do banco', 'categoria': 'saldo_inicial',
        'saldo_banco': 389.58, 'data_banco': '2026-10-13',
        'saldo_app_ate_data_banco': saldoApp,
        'primeira_importacao': primeira, 'marcado_por_padrao': primeira,
      };

  testeDeTela('o ajuste acompanha as linhas marcadas e vai junto na confirmação',
      (tester, api) async {
    api.responder('POST /api/importacao/analisar', {
      'saldo_banco': {'valor': 389.58, 'data': '2026-10-13'},
      'ajuste_saldo': ajuste(),
      'transacoes': [
        linha('x1', 'Pix enviado: ALUGUEL', -600, 'nova'),
        linha('x2', 'APLICACAO RDB', -366.38, 'movimentacao_interna', marcada: false),
      ],
    });
    api.responder('POST /api/importacao/confirmar', {'importadas': 3, 'ja_existiam': 0});
    await montarTela(tester, api, const ImportarExtratoScreen(escolher: _arquivo));

    await tester.tap(find.text('Escolher arquivo .ofx'));
    await tester.pumpAndSettle();

    // 389,58 - 0 - (-600) = 989,58 com só o aluguel marcado.
    expect(find.text('Ajuste para bater com o saldo do banco'), findsOneWidget);
    expect(find.text('+ R\$ 989,58'), findsOneWidget);
    expect(find.text('Importar 2 transações'), findsOneWidget); // aluguel + ajuste

    // Marcar a aplicação muda o ajuste: o saldo continua batendo com o banco.
    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();
    expect(find.text('+ R\$ 1355,96'), findsOneWidget);

    await tester.tap(find.text('Importar 3 transações'));
    await tester.pumpAndSettle();
    final enviadas = (jsonDecode(api.escritas.last.body)['transacoes'] as List).cast<Map>();
    final ajusteEnviado = enviadas.last;
    expect(ajusteEnviado['identificador'], 'ajuste-saldo:077:123:2026-10-13');
    expect(ajusteEnviado['tipo'], 'renda');
    expect(ajusteEnviado['valor'], 1355.96);
    expect(ajusteEnviado['categoria'], 'saldo_inicial');
  });

  testeDeTela('desmarcar o ajuste tira ele da importação', (tester, api) async {
    api.responder('POST /api/importacao/analisar', {
      'ajuste_saldo': ajuste(),
      'transacoes': [linha('x1', 'Pix enviado: ALUGUEL', -600, 'nova')],
    });
    api.responder('POST /api/importacao/confirmar', {'importadas': 1, 'ja_existiam': 0});
    await montarTela(tester, api, const ImportarExtratoScreen(escolher: _arquivo));
    await tester.tap(find.text('Escolher arquivo .ofx'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first); // o do ajuste, no topo
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importar 1 transação'));
    await tester.pumpAndSettle();

    final enviadas = (jsonDecode(api.escritas.last.body)['transacoes'] as List).cast<Map>();
    expect(enviadas.map((t) => t['identificador']), ['x1']);
  });

  testeDeTela('na primeira importação, mesmo sem linhas novas, o ajuste vem marcado',
      (tester, api) async {
    api.responder('POST /api/importacao/analisar', {
      'ajuste_saldo': ajuste(saldoApp: -823.75),
      'transacoes': [
        {...linha('x1', 'Pix enviado: ALUGUEL', -600, 'ja_importada', marcada: false)},
      ],
    });
    await montarTela(tester, api, const ImportarExtratoScreen(escolher: _arquivo));
    await tester.tap(find.text('Escolher arquivo .ofx'));
    await tester.pumpAndSettle();

    expect(find.text('Confira antes de importar'), findsOneWidget);
    expect(find.text('+ R\$ 1213,33'), findsOneWidget); // 389,58 - (-823,75)
    expect(find.text('Importar 1 transação'), findsOneWidget);
  });

  testeDeTela('nas importações seguintes, a diferença vem como aviso e desmarcada',
      (tester, api) async {
    api.responder('POST /api/importacao/analisar', {
      'ajuste_saldo': ajuste(saldoApp: 1266.38, primeira: false),
      'transacoes': [
        {...linha('x1', 'Pix enviado: ALUGUEL', -600, 'ja_importada', marcada: false)},
      ],
    });
    api.responder('POST /api/importacao/confirmar', {'importadas': 1, 'ja_existiam': 0});
    await montarTela(tester, api, const ImportarExtratoScreen(escolher: _arquivo));
    await tester.tap(find.text('Escolher arquivo .ofx'));
    await tester.pumpAndSettle();

    // 389,58 - 1266,38 = -876,80: o app ficaria acima do banco.
    expect(find.text('- R\$ 876,80'), findsOneWidget);
    expect(find.textContaining('ficaria R\$ 876,80 diferente do banco'), findsOneWidget);
    expect(find.text('Nenhuma transação marcada'), findsOneWidget); // nada vai sozinho

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('Importar 1 transação'), findsOneWidget);
  });

  testeDeTela('quando o app já bate com o banco, o ajuste nem aparece', (tester, api) async {
    api.responder('POST /api/importacao/analisar', {
      'ajuste_saldo': ajuste(saldoApp: 989.58),
      'transacoes': [linha('x1', 'Pix enviado: ALUGUEL', -600, 'nova')],
    });
    await montarTela(tester, api, const ImportarExtratoScreen(escolher: _arquivo));
    await tester.tap(find.text('Escolher arquivo .ofx'));
    await tester.pumpAndSettle();

    expect(find.text('Ajuste para bater com o saldo do banco'), findsNothing);
    expect(find.text('Importar 1 transação'), findsOneWidget);
  });

  test('sem o campo "marcada", vale a regra antiga: só o que é novo', () {
    final antigo = TransacaoExtrato.fromJson({
      'identificador': 'x', 'data': '2026-03-05', 'descricao': 'A', 'tipo': 'gasto',
      'valor': 1, 'categoria': 'outros', 'situacao': 'possivel_duplicata',
    });
    final ajusteDesmarcado = TransacaoExtrato.fromJson({
      'identificador': 'y', 'data': '2026-03-04', 'descricao': 'Saldo anterior ao extrato',
      'tipo': 'gasto', 'valor': 10, 'categoria': 'saldo_inicial',
      'situacao': 'ajuste_saldo', 'marcada': false,
    });

    expect(antigo.selecionada, isFalse);
    expect(ajusteDesmarcado.selecionada, isFalse);
  });

  testeDeTela('extrato já importado por inteiro não oferece nada para importar',
      (tester, api) async {
    final analise = api.resposta('POST /api/importacao/analisar') as Map<String, dynamic>;
    api.responder('POST /api/importacao/analisar', {
      ...analise,
      'transacoes': [
        for (final t in _transacoes(api)) {...t, 'situacao': 'ja_importada', 'aviso': null},
      ],
    });
    await montarTela(tester, api, const ImportarExtratoScreen(escolher: _arquivo));

    await tester.tap(find.text('Escolher arquivo .ofx'));
    await tester.pumpAndSettle();

    expect(find.text('Nada novo neste extrato'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    final botao = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(botao.onPressed, isNull);
  });

  testeDeTela('cancelar o seletor de arquivos deixa a tela como estava', (tester, api) async {
    await montarTela(tester, api, ImportarExtratoScreen(escolher: () async => null));

    await tester.tap(find.text('Escolher arquivo .ofx'));
    await tester.pumpAndSettle();

    expect(find.text('Escolher arquivo .ofx'), findsOneWidget);
    expect(api.escritas, isEmpty);
  });

  testeDeTela('fora do navegador, explica que a importação é só na versão web',
      (tester, api) async {
    await montarTela(
      tester,
      api,
      ImportarExtratoScreen(escolher: () async => throw SeletorIndisponivel()),
    );

    await tester.tap(find.text('Escolher arquivo .ofx'));
    await tester.pumpAndSettle();

    expect(find.textContaining('só funciona na versão web'), findsOneWidget);
  });
}
