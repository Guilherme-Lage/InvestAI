import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Trilha "Aprenda a investir": o conteúdo das lições.
///
/// Este arquivo é só texto e regras simples, para o grupo poder revisar e
/// escrever lições sem mexer em tela nenhuma. Para acrescentar uma lição,
/// copie uma das existentes em [licoes] e troque os textos. Os termos do
/// glossário (Selic, CDI, IPCA, FGC, liquidez...) viram links sozinhos.
///
/// As lições vão sendo liberadas conforme a pessoa avança no guia
/// financeiro (RF16), para ela aprender sobre cada etapa antes de chegar
/// nela - e não receber de repente uma lista de produtos ao completar a
/// reserva.

/// Quando a lição fica disponível, na mesma ordem dos passos do guia.
enum NivelLicao {
  /// Sempre: conceitos que servem para qualquer situação.
  basico,

  /// Quando as contas fecham no positivo (guia em "construir_reserva").
  saldoPositivo,

  /// Quando a reserva está completa (guia em "pronto_para_investir").
  reservaCompleta,
}

/// Os números da própria pessoa, usados para personalizar as lições. Todos
/// podem faltar (taxas fora do ar, conta nova sem despesas): a lição então
/// aparece só com o texto geral.
class ContextoLicao {
  final String? passoDoGuia; // saldo_negativo, construir_reserva, pronto_para_investir
  final double? selic;
  final double? cdi;
  final double? ipca;
  final double? reservaIdeal;
  final double? reservaGuardada;
  final double? despesaMediaMensal;
  final double? capacidadeMensal;

  const ContextoLicao({
    this.passoDoGuia,
    this.selic,
    this.cdi,
    this.ipca,
    this.reservaIdeal,
    this.reservaGuardada,
    this.despesaMediaMensal,
    this.capacidadeMensal,
  });

  /// Monta o contexto a partir das respostas da API já carregadas na aba
  /// Investir (guia financeiro e taxas de mercado).
  factory ContextoLicao.dosDados(Map<String, dynamic>? guia, Map<String, dynamic>? taxas) {
    double? numero(dynamic valor) => valor is num ? valor.toDouble() : null;
    final reserva = guia?['reserva'] as Map<String, dynamic>?;
    final composicao = guia?['composicao_gastos'] as Map<String, dynamic>?;
    return ContextoLicao(
      passoDoGuia: guia?['passo'] as String?,
      selic: numero(taxas?['selic']),
      cdi: numero(taxas?['cdi']),
      ipca: numero(taxas?['ipca']),
      reservaIdeal: numero(reserva?['valor_ideal_reserva']),
      reservaGuardada: numero(reserva?['valor_guardado']),
      despesaMediaMensal: numero(reserva?['despesa_media_mensal']),
      capacidadeMensal: numero(composicao?['capacidade_mensal']),
    );
  }

  /// Se a lição já pode ser aberta.
  bool libera(NivelLicao nivel) {
    switch (nivel) {
      case NivelLicao.basico:
        return true;
      case NivelLicao.saldoPositivo:
        return passoDoGuia == 'construir_reserva' || passoDoGuia == 'pronto_para_investir';
      case NivelLicao.reservaCompleta:
        return passoDoGuia == 'pronto_para_investir';
    }
  }
}

class Licao {
  final String id; // não mude depois de publicado: é a chave do progresso salvo
  final String titulo;
  final String resumo;
  final IconData icone;
  final NivelLicao nivel;

  /// Parágrafos curtos. Uma ideia por parágrafo.
  final List<String> paragrafos;

  /// Passo a passo opcional, mostrado numerado depois dos parágrafos.
  final String? tituloPassos;
  final List<String> passos;

  /// Aviso opcional no fim (custos, regras que mudam, cuidados).
  final String? observacao;

  /// Trecho com os números da pessoa. Devolve `null` quando faltam dados.
  final String? Function(ContextoLicao contexto)? comSeusNumeros;

