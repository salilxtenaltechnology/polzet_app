import 'package:flutter/material.dart';

class FadeUnderlineTabIndicator extends Decoration {
  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _FadeUnderlinePainter();
  }
}

class _FadeUnderlinePainter extends BoxPainter {
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final Paint paint = Paint()
      ..color = const Color(0XFF9B3046)
      ..strokeWidth = 1;

    final double x = offset.dx;
    final double y = configuration.size!.height - 7;
    final double width = configuration.size!.width;

    canvas.drawLine(Offset(x, y), Offset(x + width, y), paint);
  }
}
