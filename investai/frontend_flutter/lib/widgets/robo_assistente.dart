import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Ícone do assistente de IA: um círculo com o rosto de um robô dentro.
/// Desenhado em código (sem arquivo de imagem) para ficar nítido em
/// qualquer tamanho e seguir as cores do tema.
class RoboAssistente extends StatelessWidget {
  final double tamanho;
  final Color corFundo;
  final Color corRosto;

  const RoboAssistente({
    super.key,
    this.tamanho = 24,
    this.corFundo = InvestAITheme.verde,
    this.corRosto = InvestAITheme.texto,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: tamanho,
      child: CustomPaint(painter: _PintorRobo(corFundo: corFundo, corRosto: corRosto)),
    );
  }
}

class _PintorRobo extends CustomPainter {
  final Color corFundo;
  final Color corRosto;

  _PintorRobo({required this.corFundo, required this.corRosto});

  @override
  void paint(Canvas canvas, Size size) {
    // Todas as medidas são frações do tamanho, para o desenho escalar.
    final u = size.shortestSide;
    final fundo = Paint()..color = corFundo;
    final rosto = Paint()..color = corRosto;

    // Fundo: círculo que ocupa todo o espaço.
    canvas.drawCircle(Offset(0.5 * u, 0.5 * u), 0.5 * u, fundo);

    // Orelhas (os fones nas laterais da cabeça).
    for (final x in [0.19 * u, 0.74 * u]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 0.43 * u, 0.07 * u, 0.15 * u),
          Radius.circular(0.03 * u),
        ),
        rosto,
      );
    }

    // Cabeça.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(0.27 * u, 0.34 * u, 0.73 * u, 0.67 * u),
        Radius.circular(0.11 * u),
      ),
      rosto,
    );

    // Olhos.
    for (final x in [0.40 * u, 0.60 * u]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 0.47 * u), width: 0.065 * u, height: 0.09 * u),
        fundo,
      );
    }

    // Sorriso.
    canvas.drawArc(
      Rect.fromCenter(center: Offset(0.5 * u, 0.54 * u), width: 0.15 * u, height: 0.08 * u),
      0.15 * math.pi,
      0.7 * math.pi,
      false,
      Paint()
        ..color = corFundo
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.035 * u
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_PintorRobo antigo) =>
      antigo.corFundo != corFundo || antigo.corRosto != corRosto;
}
