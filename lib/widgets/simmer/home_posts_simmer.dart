import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

class HomeFeedSimmer extends StatelessWidget {
  const HomeFeedSimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView(
        shrinkWrap: true,
        children: [
          Container(
            height: 230.h,
            width: double.infinity,
            margin: EdgeInsets.only(
                bottom: 5.h, top: 10.h, left: 10.w, right: 10.w),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8.r)),
          ),
          Container(
            height: 230.h,
            width: double.infinity,
            margin: EdgeInsets.only(
                bottom: 5.h, top: 10.h, left: 10.w, right: 10.w),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8.r)),
          ),
          Container(
            height: 230.h,
            width: double.infinity,
            margin: EdgeInsets.only(
                bottom: 5.h, top: 10.h, left: 10.w, right: 10.w),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8.r)),
          ),
          Container(
            height: 230.h,
            width: double.infinity,
            margin: EdgeInsets.only(
                bottom: 5.h, top: 10.h, left: 10.w, right: 10.w),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8.r)),
          ),
        ],
      ),
    );
  }
}
