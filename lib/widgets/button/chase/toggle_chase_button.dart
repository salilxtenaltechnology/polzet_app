// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../../../api/services/validator/api_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/themes/app_text_styles.dart';

class ToggleChaseButton extends StatefulWidget {
  final String username;
  final dynamic userId;
  final String followStatus;
  final ApiService apiService;
  final bool isPrivate;

  const ToggleChaseButton({
    super.key,
    required this.username,
    required this.userId,
    required this.followStatus,
    required this.apiService,
    this.isPrivate = false,
  });

  @override
  State<ToggleChaseButton> createState() => _ChaseButtonState();
}

class _ChaseButtonState extends State<ToggleChaseButton> {
  late String _followStatus;
  late String _originalServerStatus;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _followStatus = widget.followStatus;
    _originalServerStatus = widget.followStatus;
  }

  @override
  void didUpdateWidget(ToggleChaseButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.followStatus != widget.followStatus) {
      _followStatus = widget.followStatus;
      _originalServerStatus = widget.followStatus;
    }
  }

  String get _buttonLabel {
    switch (_followStatus) {
      case 'following':
      case 'both':
        return 'Chasing';
      case 'followers':
      case 'follower':
        return 'Chase Back';
      case 'requested':
      case 'pending':
        return 'Requested';
      default:
        return 'Chase';
    }
  }

  bool get isFollowing =>
      _followStatus == 'following' ||
      _followStatus == 'both' ||
      _followStatus == 'requested' ||
      _followStatus == 'pending';

  Future<void> _toggleFollow() async {
    if (_isProcessing) return;

    final currentStatus = _followStatus;

    setState(() {
      _isProcessing = true;
    });

    try {
      if (currentStatus == 'requested' || currentStatus == 'pending') {
        final revertStatus =
            _originalServerStatus == 'requested' ||
                _originalServerStatus == 'pending'
            ? 'none'
            : _originalServerStatus;

        setState(() {
          _followStatus = revertStatus;
        });

        final success = await widget.apiService.cancelFriendRequest(
          widget.userId,
        );

        if (!success && mounted) {
          setState(() => _followStatus = currentStatus);
        }
      } else if (isFollowing) {
        // Unfriend
        final nextStatus =
            (_originalServerStatus == 'both' ||
                _originalServerStatus == 'followers' ||
                _originalServerStatus == 'follower')
            ? 'followers'
            : 'none';

        setState(() {
          _followStatus = nextStatus;
        });

        final response = await widget.apiService.unfriend(widget.userId);

        if (response['status'] == 'success') {
          _originalServerStatus = nextStatus;
        } else if (mounted) {
          setState(() => _followStatus = currentStatus);
        }
      } else {
        // Send friend request
        final nextStatus = widget.isPrivate
            ? 'requested'
            : ((_originalServerStatus == 'followers' ||
                      _originalServerStatus == 'follower')
                  ? 'both'
                  : 'following');

        setState(() {
          _followStatus = nextStatus;
        });

        final success = await widget.apiService.sendFriendRequest(
          widget.username,
        );

        if (success) {
          if (nextStatus != 'requested') {
            _originalServerStatus = nextStatus;
          }
        }

        if (!success && mounted) {
          setState(() => _followStatus = currentStatus);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _followStatus = currentStatus);
      debugPrint('Error toggling follow: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _toggleFollow,
      child: Container(
        height: 32,
        width: 100,
        margin: const EdgeInsets.only(left: 10),
        decoration: BoxDecoration(
          color: isFollowing
              ? (isDarkMode
                    ? Colors.transparent
                    : Theme.of(context).colorScheme.primaryContainer)
              : AppColors.primaryColor,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: isFollowing
              ? Border.all(
                  color: isDarkMode
                      ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.3)
                      : Theme.of(context).colorScheme.primary.withOpacity(0.8),
                  width: 1,
                )
              : null,
        ),
        child: Center(
          child: Text(
            _buttonLabel,
            style: AppTextStyles.subText.copyWith(
              fontSize: 13,
              color: isFollowing
                  ? (isDarkMode
                        ? Theme.of(
                            context,
                          ).colorScheme.onPrimary.withOpacity(0.7)
                        : Theme.of(context).colorScheme.primary)
                  : Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
