// ignore_for_file: deprecated_member_use

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/themes/app_text_styles.dart';
import '../home/home_imports.dart';

class AllSetScreen extends StatefulWidget {
  final VoidCallback? onContinue;

  const AllSetScreen({super.key, this.onContinue});

  @override
  State<AllSetScreen> createState() => _AllSetScreenState();
}

class _AllSetScreenState extends State<AllSetScreen>
    with TickerProviderStateMixin {
  // 1. Circle pop in
  late final AnimationController _circleCtrl;
  late final Animation<double> _circleScale;
  late final Animation<double> _circleFade;

  // 2. Check draw
  late final AnimationController _checkCtrl;
  late final Animation<double> _checkDraw;

  // 3. Text slide + fade
  late final AnimationController _textCtrl;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;

  // 4. Ripple pulse (looping)
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseFade;

  // 5. Confetti burst
  late final AnimationController _confettiCtrl;

  @override
  void initState() {
    super.initState();

    _circleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _circleScale = CurvedAnimation(
      parent: _circleCtrl,
      curve: Curves.elasticOut,
    );
    _circleFade = CurvedAnimation(
      parent: _circleCtrl,
      curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
    );

    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _checkDraw = CurvedAnimation(parent: _checkCtrl, curve: Curves.easeOut);

    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _textFade = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseScale = Tween<double>(
      begin: 1.0,
      end: 2.4,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));
    _pulseFade = Tween<double>(
      begin: 0.4,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));

    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
  await Future.delayed(const Duration(milliseconds: 250));
  _circleCtrl.forward();

  await Future.delayed(const Duration(milliseconds: 380));
  _checkCtrl.forward();
  _confettiCtrl.forward();

  await Future.delayed(const Duration(milliseconds: 320));
  _textCtrl.forward();

  await Future.delayed(const Duration(milliseconds: 300));
  _pulseCtrl.repeat();

  // ── Auto-redirect after 3.5s
  await Future.delayed(const Duration(milliseconds: 2500));
  if (!mounted) return;

  _navigateHome();
}


  void _navigateHome() {
  final callback = widget.onContinue;
  if (callback != null) {
    callback();
  } else {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const HomeScreen(initialIndex: 0),
      ),
      (route) => false,
    );
  }
}

  @override
  void dispose() {
    _circleCtrl.dispose();
    _checkCtrl.dispose();
    _textCtrl.dispose();
    _pulseCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Icon area
                SizedBox(
                  width: 180,
                  height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Ripple ring
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, __) => Transform.scale(
                          scale: _pulseScale.value,
                          child: Opacity(
                            opacity: _pulseFade.value,
                            child: Container(
                              width: 94,
                              height: 94,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Circle
                      ScaleTransition(
                        scale: _circleScale,
                        child: FadeTransition(
                          opacity: _circleFade,
                          child: Container(
                            width: 94,
                            height: 94,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),

                      // Animated check mark
                      AnimatedBuilder(
                        animation: _checkDraw,
                        builder: (_, __) => CustomPaint(
                          size: const Size(94, 94),
                          painter: _CheckPainter(progress: _checkDraw.value),
                        ),
                      ),

                      // Confetti burst
                      AnimatedBuilder(
                        animation: _confettiCtrl,
                        builder: (_, __) => CustomPaint(
                          size: const Size(180, 180),
                          painter: _ConfettiPainter(
                            progress: _confettiCtrl.value,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // ── Title
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textFade,
                    child: Text(
                      'You\'re all set! 🎉',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.subSectionHeading.copyWith(
                        fontSize: 23,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111111),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ── Subtitle
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textFade,
                    child: Text(
                      'Your feed is now personalized just for you.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 13.5,
                        color: const Color(0xFF595959),
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Check mark CustomPainter
// ─────────────────────────────────────────────────────────────────────────────

class _CheckPainter extends CustomPainter {
  final double progress;
  const _CheckPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;

    final path = Path()
      ..moveTo(cx - 16, cy + 1)
      ..lineTo(cx - 4, cy + 13)
      ..lineTo(cx + 18, cy - 12);

    final metrics = path.computeMetrics().toList();
    final totalLength = metrics.fold(0.0, (sum, m) => sum + m.length);
    final drawLength = totalLength * progress;

    final result = Path();
    var remaining = drawLength;
    for (final metric in metrics) {
      if (remaining <= 0) break;
      final take = remaining.clamp(0.0, metric.length);
      result.addPath(metric.extractPath(0, take), Offset.zero);
      remaining -= take;
    }

    canvas.drawPath(result, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// Confetti CustomPainter
// ─────────────────────────────────────────────────────────────────────────────

class _ConfettiPainter extends CustomPainter {
  final double progress;
  const _ConfettiPainter({required this.progress});

  static const _colors = [
    Color(0xFFAD2D45),
    Color(0xFFF4A261),
    Color(0xFF2A9D8F),
    Color(0xFFE9C46A),
    Color(0xFF457B9D),
    Color(0xFFE76F51),
    Color(0xFFD62839),
    Color(0xFF6A0572),
  ];

  // (angle in radians, speed multiplier, color index, shape: 0=circle 1=rect)
  static const _particles = [
    (a: -0.5, s: 1.1, c: 0, sh: 0),
    (a: -0.2, s: 0.95, c: 1, sh: 1),
    (a: 0.15, s: 1.2, c: 2, sh: 0),
    (a: 0.55, s: 1.0, c: 3, sh: 1),
    (a: 0.95, s: 0.85, c: 4, sh: 0),
    (a: 1.35, s: 1.15, c: 5, sh: 1),
    (a: -0.9, s: 0.95, c: 6, sh: 0),
    (a: -1.3, s: 1.05, c: 1, sh: 1),
    (a: 1.75, s: 0.9, c: 7, sh: 0),
    (a: 2.1, s: 1.1, c: 2, sh: 1),
    (a: 2.5, s: 0.8, c: 5, sh: 0),
    (a: -1.9, s: 1.0, c: 3, sh: 1),
    (a: -2.3, s: 1.2, c: 0, sh: 0),
    (a: 2.9, s: 0.9, c: 6, sh: 1),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 0.92) return;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final eased = Curves.easeOut.transform(progress);

    for (final p in _particles) {
      final dist = eased * 78 * p.s;
      final dx = cx + dist * math.cos(p.a);
      final dy = cy + dist * math.sin(p.a) - eased * 18;
      final opacity = (1.0 - eased).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = _colors[p.c].withOpacity(opacity)
        ..style = PaintingStyle.fill;

      if (p.sh == 0) {
        // Circle dot
        canvas.drawCircle(Offset(dx, dy), 4.5 * (1 - eased * 0.3), paint);
      } else {
        // Small rectangle
        final w = 7.0 * (1 - eased * 0.2);
        final h = 4.0 * (1 - eased * 0.2);
        final rotate = eased * math.pi * p.s;
        canvas.save();
        canvas.translate(dx, dy);
        canvas.rotate(rotate);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: w, height: h),
            const Radius.circular(1.5),
          ),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