  /// Pergunta enviada ao assistente pelo botão "Me explica isso".
  final String perguntaParaIa;

  const Licao({
    required this.id,
    required this.titulo,
    required this.resumo,
    required this.icone,
    required this.nivel,
    required this.paragrafos,
    required this.perguntaParaIa,
    this.tituloPassos,
    this.passos = const [],
    this.observacao,
    this.comSeusNumeros,
  });
}

/// Por que a lição ainda está fechada, em linguagem de usuário.
String motivoDoBloqueio(NivelLicao nivel) {
  switch (nivel) {
    case NivelLicao.basico:
      return '';
    case NivelLicao.saldoPositivo:
      return 'Libera quando suas contas fecharem no positivo.';
    case NivelLicao.reservaCompleta:
      return 'Libera quando sua reserva de emergência estiver completa.';
  }
}

String _reais(double valor) => 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
String _pct(double valor) => '${valor.toStringAsFixed(2).replaceAll('.', ',')}%';

/// Taxa mensal equivalente a uma taxa anual (juros compostos).
double _taxaMensal(double taxaAnual) => math.pow(1 + taxaAnual / 100, 1 / 12) - 1;

final List<Licao> licoes = [
  Licao(
    id: 'dinheiro_parado',
    titulo: 'Por que o dinheiro parado perde valor',
    resumo: 'Inflação e poder de compra',
    icone: Icons.trending_down_rounded,
    nivel: NivelLicao.basico,
    paragrafos: const [
      'Inflação é o aumento geral dos preços. Quando ela sobe, o mesmo dinheiro '
          'compra menos coisas do que comprava antes.',
      'No Brasil, a inflação oficial é medida pelo IPCA. Se o IPCA de um ano foi '
          'de 5%, o que custava R\$ 100 passou a custar, em média, R\$ 105.',
      'Por isso o dinheiro parado na conta, sem render nada, perde valor todo '
          'mês, mesmo que o número no extrato continue igual.',
      'No começo, investir é antes de tudo uma defesa: fazer o dinheiro render '
          'pelo menos a inflação. O que sobra acima dela se chama juro real.',
    ],
    comSeusNumeros: (c) {
      if (c.ipca == null) return null;
      final poderDeCompra = 1000 / (1 + c.ipca! / 100);
      return 'Com o IPCA atual de ${_pct(c.ipca!)} em 12 meses, R\$ 1.000 parados '
          'há um ano compram hoje o mesmo que ${_reais(poderDeCompra)} compravam antes.';
    },
    perguntaParaIa: 'Me explica, com exemplos do dia a dia, por que o dinheiro '
        'parado perde valor com a inflação.',
  ),
  Licao(
    id: 'juros_compostos',
    titulo: 'Juros compostos: o tempo trabalhando por você',
    resumo: 'Por que começar cedo, mesmo com pouco',
    icone: Icons.auto_graph_rounded,
    nivel: NivelLicao.basico,
    paragrafos: const [
      'Juro composto é o juro sobre juro: o rendimento de um mês também passa a '
          'render nos meses seguintes.',
      'No começo a diferença é pequena, mas ela cresce com o tempo. Por isso '
          'começar cedo, mesmo com pouco, costuma valer mais do que começar tarde '
          'com muito.',
      'Três coisas decidem o resultado: quanto você guarda por mês, por quanto '
          'tempo e quanto o investimento paga.',
      'O mesmo efeito funciona ao contrário nas dívidas. Os juros do cartão de '
          'crédito e do cheque especial crescem do mesmo jeito, só que contra '
          'você. Quitar essas dívidas costuma render mais do que qualquer '
          'investimento.',
    ],
    comSeusNumeros: (c) {
      if (c.cdi == null) return null;
      final usouSobra = c.capacidadeMensal != null && c.capacidadeMensal! >= 50;
      final aporte = usouSobra ? c.capacidadeMensal!.roundToDouble() : 100.0;
      const meses = 60;
      final i = _taxaMensal(c.cdi!);
      final total = aporte * (math.pow(1 + i, meses) - 1) / i;
      return 'Guardando ${_reais(aporte)} por mês${usouSobra ? ' (o que sobra no seu mês hoje)' : ''} '
          'durante 5 anos, você coloca ${_reais(aporte * meses)} do próprio bolso. '
          'Rendendo 100% do CDI (hoje ${_pct(c.cdi!)} ao ano), isso viraria cerca de '
          '${_reais(total)}, antes do imposto. Teste outros valores em "E se eu guardasse?".';
    },
    perguntaParaIa: 'Me explica juros compostos com um exemplo simples, e por que '
        'começar cedo faz diferença.',
  ),
  Licao(
    id: 'reserva_emergencia',
    titulo: 'Reserva de emergência: quanto e por quê',
    resumo: 'O primeiro objetivo de quem quer investir',
    icone: Icons.shield_outlined,
    nivel: NivelLicao.basico,
    paragrafos: const [
      'A reserva de emergência é o dinheiro guardado para imprevistos: perder o '
          'emprego, um problema de saúde, um conserto urgente.',
      'Sem ela, qualquer imprevisto vira dívida, e a dívida cresce com juros '
          'compostos contra você.',
      'O InvestAI recomenda guardar o equivalente a 3 meses das suas despesas, '
          'num lugar seguro e com liquidez diária, para resgatar no mesmo dia em '
          'que precisar.',
      'É por isso que o app só libera sugestões de outros investimentos depois '
          'da reserva completa: primeiro a segurança, depois o crescimento.',
    ],
    comSeusNumeros: (c) {
      if (c.reservaIdeal == null || c.reservaIdeal! <= 0) return null;
      final guardado = c.reservaGuardada ?? 0;
      final falta = math.max(c.reservaIdeal! - guardado, 0.0);
      final despesa = c.despesaMediaMensal != null
          ? ' (3 vezes sua despesa média de ${_reais(c.despesaMediaMensal!)})'
          : '';
      return 'Sua reserva ideal é ${_reais(c.reservaIdeal!)}$despesa. '
          'Você já tem ${_reais(guardado)} guardados'
          '${falta > 0 ? ' e faltam ${_reais(falta)}.' : ': reserva completa!'}';
    },
    perguntaParaIa: 'Me explica por que preciso de uma reserva de emergência antes '
        'de investir, considerando a minha situação.',
  ),
  Licao(
    id: 'primeiro_investimento',
    titulo: 'Seu primeiro investimento: a reserva no Tesouro Selic',
    resumo: 'Guardar a reserva já é investir',
    icone: Icons.account_balance_outlined,
    nivel: NivelLicao.saldoPositivo,
    paragrafos: const [
      'Guardar a reserva já é investir. Para ela, a opção mais usada no Brasil é '
          'o Tesouro Selic: você empresta dinheiro ao governo federal e recebe '
          'de volta com juros que acompanham a taxa Selic.',
      'Ele combina com a reserva porque é considerado o investimento de menor '
          'risco do país, o valor praticamente não oscila e dá para resgatar em '
          'qualquer dia útil.',
      'Uma alternativa é um CDB de liquidez diária que pague pelo menos 100% do '
          'CDI, protegido pelo FGC até R\$ 250 mil por banco.',
    ],
    tituloPassos: 'Como comprar, passo a passo',
    passos: const [
      'Abra conta numa corretora ou banco habilitado no Tesouro Direto. A maioria '
          'é digital e não cobra para abrir; o cadastro pede CPF e documento.',
      'Transfira o dinheiro da reserva para a conta da corretora, normalmente '
          'por Pix.',
      'Na área "Tesouro Direto", escolha o Tesouro Selic com o vencimento mais '
          'próximo e digite o valor. O mínimo é cerca de 1% do preço do título, a '
          'partir de R\$ 30.',
      'Confirme a compra. O título aparece na sua conta em até um dia útil e '
          'começa a render.',
      'No InvestAI, cadastre o investimento na aba Investir e registre o valor '
          'como aporte na sua reserva, na aba Metas, para acompanhar tudo aqui.',
    ],
    observacao: 'Custos: o Tesouro Selic não paga taxa de custódia até R\$ 10 mil '
        'investidos, e o imposto de renda incide só sobre o rendimento, numa '
        'tabela que cai com o tempo (de 22,5% para 15%). Regras de taxa e de '
        'imposto podem mudar: confira no site oficial do Tesouro Direto antes '
        'de investir.',
    comSeusNumeros: (c) {
      if (c.selic == null) return null;
      final texto = 'Hoje a Selic está em ${_pct(c.selic!)} ao ano.';
      if (c.reservaIdeal == null || c.reservaIdeal! <= 0) return texto;
      final porMes = c.reservaIdeal! * _taxaMensal(c.selic!);
      return '$texto Com a sua reserva completa (${_reais(c.reservaIdeal!)}), isso '
          'renderia cerca de ${_reais(porMes)} por mês, antes do imposto, sem '
          'você fazer nada.';
    },
    perguntaParaIa: 'Me explica como funciona o Tesouro Selic e o passo a passo '
        'para comprar o primeiro título, como se eu nunca tivesse investido.',
  ),
  const Licao(
    id: 'risco_liquidez',
    titulo: 'Risco, liquidez e rentabilidade',
    resumo: 'Como escolher entre um investimento e outro',
    icone: Icons.balance_rounded,
    nivel: NivelLicao.saldoPositivo,
    paragrafos: [
      'Todo investimento equilibra três coisas: segurança (o risco de perder '
          'dinheiro), liquidez (a rapidez para resgatar) e rentabilidade (quanto '
          'rende).',
      'Nenhum investimento é o melhor nas três ao mesmo tempo. Quando alguém '
          'promete rendimento alto, sem risco e com resgate imediato, desconfie: '
          'é o sinal mais comum de golpe.',
      'Por isso o objetivo define a escolha. Dinheiro de emergência pede '
          'liquidez e segurança. Dinheiro para daqui a muitos anos pode abrir mão '
          'de liquidez em troca de rendimento maior, como o Tesouro IPCA+ ou CDBs '
          'com carência.',
      'Outro jeito de reduzir o risco é a diversificação: dividir o dinheiro '
          'entre tipos diferentes de investimento, para um problema em um não '
          'derrubar tudo.',
    ],
    perguntaParaIa: 'Me explica a diferença entre risco, liquidez e rentabilidade, '
        'e como isso se aplica aos meus objetivos.',
  ),
  const Licao(
    id: 'renda_variavel',
    titulo: 'Ações e fundos: renda variável com calma',
    resumo: 'O próximo passo, para quem já tem a reserva',
    icone: Icons.candlestick_chart_outlined,
    nivel: NivelLicao.reservaCompleta,
    paragrafos: [
      'Na renda variável, o valor sobe e desce todos os dias. Ao comprar uma '
          'ação, você vira sócio de uma pequena parte de uma empresa e ganha se '
          'ela se valorizar ou distribuir lucros.',
      'Um jeito mais simples de começar são os ETFs de índice, que compram de '
          'uma vez várias ações (por exemplo, as do Ibovespa): diversificação '
          'pronta, num investimento só.',
      'Regras de ouro: use só dinheiro de que você não vai precisar por anos; '
          'nunca use a reserva de emergência; e espere ver o valor cair em algum '
          'momento. Isso faz parte, e vender no susto é o erro mais comum.',
      'O perfil de investidor que você escolheu no Perfil define as suas '
          'sugestões: no arrojado elas incluem ações e ETFs; no moderado, fundos '
          'multimercado; no conservador, só renda fixa.',
    ],
    perguntaParaIa: 'Me explica como funcionam ações e ETFs, e se faz sentido '
        'para o meu perfil começar por eles.',
  ),
];
