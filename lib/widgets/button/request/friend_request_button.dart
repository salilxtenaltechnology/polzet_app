// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../models/notifications/notification_model.dart';

class FriendRequestButtons extends StatefulWidget {
  final NotificationItem notification;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const FriendRequestButtons({super.key, 
    required this.notification,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<FriendRequestButtons> createState() => _FriendRequestButtonsState();
}

class _FriendRequestButtonsState extends State<FriendRequestButtons> {
  bool _isDone = false; 

  @override
  Widget build(BuildContext context) {
    if (_isDone) return const SizedBox.shrink();

    return Row(
      children: [
        // ── Approve ──────────────────────────────────────────────────
        GestureDetector(
          onTap: () {
            setState(() => _isDone = true);
            widget.onApprove();
          },
          child: Container(
            height: 30.h,
            width: 85.w,
            decoration: BoxDecoration(
              color: AppColors.primaryColor,
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            child: Center(
              child: Text(
                'Approve',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        GestureDetector(
          onTap: () {
            setState(() => _isDone = true);
            widget.onReject();
          },
          child: Container(
            height: 30.h,
            width: 85.w,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.button),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
              ),
            ),
            child: Center(
              child: Text(
                'Reject',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onBackground,
                  fontSize: 10.2.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
