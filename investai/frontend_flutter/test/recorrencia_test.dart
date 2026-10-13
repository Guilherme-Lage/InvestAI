import 'package:flutter_test/flutter_test.dart';

import 'package:investai/models/recorrencia.dart';

void main() {
  test('lê a recorrência devolvida pela API', () {
    final r = Recorrencia.fromJson({
      'id': 7,
      'descricao': 'Aluguel',
      'tipo': 'gasto',
      'valor': 1500, // a API devolve inteiro quando não há centavos
      'categoria': 'contas_fixas',
      'dia_mes': 10,
      'ativa': false,
    });

    expect(r.id, 7);
    expect(r.valor, 1500.0);
    expect(r.diaMes, 10);
    expect(r.ativa, isFalse);
    expect(r.isRenda, isFalse);
  });

  test('envia só os campos que o usuário edita', () {
    final json = Recorrencia(
      id: 7,
      descricao: 'Salário',
      tipo: 'renda',
      valor: 5000,
      categoria: 'salario',
      diaMes: 5,
    ).toJson();

    // id e ativa não vão no corpo: o id está na URL e pausar/retomar é uma
    // chamada à parte, para editar o valor não reativar algo pausado.
    expect(json, {
      'descricao': 'Salário',
      'tipo': 'renda',
      'valor': 5000.0,
      'categoria': 'salario',
      'dia_mes': 5,
    });
  });
}
