import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:investai/models/usuario.dart';
import 'package:investai/screens/dashboard_tab.dart';
import 'package:investai/screens/investimentos_tab.dart';
import 'package:investai/screens/metas_tab.dart';
import 'package:investai/screens/perfil_tab.dart';
import 'package:investai/screens/recorrentes_screen.dart';
import 'package:investai/screens/report_tab.dart';
import 'package:investai/services/api_service.dart';

import 'apoio/api_falsa.dart';

Usuario _usuario(ApiFalsa api) => Usuario.fromJson(api.resposta('/api/usuarios/me'));

void main() {
  // As cinco abas e a tela de recorrências, com os dados da conta de
  // demonstração, em dois tamanhos de celular. Qualquer texto estourando
  // ou widget que não cabe derruba o teste.
  for (final (nome, tamanho) in [('comum', telaComum), ('pequena', telaPequena)]) {
    group('telas cabem em tela $nome', () {
      testeDeTela('Início', (tester, api) async {
        await montarTela(
          tester,
          api,
          DashboardTab(usuario: _usuario(api), onVerTodasMetas: () {}),
          tamanho: tamanho,
        );
        expect(find.textContaining('Olá, Marina'), findsOneWidget);
        expect(find.text('Saldo disponível'), findsOneWidget);
      });

      testeDeTela('Metas', (tester, api) async {
        await montarTela(tester, api, const MetasTab(), tamanho: tamanho);
        expect(find.text('Reserva de emergência'), findsWidgets);
        await rolarAte(tester, find.textContaining('Viagem para o Nordeste'));
      });

      testeDeTela('Relatório', (tester, api) async {
        await montarTela(tester, api, const ReportTab(), tamanho: tamanho);
        expect(find.text('Relatório'), findsOneWidget);
        expect(find.text('Lazer no limite'), findsOneWidget);
        expect(find.byTooltip('Importar extrato do banco'), findsOneWidget);
        expect(find.byTooltip('Receitas e despesas recorrentes'), findsOneWidget);
        expect(find.byTooltip('Exportar relatório (PDF ou CSV)'), findsOneWidget);
      });

      testeDeTela('Investir', (tester, api) async {
        await montarTela(tester, api, const InvestimentosTab(), tamanho: tamanho);
        expect(find.text('Investimentos'), findsOneWidget);
        await rolarAte(tester, find.text('Seu score financeiro'));
      });

      testeDeTela('Perfil', (tester, api) async {
        await montarTela(
          tester,
          api,
          PerfilTab(usuario: _usuario(api), aoAtualizarUsuario: (_) {}),
          tamanho: tamanho,
        );
        expect(find.textContaining('Marina'), findsWidgets);
      });

      testeDeTela('Recorrentes', (tester, api) async {
        await montarTela(tester, api, const RecorrentesScreen(), tamanho: tamanho);
        expect(find.text('Aluguel'), findsOneWidget);
        expect(find.text('Salário'), findsOneWidget);
      });
    });
  }

  group('Relatório', () {
    testeDeTela('"Repetir todo mês" cadastra uma recorrência, não uma transação avulsa',
        (tester, api) async {
      await montarTela(tester, api, const ReportTab());

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Descrição'), 'Academia');
      await tester.enterText(find.widgetWithText(TextFormField, 'Valor'), '99,90');
      await tester.ensureVisible(find.text('Repetir todo mês'));
      await tester.tap(find.text('Repetir todo mês'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Adicionar'));
      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();

      final hoje = DateTime.now();
      expect(api.escritas, hasLength(1));
      expect(api.escritas.single.method, 'POST');
      expect(api.escritas.single.url.path, '/api/recorrencias');
      final corpo = jsonDecode(api.escritas.single.body);
      expect(corpo['descricao'], 'Academia');
      expect(corpo['valor'], 99.9);
      expect(corpo['dia_mes'], hoje.day);
      expect(corpo['data_inicio'], startsWith('${hoje.year}-'));
    });

    testeDeTela('sem "Repetir", registra uma transação comum', (tester, api) async {
      await montarTela(tester, api, const ReportTab());

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Descrição'), 'Padaria');
      await tester.enterText(find.widgetWithText(TextFormField, 'Valor'), '18,50');
      await tester.ensureVisible(find.text('Adicionar'));
      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();

      expect(api.escritas.single.url.path, '/api/movimentacoes');
      expect(jsonDecode(api.escritas.single.body)['valor'], 18.5);
    });

    testeDeTela('editar só a descrição não altera o valor da transação', (tester, api) async {
      // Já aconteceu: o valor era preenchido como "1500.00", lido de volta
      // como 150000 e salvo cem vezes maior.
      final primeira = (api.resposta('/api/movimentacoes') as List).first;
      await montarTela(tester, api, const ReportTab());

      await rolarAte(tester, find.text(primeira['descricao']).first);
      await tester.tap(find.text(primeira['descricao']).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Descrição'), 'Outro nome');
      await tester.ensureVisible(find.text('Salvar alterações'));
      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();

      expect(api.escritas.single.method, 'PUT');
      expect(api.escritas.single.url.path, '/api/movimentacoes/${primeira['id']}');
      expect(jsonDecode(api.escritas.single.body)['valor'], primeira['valor']);
    });

    testeDeTela('exportação abre no mês atual e não avança para o futuro', (tester, api) async {
      const meses = [
        'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
        'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
      ];
      final hoje = DateTime.now();
      final anterior = DateTime(hoje.year, hoje.month - 1);
      await montarTela(tester, api, const ReportTab());

      await tester.tap(find.byTooltip('Exportar relatório (PDF ou CSV)'));
      await tester.pumpAndSettle();

      expect(find.text('${meses[hoje.month - 1]} de ${hoje.year}'), findsOneWidget);
      final proximo = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.chevron_right_rounded));
      expect(proximo.onPressed, isNull);

      await tester.tap(find.byTooltip('Mês anterior'));
      await tester.pumpAndSettle();
      expect(find.text('${meses[anterior.month - 1]} de ${anterior.year}'), findsOneWidget);
    });

    testeDeTela('o pedido de exportação leva formato, ano e mês', (tester, api) async {
      await montarTela(tester, api, const SizedBox());

      // Rota fora do arquivo de respostas: o backend falso devolve erro, e
      // o que interessa aqui é a requisição que saiu.
      await expectLater(
        ApiService.exportarRelatorio(formato: 'csv', ano: 2026, mes: 3),
        throwsA(isA<ApiException>()),
      );

      final pedido = api.chamadas.last.url;
      expect(pedido.path, '/api/movimentacoes/relatorio-mensal/exportar');
      expect(pedido.queryParameters, {'formato': 'csv', 'ano': '2026', 'mes': '3'});
    });
  });

  group('Recorrentes', () {
    testeDeTela('mostra o total fixo do mês', (tester, api) async {
      await montarTela(tester, api, const RecorrentesScreen());

      // Aluguel 1500 + Internet 120 + Streaming 39,90.
      expect(find.text('R\$ 1659,90'), findsOneWidget);
      expect(find.text('R\$ 5200,00'), findsOneWidget);
    });

    testeDeTela('a chave pausa a recorrência', (tester, api) async {
      final aluguel = (api.resposta('/api/recorrencias') as List)
          .firstWhere((r) => r['descricao'] == 'Aluguel');
      await montarTela(tester, api, const RecorrentesScreen());

      final linha = find.ancestor(of: find.text('Aluguel'), matching: find.byType(Row)).first;
      await tester.tap(find.descendant(of: linha, matching: find.byType(Switch)));
      await tester.pumpAndSettle();

      expect(api.escritas.single.method, 'PUT');
      expect(api.escritas.single.url.path, '/api/recorrencias/${aluguel['id']}');
      expect(jsonDecode(api.escritas.single.body), {'ativa': false});
    });

    testeDeTela('excluir pede confirmação antes de apagar', (tester, api) async {
      await montarTela(tester, api, const RecorrentesScreen());

      await tester.tap(find.byTooltip('Excluir').first);
      await tester.pumpAndSettle();
      expect(api.escritas, isEmpty);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(api.escritas, isEmpty);

      await tester.tap(find.byTooltip('Excluir').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Excluir'));
      await tester.pumpAndSettle();
      expect(api.escritas.single.method, 'DELETE');
    });

    testeDeTela('o formulário de edição abre preenchido e cabe em tela pequena',
        (tester, api) async {
      await montarTela(tester, api, const RecorrentesScreen(), tamanho: telaPequena);

      await tester.tap(find.text('Aluguel'));
      await tester.pumpAndSettle();

      expect(find.text('Editar recorrência'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Aluguel'), findsOneWidget);
      expect(find.text('Dia 10'), findsOneWidget);

      await tester.ensureVisible(find.text('Salvar alterações'));
      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();

      final corpo = jsonDecode(api.escritas.single.body);
      expect(corpo['valor'], 1500.0);
      expect(corpo['dia_mes'], 10);
      expect(corpo.containsKey('ativa'), isFalse);
    });
  });

  group('Investir', () {
    testeDeTela('reserva completa com saldo negativo explica por que segue bloqueado',
        (tester, api) async {
      // Aconteceu de verdade: extrato importado sem o saldo anterior deixou
      // o saldo negativo, e a tela pedia para "continuar guardando" numa
      // reserva que já estava completa.
      final guia = Map<String, dynamic>.from(api.resposta('/api/orientacao/guia'));
      api.responder('/api/orientacao/guia', {
        ...guia,
        'passo': 'saldo_negativo',
        'saldo': -823.75,
        'reserva': {
          ...(guia['reserva'] as Map<String, dynamic>),
          'valor_guardado': 4000.0,
          'valor_ideal_reserva': 3743.74,
          'sugestoes_investimento_liberadas': true,
        },
      });
      await montarTela(tester, api, const InvestimentosTab());

      expect(find.text('Saldo no positivo'), findsOneWidget);
      expect(find.text('Saldo atual: R\$ -823,75'), findsOneWidget);
      expect(find.text('Concluída'), findsOneWidget); // a reserva
      expect(find.textContaining('saldo no app está negativo'), findsOneWidget);
      expect(find.textContaining('Continue guardando'), findsNothing);
    });

    testeDeTela('o score mostra a evolução quando há histórico', (tester, api) async {
      await montarTela(tester, api, const InvestimentosTab());

      await rolarAte(tester, find.text('Seu score financeiro'));
      await tester.tap(find.text('Seu score financeiro'));
      await tester.pumpAndSettle();

      final variacao = api.resposta('/api/orientacao/score/historico')['variacao'];
      expect(find.text('Evolução'), findsOneWidget);
      expect(find.textContaining('+$variacao pontos desde'), findsOneWidget);
    });
  });
}
