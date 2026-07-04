import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../core/themes/app_text_styles.dart';

class ExpandableBio extends StatefulWidget {
  final String bio;
  final TextStyle? style;
  final int maxLines;

  const ExpandableBio({
    super.key,
    required this.bio,
    this.style,
    this.maxLines = 2,
  });

  @override
  State<ExpandableBio> createState() => _ExpandableBioState();
}

class _ExpandableBioState extends State<ExpandableBio> {
  bool _isExpanded = false;

  int _findTruncationIndex(
    String text,
    TextStyle style,
    double maxWidth,
    int maxLines,
    String suffix,
    TextStyle suffixStyle,
  ) {
    int low = 0;
    int high = text.length;
    int best = 0;

    while (low <= high) {
      int mid = (low + high) ~/ 2;
      
      final painter = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(text: text.substring(0, mid).trimRight(), style: style),
            TextSpan(text: suffix, style: suffixStyle),
          ],
        ),
        textDirection: TextDirection.ltr,
        maxLines: maxLines,
      )..layout(maxWidth: maxWidth);

      if (painter.didExceedMaxLines) {
        high = mid - 1;
      } else {
        best = mid;
        low = mid + 1;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyle = widget.style ??
        AppTextStyles.bodyText.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 13.7,
        );

    final linkStyle = defaultStyle.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.bold,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Measure first if the bio as a whole exceeds maxLines
        final textPainter = TextPainter(
          text: TextSpan(text: widget.bio, style: defaultStyle),
          textDirection: TextDirection.ltr,
          maxLines: widget.maxLines,
        )..layout(maxWidth: constraints.maxWidth);

        if (!textPainter.didExceedMaxLines) {
          // If the bio is short and fits within maxLines, show it normally.
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              widget.bio,
              style: defaultStyle,
              textAlign: TextAlign.center,
            ),
          );
        }

        // Exceeds maxLines: show more/less toggle
        if (_isExpanded) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: defaultStyle,
                children: [
                  TextSpan(text: widget.bio),
                  TextSpan(
                    text: '  less',
                    style: linkStyle,
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        setState(() {
                          _isExpanded = false;
                        });
                      },
                  ),
                ],
              ),
            ),
          );
        } else {
          const suffix = ' ...more';
          final truncationIndex = _findTruncationIndex(
            widget.bio,
            defaultStyle,
            constraints.maxWidth - 48, // accounting for the horizontal padding
            widget.maxLines,
            suffix,
            linkStyle,
          );

          final truncatedText = widget.bio.substring(0, truncationIndex).trimRight();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: defaultStyle,
                children: [
                  TextSpan(text: truncatedText),
                  TextSpan(
                    text: suffix,
                    style: linkStyle,
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        setState(() {
                          _isExpanded = true;
                        });
                      },
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
}
