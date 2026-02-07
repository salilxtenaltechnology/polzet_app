// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/models/public/public_profile_model.dart';

import '../../../../api/api_config.dart';
import '../../../../api/services/api_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../widgets/show_toast.dart';

class PublicImagesPopup extends StatefulWidget {
  final List<PublicPollOption> images;
  final Function(int) onImageTap;
  final int postId;
  final bool isPolledByCurrentUser;

  const PublicImagesPopup({
    super.key,
    required this.images,
    required this.onImageTap,
    required this.postId,
    required this.isPolledByCurrentUser,
  });

  @override
  State<PublicImagesPopup> createState() => _AllImagesPopupState();
}

class _AllImagesPopupState extends State<PublicImagesPopup> {
  // Map to store selected images with their selection order
  Map<int, int> selectedImages = {};
  int selectionCounter = 0;
  bool isSubmitting = false;

  void toggleImageSelection(int index) {
    // Disable selection if user has already polled
    if (widget.isPolledByCurrentUser) {
      showToast(message: 'You have already voted on this poll');
      return;
    }

    setState(() {
      if (selectedImages.containsKey(index)) {
        // Unselect: Remove from map and reorder remaining selections
        int removedOrder = selectedImages[index]!;
        selectedImages.remove(index);

        // Reorder remaining selections
        Map<int, int> reorderedMap = {};
        selectedImages.forEach((key, value) {
          if (value > removedOrder) {
            reorderedMap[key] = value - 1;
          } else {
            reorderedMap[key] = value;
          }
        });
        selectedImages = reorderedMap;
        selectionCounter--;
      } else {
        // Select: Add with next order number
        selectionCounter++;
        selectedImages[index] = selectionCounter;
      }
    });
  }

