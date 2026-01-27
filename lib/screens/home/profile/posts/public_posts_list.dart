// ignore_for_file: deprecated_member_use, must_be_immutable

import 'dart:math' as math;

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:math';

import '../../../../api/api_config.dart';
import '../../../../api/services/api_service.dart';
import '../../../../core/constants/app_images.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../models/public/images/public_user_posts.dart';
import '../../../../widgets/button/back_button.dart';
import '../../../../widgets/custom_text_styles.dart';

class PublicPostsList extends StatefulWidget {
  int userId;
  PublicPostsList({super.key, required this.userId});

  @override
  State<PublicPostsList> createState() => _PublicPostsListState();
}

class _PublicPostsListState extends State<PublicPostsList> {
  final ApiService apiService = ApiService();
  bool isLike = false;

  // Map to store selection order for each post
  Map<int, List<int>> postSelectionOrder = {};

  // Map to store display indices for each post
  Map<int, List<int>> postDisplayIndices = {};

  // Store the posts data to avoid rebuilding FutureBuilder
  List<PublicPost>? cachedPosts;

  // Get the selection number for an image (1, 2, 3, etc.)
  int getSelectionNumber(int imageNumber, int postIndex) {
    List<int> selectionOrder = postSelectionOrder[postIndex] ?? [];
    int index = selectionOrder.indexOf(imageNumber);
    return index == -1 ? 0 : index + 1;
  }

