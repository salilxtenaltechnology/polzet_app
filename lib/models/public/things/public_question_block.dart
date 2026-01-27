// ignore_for_file: unused_element, deprecated_member_use, unused_local_variable, must_be_immutable
import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/constants/app_images.dart';
import '../../../api/services/api_service.dart';
import 'things_question.dart';

class PublicQuestionsBlock extends StatefulWidget {
  int postIndex;
  final PublicPollsQuestion pollQuestion;

  PublicQuestionsBlock({
    super.key,
    required this.pollQuestion,
    required this.postIndex,
  });

  @override
  State<PublicQuestionsBlock> createState() => _PublicQuestionsBlockState();
}

class _PublicQuestionsBlockState extends State<PublicQuestionsBlock> {
  final ApiService apiService = ApiService();
  bool isLike = false; // Added isLike state variable
  Map<String, int?> selectedOptions = {}; // Track selected poll options

  // Helper method to check if any option is selected for current poll
  bool get isAnyOptionSelected {
    String pollKey = widget.pollQuestion.id.toString();
    return selectedOptions[pollKey] != null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${widget.postIndex + 1}. ',
              style: TextStyle(
                color: Colors.black,
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            Expanded(
              child: Text(
                widget.pollQuestion.question,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 5.h),
        ...widget.pollQuestion.options.map(
          (option) => _buildPollOption(
            widget.pollQuestion,
            widget.pollQuestion.totalVotes,
            context,
            widget.pollQuestion.options.indexOf(option),
          ),
        ),
        SizedBox(height: 3.h),
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
        SizedBox(height: 5.h),
        Text(
          '${widget.pollQuestion.totalVotes.toString()} votes',
          style: TextStyle(
            fontSize: 10.7.sp,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        // Animated button that appears when an option is selected
        Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isAnyOptionSelected ? 1.0 : 0.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: EdgeInsets.only(top: isAnyOptionSelected ? 10.h : 0),
              height: isAnyOptionSelected ? 45.h : 0,
              width: isAnyOptionSelected ? 45.w : 0,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFCF4B73), Color(0xFFC76294)],
                ),
                boxShadow: isAnyOptionSelected
                    ? [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.onBackground.withOpacity(0.3),
                          blurRadius: 5,
                        ),
                      ]
                    : [],
              ),
              child: GestureDetector(
                onTap: isAnyOptionSelected
                    ? () {
                        // Handle analytics button tap
                        // Add your analytics logic here
                        debugPrint(
                          'Analytics button tapped for poll: ${widget.pollQuestion.id}',
                        );
                        String pollKey = widget.pollQuestion.id.toString();
                        int? selectedIndex = selectedOptions[pollKey];
                        if (selectedIndex != null) {
                          debugPrint(
                            'Selected option: ${widget.pollQuestion.options[selectedIndex].text}',
                          );
                        }
                      }
                    : null,
                child: Icon(
                  Icons.analytics,
                  color: Colors.white,
                  size: isAnyOptionSelected ? 22.spMax : 0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPollOption(
    final PublicPollsQuestion pollQuestion,
    int totalVotes,
    BuildContext context,
    int optionIndex,
  ) {
    final percentage = totalVotes > 0
        ? ((pollQuestion.options[optionIndex].voteCount) / totalVotes * 100)
        : 0.0;

    // Define different gradient colors for dynamic options
    List<Color> getGradientColors(int index) {
      final colors = [
        [const Color(0xFFFC3E7E), const Color(0xFFEEA0F0)], // Option 1
        [const Color(0xFF4FC3F7), const Color(0xFFB6E2F8)], // Option 2
        [Colors.red, const Color(0xFFEFB0C3)], // Option 3
        [Colors.green, Colors.teal], // Option 4
      ];
      return colors[index % colors.length];
    }

    final gradientColors = getGradientColors(optionIndex);

    int percentageFull = 100;
    int totalVoteCount =
        ((pollQuestion.options[optionIndex].voteCount * 100) / percentageFull)
            .round();

    // Check if this option is selected using poll ID and option index
    String pollKey = widget.pollQuestion.id.toString(); // Use poll ID
    bool isSelected = selectedOptions[pollKey] == optionIndex;

    return GestureDetector(
      onTap: () {
        // Handle option selection
        setState(() {
          if (selectedOptions[pollKey] == optionIndex) {
            // If already selected, unselect it
            selectedOptions[pollKey] = null;
          } else {
            // If not selected, select it
            selectedOptions[pollKey] = optionIndex;
          }
        });
        // Add your vote logic here
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: 0.h),
        child: Container(
          padding: EdgeInsets.all(5.w),
          decoration: BoxDecoration(
            border: isSelected
                ? Border.all(color: Theme.of(context).primaryColor, width: 1.5)
                : Border.all(color: Colors.transparent, width: 1.5),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pollQuestion.options[optionIndex].text,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onBackground,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 5.h),
              Container(
                height: 5.h,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200], // Grey background for unfilled area
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4.r),
                  child: Stack(
                    children: [
                      // Only show filled area if total_vote_count > 0
                      if (totalVoteCount > 0)
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: totalVoteCount / 100,
                          child: Container(
                            height: 8.h,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: gradientColors,
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 2.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${totalVoteCount.toInt()}%',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
