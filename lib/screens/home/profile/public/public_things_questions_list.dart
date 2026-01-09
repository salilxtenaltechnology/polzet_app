// ignore_for_file: deprecated_member_use, must_be_immutable, unused_field

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../api/services/api_service.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../models/public/images/public_user_posts.dart';
import '../../../../models/public/things/public_post_things_model.dart';
import '../../../../models/public/things/public_questions_card.dart';
import '../../../../widgets/button/back_button.dart';
import '../../../../widgets/custom_text_styles.dart';


class PublicThingsQuestionsList extends StatefulWidget {
  int userId;
  PublicThingsQuestionsList({super.key, required this.userId});

  @override
  State<PublicThingsQuestionsList> createState() =>
      _PublicThingsQuestionsListState();
}

class _PublicThingsQuestionsListState extends State<PublicThingsQuestionsList> {
  late final ApiService apiService = ApiService();
  Future<List<PublicPost>>? _postsFuture;
  Future<List<PublicPostPolls>>? _pollsFuture;

  @override
  void initState() {
    _postsFuture = Future.value(<PublicPost>[]);
    _pollsFuture = Future.value(<PublicPostPolls>[]);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: PrimaryBackButton(),
        centerTitle: true,
        title: Text(AppLocalizations.of(context)!.pollthings,
            style: CustomTextStyles.appBarTitleText(context)),
        backgroundColor: Theme.of(context).colorScheme.background,
        surfaceTintColor: Theme.of(context).colorScheme.background,
      ),
      body: FutureBuilder<List<PublicPostPolls>>(
        future: apiService.fetchPublicPostsPolls(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: ListView(
                children: [
                  Container(
                    height: 300.h,
                    width: double.infinity,
                    margin:
                        EdgeInsets.only(bottom: 12.h, left: 12.w, right: 12.h),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  Container(
                    height: 300.h,
                    width: double.infinity,
                    margin:
                        EdgeInsets.only(bottom: 12.h, left: 12.w, right: 12.h),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  Container(
                    height: 300.h,
                    width: double.infinity,
                    margin:
                        EdgeInsets.only(bottom: 12.h, left: 12.w, right: 12.h),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.grey[600],
                    size: 50,
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    'Error loading polls',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            );
          }

          final postsPolls = snapshot.data ?? const <PublicPostPolls>[];
          if (postsPolls.isEmpty) {
            return Center(
              child: Column(
                children: [
                  SizedBox(height: 12.h),
                  Text(
                    'No posts with things',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }
          final postsWithPolls = postsPolls
              .where((post) => post.publicPollQuestion.isNotEmpty)
              .toList();

          if (postsWithPolls.isEmpty) {
            return const Center(child: Text('No active polls found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            shrinkWrap: true,
            itemCount: postsWithPolls.length > 3 ? 3 : postsWithPolls.length,
            itemBuilder: (context, index) {
              return PublicQuestionsCard(
                  post: postsWithPolls[index], postIndex: index);
            },
          );
        },
      ),
    );
  }
}
