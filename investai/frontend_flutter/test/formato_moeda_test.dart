import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investai/utils/formato_moeda.dart';

/// O par formatador + leitor precisa fechar: o que é escrito na tela tem
/// de voltar como o mesmo número. Um erro aqui faria o app enviar valores
/// errados para o backend sem ninguém perceber.
void main() {
  const formatador = FormatadorMilhar();

  /// Formata como se o texto tivesse sido colado de uma vez.
  String formatar(String digitado) {
    return formatador
        .formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(text: digitado),
        )
        .text;
  }

  /// Simula a digitação tecla a tecla, que é como o formatador é usado de
  /// verdade: ele recebe o próprio texto de volta a cada caractere.
  String digitar(String teclas, {String aPartirDe = ''}) {
    var atual = aPartirDe;
    for (final tecla in teclas.split('')) {
      atual = formatador
          .formatEditUpdate(
            TextEditingValue(text: atual),
            TextEditingValue(text: '$atual$tecla'),
          )
          .text;
    }
    return atual;
  }

  /// Simula apagar o último caractere.
  String apagarUltimo(String atual) {
    final menor = atual.substring(0, atual.length - 1);
    return formatador
        .formatEditUpdate(
          TextEditingValue(text: atual),
          TextEditingValue(text: menor),
        )
        .text;
  }

  group('FormatadorMilhar', () {
    test('agrupa milhares com ponto', () {
      expect(formatar('5400'), '5.400');
      expect(formatar('15000'), '15.000');
      expect(formatar('1234567'), '1.234.567');
    });

    test('nao mexe em numeros de ate tres digitos', () {
      expect(formatar('7'), '7');
      expect(formatar('999'), '999');
    });

    test('aceita virgula para centavos', () {
      expect(formatar('1500,50'), '1.500,50');
    });

    test('trata ponto final como separador de centavos', () {
      // No teclado numerico do celular nem sempre da para escolher.
      expect(formatar('1500.50'), '1.500,50');
    });

    test('ponto de milhar ja formatado nao vira centavos', () {
      // Caso que acontece a cada tecla: o formatador recebe de volta o
      // proprio texto com o ponto que ele mesmo inseriu.
      expect(formatar('2.3005'), '23.005');
      expect(formatar('1.234.567'), '1.234.567');
    });

    test('virgula repetida por engano nao multiplica o valor', () {
      // Vale a primeira virgula: usar a ultima leria 150.050.
      expect(formatar('1.500,50,'), '1.500,50');
    });

    test('limita os centavos a duas casas', () {
      expect(formatar('10,999'), '10,99');
    });

    test('ignora letras e simbolos', () {
      expect(formatar('R\$ 2.300abc'), '2.300');
    });

    test('aceita apenas uma virgula', () {
      expect(formatar('10,5,7'), '10,57');
    });

    test('digitar mais um digito em valor ja formatado funciona', () {
      expect(digitar('23000'), '23.000');
      expect(digitar('1234567'), '1.234.567');
    });
  });

  group('edicao tecla a tecla', () {
    test('apagar um zero de 2.000 da 200, nao 2,00', () {
      // Bug relatado: apagar um digito convertia o ponto de milhar em
      // virgula decimal, e o campo parava de aceitar digitos.
      final depoisDeApagar = apagarUltimo(digitar('2000'));
      expect(depoisDeApagar, '200');
    });

    test('da para continuar digitando depois de apagar', () {
      var texto = apagarUltimo(digitar('2000')); // 200
      texto = digitar('5', aPartirDe: texto);
      expect(texto, '2.005');
    });

    test('apagar varias vezes nao trava o campo', () {
      var texto = digitar('15000'); // 15.000
      expect(texto, '15.000');
      texto = apagarUltimo(texto);
      expect(texto, '1.500');
      texto = apagarUltimo(texto);
      expect(texto, '150');
      texto = digitar('99', aPartirDe: texto);
      expect(texto, '15.099');
    });

    test('ponto digitado pela pessoa vira centavos', () {
      final texto = digitar('1500.50');
      expect(texto, '1.500,50');
    });

    test('virgula digitada apos milhar funciona', () {
      final texto = digitar('1500,50');
      expect(texto, '1.500,50');
    });

    test('remove zeros a esquerda', () {
      expect(formatar('007'), '7');
    });

    test('campo vazio continua vazio', () {
      expect(formatar(''), '');
    });
  });

  group('valorDigitado', () {
    test('le valores com separador de milhar', () {
      expect(valorDigitado('15.000'), 15000.0);
      expect(valorDigitado('1.234.567'), 1234567.0);
    });

    test('le centavos', () {
      expect(valorDigitado('1.500,50'), 1500.5);
    });

    test('campo vazio devolve nulo', () {
      expect(valorDigitado(''), isNull);
      expect(valorDigitado('   '), isNull);
    });
  });

  group('formatar e ler fecham o ciclo', () {
    test('o numero escrito na tela volta igual', () {
      for (final valor in ['5400', '15000', '1234567', '250', '1500,50']) {
        final naTela = formatar(valor);
        final lido = valorDigitado(naTela);
        final esperado = double.parse(valor.replaceAll(',', '.'));
        // "1500,50" vira 1500.5; os demais sao inteiros.
        expect(lido, esperado, reason: 'falhou para "$valor" (tela: $naTela)');
      }
    });
  });
}
