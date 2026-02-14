import 'dart:typed_data';

// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/widgets/base64/image_convert.dart';

import '../../core/constants/app_colors.dart';
import '../../models/voters/top_voters_model.dart';

class VotersListWidget extends StatelessWidget {
  final List<TopVoterUser> userList;
  final int maxVisibleUsers;

  const VotersListWidget({
    super.key,
    required this.userList,
    this.maxVisibleUsers = 3,
  });

  @override
  Widget build(BuildContext context) {
    if (userList.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayUsers = userList.length > maxVisibleUsers
        ? userList.sublist(userList.length - maxVisibleUsers)
        : userList;

    final remainingCount = userList.length - displayUsers.length;

    return Row(
      children: [
        SizedBox(
          height: 22.h,
          width: _calculateWidth(displayUsers.length),
          child: Stack(
            children: [
              ...displayUsers.asMap().entries.map((entry) {
                final index = entry.key;
                final user = entry.value;
                return Positioned(
                  left: index * 10.w,
                  child: _buildUserAvatar(user),
                );
              }),
            ],
          ),
        ),
        SizedBox(width: 5.w),
        Flexible(
          child: Text(
            _buildVotersText(displayUsers, remainingCount),
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 9.sp,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildUserAvatar(TopVoterUser user) {
    Uint8List? bytes;
    try {
      bytes =
          (user.profilePictureUrl != null && user.profilePictureUrl!.isNotEmpty)
          ? getProfileImage(user.profilePictureUrl!)
          : null;
    } catch (e) {
      debugPrint('Failed to decode avatar for ${user.username}: $e');
      bytes = null;
    }

    return Container(
      width: 22.w,
      height: 22.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7.r),
        color: const Color(0xFFF9E3E8),
        border: Border.all(color: Colors.white, width: 1),
        image: bytes != null
            ? DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover)
            : null,
      ),
      child: bytes == null ? _buildInitialAvatar(user) : null,
    );
  }

  Widget _buildInitialAvatar(TopVoterUser user) {
    return Center(
      child: Text(
        user.firstLetter,
        style: TextStyle(
          color: AppColors.primaryColor,
          fontSize: 9.5.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _buildVotersText(List<TopVoterUser> displayUsers, int remainingCount) {
    if (displayUsers.isEmpty) return '';
    return 'picked this as\ntop choice';
  }

  double _calculateWidth(int userCount) {
    if (userCount == 0) return 0;
    return (21.w + (userCount - 1) * 10.w);
  }
}
