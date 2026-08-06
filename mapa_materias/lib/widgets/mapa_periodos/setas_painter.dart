import 'package:flutter/material.dart';

class SetasPainter extends CustomPainter {
  final List<(String, String)> arestas;
  final Map<String, Offset> posicoes;
  final double larguraCard;
  final double alturaCard;
  final Set<String> destacados;
  final String? codigoFoco;

  SetasPainter({
    required this.arestas,
    required this.posicoes,
    required this.larguraCard,
    required this.alturaCard,
    required this.destacados,
    this.codigoFoco,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linhaNormal = Paint()
      ..color = Colors.blueGrey.shade400
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final linhaDestaque = Paint()
      ..color = Colors.deepOrange
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final linhaFoco = Paint()
      ..color = Colors.amber.shade800
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (final (origemCodigo, destinoCodigo) in arestas) {
      final origem = posicoes[origemCodigo];
      final destino = posicoes[destinoCodigo];
      if (origem == null || destino == null) continue;

      final destacada = destacados.contains(origemCodigo) && destacados.contains(destinoCodigo);
      final emFoco = codigoFoco != null && (origemCodigo == codigoFoco || destinoCodigo == codigoFoco);
      final linha = destacada ? linhaDestaque : (emFoco ? linhaFoco : linhaNormal);

      final saida = origem + Offset(larguraCard, alturaCard / 2);
      final chegada = destino + Offset(0, alturaCard / 2);
      final meio1 = Offset((saida.dx + chegada.dx) / 2, saida.dy);
      final meio2 = Offset((saida.dx + chegada.dx) / 2, chegada.dy);

      final path = Path()
        ..moveTo(saida.dx, saida.dy)
        ..cubicTo(meio1.dx, meio1.dy, meio2.dx, meio2.dy, chegada.dx, chegada.dy);
      canvas.drawPath(path, linha);
      _desenharSeta(canvas, chegada, linha.color);
    }
  }

  void _desenharSeta(Canvas canvas, Offset ponta, Color cor) {
    const tamanho = 6.0;
    final path = Path()
      ..moveTo(ponta.dx, ponta.dy)
      ..lineTo(ponta.dx - tamanho, ponta.dy - tamanho / 2)
      ..lineTo(ponta.dx - tamanho, ponta.dy + tamanho / 2)
      ..close();
    canvas.drawPath(path, Paint()..color = cor);
  }

  @override
  bool shouldRepaint(covariant SetasPainter oldDelegate) => true;
}