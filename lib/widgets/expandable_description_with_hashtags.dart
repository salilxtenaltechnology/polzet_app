import 'package:flutter/material.dart';
import '../core/themes/app_text_colors.dart';
import '../core/themes/app_text_styles.dart';

class ExpandableDescriptionWithHashtags extends StatefulWidget {
  final String description;
  final AppTextColors txt;

  const ExpandableDescriptionWithHashtags({
    super.key,
    required this.description,
    required this.txt,
  });

  @override
  State<ExpandableDescriptionWithHashtags> createState() =>
      _ExpandableDescriptionWithHashtagsState();
}

class _ExpandableDescriptionWithHashtagsState
    extends State<ExpandableDescriptionWithHashtags> {
  bool _isExpanded = false;

  @override
  void didUpdateWidget(covariant ExpandableDescriptionWithHashtags oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.description != widget.description) {
      _isExpanded = false;
    }
  }

  InlineSpan _buildTextSpan(BuildContext context) {
    if (!widget.description.contains('#')) {
      return TextSpan(
        text: widget.description,
        style: AppTextStyles.bodyText.copyWith(
          color: widget.txt.body,
          fontSize: 14.2,
          fontWeight: FontWeight.w400,
        ),
      );
    }

    final RegExp exp = RegExp(r'(#[a-zA-Z0-9_]+)');
    final List<TextSpan> spans = [];

    widget.description.splitMapJoin(
      exp,
      onMatch: (Match match) {
        spans.add(
          TextSpan(
            text: match.group(0),
            style: AppTextStyles.bodyText.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
        return '';
      },
      onNonMatch: (String text) {
        if (text.isNotEmpty) {
          spans.add(
            TextSpan(
              text: text,
              style: AppTextStyles.bodyText.copyWith(
                color: widget.txt.body,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          );
        }
        return '';
      },
    );

    return TextSpan(children: spans);
  }

  @override
  Widget build(BuildContext context) {
    final textSpan = _buildTextSpan(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: textSpan,
          maxLines: 2,
          textDirection: Directionality.of(context),
        );
        textPainter.layout(maxWidth: constraints.maxWidth);

        final bool exceedsMaxLines = textPainter.didExceedMaxLines;

        if (!exceedsMaxLines) {
          return RichText(text: textSpan);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: RichText(
                text: textSpan,
                maxLines: _isExpanded ? null : 2,
                overflow: _isExpanded
                    ? TextOverflow.clip
                    : TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  _isExpanded ? 'Read less' : 'Read more',
                  style: AppTextStyles.bodyText.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 12.7,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
