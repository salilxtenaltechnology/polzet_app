// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../../../../core/themes/app_text_styles.dart';

class RankSubmittedScreen extends StatefulWidget {
   final Widget? nextScreen; 
  const RankSubmittedScreen({super.key,    this.nextScreen, 
});

  @override
  State<RankSubmittedScreen> createState() => _RankSubmittedScreenState();
}

class _RankSubmittedScreenState extends State<RankSubmittedScreen>
    with TickerProviderStateMixin {
  // Circle scale + fade
  late final AnimationController _circleController;
  late final Animation<double> _circleScale;
  late final Animation<double> _circleFade;

  // Checkmark draw
  late final AnimationController _checkController;
  late final Animation<double> _checkDraw;

  // Text slide + fade
  late final AnimationController _textController;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;

  static const _primaryColor = Color(0xFFA0253A);

  @override
  void initState() {
    super.initState();

    // ── Circle ────────────────────────────────────────────────────────
    _circleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _circleScale = CurvedAnimation(
      parent: _circleController,
      curve: Curves.elasticOut,
    );
    _circleFade = CurvedAnimation(
      parent: _circleController,
      curve: Curves.easeIn,
    );

    // ── Checkmark ─────────────────────────────────────────────────────
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _checkDraw = CurvedAnimation(
      parent: _checkController,
      curve: Curves.easeOut,
    );

    // ── Text ──────────────────────────────────────────────────────────
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _textFade = CurvedAnimation(parent: _textController, curve: Curves.easeIn);
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    // ── Sequence ──────────────────────────────────────────────────────
    _runSequence();
  }

  Future<void> _runSequence() async {
  await Future.delayed(const Duration(milliseconds: 100));
  await _circleController.forward();

  await Future.delayed(const Duration(milliseconds: 60));
  await _checkController.forward();

  await Future.delayed(const Duration(milliseconds: 60));
  await _textController.forward();

  await Future.delayed(const Duration(milliseconds: 1500));

  if (!mounted) return;

  if (widget.nextScreen != null) {
    // Replace self with ImageResultScreen
    // Back from ImageResultScreen → goes straight to HomeScreen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => widget.nextScreen!),
    );
  } else {
    Navigator.of(context).pop(true);
  }
}

  @override
  void dispose() {
    _circleController.dispose();
    _checkController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Animated circle + checkmark ───────────────────────────
            FadeTransition(
              opacity: _circleFade,
              child: ScaleTransition(
                scale: _circleScale,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: const BoxDecoration(
                    color: _primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _checkDraw,
                      builder: (_, __) => CustomPaint(
                        size: const Size(38, 38),
                        painter: _CheckPainter(_checkDraw.value),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Animated text ─────────────────────────────────────────
            SlideTransition(
              position: _textSlide,
              child: FadeTransition(
                opacity: _textFade,
                child: Column(
                  children: [
                    Text(
                      'Ranking submitted!',
                      style: AppTextStyles.subSectionHeading.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: const Color(0XFF111111),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your feed is now personalized just for you.',
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 14,
                        color: const Color(0xFF595959),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Custom checkmark painter ──────────────────────────────────────────────────

class _CheckPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0

  _CheckPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Checkmark path: short leg then long leg
    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.52)
      ..lineTo(size.width * 0.42, size.height * 0.74)
      ..lineTo(size.width * 0.82, size.height * 0.28);

    final metrics = path.computeMetrics().first;
    final drawn = metrics.extractPath(0, metrics.length * progress);
    canvas.drawPath(drawn, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}
