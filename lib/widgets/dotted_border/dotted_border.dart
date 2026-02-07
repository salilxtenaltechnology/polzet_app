// Custom painter for dotted border
import 'package:flutter/material.dart';

class DottedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  DottedBorderPainter({
    required this.color,
    this.strokeWidth = 1,
    this.gap = 5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    const borderRadius = 10.0;
    final rect = Rect.fromLTWH(
      strokeWidth / 1,
      strokeWidth / 1,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(borderRadius),
    );

    _drawDottedRRect(canvas, paint, rrect);
  }

  void _drawDottedRRect(Canvas canvas, Paint paint, RRect rrect) {
    final path = Path()..addRRect(rrect);
    final pathMetrics = path.computeMetrics();

    for (final pathMetric in pathMetrics) {
      double distance = 0.0;
      while (distance < pathMetric.length) {
        final nextDistance = distance + gap;
        final segment = pathMetric.extractPath(distance, nextDistance);
        canvas.drawPath(segment, paint);
        distance = nextDistance + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DottedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gap != gap;
  }
}
