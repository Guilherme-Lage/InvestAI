import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:investai/conteudo/licoes.dart';
import 'package:investai/screens/investimentos_tab.dart';
import 'package:investai/screens/trilha_aprendizado_screen.dart';
import 'package:investai/services/progresso_licoes.dart';

import 'apoio/api_falsa.dart';

Licao _licao(String id) => licoes.firstWhere((l) => l.id == id);

const _completo = ContextoLicao(
  passoDoGuia: 'construir_reserva',
  selic: 12.0,
  cdi: 11.9,
  ipca: 5.0,
  reservaIdeal: 9000,
  reservaGuardada: 3000,
  despesaMediaMensal: 3000,
  capacidadeMensal: 500,
);

void main() {
  group('conteúdo e regras da trilha', () {
    test('ids únicos: são a chave do progresso salvo', () {
      final ids = licoes.map((l) => l.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('as lições abrem conforme o passo do guia', () {
      int liberadas(String? passo) =>
          licoes.where((l) => ContextoLicao(passoDoGuia: passo).libera(l.nivel)).length;

      expect(liberadas('saldo_negativo'), 3);
      expect(liberadas('construir_reserva'), 5);
      expect(liberadas('pronto_para_investir'), 6);
      expect(liberadas(null), 3); // guia ainda não carregou
    });

    test('ensina sobre investir antes de liberar as sugestões', () {
      // A lição do primeiro investimento abre durante a construção da
      // reserva, não só depois dela.
      const construindo = ContextoLicao(passoDoGuia: 'construir_reserva');
      expect(construindo.libera(_licao('primeiro_investimento').nivel), isTrue);
      expect(construindo.libera(_licao('renda_variavel').nivel), isFalse);
    });

    test('os números da pessoa entram na lição', () {
      expect(_licao('dinheiro_parado').comSeusNumeros!(_completo),
          contains('R\$ 952,38')); // 1000 / 1,05
      expect(_licao('reserva_emergencia').comSeusNumeros!(_completo),
          allOf(contains('R\$ 9000,00'), contains('faltam R\$ 6000,00')));
      expect(_licao('juros_compostos').comSeusNumeros!(_completo),
          allOf(contains('R\$ 500,00 por mês'), contains('R\$ 30000,00')));
    });

    test('sem os dados, a lição aparece só com o texto geral', () {
      const vazio = ContextoLicao();
      for (final licao in licoes) {
        expect(licao.comSeusNumeros?.call(vazio), isNull, reason: licao.id);
      }
    });

    test('monta o contexto a partir das respostas reais da API', () {
      final api = ApiFalsa();
      final contexto = ContextoLicao.dosDados(
        api.resposta('/api/orientacao/guia'),
        api.resposta('/api/mercado/taxas'),
      );

      expect(contexto.passoDoGuia, 'construir_reserva');
      expect(contexto.selic, 10.0);
      expect(contexto.reservaIdeal, greaterThan(0));
      expect(contexto.capacidadeMensal, isNotNull);
    });
  });

  group('telas', () {
    for (final (nome, tamanho) in [('comum', telaComum), ('pequena', telaPequena)]) {
      testeDeTela('todas as lições cabem em tela $nome', (tester, api) async {
        for (var i = 0; i < licoes.length; i++) {
          await montarTela(tester, api, LicaoScreen(indice: i, contexto: _completo),
              tamanho: tamanho);
          await rolarAte(tester, find.byType(ElevatedButton));
        }
      });
    }

    testeDeTela('a trilha mostra o que está fechado e por quê', (tester, api) async {
      await montarTela(tester, api, const TrilhaAprendizadoScreen(contexto: _completo));

      expect(find.text('0 de 6 lições concluídas'), findsOneWidget);
      await rolarAte(tester, find.text(_licao('renda_variavel').titulo));
      expect(find.text('Libera quando sua reserva de emergência estiver completa.'),
          findsOneWidget);
    });

    testeDeTela('concluir uma lição leva à próxima e fica salvo', (tester, api) async {
      await montarTela(tester, api, const LicaoScreen(indice: 0, contexto: _completo));

      await rolarAte(tester, find.text('Concluir e ir para a próxima'));
      await tester.tap(find.text('Concluir e ir para a próxima'));
      await tester.pumpAndSettle();

      expect(find.text('Lição 2 de 6'), findsOneWidget);
      expect(await ProgressoLicoes.concluidas(), {'dinheiro_parado'});
    });

    testeDeTela('a aba Investir mostra a trilha e a próxima lição', (tester, api) async {
      await montarTela(tester, api, const InvestimentosTab());

      await rolarAte(tester, find.text('Aprenda a investir'));
      expect(find.text('0 de 6'), findsOneWidget);
      expect(find.text('Próxima: ${licoes.first.titulo}'), findsOneWidget);

      await tester.tap(find.text('Aprenda a investir'));
      await tester.pumpAndSettle();
      expect(find.text('0 de 6 lições concluídas'), findsOneWidget);
    });
  });
}
