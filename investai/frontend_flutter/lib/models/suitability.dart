import 'usuario.dart';

/// Uma pergunta do questionário de suitability (RF18). Os pontos de cada
/// opção ficam só no backend, que é quem calcula o perfil.
class PerguntaSuitability {
  final String id;
  final String texto;
  final List<String> opcoes;

  const PerguntaSuitability({
    required this.id,
    required this.texto,
    required this.opcoes,
  });

  factory PerguntaSuitability.fromJson(Map<String, dynamic> json) {
    return PerguntaSuitability(
      id: json['id'] as String,
      texto: json['texto'] as String,
      opcoes: (json['opcoes'] as List).cast<String>(),
    );
  }
}

/// Resultado de responder o questionário: o usuário já atualizado e o
/// perfil calculado, com a explicação para mostrar à pessoa.
class ResultadoSuitability {
  final Usuario usuario;
  final String perfil;
  final String descricao;

  const ResultadoSuitability({
    required this.usuario,
    required this.perfil,
    required this.descricao,
  });
}

const Map<String, String> rotulosPerfilInvestidor = {
  'conservador': 'Conservador',
  'moderado': 'Moderado',
  'arrojado': 'Arrojado',
};
