/// RF13 - limite de gasto mensal que o usuário define para uma categoria.
class LimiteCategoria {
  final int? id;
  final String categoria;
  final double valorLimite;

  LimiteCategoria({
    this.id,
    required this.categoria,
    required this.valorLimite,
  });

  factory LimiteCategoria.fromJson(Map<String, dynamic> json) {
    return LimiteCategoria(
      id: json['id'],
      categoria: json['categoria'] ?? '',
      valorLimite: (json['valor_limite'] ?? 0).toDouble(),
    );
  }
}
