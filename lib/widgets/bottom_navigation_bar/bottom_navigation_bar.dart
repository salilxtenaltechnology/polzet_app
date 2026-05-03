// ignore_for_file: must_be_immutable, deprecated_member_use
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
  });

  final int index;
  GlobalKey bottomNavigationKey = GlobalKey();
  final ValueChanged<int> onTap;
  final int notificationCount;
  final int messageCount;
  final VoidCallback? onAddTap;

  static const Color _fabColor = Color(0xFF7D1F3A);

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.tertiaryContainer;
    final surface = Theme.of(context).colorScheme.background;

    return Container(
      color: surface,
      child: Container(
        height: 50.h,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24.r),
            topRight: Radius.circular(24.r),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left: Home + Message
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _NavItemPng(
                    activeImage: Assets.images.activeHome,
                    inactiveImage: Assets.images.inactiveHome,
                    isActive: index == 0,
                    onTap: () => onTap(0),
                    size: 24.sp,
                  ),
                  _NavItemPngWithBadge(
                    activeImage: Assets.images.activeMessage,
                    inactiveImage: Assets.images.inactiveMessage,
                    isActive: index == 1,
                    badgeCount: messageCount,
                    onTap: () => onTap(1),
                    size: 22.sp,
                  ),
                ],
              ),
            ),

            // Center: Embedded FAB
            GestureDetector(
              onTap: onAddTap,
              child: Container(
                width: 38.w,
                height: 38.w,
                margin: EdgeInsets.symmetric(horizontal: 8.w),
                decoration: BoxDecoration(
                  color: _fabColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(Icons.add, color: Colors.white, size: 24.sp),
              ),
            ),

            // Right: Bell + Profile
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // _NavItemPngWithBadge(
                  //   activeImage: Assets.images.activeBell,
                  //   inactiveImage: Assets.images.inactiveBell,
                  //   isActive: index == 3,
                  //   badgeCount: notificationCount,
                  //   onTap: () => onTap(3),
                  //   size: 21.7.sp,
                  // ),
                  _NavItemIcon(
                    icon: FeatherIcons.barChart2,
                    isActive: index == 3,
                    onTap: () => onTap(3),
                    size: 24.sp,
                  ),
                  _NavItemPng(
                    activeImage: Assets.images.activeUser,
                    inactiveImage: Assets.images.inactiveUser,
                    isActive: index == 4,
                    onTap: () => onTap(4),
                    size: 21.sp,
                  ),
                ],
              ),
            ),
          ],
        ),
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
  });

  final AssetGenImage activeImage;
  final AssetGenImage inactiveImage;
  final bool isActive;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? AppColors.primaryColor
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.6);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: Colors.transparent,
          // color: isActive
          //     ? Theme.of(context).primaryColor.withOpacity(0.1)
          //     : Colors.transparent,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: (isActive ? activeImage : inactiveImage).image(
          width: size,
          height: size,
          fit: BoxFit.contain,
          color: color,
          colorBlendMode: BlendMode.srcIn,
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
  });

  final AssetGenImage activeImage;
  final AssetGenImage inactiveImage;
  final bool isActive;
  final int badgeCount;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.tertiaryContainer;
    final color = isActive
        ? AppColors.primaryColor
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.6);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: Colors.transparent,
          // color: isActive
          //     ? AppColors.primaryColor.withOpacity(0.18)
          //     : Colors.transparent,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            (isActive ? activeImage : inactiveImage).image(
              width: size,
              height: size,
              fit: BoxFit.contain,
              color: color,
              colorBlendMode: BlendMode.srcIn,
            ),
            Positioned(
              top: -2,
              right: -2,
              child: AnimatedScale(
                scale: badgeCount > 0 ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                child: Container(
                  width: 11.sp,
                  height: 11.sp,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB82B53),
                    shape: BoxShape.circle,
                    border: Border.all(color: bg, width: 2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItemIcon extends StatelessWidget {
  const _NavItemIcon({
    required this.icon,
    required this.isActive,
    required this.onTap,
    required this.size,
  });

  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? AppColors.primaryColor
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.5);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Icon(icon, color: color, size: size),
      ),
    );
  }
}
