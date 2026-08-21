class Usuario {
  final int? id;
  final String nome;
  final String email;
  final String perfilRisco;
  final double rendaMensal;

  Usuario({
    this.id,
    required this.nome,
    required this.email,
    required this.perfilRisco,
    required this.rendaMensal,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'],
      nome: json['nome'],
      email: json['email'],
      perfilRisco: json['perfil_risco'] ?? 'conservador',
      rendaMensal: (json['renda_mensal'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'nome': nome,
      'email': email,
      'perfil_risco': perfilRisco,
      'renda_mensal': rendaMensal,
    };
  }
}
