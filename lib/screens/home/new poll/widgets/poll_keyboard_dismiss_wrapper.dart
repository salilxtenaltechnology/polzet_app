import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A reusable wrapper for poll creation screens that ensures:
/// 1. When the soft keyboard transitions from visible to hidden (e.g., via Android system Back button),
///    the currently focused TextField automatically loses focus (removing cursor and selection handles).
/// 2. Tapping outside of any TextField removes focus and dismisses the keyboard.
/// 3. Normal typing, switching between TextFields, and re-focusing work seamlessly without resetting text.
class PollKeyboardDismissWrapper extends StatefulWidget {
  final Widget child;

  const PollKeyboardDismissWrapper({
    super.key,
    required this.child,
  });

  @override
  State<PollKeyboardDismissWrapper> createState() =>
      _PollKeyboardDismissWrapperState();
}

class _PollKeyboardDismissWrapperState
    extends State<PollKeyboardDismissWrapper>
    with WidgetsBindingObserver {
  bool _wasKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _wasKeyboardVisible = _isKeyboardVisible;
      }
    });
  }

  bool get _isKeyboardVisible {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isNotEmpty) {
      return views.first.viewInsets.bottom > 0;
    }
    return false;
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;

    final isVisible = _isKeyboardVisible;
    if (_wasKeyboardVisible && !isVisible) {
      // Soft keyboard was dismissed (such as Android system Back button)
      final primaryFocus = FocusManager.instance.primaryFocus;
      if (primaryFocus != null && primaryFocus.hasFocus) {
        primaryFocus.unfocus();
      }
    }
    _wasKeyboardVisible = isVisible;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        // When tapping outside of any TextField, remove focus.
        // If the tap landed on any TextField/EditableText, do not unfocus
        // so switching between TextFields works seamlessly without hiding the keyboard.
        final primaryFocus = FocusManager.instance.primaryFocus;
        if (primaryFocus != null && primaryFocus.hasFocus) {
          final HitTestResult hitTestResult = HitTestResult();
          WidgetsBinding.instance.hitTestInView(
            hitTestResult,
            event.position,
            event.viewId,
          );

          final bool hitTextField = hitTestResult.path.any((entry) {
            final target = entry.target;
            return target is RenderEditable ||
                (target is RenderTapRegion && target.groupId == EditableText);
          });

          if (!hitTextField) {
            primaryFocus.unfocus();
          }
        }
      },
      child: widget.child,
    );
  }
}

