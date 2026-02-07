// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../public_profile_model.dart';

class PublicPollTextCard extends StatelessWidget {
  final PublicPost publicPost;
  final List<Color>? gradientColors;

  const PublicPollTextCard({
    super.key,
    required this.publicPost,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    // Get the first poll from the post
    final poll = publicPost.polls.isNotEmpty ? publicPost.polls.first : null;

    if (poll == null) return const SizedBox.shrink();

    // Filter options to show ONLY text-based options (ignore image options)
    final textOptions = poll.options
        .where((option) => option.text != null)
        .toList();

    if (textOptions.isEmpty) return const SizedBox.shrink();

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
            BoxShadow(color: Colors.black12, blurRadius: 6, spreadRadius: 2),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poll Question
            Text(
              poll.question,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
