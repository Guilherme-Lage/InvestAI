/// Receita ou despesa que se repete todo mês (aluguel, assinatura,
/// salário) e que o sistema lança sozinho no dia combinado.
class Recorrencia {
  final int? id;
  final String descricao;
  final String tipo; // 'renda' ou 'gasto'
  final double valor;
  final String categoria;
  final int diaMes; // 1 a 31
  final bool ativa;

  Recorrencia({
    this.id,
    required this.descricao,
    required this.tipo,
    required this.valor,
    required this.categoria,
    required this.diaMes,
    this.ativa = true,
  });

  bool get isRenda => tipo == 'renda';

  factory Recorrencia.fromJson(Map<String, dynamic> json) {
    return Recorrencia(
      id: json['id'],
      descricao: json['descricao'] ?? '',
      tipo: json['tipo'] ?? 'gasto',
      valor: (json['valor'] ?? 0).toDouble(),
      categoria: json['categoria'] ?? 'outros',
      diaMes: json['dia_mes'] ?? 1,
      ativa: json['ativa'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'descricao': descricao,
      'tipo': tipo,
      'valor': valor,
      'categoria': categoria,
      'dia_mes': diaMes,
    };
  }
}
