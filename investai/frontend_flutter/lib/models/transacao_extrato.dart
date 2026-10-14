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
      // Só o que é claramente novo já vem marcado; o resto o usuário
      // decide se quer mesmo importar.
      selecionada: situacao == 'nova',
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
