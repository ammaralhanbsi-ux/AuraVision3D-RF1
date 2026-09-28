import 'dart:math' as math;

import 'package:flutter/material.dart';

class RfContourPainter extends CustomPainter {
  const RfContourPainter({required this.value, required this.phase});

  final double value;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final cols = 24;
    final rows = 14;
    final cellW = size.width / cols;
    final cellH = size.height / rows;

    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final dx = x / cols - 0.5;
        final dy = y / rows - 0.5;
        final wave = 0.5 + 0.5 * math.sin((dx * 7) + (dy * 5) + phase * 6);
        final radial = math.exp(-(dx * dx + dy * dy) * 7);
        final s = (0.55 * wave + 0.45 * radial) * value.clamp(0, 1);
        final alpha = (18 + 56 * s).round();
        final paint = Paint()..color = Colors.cyan.withAlpha(alpha);
        canvas.drawRect(Rect.fromLTWH(x * cellW, y * cellH, cellW + 0.7, cellH + 0.7), paint);
      }
    }

    final contour = Paint()
      ..color = Colors.white.withAlpha(34)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (var i = 1; i < 7; i++) {
      final r = Rect.fromCenter(
        center: size.center(Offset.zero),
        width: size.width * i / 7,
        height: size.height * i / 7,
      );
      canvas.drawOval(r, contour);
    }
  }

  @override
  bool shouldRepaint(covariant RfContourPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.phase != phase;
}
