// ignore_for_file: must_be_immutable, deprecated_member_use
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/constants/app_colors.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  CustomBottomNavigationBar({
    super.key,
    required this.index,
    required this.bottomNavigationKey,
    required this.onTap,
  });

  final int index;
  GlobalKey<CurvedNavigationBarState> bottomNavigationKey = GlobalKey();
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return CurvedNavigationBar(
      key: bottomNavigationKey,
      height: 42.h,
      index: index,
      items: [
        Icon(
          FeatherIcons.home,
          size: 22.sp,
          weight: 1,
          color: index == 0
              ? Colors.white
              : Theme.of(context).colorScheme.onPrimary,
        ),
        Icon(
          Icons.insights,
          size: 22.sp,
          color: index == 1
              ? Colors.white
              : Theme.of(context).colorScheme.onPrimary,
        ),
        IconButton(
          onPressed: () {},
          icon: const SizedBox.shrink(),
          color: Theme.of(context).colorScheme.tertiaryContainer,
        ),
        Icon(
          FeatherIcons.bell,
          size: 22.sp,
          color: index == 3
              ? Colors.white
              : Theme.of(context).colorScheme.onPrimary,
        ),
        Icon(
          FeatherIcons.user,
          size: 22.sp,
          color: index == 4
              ? Colors.white
              : Theme.of(context).colorScheme.onPrimary,
        ),
      ],
      backgroundColor: Theme.of(context).colorScheme.background,
      color: Theme.of(context).colorScheme.tertiaryContainer,
      animationCurve: Curves.easeInOut,
      animationDuration: const Duration(milliseconds: 300),
      buttonBackgroundColor: AppColors.primaryColor,
      maxWidth: double.infinity,
      onTap: onTap,
      letIndexChange: (index) {
        return true;
      },
    );
  }
}
