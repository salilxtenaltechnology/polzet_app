import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

class UserChaseSimmer extends StatelessWidget {
  const UserChaseSimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 55.h, // Adjusted to match the user profile containers
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            Container(
              height: 55.h,
              width: 55.w,
              margin: EdgeInsets.symmetric(horizontal: 5.w),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              height: 55.h,
              width: 55.w,
              margin: EdgeInsets.symmetric(horizontal: 5.w),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              height: 55.h,
              width: 55.w,
              margin: EdgeInsets.symmetric(horizontal: 5.w),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              height: 55.h,
              width: 55.w,
              margin: EdgeInsets.symmetric(horizontal: 5.w),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
