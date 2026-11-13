class Usuario {
  final int? id;
  final String nome;
  final String email;
  final String perfilRisco;
  final double rendaMensal;
  final double despesaMensalEstimada;

  /// Se a pessoa já respondeu o questionário de suitability (RF18).
  /// Enquanto for false, o perfil é o padrão (conservador) e o app pede
  /// para ela completar o questionário.
  final bool suitabilityRespondido;

  Usuario({
    this.id,
    required this.nome,
    required this.email,
    required this.perfilRisco,
    required this.rendaMensal,
    this.despesaMensalEstimada = 0,
    this.suitabilityRespondido = false,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'],
      nome: json['nome'],
      email: json['email'],
      perfilRisco: json['perfil_risco'] ?? 'conservador',
      rendaMensal: (json['renda_mensal'] ?? 0).toDouble(),
      despesaMensalEstimada: (json['despesa_mensal_estimada'] ?? 0).toDouble(),
      suitabilityRespondido: json['suitability_respondido'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'nome': nome,
      'email': email,
      'perfil_risco': perfilRisco,
      'renda_mensal': rendaMensal,
      'despesa_mensal_estimada': despesaMensalEstimada,
      'suitability_respondido': suitabilityRespondido,
    };
  }
}
