/// Um investimento cadastrado pelo usuário.
class Investimento {
  final int? id;
  final String nome;
  final String tipo;
  final double valorAplicado;
  final double rendimentoAtual;
  final String liquidez;

  Investimento({
    this.id,
    required this.nome,
    required this.tipo,
    required this.valorAplicado,
    required this.rendimentoAtual,
    required this.liquidez,
  });

  factory Investimento.fromJson(Map<String, dynamic> json) {
    return Investimento(
      id: json['id'],
      nome: json['nome'] ?? '',
      tipo: json['tipo'] ?? '',
      valorAplicado: (json['valor_aplicado'] ?? 0).toDouble(),
      rendimentoAtual: (json['rendimento_atual'] ?? 0).toDouble(),
      liquidez: json['liquidez'] ?? 'diaria',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      'tipo': tipo,
      'valor_aplicado': valorAplicado,
      'rendimento_atual': rendimentoAtual,
      'liquidez': liquidez,
    };
  }
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
