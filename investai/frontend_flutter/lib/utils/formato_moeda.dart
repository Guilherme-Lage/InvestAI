import 'package:flutter/services.dart';

/// Formata valores em reais enquanto a pessoa digita: ponto a cada três
/// casas e vírgula para os centavos (5400 vira 5.400).
///
/// Sem isso, campos como "15000" e "150000" ficam quase indistinguíveis na
/// tela de cadastro, onde a pessoa informa renda e vários gastos seguidos.
class FormatadorMilhar extends TextInputFormatter {
  const FormatadorMilhar();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue anterior, TextEditingValue novo) {
    if (novo.text.isEmpty) return novo;

    // Três situações, três tratamentos do ponto:
    //  - digitou um caractere  -> só é decimal se o ponto for o que entrou;
    //  - colou/preencheu       -> vale a convenção do último ponto;
    //  - apagou                -> nenhum ponto vira decimal, senão apagar
    //    um dígito de "2.000" transformaria o milhar em centavos.
    final crescimento = novo.text.length - anterior.text.length;
    final String texto;
    if (crescimento == 1) {
      texto = _virgulaDigitada(anterior.text, novo.text);
    } else if (crescimento > 1) {
      texto = _virgulaColada(novo.text);
    } else {
      texto = novo.text;
    }

    final limpo = _separarParteDecimal(texto);
    if (limpo.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final partes = limpo.split(',');
    final inteiros = partes[0];
    final decimais = partes.length > 1 ? partes[1] : null;

    final formatado = StringBuffer(_comPontos(inteiros));
    if (decimais != null) {
      // Centavos: no máximo duas casas.
      formatado.write(',');
      formatado.write(decimais.length > 2 ? decimais.substring(0, 2) : decimais);
    }

    final resultado = formatado.toString();
    // Cursor sempre no fim: estes campos são preenchidos da esquerda para a
    // direita, e recalcular a posição exata traria mais erro que ganho.
    return TextEditingValue(
      text: resultado,
      selection: TextSelection.collapsed(offset: resultado.length),
    );
  }

  /// Reduz o texto digitado a "inteiros[,decimais]", resolvendo a
  /// ambiguidade do ponto.
  ///
  /// Converte em vírgula um ponto que a **pessoa acabou de digitar**.
  ///
  /// Olhando só o texto final é impossível saber se um ponto é de milhar
  /// (inserido por este formatador) ou decimal (digitado por ela): em
  /// "2.00" os dois são plausíveis. A diferença está na edição — por isso
  /// comparamos com o texto anterior e só tratamos como decimal o ponto
  /// que apareceu agora.
  ///
  /// Sem isso, apagar um dígito de "2.000" produzia "2,00" e o campo
  /// travava: os dígitos seguintes caíam no limite de duas casas decimais.
  String _virgulaDigitada(String anterior, String novo) {
    // Acha a posição em que o caractere foi inserido.
    var i = 0;
    while (i < anterior.length && anterior[i] == novo[i]) {
      i++;
    }
    if (i >= novo.length || novo[i] != '.') return novo;

    return '${novo.substring(0, i)},${novo.substring(i + 1)}';
  }

  /// Texto colado ou preenchido de uma vez: aqui o problema do texto
  /// reprocessado não existe, então dá para usar a convenção comum — o
  /// último ponto é decimal se tiver até duas casas depois ("1500.50"),
  /// e é de milhar caso contrário ("1.234.567").
  String _virgulaColada(String texto) {
    if (texto.contains(',')) return texto;

    final ultimoPonto = texto.lastIndexOf('.');
    if (ultimoPonto < 0) return texto;

    final depois = texto.substring(ultimoPonto + 1);
    if (depois.isEmpty || depois.length > 2 || !RegExp(r'^\d+$').hasMatch(depois)) {
      return texto;
    }
    return '${texto.substring(0, ultimoPonto)},$depois';
  }

  /// Reduz o texto a "inteiros[,decimais]".
  ///
  /// Só a vírgula separa centavos, e vale a **primeira**: o formatador
  /// nunca emite mais de uma, então vírgula repetida é digitação
  /// acidental. Em "1.500,50," a primeira é a real — usar a última leria
  /// 150.050, erro de cem vezes. Todo ponto é descartado como separador
  /// de milhar.
  String _separarParteDecimal(String texto) {
    final so = texto.replaceAll(RegExp(r'[^\d,]'), '');
    if (so.isEmpty) return '';

    final primeiraVirgula = so.indexOf(',');
    if (primeiraVirgula < 0) return so;

    final inteiros = so.substring(0, primeiraVirgula);
    final decimais =
        so.substring(primeiraVirgula + 1).replaceAll(RegExp(r'\D'), '');
    return '$inteiros,$decimais';
  }

  String _comPontos(String digitos) {
    final semZerosAtoa = digitos.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final invertido = semZerosAtoa.split('').reversed.toList();
    final saida = <String>[];
    for (var i = 0; i < invertido.length; i++) {
      if (i > 0 && i % 3 == 0) saida.add('.');
      saida.add(invertido[i]);
    }
    return saida.reversed.join();
  }
}

/// Lê o número de um campo formatado: ponto é separador de milhar e
/// vírgula é decimal. Deve ser usada junto do [FormatadorMilhar] — é ele
/// que garante que o texto siga sempre esse formato.
double? valorDigitado(String texto) {
  final limpo = texto.trim();
  if (limpo.isEmpty) return null;
  final normalizado = limpo.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(normalizado);
}
