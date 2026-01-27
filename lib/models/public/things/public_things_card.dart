// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'public_post_things_model.dart';
import 'public_things_block.dart';

class PublicThingsCard extends StatelessWidget {
  const PublicThingsCard({
    super.key,
    required this.publicPosts,
    this.gradientColors,
  });

  final PublicPostPolls publicPosts;
  final List<Color>? gradientColors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10).w,
        decoration: BoxDecoration(
          gradient: gradientColors != null
              ? LinearGradient(
                  colors: gradientColors!,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: gradientColors == null
              ? Theme.of(context).colorScheme.secondaryContainer
              : null,
          borderRadius: BorderRadius.circular(15.r),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...publicPosts.publicPollQuestion
                .map((question) => ThingsBlock(
                      publicPollsQuestion: question,
                    ))
                ,
          ],
        ),
      ),
    );
  }
}