  Widget _buildPostsList(List<PublicPost> postsWithImages) {
    return ListView.builder(
      padding: EdgeInsets.only(top: 5.h),
      itemCount: postsWithImages.length > 4 ? 4 : postsWithImages.length,
      itemBuilder: (context, index) {
        final post = postsWithImages[index];

        // Initialize display indices for this post if not already done
        if (!postDisplayIndices.containsKey(index)) {
          postDisplayIndices[index] = _getRandomImageIndices(
            post.images.length,
          );
        }

        // Initialize selection order for this post if not already done
        if (!postSelectionOrder.containsKey(index)) {
          postSelectionOrder[index] = <int>[];
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10).w,
          margin: EdgeInsets.only(bottom: 10.h, right: 10.w, left: 10.w),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(10.r),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 6, spreadRadius: 2),
            ],
          ),
          child: Column(
            children: [
              _buildImagesSection(post, index),
              SizedBox(height: 5.h),
              Row(
                children: [
                  Image.asset(
                    Assets.assetsImagesIcHeart,
                    key: const ValueKey('outline'),
                    height: 23.h,
                    width: 23.w,
                    color: const Color(0xFFC6C5C5),
                  ),
                  SizedBox(width: 10.w),
                  Icon(
                    FeatherIcons.messageSquare,
                    size: 21.sp,
                    color: const Color(0xFFC6C5C5),
                  ),
                ],
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: areAllImagesSelected(index)
                    ? Container(
                        key: ValueKey("analytics_$index"),
                        height: 45.h,
                        width: 45.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFCF4B73), Color(0xFFC76294)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).colorScheme.onBackground.withOpacity(0.3),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.analytics,
                          color: Colors.white,
                          size: 22.spMax,
                        ),
                      )
                    : const SizedBox.shrink(), // hidden when false
              ),
            ],
          ),
        );
      },
    );
  }

  // Check if an image is selected
  bool isImageSelected(int imageNumber, int postIndex) {
    List<int> selectionOrder = postSelectionOrder[postIndex] ?? [];
    return selectionOrder.contains(imageNumber);
  }

  // Check if all images are selected for a post
  bool areAllImagesSelected(int postIndex) {
    List<int> randomImageIndices = postDisplayIndices[postIndex] ?? [];
    List<int> selectionOrder = postSelectionOrder[postIndex] ?? [];
    return randomImageIndices.isNotEmpty &&
        selectionOrder.length == randomImageIndices.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const PrimaryBackButton(),
        centerTitle: true,
        title: Text(
          AppLocalizations.of(context)!.posts,
          style: CustomTextStyles.appBarTitleText(context),
        ),
        backgroundColor: Theme.of(context).colorScheme.background,
        surfaceTintColor: Theme.of(context).colorScheme.background,
      ),
      body: cachedPosts == null
          ? FutureBuilder<List<PublicPost>>(
              future: apiService.fetchPostsWithImages(widget.userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: ListView(
                      children: [
                        SizedBox(height: 10.h),
                        Container(
                          height: 300.h,
                          width: double.infinity,
                          margin: EdgeInsets.only(
                            bottom: 10.h,
                            right: 10.w,
                            left: 10.w,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                        Container(
                          height: 300.h,
                          width: double.infinity,
                          margin: EdgeInsets.only(
                            bottom: 10.h,
                            right: 10.w,
                            left: 10.w,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer,
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
                          'Error loading posts',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final postsWithImages = snapshot.data ?? [];
                if (postsWithImages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 10.h),
                        Icon(
                          Icons.photo_library_outlined,
                          size: 45.spMax,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 10.h),
                        Text(
                          'No posts with image',
                          style: TextStyle(
                            fontSize: 11.5.sp,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 10.h),
                      ],
                    ),
                  );
                }

                // Cache the posts data
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() {
                    cachedPosts = postsWithImages;
                  });
                });

                return _buildPostsList(postsWithImages);
              },
            )
          : _buildPostsList(cachedPosts!),
    );
  }

  Widget _buildImagesSection(PublicPost post, int postIndex) {
    List<int> randomImageIndices = postDisplayIndices[postIndex] ?? [];

    if (randomImageIndices.isEmpty) return const SizedBox.shrink();

    if (randomImageIndices.length == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description (only if not empty)
          if (post.description.isNotEmpty && post.description != 'fkglfd')
            Container(
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 4.h),
              margin: EdgeInsets.only(bottom: 7.h),
              child: Row(
                children: [
                  Text(
                    '${postIndex + 1}. ',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    post.description,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          _buildImageWithNumber(
            '${ApiConfig.baseUrlImage}${post.images[randomImageIndices[0]].url}',
            1,
            postIndex,
            200.h,
          ),
        ],
      );
    } else if (randomImageIndices.length == 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description (only if not empty)
          if (post.description.isNotEmpty && post.description != 'fkglfd')
            Container(
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 4.h),
              margin: EdgeInsets.only(bottom: 7.h),
              child: Row(
                children: [
                  Text(
                    '${postIndex + 1}. ',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    post.description,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _buildImageWithNumber(
                  '${ApiConfig.baseUrlImage}${post.images[randomImageIndices[0]].url}',
                  1,
                  postIndex,
                  150.h,
                ),
              ),
              SizedBox(width: 7.w),
              Expanded(
                child: _buildImageWithNumber(
                  '${ApiConfig.baseUrlImage}${post.images[randomImageIndices[1]].url}',
                  2,
                  postIndex,
                  150.h,
                ),
              ),
            ],
          ),
        ],
      );
    } else if (randomImageIndices.length >= 3) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description (only if not empty)
          if (post.description.isNotEmpty && post.description != 'fkglfd')
            Container(
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 4.h),
              margin: EdgeInsets.only(bottom: 7.h),
              child: Row(
                children: [
                  Text(
                    '${postIndex + 1}. ',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    post.description,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _buildImageWithNumber(
                  '${ApiConfig.baseUrlImage}${post.images[randomImageIndices[0]].url}',
                  1,
                  postIndex,
                  150.h,
                ),
              ),
              SizedBox(width: 5.w),
              Expanded(
                child: _buildImageWithNumber(
                  '${ApiConfig.baseUrlImage}${post.images[randomImageIndices[1]].url}',
                  2,
                  postIndex,
                  150.h,
                ),
              ),
              SizedBox(width: 5.w),
              Expanded(
                child: _buildImageWithNumber(
                  '${ApiConfig.baseUrlImage}${post.images[randomImageIndices[2]].url}',
                  3,
                  postIndex,
                  150.h,
                ),
              ),
            ],
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  List<int> _getRandomImageIndices(int imageCount) {
    if (imageCount == 0) return [];

    List<int> allIndices = List.generate(imageCount, (index) => index);

    // Shuffle and take up to 3 images
    allIndices.shuffle(Random());
    int takeCount = math.min(3, imageCount);

    return allIndices.take(takeCount).toList();
  }

  Widget _buildImageWithNumber(
    String imageUrl,
    int number,
    int postIndex,
    double height, {
    BoxFit fit = BoxFit.cover,
  }) {
    bool isSelected = isImageSelected(number, postIndex);
    int selectionNumber = getSelectionNumber(number, postIndex);

    return GestureDetector(
      onTap: () {
        setState(() {
          List<int> selectionOrder = postSelectionOrder[postIndex] ?? [];
          if (isImageSelected(number, postIndex)) {
            // Remove from selection order
            selectionOrder.remove(number);
          } else {
            // Add to selection order
            selectionOrder.add(number);
          }
          postSelectionOrder[postIndex] = selectionOrder;
        });
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              // Image with overlay when selected
              Stack(
                children: [
                  Image.network(
                    imageUrl,
                    height: height,
                    width: double.infinity,
                    fit: fit,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: height,
                        color: Colors.grey[200],
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: height,
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.image,
                          size: 50,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                  // Semi-transparent overlay when selected
                  if (isSelected)
                    Container(
                      height: height,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.onBackground.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                ],
              ),
              // Number overlay - show selection number when selected
              if (isSelected)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: 1.0,
                    child: Container(
                      width: 30.w,
                      height: 30.h,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$selectionNumber',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
