import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../models/posts/user_post_model.dart';

class UserThingsCard extends StatelessWidget {
  const UserThingsCard({
    super.key,
    required this.post,
    required this.gradientColors,
  });

  final UserPostModel post;
  final List<Color>? gradientColors;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Text(
        post.description,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
