// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../widgets/base64/image_convert.dart';

class LikeUtils {
  static String getLikedByText(List<dynamic> viewLikes) {
    if (viewLikes.isEmpty) return '';

    if (viewLikes.length == 1) {
      return 'Liked by ${viewLikes[0].username}';
    } else if (viewLikes.length == 2) {
      return 'Liked by ${viewLikes[0].username} and ${viewLikes[1].username}';
    } else {
      final othersCount = viewLikes.length - 1;
      return 'Liked by ${viewLikes[0].username} and $othersCount ${othersCount == 1 ? 'other' : 'others'}';
    }
  }

  static TextSpan buildLikedByRichText(
    BuildContext context,
    List<dynamic> likeUsers,
  ) {
    if (likeUsers.isEmpty) {
      return const TextSpan(text: '');
    }

    final baseStyle = TextStyle(
      fontSize: 10.sp,
      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
      fontWeight: FontWeight.w400,
    );

    final boldStyle = TextStyle(
      fontSize: 10.sp,
      color: Theme.of(context).colorScheme.onBackground,
      fontWeight: FontWeight.w600,
    );

    if (likeUsers.length == 1) {
      return TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(text: 'Liked by '),
          TextSpan(text: likeUsers[0].username, style: boldStyle),
        ],
      );
    } else if (likeUsers.length == 2) {
      return TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(text: 'Liked by '),
          TextSpan(text: likeUsers[0].username, style: boldStyle),
          const TextSpan(text: ' and '),
          TextSpan(text: likeUsers[1].username, style: boldStyle),
        ],
      );
    } else {
      final othersCount = likeUsers.length - 1;
      return TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(text: 'Liked by '),
          TextSpan(text: likeUsers[0].username, style: boldStyle),
          const TextSpan(text: ' and '),
          TextSpan(
            text: '$othersCount ${othersCount == 1 ? 'other' : 'others'}',
            style: boldStyle,
          ),
        ],
      );
    }
  }

  static Widget buildLikeAvatarsStack(
    BuildContext context,
    List<dynamic> viewLikes, {
    int maxDisplay = 2,
    double avatarSize = 16,
  }) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return SizedBox(
      height: avatarSize.h,
      width: (viewLikes.take(maxDisplay).length * (avatarSize * 0.65) + 7).w,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          for (int i = 0; i < viewLikes.take(maxDisplay).length; i++)
            Positioned(
              left: i * (avatarSize * 0.55).w,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDarkMode 
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Colors.white,
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: (avatarSize / 2).r,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.2),
                  backgroundImage:
                      viewLikes[i].profileImage != null &&
                          viewLikes[i].profileImage!.isNotEmpty
                      ? MemoryImage(getProfileImage(viewLikes[i].profileImage)!)
                      : null,
                  child:
                      viewLikes[i].profileImage == null ||
                          viewLikes[i].profileImage!.isEmpty
                      ? Text(
                          viewLikes[i].firstLetter,
                          style: TextStyle(
                            fontSize: (avatarSize * 0.6).sp,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}