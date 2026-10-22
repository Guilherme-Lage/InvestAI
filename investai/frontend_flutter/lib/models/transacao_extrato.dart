/// Uma linha do extrato bancário, do jeito que o backend devolve na
/// análise (POST /api/importacao/analisar), para o usuário revisar antes
/// de importar.
class TransacaoExtrato {
  final String identificador; // código da transação no banco
  final String data; // 'AAAA-MM-DD'
  final String descricao;
  final String tipo; // 'renda' ou 'gasto'
  final double valor; // sempre positivo; o sentido está em `tipo`

  /// O que o backend concluiu sobre a linha: 'nova', 'ja_importada',
  /// 'possivel_duplicata' ou 'movimentacao_interna'.
  final String situacao;

  /// Explicação para o usuário quando a linha veio desmarcada.
  final String? aviso;

  // Os dois campos abaixo mudam na tela de revisão: o usuário pode trocar
  // a categoria sugerida e marcar ou desmarcar a linha.
  String categoria;
  bool selecionada;

  TransacaoExtrato({
    required this.identificador,
    required this.data,
    required this.descricao,
    required this.tipo,
    required this.valor,
    required this.situacao,
    required this.categoria,
    required this.selecionada,
    this.aviso,
  });

  bool get isRenda => tipo == 'renda';
  bool get jaImportada => situacao == 'ja_importada';

  factory TransacaoExtrato.fromJson(Map<String, dynamic> json) {
    final situacao = json['situacao'] ?? 'nova';
    return TransacaoExtrato(
      identificador: json['identificador'] ?? '',
      data: json['data'] ?? '',
      descricao: json['descricao'] ?? '',
      tipo: json['tipo'] ?? 'gasto',
      valor: (json['valor'] ?? 0).toDouble(),
      situacao: situacao,
      aviso: json['aviso'],
      categoria: json['categoria'] ?? 'outros',
      // O backend diz o que já vem marcado (o que é claramente novo); o
      // resto o usuário decide se quer mesmo importar.
      selecionada: json['marcada'] ?? situacao == 'nova',
    );
  }

  /// Corpo enviado na confirmação (POST /api/importacao/confirmar).
  Map<String, dynamic> toJson() {
    return {
      'identificador': identificador,
      'data': data,
      'descricao': descricao,
      'tipo': tipo,
      'valor': valor,
      'categoria': categoria,
    };
  }
}

/// Lançamento que faz o saldo do app terminar igual ao saldo que o banco
/// informa no extrato. Cobre o dinheiro que já estava na conta antes do
/// período e o que o usuário deixar de fora (uma aplicação, por exemplo).
///
/// O valor depende das linhas marcadas, por isso é recalculado na tela de
/// revisão a cada mudança, com [valorPara].
class AjusteSaldo {
  final String identificador;
  final String data; // véspera do extrato
  final String descricao;
  final String categoria;
  final double saldoBanco;
  final String dataBanco; // 'AAAA-MM-DD' do saldo informado pelo banco
  final double saldoAppAteDataBanco;

  /// Primeira importação desta conta do banco: o ajuste vem marcado e o
  /// saldo do app passa a ser o do banco. Nas seguintes, uma diferença é
  /// só um aviso, e o ajuste vem desmarcado.
  final bool primeiraImportacao;

  /// Se o usuário quer o ajuste. Começa como o backend sugere.
  bool marcado;

  AjusteSaldo({
    required this.identificador,
    required this.data,
    required this.descricao,
    required this.categoria,
    required this.saldoBanco,
    required this.dataBanco,
    required this.saldoAppAteDataBanco,
    required this.primeiraImportacao,
    required this.marcado,
  });

  factory AjusteSaldo.fromJson(Map<String, dynamic> json) {
    return AjusteSaldo(
      identificador: json['identificador'] ?? '',
      data: json['data'] ?? '',
      descricao: json['descricao'] ?? 'Ajuste para bater com o saldo do banco',
      categoria: json['categoria'] ?? 'saldo_inicial',
      saldoBanco: (json['saldo_banco'] ?? 0).toDouble(),
      dataBanco: json['data_banco'] ?? '',
      saldoAppAteDataBanco: (json['saldo_app_ate_data_banco'] ?? 0).toDouble(),
      primeiraImportacao: json['primeira_importacao'] ?? true,
      marcado: json['marcado_por_padrao'] ?? false,
    );
  }

  /// Valor com sinal (positivo = entrada) que deixa o saldo do app igual
  /// ao do banco, se forem importadas exatamente as linhas [marcadas].
  double valorPara(Iterable<TransacaoExtrato> marcadas) {
    final movimento = marcadas
        .where((t) => t.data.compareTo(dataBanco) <= 0)
        .fold<double>(0, (soma, t) => soma + (t.isRenda ? t.valor : -t.valor));
    final valor = saldoBanco - saldoAppAteDataBanco - movimento;
    return (valor * 100).roundToDouble() / 100;
  }

  /// Corpo enviado na confirmação, junto com as transações.
  Map<String, dynamic> toJson(double valor) {
    return {
      'identificador': identificador,
      'data': data,
      'descricao': descricao,
      'tipo': valor > 0 ? 'renda' : 'gasto',
      'valor': valor.abs(),
      'categoria': categoria,
    };
  }
}

/// Resultado da análise do extrato: as linhas para revisar e, se o banco
/// informou o saldo, o ajuste.
class AnaliseExtrato {
  final List<TransacaoExtrato> transacoes;
  final AjusteSaldo? ajuste;

  const AnaliseExtrato({required this.transacoes, this.ajuste});
}
