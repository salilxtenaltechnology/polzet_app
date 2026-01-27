// ignore_for_file: must_be_immutable

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../widgets/custom_card.dart';
import 'public_post_things_model.dart';
import 'public_question_block.dart';

class PublicQuestionsCard extends StatelessWidget {
   PublicQuestionsCard({super.key, required this.post,required this.postIndex});
  int postIndex;
  final PublicPostPolls post;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: CustomCard(
        widget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Description
            // Text(
            //   post.description,
            //   style: Theme.of(context).textTheme.titleMedium,
            // Each poll in this post
            ...post.publicPollQuestion
                .map((p) => PublicQuestionsBlock(pollQuestion: p, postIndex: postIndex))
                ,
          ],
        ),
      ),
    );
  }
}
