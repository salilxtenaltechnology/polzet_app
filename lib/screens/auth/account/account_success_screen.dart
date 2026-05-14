// ignore_for_file: deprecated_member_use

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:polzet_app/gen/assets.gen.dart';

import '../../../api/services/api_service.dart';
import '../../../core/themes/app_text_styles.dart';

class AccountSuccessScreen extends StatefulWidget {
  final String email;
  final String password;
  const AccountSuccessScreen({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  State<AccountSuccessScreen> createState() => _AccountSuccessScreenState();
}

class _AccountSuccessScreenState extends State<AccountSuccessScreen>
    with TickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────────────────────────────────
  late final AnimationController _imageController;
  late final AnimationController _textController;
  late final AnimationController _confettiController;

  // ── Image animations ─────────────────────────────────────────────────────────
  late final Animation<double> _imageScale;
  late final Animation<double> _imageOpacity;
  late final Animation<double> _imageBounce;

  // ── Text animations ──────────────────────────────────────────────────────────
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _subtitleOpacity;
  late final Animation<Offset> _subtitleSlide;

  // ── Confetti ─────────────────────────────────────────────────────────────────
  late final Animation<double> _confettiProgress;
  final List<_ConfettiParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    _generateParticles();
    _setupAnimations();
    _startSequence();
  }

  void _generateParticles() {
    final rnd = Random();
    for (int i = 0; i < 40; i++) {
      _particles.add(
        _ConfettiParticle(
          x: rnd.nextDouble(),
          delay: rnd.nextDouble() * 0.4,
          color: [
            const Color(0xFFFF6B6B),
            const Color(0xFFFFD93D),
            const Color(0xFF6BCB77),
            const Color(0xFF4D96FF),
            const Color(0xFFB02A4C),
            const Color(0xFFA855F7),
          ][rnd.nextInt(6)],
          size: 6 + rnd.nextDouble() * 6,
          isCircle: rnd.nextBool(),
          horizontalDrift: (rnd.nextDouble() - 0.5) * 0.3,
          rotationSpeed: (rnd.nextDouble() - 0.5) * 8,
        ),
      );
    }
  }

  void _setupAnimations() {
    // Image: scale + fade + bounce
    _imageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _imageScale = TweenSequence([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.15,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.15,
          end: 0.92,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.92,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
    ]).animate(_imageController);
    _imageOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _imageController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );
    _imageBounce = Tween(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _imageController, curve: Curves.elasticOut),
    );

    // Text: slide + fade
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _titleOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );
    _subtitleOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );
    _subtitleSlide = Tween(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _textController,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
          ),
        );

    // Confetti
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _confettiProgress = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _confettiController, curve: Curves.easeIn),
    );
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _imageController.forward();
    _confettiController.forward();

    await Future.delayed(const Duration(milliseconds: 400));
    _textController.forward();

    // Auto-login runs in background while animation plays
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    await ApiService().loginUser(
      email_username: widget.email,
      password: widget.password,
      context: context,
    );
  }

  @override
  void dispose() {
    _imageController.dispose();
    _textController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Stack(
        children: [
          // ── Confetti layer ──────────────────────────────────────────────────
          AnimatedBuilder(
            animation: _confettiProgress,
            builder: (_, __) => CustomPaint(
              size: size,
              painter: _ConfettiPainter(
                particles: _particles,
                progress: _confettiProgress.value,
              ),
            ),
          ),

          // ── Main content ────────────────────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Celebrate image ───────────────────────────────────────────
                AnimatedBuilder(
                  animation: _imageController,
                  builder: (_, child) => Opacity(
                    opacity: _imageOpacity.value,
                    child: Transform.translate(
                      offset: Offset(0, _imageBounce.value),
                      child: Transform.scale(
                        scale: _imageScale.value,
                        child: child,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Image.asset(
                      Assets.images.celebration.path,
                      width: 110,
                      height: 110,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Title ─────────────────────────────────────────────────────
                AnimatedBuilder(
                  animation: _textController,
                  builder: (_, child) => FadeTransition(
                    opacity: _titleOpacity,
                    child: SlideTransition(position: _titleSlide, child: child),
                  ),
                  child: Text(
                    'Account created\nsuccessfully!',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subSectionHeading.copyWith(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111111),
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // ── Subtitle ──────────────────────────────────────────────────
                AnimatedBuilder(
                  animation: _textController,
                  builder: (_, child) => FadeTransition(
                    opacity: _subtitleOpacity,
                    child: SlideTransition(
                      position: _subtitleSlide,
                      child: child,
                    ),
                  ),
                  child: Text(
                    'Your account has been created successfully',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.subText.copyWith(
                      fontSize: 14,
                      color: const Color(0xFF595959),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Confetti particle model ───────────────────────────────────────────────────
class _ConfettiParticle {
  final double x; // 0..1 horizontal start position
  final double delay; // 0..1 animation delay
  final Color color;
  final double size;
  final bool isCircle;
  final double horizontalDrift;
  final double rotationSpeed;

  const _ConfettiParticle({
    required this.x,
    required this.delay,
    required this.color,
    required this.size,
    required this.isCircle,
    required this.horizontalDrift,
    required this.rotationSpeed,
  });
}

// ── Confetti painter ──────────────────────────────────────────────────────────
class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  const _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = ((progress - p.delay) / (1.0 - p.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final x = p.x * size.width + p.horizontalDrift * size.width * t;
      final y = -p.size + (size.height + p.size * 2) * t;
      final opacity = t < 0.7 ? 1.0 : (1.0 - t) / 0.3;
      final rotation = p.rotationSpeed * t * pi;

      final paint = Paint()
        ..color = p.color.withOpacity(opacity.clamp(0.0, 1.0));

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.5,
          ),
          paint,
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
