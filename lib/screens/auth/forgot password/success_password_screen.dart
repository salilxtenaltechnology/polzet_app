// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:polzet_app/core/constants/feather_icons_compat.dart';
import '../../../core/themes/app_text_colors.dart';
import '../../../core/themes/app_text_styles.dart';
import '../login/email_login.dart';

class SuccessPasswordScreen extends StatefulWidget {
  const SuccessPasswordScreen({super.key});

  @override
  State<SuccessPasswordScreen> createState() =>
      _PasswordResetSuccessScreenState();
}

class _PasswordResetSuccessScreenState extends State<SuccessPasswordScreen>
    with TickerProviderStateMixin {
  /// Circle scale + fade-in
  late final AnimationController _circleCtrl;
  late final Animation<double> _circleScale;
  late final Animation<double> _circleFade;

  /// Check-mark draw
  late final AnimationController _checkCtrl;
  late final Animation<double> _checkProgress;

  /// Text slide-up + fade-in
  late final AnimationController _textCtrl;
  late final Animation<Offset> _titleSlide;
  late final Animation<Offset> _subtitleSlide;
  late final Animation<double> _textFade;

  /// Ripple / pulse ring around circle
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  /// Confetti burst
  late final AnimationController _confettiCtrl;

  /// Exit page-out fade
  late final AnimationController _exitCtrl;
  late final Animation<double> _exitFade;

  Timer? _redirectTimer;
  bool _hasRedirected = false;

  @override
  void initState() {
    super.initState();
    _buildAnimations();
    _startSequence();
  }

  void _buildAnimations() {
    // 1. Circle entrance – 650 ms
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

    // 2. Check-mark draw – 450 ms
    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _checkProgress = CurvedAnimation(parent: _checkCtrl, curve: Curves.easeOut);

    // 3. Text reveal – 500 ms
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _subtitleSlide =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _textCtrl,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
          ),
        );
    _textFade = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);

    // 4. Pulse ring – 1.5 s looping
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseScale = Tween<double>(
      begin: 1.0,
      end: 2.4,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));
    _pulseOpacity = Tween<double>(
      begin: 0.4,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));

    // 5. Confetti burst – 1000 ms
    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // 6. Exit fade – 400 ms
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _exitFade = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn));
  }

  Future<void> _startSequence() async {
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 250));

    if (!mounted) return;
    _circleCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 380));
    if (!mounted) return;
    _checkCtrl.forward();
    _confettiCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;
    _textCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _pulseCtrl.repeat();

    if (!mounted) return;
    _redirectTimer = Timer(const Duration(milliseconds: 1500), _redirect);
  }

  Future<void> _redirect() async {
    if (_hasRedirected) return;
    _hasRedirected = true;

    _pulseCtrl.stop();
    _redirectTimer?.cancel();

    if (!mounted) return;
    await _exitCtrl.forward();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      PageTransition(
        type: PageTransitionType.fade,
        duration: const Duration(milliseconds: 400),
        child: const EmailLoginScreen(),
      ),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    _circleCtrl.dispose();
    _checkCtrl.dispose();
    _textCtrl.dispose();
    _pulseCtrl.dispose();
    _confettiCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
     final txt = AppTextColors.of(context);
    return FadeTransition(
      opacity: _exitFade,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Icon area ─────────────────────────────────────
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ripple ring (stroke, matches AllSetScreen)
                        AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (_, __) => Transform.scale(
                            scale: _pulseScale.value,
                            child: Opacity(
                              opacity: _pulseOpacity.value,
                              child: Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Solid circle
                        ScaleTransition(
                          scale: _circleScale,
                          child: FadeTransition(
                            opacity: _circleFade,
                            child: Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.primary,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x449B2C47),
                                    blurRadius: 24,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Animated check mark
                        AnimatedBuilder(
                          animation: _checkProgress,
                          builder: (_, __) => CustomPaint(
                            size: const Size(96, 96),
                            painter: _CheckPainter(
                              progress: _checkProgress.value,
                            ),
                          ),
                        ),

                        // Confetti burst ✅
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

                  const SizedBox(height: 36),

                  // ── Title (unchanged text) ────────────────────────
                  SlideTransition(
                    position: _titleSlide,
                    child: FadeTransition(
                      opacity: _textFade,
                      child: Text(
                        'Password reset\nsuccessfully',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.subSectionHeading.copyWith(
                          fontSize: 23,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Subtitle (unchanged text) ─────────────────────
                  SlideTransition(
                    position: _subtitleSlide,
                    child: FadeTransition(
                      opacity: _textFade,
                      child: Text(
                        'Your password has been updated\nyou can now log in',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 13.5,
                          color: txt.body,
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Check mark CustomPainter  (matches AllSetScreen logic)
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
// Confetti CustomPainter  (copied exactly from AllSetScreen)
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
        canvas.drawCircle(Offset(dx, dy), 4.5 * (1 - eased * 0.3), paint);
      } else {
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
