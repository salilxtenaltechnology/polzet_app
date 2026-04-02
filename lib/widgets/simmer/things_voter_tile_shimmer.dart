// common/voters/things_voter_tile_shimmer.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ThingsVoterTileShimmer extends StatefulWidget {
  const ThingsVoterTileShimmer({super.key});

  @override
  State<ThingsVoterTileShimmer> createState() => _ThingsVoterTileShimmerState();
}

class _ThingsVoterTileShimmerState extends State<ThingsVoterTileShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _animation = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _shimmerBox({
    required double width,
    required double height,
    double? borderRadius,
    bool isCircle = false,
  }) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final baseColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);
        final highlightColor = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5);

        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: isCircle
                ? BorderRadius.circular(height / 2)
                : BorderRadius.circular(borderRadius ?? 6.r),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
              transform: _SlidingGradientTransform(_animation.value),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      child: Row(
        children: [
          // Avatar circle
          _shimmerBox(
            width: 32.r,
            height: 32.r,
            isCircle: true,
          ),
          SizedBox(width: 8.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Username line
              _shimmerBox(width: 100.w, height: 10.h),
              SizedBox(height: 5.h),
              // Subtitle line
              _shimmerBox(width: 130.w, height: 8.h),
            ],
          ),
        ],
      ),
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform(this.slidePercent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0, 0);
  }
}