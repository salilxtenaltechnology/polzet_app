// hashtag_image_post_popup.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/languages/l10n/generated/app_localizations.dart';

import '../../../../../api/api_config.dart';
import '../../../../../api/services/api_service.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../models/search/hashtag/hashtag_posts_list_model.dart';
import '../../../../../models/voters/top_voters_model.dart';
import '../../../../../widgets/show_toast.dart';
import '../../../../../core/utils/bottomsheet_util.dart';
import '../../../../../widgets/voter_list/voters_list.dart';

class HashtagImagePostPopup extends StatefulWidget {
  final List<HashtagPollOption> images;
  final Function(int) onImageTap;
  final int postId;
  final int pollId;
  final bool isPolledByCurrentUser;

  const HashtagImagePostPopup({
    super.key,
    required this.images,
    required this.onImageTap,
    required this.postId,
    required this.pollId,
    required this.isPolledByCurrentUser,
  });

  @override
  State<HashtagImagePostPopup> createState() => _HashtagImagePostPopupState();
}

class _HashtagImagePostPopupState extends State<HashtagImagePostPopup> {
  Map<int, int> selectedImages = {};
  int selectionCounter = 0;
  bool isSubmitting = false;

  final Map<int, List<TopVoterUser>> _topVotersMap = {};
  bool _votersLoading = true;

  @override
  void initState() {
    super.initState();
    debugPrint('isPolledByCurrentUser: ${widget.isPolledByCurrentUser}');
    _fetchAllTopVoters();
  }

