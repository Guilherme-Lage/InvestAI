/// Um investimento cadastrado pelo usuário.
class Investimento {
  final int? id;
  final String nome;
  final String tipo;
  final double valorAplicado;
  final double rendimentoAtual;
  final String liquidez;

  /// Índice que o investimento acompanha (selic, cdi, ipca, poupanca).
  /// Quando presente, o rendimento é calculado pelo backend a partir das
  /// taxas do dia, em vez de depender do usuário atualizar na mão.
  final String? indexador;
  final double percentualIndexador;
  final String? dataAplicacao;

  /// Preenchidos pelo backend na listagem, a partir das taxas atuais.
  final double valorAtual;
  final double rendimentoPercentual;
  final double? taxaAnual;
  final bool calculadoAutomaticamente;

  Investimento({
    this.id,
    required this.nome,
    required this.tipo,
    required this.valorAplicado,
    required this.rendimentoAtual,
    required this.liquidez,
    this.indexador,
    this.percentualIndexador = 100,
    this.dataAplicacao,
    double? valorAtual,
    this.rendimentoPercentual = 0,
    this.taxaAnual,
    this.calculadoAutomaticamente = false,
  }) : valorAtual = valorAtual ?? (valorAplicado + rendimentoAtual);

  factory Investimento.fromJson(Map<String, dynamic> json) {
    final aplicado = (json['valor_aplicado'] ?? 0).toDouble();
    final rendimento = (json['rendimento_atual'] ?? 0).toDouble();
    return Investimento(
      id: json['id'],
      nome: json['nome'] ?? '',
      tipo: json['tipo'] ?? '',
      valorAplicado: aplicado,
      rendimentoAtual: (json['rendimento'] ?? rendimento).toDouble(),
      liquidez: json['liquidez'] ?? 'diaria',
      indexador: json['indexador'],
      percentualIndexador: (json['percentual_indexador'] ?? 100).toDouble(),
      dataAplicacao: json['data_aplicacao'],
      valorAtual: (json['valor_atual'] as num?)?.toDouble(),
      rendimentoPercentual: (json['rendimento_percentual'] ?? 0).toDouble(),
      taxaAnual: (json['taxa_anual'] as num?)?.toDouble(),
      calculadoAutomaticamente: json['calculado_automaticamente'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      'tipo': tipo,
      'valor_aplicado': valorAplicado,
      'rendimento_atual': rendimentoAtual,
      'liquidez': liquidez,
      if (indexador != null) 'indexador': indexador,
      'percentual_indexador': percentualIndexador,
      if (dataAplicacao != null) 'data_aplicacao': dataAplicacao,
    };
  }
}

/// Índices que o app sabe acompanhar sozinho.
class Indexadores {
  static const Map<String, String> rotulos = {
    'selic': 'Tesouro Selic (segue a Selic)',
    'cdi': 'CDB / LCI (segue o CDI)',
    'ipca': 'Tesouro IPCA+ (inflação + juro real)',
    'poupanca': 'Poupança',
  };

  static String rotulo(String? chave) =>
      chave == null ? 'Não acompanhar automaticamente' : (rotulos[chave] ?? chave);
}

/// RF16 - sugestão de investimento devolvida pelo guia financeiro,
/// adaptada ao perfil de investidor do usuário (RF18).
class SugestaoInvestimento {
  final String nome;
  final String tipo;
  final String liquidez;
  final String descricao;

  SugestaoInvestimento({
    required this.nome,
    required this.tipo,
    required this.liquidez,
    required this.descricao,
  });

  factory SugestaoInvestimento.fromJson(Map<String, dynamic> json) {
    return SugestaoInvestimento(
      nome: json['nome'] ?? '',
      tipo: json['tipo'] ?? '',
      liquidez: json['liquidez'] ?? '',
      descricao: json['descricao'] ?? '',
    );
  }
}
