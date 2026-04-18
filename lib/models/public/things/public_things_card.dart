// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_radius.dart';
import '../public_profile_model.dart';

class PublicPollTextCard extends StatelessWidget {
  final PublicPost publicPost;
  final List<Color>? gradientColors;
  final VoidCallback onTap;

  const PublicPollTextCard({
    super.key,
    required this.publicPost,
    this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final poll = publicPost.polls.isNotEmpty ? publicPost.polls.first : null;

    if (poll == null) return const SizedBox.shrink();

    final textOptions = poll.options
        .where((option) => option.text != null)
        .toList();

    if (textOptions.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
        margin: EdgeInsets.only(bottom: 10.h),
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
          borderRadius: AppRadius.cardRadius,
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 6, spreadRadius: 2),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              poll.question,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
