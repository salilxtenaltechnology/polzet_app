// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../api/services/api_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';

class ToggleChaseButton extends StatefulWidget {
  final String username;
  final int userId;
  final String followStatus;
  final ApiService apiService;

  const ToggleChaseButton({super.key, 
    required this.username,
    required this.userId,
    required this.followStatus,
    required this.apiService,
  });

  @override
  State<ToggleChaseButton> createState() => _ChaseButtonState();
}

class _ChaseButtonState extends State<ToggleChaseButton> {
  late String _followStatus;

  @override
  void initState() {
    super.initState();
    _followStatus = widget.followStatus;
  }

  @override
  void didUpdateWidget(ToggleChaseButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.followStatus != widget.followStatus) {
      _followStatus = widget.followStatus;
    }
  }

  /// "following" → "Chasing"
  /// "follower"  → "Chase Back"
  /// ""          → "Chase"
  String get _buttonLabel {
    switch (_followStatus) {
      case 'following':
        return 'Chasing';
      case 'follower':
        return 'Chase Back';
      default:
        return 'Chase';
    }
  }

  bool get _isFollowing => _followStatus == 'following';

  Future<void> _toggleFollow() async {
    final wasFollowing = _isFollowing;
    final previousStatus = _followStatus;

    // Optimistic update
    setState(() {
      _followStatus = wasFollowing ? 'follower' : 'following';
    });

    try {
      if (wasFollowing) {
        final response = await widget.apiService.unfriend(widget.userId);
        if (response['status'] != 'success' && mounted) {
          setState(() => _followStatus = previousStatus);
          // showToast(message: 'Failed to unfollow');
        }
      } else {
        final success = await widget.apiService.sendFriendRequest(
          widget.username,
        );
        if (!success && mounted) {
          setState(() => _followStatus = previousStatus);
          // showToast(message: 'Failed to send friend request');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _followStatus = previousStatus);
     // showToast(message: 'Error: ${e.toString()}');
      debugPrint('Error toggling follow: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleFollow,
      child: Container(
        width: 80.w,
        margin: EdgeInsets.fromLTRB(3.w, 4.h, 0, 4.h),
        decoration: BoxDecoration(
          color: _isFollowing
              ? Theme.of(context).colorScheme.primaryContainer
              : AppColors.primaryColor,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(
            color: _isFollowing
                ? const Color(0xFFD9D9D9)
                : AppColors.primaryColor,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            _buttonLabel,
            style: TextStyle(
              color: _isFollowing
                  ? Theme.of(context).colorScheme.onBackground
                  : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
