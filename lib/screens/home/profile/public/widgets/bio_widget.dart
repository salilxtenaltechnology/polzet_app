import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class BioWidget extends StatelessWidget {
  final double maxWidth;
  final String userBio;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  const BioWidget({
    super.key,
    required this.maxWidth,
    required this.userBio,
    required this.isExpanded,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    if (userBio.isEmpty) return const SizedBox.shrink();

    final textStyle = TextStyle(color: Colors.white, fontSize: 11.3.sp);

    final textSpan = TextSpan(text: userBio, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );

    textPainter.layout(maxWidth: maxWidth);

    final isTextOverflowing = textPainter.didExceedMaxLines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  userBio,
                  style: textStyle,
                  maxLines: isExpanded ? null : 1,
                  overflow: isExpanded ? null : TextOverflow.ellipsis,
                ),
              ),
            ),
            if (isTextOverflowing) ...[
              SizedBox(width: 8.w),
              GestureDetector(
                onTap: onToggleExpand,
                child: Text(
                  isExpanded ? 'Less' : 'More',
                  style: TextStyle(
                    color: Colors.blue.shade300,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
