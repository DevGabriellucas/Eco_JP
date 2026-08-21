import 'package:flutter/material.dart';

/// Contorno tracejado arredondado (usado na área de "adicionar foto" vazia).
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;


  const DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5),
          Radius.circular(radius),
        ),
      );

    final dashed = Path();
    for (final m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        dashed.addPath(m.extractPath(d, d + 5), Offset.zero);
        d += 9;
      }
    }
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