  Future<void> submitPollVotes() async {
    if (selectedImages.isEmpty) return;

    // Additional check before submission
    if (widget.isPolledByCurrentUser) {
      showToast(message: 'You have already voted on this poll');
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      // Prepare votes array with ALL images (selected + unselected)
      List<Map<String, int>> votes = [];

      // First, add all selected images with their user-assigned ranks
      selectedImages.forEach((imageIndex, rank) {
        final image = widget.images[imageIndex];

        // Extract option_id from HomeFeedPollOption
        int optionId;
        if (image is Map) {
          // If it's a Map (from JSON)
          optionId = image.id;
        } else {
          // If it's a HomeFeedPollOption object
          optionId = (image as dynamic).id as int;
        }

        votes.add({"option_id": optionId, "rank": rank});
      });

      // Then, add all unselected images with automatic ranks
      int nextRank = selectionCounter + 1;
      for (int i = 0; i < widget.images.length; i++) {
        if (!selectedImages.containsKey(i)) {
          final image = widget.images[i];

          int optionId;
          if (image is Map) {
            optionId = image.id;
          } else {
            optionId = (image as dynamic).id as int;
          }

          votes.add({'option_id': optionId, 'rank': nextRank});
          nextRank++;
        }
      }

      // Debug print to verify the data structure
      // print('Submitting votes: $votes');
      // print('Post ID: ${widget.postId}');

      // Make single API call with all votes
      final result = await ApiService.voteOnPollMultiple(
        postId: widget.postId,
        votes: votes,
      );

      if (result['success'] == true) {
        if (mounted) {
          showToast(message: 'Poll votes submitted successfully!');
          Navigator.of(context).pop(true);
        }
      } else {
        if (mounted) {
          showToast(message: 'Failed to submit votes');
        }
      }
    } catch (e) {
      debugPrint('Error submitting poll votes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'All Images',
                        style: TextStyle(
                          color: AppColors.primaryColor,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (selectedImages.isNotEmpty) ...[
                        SizedBox(width: 10.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${selectedImages.length}/${widget.images.length} selected',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      // Show "Already Voted" indicator
                      if (widget.isPolledByCurrentUser) ...[
                        SizedBox(width: 10.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Polled',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Vertical scrollable list of images
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: widget.images.length,
                itemBuilder: (context, index) {
                  final image = widget.images[index];
                  final isSelected = selectedImages.containsKey(index);
                  final selectionNumber = selectedImages[index];
                  final percentage = image.percentage.round();

                  return IgnorePointer(
                    ignoring: widget.isPolledByCurrentUser,
                    child: GestureDetector(
                      onTap: () => toggleImageSelection(index),
                      onLongPress: () => widget.onImageTap(index),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: 1,
                        child: Container(
                          width: double.infinity,
                          margin: EdgeInsets.only(bottom: 1.h),
                          child: Stack(
                            children: [
                              Hero(
                                tag: 'image_${widget.images[index].id}',
                                child: Container(
                                  margin: EdgeInsets.all(10.w),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: widget.isPolledByCurrentUser
                                          ? Colors.grey.withOpacity(0.4)
                                          : AppColors.primaryColor,
                                      width: 1,
                                    ),
                                  ),
                                  child: Image.network(
                                    '${ApiConfig.baseUrlImage}${image.image!.url}',
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) {
                                        return child;
                                      }
                                      return Container(
                                        height: 250.h,
                                        color: Colors.grey[900],
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            value:
                                                loadingProgress
                                                        .expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                : null,
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        height: 250.h,
                                        color: Colors.grey[900],
                                        child: const Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            size: 50,
                                            color: Colors.white54,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),

                              // Circular Percentage display (only when user has already polled)
                              if (widget.isPolledByCurrentUser)
                                Positioned(
                                  bottom: 15.h,
                                  left: 17.w,
                                  child: TweenAnimationBuilder<double>(
                                    duration: const Duration(milliseconds: 800),
                                    curve: Curves.easeOut,
                                    tween: Tween<double>(
                                      begin: 0,
                                      end: percentage / 100,
                                    ),
                                    builder: (context, value, child) {
                                      return SizedBox(
                                        width: 60,
                                        height: 60,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            // Background circle
                                            SizedBox(
                                              width: 60,
                                              height: 60,
                                              child: CircularProgressIndicator(
                                                value: 1.0,
                                                strokeWidth: 5,
                                                backgroundColor:
                                                    Colors.transparent,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(
                                                      Colors.white.withOpacity(
                                                        0.3,
                                                      ),
                                                    ),
                                              ),
                                            ),
                                            // Progress circle
                                            SizedBox(
                                              width: 60,
                                              height: 60,
                                              child: CircularProgressIndicator(
                                                value: value,
                                                strokeWidth: 5,
                                                backgroundColor:
                                                    Colors.transparent,
                                                valueColor:
                                                    const AlwaysStoppedAnimation<
                                                      Color
                                                    >(AppColors.primaryColor),
                                              ),
                                            ),
                                            // Percentage text
                                            Container(
                                              width: 48,
                                              height: 48,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.2),
                                                    blurRadius: 8,
                                                    spreadRadius: 1,
                                                  ),
                                                ],
                                              ),
                                              child: Center(
                                                child: TweenAnimationBuilder<int>(
                                                  duration: const Duration(
                                                    milliseconds: 800,
                                                  ),
                                                  curve: Curves.easeOut,
                                                  tween: IntTween(
                                                    begin: 0,
                                                    end: percentage,
                                                  ),
                                                  builder:
                                                      (
                                                        context,
                                                        intValue,
                                                        child,
                                                      ) {
                                                        return Text(
                                                          '$intValue%',
                                                          style: TextStyle(
                                                            color: AppColors
                                                                .primaryColor,
                                                            fontSize: 14.sp,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        );
                                                      },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),

                              // Selection indicator (only when user hasn't polled)
                              if (isSelected && !widget.isPolledByCurrentUser)
                                Positioned(
                                  top: 15.h,
                                  right: 17.w,
                                  child: Container(
                                    width: 35,
                                    height: 35,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 5,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$selectionNumber',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Poll button (shown when ALL images are selected AND user hasn't polled)
            if (selectedImages.length == widget.images.length &&
                !widget.isPolledByCurrentUser)
              Container(
                width: 150.w,
                padding: EdgeInsets.all(15.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: ElevatedButton(
                    onPressed: isSubmitting ? null : submitPollVotes,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 35.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50.r),
                      ),
                      elevation: 0,
                      disabledBackgroundColor: AppColors.primaryColor
                          .withOpacity(0.5),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 1.1,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.poll, size: 22),
                              SizedBox(width: 10.w),
                              Text(
                                'Poll',
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
