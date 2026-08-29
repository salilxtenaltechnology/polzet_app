import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../gen/assets.gen.dart';
import '../../languages/l10n/generated/app_localizations.dart';

class GenerateDescriptionButton extends StatefulWidget {
  final VoidCallback? onTap;
  final bool isGenerating;
  final bool hasGenerated;
  final bool isEnabled;

  const GenerateDescriptionButton({
    super.key,
    this.onTap,
    this.isGenerating = false,
    this.hasGenerated = false,
    this.isEnabled = true,
  });

  @override
  State<GenerateDescriptionButton> createState() =>
      _GenerateDescriptionButtonState();
}

class _GenerateDescriptionButtonState extends State<GenerateDescriptionButton>
    with TickerProviderStateMixin {
  late AnimationController _borderController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // Border animation controller for gradient rotation
    _borderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    if (widget.isGenerating && widget.isEnabled) {
      _borderController.repeat();
    }

    // Scale press animation controller
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant GenerateDescriptionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isEnabled) {
      _borderController.stop();
    } else if (widget.isGenerating != oldWidget.isGenerating) {
      if (widget.isGenerating) {
        _borderController.repeat();
      } else {
        _borderController.stop();
        _borderController.animateTo(
          1.0,
          duration: const Duration(milliseconds: 300),
        );
      }
    }
  }

  @override
  void dispose() {
    _borderController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  bool get _canInteract =>
      widget.isEnabled && !widget.isGenerating && widget.onTap != null;

  void _handleTapDown(TapDownDetails details) {
    if (_canInteract) {
      _scaleController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_canInteract) {
      _scaleController.reverse();
    }
  }

  void _handleTapCancel() {
    if (_canInteract) {
      _scaleController.reverse();
    }
  }

  void _handleTap() {
    if (!_canInteract) return;

    // Trigger spin rotation animation on tap
    if (!_borderController.isAnimating) {
      _borderController.forward(from: 0.0).then((_) {
        if (mounted && !widget.isGenerating) {
          _borderController.value = 0.0;
        }
      });
    }

    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = widget.isEnabled
        ? (isDark ? Colors.transparent : Colors.white)
        : (isDark ? const Color(0x0DFFFFFF) : const Color(0xFFF3F4F6));

    final contentColor = widget.isEnabled
        ? Theme.of(context).colorScheme.onPrimary
        : (isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF));

    String labelText;
    if (widget.isGenerating) {
      labelText = AppLocalizations.of(context)!.generating;
    } else if (widget.hasGenerated) {
      labelText = AppLocalizations.of(context)!.regeneratequestion;
    } else {
      labelText = AppLocalizations.of(context)!.generatequestion;
    }

    return GestureDetector(
      onTapDown: widget.isEnabled ? _handleTapDown : null,
      onTapUp: widget.isEnabled ? _handleTapUp : null,
      onTapCancel: widget.isEnabled ? _handleTapCancel : null,
      onTap: widget.isEnabled ? _handleTap : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge([_borderController, _scaleAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: CustomPaint(
              foregroundPainter: _GradientBorderPainter(
                animationValue: _borderController.value,
                strokeWidth: 1.5,
                radius: 8.0,
                isEnabled: widget.isEnabled,
                isDark: isDark,
              ),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: widget.isEnabled
                      ? const [
                          BoxShadow(
                            color: Color(0x1F8B2544),
                            blurRadius: 5,
                            spreadRadius: 0,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Builder(
                      builder: (context) {
                        final bool isAnimating =
                            widget.isEnabled &&
                            (widget.isGenerating ||
                                _borderController.isAnimating);
                        final double pulse = isAnimating
                            ? math.sin(
                                _borderController.value * 2 * math.pi,
                              )
                            : 0.0;
                        final double iconScale = 1.0 + (0.22 * pulse);
                        final double iconOpacity = widget.isEnabled
                            ? (1.0 + (0.35 * pulse)).clamp(0.4, 1.0)
                            : 1.0;

                        return Transform.scale(
                          scale: iconScale,
                          child: Opacity(
                            opacity: iconOpacity,
                            child: Assets.images.icAssistant.image(
                              width: 12.w,
                              height: 12.h,
                              color: contentColor,
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      labelText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: contentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GradientBorderPainter extends CustomPainter {
  final double animationValue;
  final double strokeWidth;
  final double radius;
  final bool isEnabled;
  final bool isDark;

  _GradientBorderPainter({
    required this.animationValue,
    required this.strokeWidth,
    required this.radius,
    this.isEnabled = true,
    this.isDark = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 1.5,
      strokeWidth / 1.5,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    if (!isEnabled) {
      paint.color = isDark ? const Color(0x26FFFFFF) : const Color(0xFFE5E7EB);
    } else {
      paint.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          Color.fromARGB(255, 246, 44, 105),
          Color.fromARGB(255, 243, 164, 81),
          Color.fromARGB(255, 210, 40, 60),
        ],
        transform: GradientRotation(animationValue * 2 * math.pi),
      ).createShader(rect);
    }

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientBorderPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius ||
        oldDelegate.isEnabled != isEnabled ||
        oldDelegate.isDark != isDark;
  }
}