  Future<void> _fetchAllTopVoters() async {
    try {
      final futures = widget.images.map((option) async {
        try {
          final result = await ApiService.getTopVoters(
            pollId: widget.pollId,
            optionId: option.id,
          );
          return MapEntry(option.id, result.users);
        } catch (_) {
          return MapEntry(option.id, <TopVoterUser>[]);
        }
      });

      final entries = await Future.wait(futures);

      if (mounted) {
        setState(() {
          for (final entry in entries) {
            _topVotersMap[entry.key] = entry.value;
          }
          _votersLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _votersLoading = false);
    }
  }

  void toggleImageSelection(int index) {
    if (widget.isPolledByCurrentUser) {
      showToast(message: 'You have already voted on this poll');
      return;
    }

    setState(() {
      if (selectedImages.containsKey(index)) {
        final int removedOrder = selectedImages[index]!;
        selectedImages.remove(index);

        final Map<int, int> reorderedMap = {};
        selectedImages.forEach((key, value) {
          reorderedMap[key] = value > removedOrder ? value - 1 : value;
        });
        selectedImages = reorderedMap;
        selectionCounter--;
      } else {
        selectionCounter++;
        selectedImages[index] = selectionCounter;
      }
    });
  }

  Future<void> submitPollVotes() async {
    if (selectedImages.isEmpty) return;
    if (widget.isPolledByCurrentUser) {
      showToast(message: 'You have already voted on this poll');
      return;
    }

    setState(() => isSubmitting = true);

    try {
      // Build ranked votes for selected images
      final List<Map<String, int>> votes = [];
      selectedImages.forEach((imageIndex, rank) {
        votes.add({
          'option_id': widget.images[imageIndex].id,
          'rank': rank,
        });
      });

      // Append unselected images with trailing ranks
      int nextRank = selectionCounter + 1;
      for (int i = 0; i < widget.images.length; i++) {
        if (!selectedImages.containsKey(i)) {
          votes.add({
            'option_id': widget.images[i].id,
            'rank': nextRank,
          });
          nextRank++;
        }
      }

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
        if (mounted) showToast(message: 'Failed to submit votes');
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
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  void _showPostVotersBottomSheet({
    required int pollId,
    required int optionId,
  }) {
    BottomSheetUtils.showPostVotersBottomSheet(
      context: context,
      pollId: pollId,
      optionId: optionId,
    );
  }


  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildImageList()),
            _buildPollButton(),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.background,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
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
                AppLocalizations.of(context)!.allimages,
                style: TextStyle(
                  color: AppColors.primaryColor,
                  fontSize: 11.2.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (selectedImages.isNotEmpty) ...[
                SizedBox(width: 10.w),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8.w,
                    vertical: 2.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${selectedImages.length}/${widget.images.length} selected',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.2.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              if (widget.isPolledByCurrentUser) ...[
                SizedBox(width: 10.w),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8.w,
                    vertical: 1.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5EBC5A).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.polled,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.3.sp,
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
              child: const Icon(Icons.close, color: Colors.white, size: 17),
            ),
          ),
        ],
      ),
    );
  }

  // ── Image list ─────────────────────────────────────────────────────────────
  Widget _buildImageList() {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: widget.images.length,
      itemBuilder: (context, index) {
        final HashtagPollOption option = widget.images[index];
        if (option.image == null) return const SizedBox.shrink();

        final bool isSelected = selectedImages.containsKey(index);
        final int? selectionNumber = selectedImages[index];
        final int percentage = option.percentage.round();
        final List<TopVoterUser> topVoters = _topVotersMap[option.id] ?? [];
        final String imageUrl =
            '${ApiConfig.baseUrlImage}${option.image!.url}';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IgnorePointer(
              ignoring: widget.isPolledByCurrentUser,
              child: GestureDetector(
                onTap: () => toggleImageSelection(index),
                onLongPress: () => widget.onImageTap(index),
                child: Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: 1.h),
                  child: Stack(
                    children: [
                      // Image
                      Hero(
                        tag: 'hashtag_image_${option.id}',
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
                            imageUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                height: 250.h,
                                color: Colors.grey[900],
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: progress.expectedTotalBytes != null
                                        ? progress.cumulativeBytesLoaded /
                                              progress.expectedTotalBytes!
                                        : null,
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => Container(
                              height: 250.h,
                              color: Colors.grey[900],
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  size: 50,
                                  color: Colors.white54,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Circular percentage (after voting)
                      if (widget.isPolledByCurrentUser)
                        Positioned(
                          bottom: 15.h,
                          left: 17.w,
                          child: _buildPercentageRing(percentage),
                        ),

                      // Selection badge (before voting)
                      if (isSelected && !widget.isPolledByCurrentUser)
                        Positioned(
                          top: 15.h,
                          right: 17.w,
                          child: _buildSelectionBadge(selectionNumber!),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Voters row
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showPostVotersBottomSheet(
                pollId: widget.pollId,
                optionId: option.id,
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 10.w,
                  right: 10.w,
                  bottom: 8.h,
                ),
                child: _buildVotersRow(topVoters),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Percentage ring ────────────────────────────────────────────────────────
  Widget _buildPercentageRing(int percentage) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
      tween: Tween<double>(begin: 0, end: percentage / 100),
      builder: (_, value, __) => SizedBox(
        width: 58,
        height: 58,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                value: 1.0,
                strokeWidth: 5,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withOpacity(0.3),
                ),
              ),
            ),
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 5,
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primaryColor,
                ),
              ),
            ),
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: TweenAnimationBuilder<int>(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOut,
                  tween: IntTween(begin: 0, end: percentage),
                  builder: (_, val, __) => Text(
                    '$val%',
                    style: TextStyle(
                      color: AppColors.primaryColor,
                      fontSize: 12.2.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Selection badge ────────────────────────────────────────────────────────
  Widget _buildSelectionBadge(int number) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.primaryColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1),
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
          '$number',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12.2.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ── Voters row ─────────────────────────────────────────────────────────────
  Widget _buildVotersRow(List<TopVoterUser> topVoters) {
    if (_votersLoading) {
      return Row(
        children: List.generate(
          3,
          (i) => Container(
            width: 22.w,
            height: 22.h,
            margin: EdgeInsets.only(right: 4.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7.r),
              color: Colors.grey[200],
            ),
          ),
        ),
      );
    }

    if (topVoters.isNotEmpty) {
      return VotersListWidget(userList: topVoters, maxVisibleUsers: 3);
    }

    return Row(
      children: [
        Container(
          width: 22.w,
          height: 22.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7.r),
            color: const Color.fromARGB(255, 244, 230, 233),
            border: Border.all(color: Colors.white, width: 1),
          ),
          child: Center(
            child: Icon(Icons.add, color: AppColors.primaryColor, size: 10.sp),
          ),
        ),
        SizedBox(width: 5.w),
        Text(
          AppLocalizations.of(context)!.pickedthisastopchoice,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 9.sp,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // ── Poll button ────────────────────────────────────────────────────────────
  Widget _buildPollButton() {
    if (selectedImages.length != widget.images.length ||
        widget.isPolledByCurrentUser) {
      return const SizedBox.shrink();
    }

    return Container(
      width: 120.w,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.background,
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
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
            disabledBackgroundColor: AppColors.primaryColor.withOpacity(0.5),
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
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}