/// RF06/RF07/RF14/RF15/RF17 - uma meta financeira do usuário.
class Meta {
  final int? id;
  final String titulo;
  final double valorAlvo;
  final double valorAtual;
  final String prazo; // 'AAAA-MM-DD'
  final String tipo; // 'geral' ou 'reserva_emergencia'
  final double progresso; // percentual (0-100), calculado pelo backend
  final double aporteSugerido; // RF17
  final int mesesRestantes;

  Meta({
    this.id,
    required this.titulo,
    required this.valorAlvo,
    required this.valorAtual,
    required this.prazo,
    this.tipo = 'geral',
    this.progresso = 0,
    this.aporteSugerido = 0,
    this.mesesRestantes = 0,
  });

  bool get isReservaEmergencia => tipo == 'reserva_emergencia';
  bool get concluida => valorAtual >= valorAlvo;

  factory Meta.fromJson(Map<String, dynamic> json) {
    return Meta(
      id: json['id'],
      titulo: json['titulo'] ?? '',
      valorAlvo: (json['valor_alvo'] ?? 0).toDouble(),
      valorAtual: (json['valor_atual'] ?? 0).toDouble(),
      prazo: json['prazo'] ?? '',
      tipo: json['tipo'] ?? 'geral',
      progresso: (json['progresso'] ?? 0).toDouble(),
      aporteSugerido: (json['aporte_sugerido'] ?? 0).toDouble(),
      mesesRestantes: json['meses_restantes'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'titulo': titulo,
      'valor_alvo': valorAlvo,
      'valor_atual': valorAtual,
      'prazo': prazo,
      'tipo': tipo,
    };
  }
}
