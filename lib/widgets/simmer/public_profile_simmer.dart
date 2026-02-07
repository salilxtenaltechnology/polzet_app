import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

class PublicProfileSimmer extends StatelessWidget {
  const PublicProfileSimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: [
          Container(height: 180.h, width: double.infinity, color: Colors.white),
          Container(
            width: double.infinity,
            height: 38.h,
            margin: EdgeInsets.only(
              left: 12.w,
              right: 12.w,
              top: 10.h,
              bottom: 10.h,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(20.r),
            ),
          ),
        ],
      ),
    );
  }
}
