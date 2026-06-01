// ignore_for_file: must_be_immutable, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/core/themes/app_text_styles.dart';
import 'package:polzet_app/languages/l10n/generated/app_localizations.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../../core/constants/app_colors.dart';
import '../../gen/assets.gen.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  CustomBottomNavigationBar({
    super.key,
    required this.index,
    required this.bottomNavigationKey,
    required this.onTap,
    this.notificationCount = 0,
    this.messageCount = 0,
    this.onAddTap,
    this.addFabShowcaseKey,
    this.insightsShowcaseKey,
  });

  final int index;
  GlobalKey bottomNavigationKey = GlobalKey();
  final ValueChanged<int> onTap;
  final int notificationCount;
  final int messageCount;
  final VoidCallback? onAddTap;
  final GlobalKey? addFabShowcaseKey;
  final GlobalKey? insightsShowcaseKey;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.background;
    // final surface = Theme.of(context).colorScheme.background;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final shadowColor = isDarkMode
        ? Colors.black.withOpacity(0.3)
        : Colors.black.withOpacity(0.05);
    final shadowBlurRadius = isDarkMode ? 4.0 : 5.0;

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      color: Colors.transparent,
      height: 80.h + bottomPadding,
      child: Stack(
        children: [
          CustomPaint(
            size: Size(double.infinity, 85.h + bottomPadding),
            painter: BulgePainter(
              color: bg,
              shadowColor: shadowColor,
              shadowBlurRadius: shadowBlurRadius,
            ),
          ),
          Positioned(
            top: 28.h,
            bottom: bottomPadding,
            left: 0,
            right: 0,
            child: Row(
              children: [
                // Left: Home + Message
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _NavItemPng(
                        activeImage: Assets.images.activeHome,
                        inactiveImage: Assets.images.inactiveHome,
                        isActive: index == 0,
                        label: AppLocalizations.of(context)!.home,
                        onTap: () => onTap(0),
                        size: 22.sp,
                        sapce: 7,
                      ),
                      _NavItemPngWithBadge(
                        activeImage: Assets.images.activeMessage,
                        inactiveImage: Assets.images.inactiveMessage,
                        isActive: index == 1,
                        badgeCount: messageCount,
                        label: AppLocalizations.of(context)!.message,
                        onTap: () => onTap(1),
                        size: 22.sp,
                      ),
                    ],
                  ),
                ),

                // Center spacer for FAB
                SizedBox(width: 70.w),

                // Right: Insights + Profile
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      if (insightsShowcaseKey != null)
                        Showcase(
                          tooltipBackgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          overlayColor: const Color(0x0D000000),
                          key: insightsShowcaseKey!,
                          description: 'Tap to see profile insights',
                          descTextStyle: AppTextStyles.bodyText.copyWith(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          child: _NavItemPng(
                            activeImage: Assets.images.activeInsights,
                            inactiveImage: Assets.images.inactiveInsights,
                            isActive: index == 3,
                            label: AppLocalizations.of(context)!.insights,
                            onTap: () => onTap(3),
                            size: 22.sp,
                            sapce: 7,
                          ),
                        )
                      else
                        _NavItemPng(
                          activeImage: Assets.images.activeInsights,
                          inactiveImage: Assets.images.inactiveInsights,
                          isActive: index == 3,
                          label: AppLocalizations.of(context)!.insights,
                          onTap: () => onTap(3),
                          size: 24.sp,
                          sapce: 7,
                        ),
                      _NavItemPng(
                        activeImage: Assets.images.activeUser,
                        inactiveImage: Assets.images.inactiveUser,
                        isActive: index == 4,
                        label: AppLocalizations.of(context)!.profile,
                        onTap: () => onTap(4),
                        size: 21.sp,
                        sapce: 7,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Center FAB
          Positioned(
            top: 7.h,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.center,
              child: _buildFabWithShowcase(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFabWithShowcase(BuildContext context) {
    if (addFabShowcaseKey != null) {
      return Showcase(
        tooltipBackgroundColor: Theme.of(context).colorScheme.primary,
        overlayColor: const Color(0x0D000000),
        key: addFabShowcaseKey!,
        description: 'Tap to create new poll things and images.',
        descTextStyle: AppTextStyles.bodyText.copyWith(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        child: _buildFab(context),
      );
    }
    return _buildFab(context);
  }

  Widget _buildFab(BuildContext context) {
    return GestureDetector(
      onTap: onAddTap,
      child: Container(
        width: 55,
        height: 55,
        margin: const EdgeInsets.only(top: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(Icons.add, color: Colors.white, size: 28.sp),
      ),
    );
  }
}

class _NavItemPng extends StatelessWidget {
  const _NavItemPng({
    required this.activeImage,
    required this.inactiveImage,
    required this.isActive,
    required this.onTap,
    required this.size,
    required this.sapce,
    required this.label,
  });

  final AssetGenImage activeImage;
  final AssetGenImage inactiveImage;
  final bool isActive;
  final VoidCallback onTap;
  final double size;
  final double sapce;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final color = isActive
        ? AppColors.primaryColor
        : (isDarkMode
              ? Colors.white.withOpacity(0.7)
              : const Color(0xFF898989));

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            (isActive ? activeImage : inactiveImage).image(
              width: size,
              height: size,
              fit: BoxFit.contain,
              color: isDarkMode ? const Color(0xFFFDFDFD) : color,
              colorBlendMode: BlendMode.srcIn,
            ),
            SizedBox(height: sapce),
            Text(
              label,
              style: AppTextStyles.subText.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: isDarkMode ? const Color(0xFFFDFDFD) : color,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItemPngWithBadge extends StatelessWidget {
  const _NavItemPngWithBadge({
    required this.activeImage,
    required this.inactiveImage,
    required this.isActive,
    required this.badgeCount,
    required this.onTap,
    required this.size,
    required this.label,
  });

  final AssetGenImage activeImage;
  final AssetGenImage inactiveImage;
  final bool isActive;
  final int badgeCount;
  final VoidCallback onTap;
  final double size;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).colorScheme.tertiaryContainer;
    final color = isActive
        ? AppColors.primaryColor
        : (isDarkMode
              ? Colors.white.withOpacity(0.9)
              : Theme.of(context).colorScheme.onSurface.withOpacity(0.6));

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                (isActive ? activeImage : inactiveImage).image(
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  color: isDarkMode ? const Color(0xFFFDFDFD) : color,
                  colorBlendMode: BlendMode.srcIn,
                ),
                Positioned(
                  top: 0,
                  right: -5,
                  child: AnimatedScale(
                    scale: badgeCount > 0 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    child: Container(
                      height: 13.5,
                      width: 13.5,
                      // padding: EdgeInsets.symmetric(
                      //   horizontal: 4.w,
                      //   vertical: 2.h,
                      // ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD20C3E),
                        shape: BoxShape.circle,
                        // borderRadius: BorderRadius.circular(100.r),
                        border: Border.all(color: bg, width: 1.5),
                      ),
                      // constraints: BoxConstraints(
                      //   minWidth: 16.sp,
                      //   minHeight: 16.sp,
                      // ),
                      alignment: Alignment.center,
                      // child: Text(
                      //   badgeCount > 99 ? '99+' : badgeCount.toString(),
                      //   style: TextStyle(
                      //     color: Colors.white,
                      //     fontSize: 9.sp,
                      //     fontWeight: FontWeight.bold,
                      //     height: 1.1,
                      //   ),
                      //   textAlign: TextAlign.center,
                      // ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              label,
              style: AppTextStyles.subText.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: isDarkMode ? const Color(0xFFFDFDFD) : color,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BulgePainter extends CustomPainter {
  final Color color;
  final Color shadowColor;
  final double shadowBlurRadius;

  BulgePainter({
    required this.color,
    required this.shadowColor,
    required this.shadowBlurRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final width = size.width;
    final height = size.height;

    final top = 25.h;
    final center = width / 2;
    final bulgeRadius = 60.w;
    const cornerRadius = 0.0;

    path.moveTo(0, top + cornerRadius);
    path.quadraticBezierTo(0, top, cornerRadius, top);

    path.lineTo(center - bulgeRadius, top);

    path.cubicTo(
      center - bulgeRadius * 0.5,
      top,
      center - bulgeRadius * 0.5,
      0,
      center,
      0,
    );

    path.cubicTo(
      center + bulgeRadius * 0.5,
      0,
      center + bulgeRadius * 0.5,
      top,
      center + bulgeRadius,
      top,
    );

    path.lineTo(width - cornerRadius, top);
    path.quadraticBezierTo(width, top, width, top + cornerRadius);

    path.lineTo(width, height);
    path.lineTo(0, height);
    path.close();

    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowBlurRadius);

    canvas.drawPath(path.shift(const Offset(0, -2)), shadowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
