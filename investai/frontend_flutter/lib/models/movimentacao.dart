/// RF03/RF04/RF19 - uma receita ou despesa do usuário.
class Movimentacao {
  final int? id;
  final String descricao;
  final String tipo; // 'renda' ou 'gasto'
  final double valor;
  final String data; // 'AAAA-MM-DD'
  final String categoria;

  Movimentacao({
    this.id,
    required this.descricao,
    required this.tipo,
    required this.valor,
    required this.data,
    required this.categoria,
  });

  bool get isRenda => tipo == 'renda';

  factory Movimentacao.fromJson(Map<String, dynamic> json) {
    return Movimentacao(
      id: json['id'],
      descricao: json['descricao'] ?? '',
      tipo: json['tipo'] ?? 'gasto',
      valor: (json['valor'] ?? 0).toDouble(),
      data: json['data'] ?? '',
      categoria: json['categoria'] ?? 'outros',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'descricao': descricao,
      'tipo': tipo,
      'valor': valor,
      'data': data,
      'categoria': categoria,
    };
  }
}

/// Categorias sugeridas para receitas e despesas (RF03/RF04/RF11/RF13).
class Categorias {
  static const List<String> despesa = [
    'alimentacao',
    'lazer',
    'contas_fixas',
    'transporte',
    'saude',
    'educacao',
    'outros',
  ];

  static const List<String> receita = [
    'salario',
    'freelance',
    'investimentos',
    'outros',
  ];

  static const Map<String, String> rotulos = {
    'alimentacao': 'Alimentação',
    'lazer': 'Lazer',
    'contas_fixas': 'Contas fixas',
    'transporte': 'Transporte',
    'saude': 'Saúde',
    'educacao': 'Educação',
    'salario': 'Salário',
    'freelance': 'Freelance',
    'investimentos': 'Investimentos',
    'outros': 'Outros',
  };

  static String rotulo(String categoria) => rotulos[categoria] ?? categoria;
}
