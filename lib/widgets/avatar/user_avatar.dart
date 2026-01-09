// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../base64/image_convert.dart';

// Define a User model interface/type
abstract class BaseUser {
  String get username;
  String? get profileImage;
  String get firstLetter;
}

// User Avatar Widget
class UserAvatar extends StatelessWidget {
  final dynamic user;
  final double radius;
  final double? fontSize;
  final bool showBorder;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? textColor;
  final BoxFit? imageFit;

  const UserAvatar({
    super.key,
    required this.user,
    this.radius = 15,
    this.fontSize,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth = 2.0,
    this.onTap,
    this.backgroundColor,
    this.textColor,
    this.imageFit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBackgroundColor = backgroundColor ??
        theme.colorScheme.primary.withOpacity(0.15);
    final effectiveTextColor = textColor ?? theme.colorScheme.primary;
    final effectiveBorderColor = borderColor ?? Colors.white;
    final effectiveFontSize = fontSize ?? 16.sp;

    // Get user data based on user model structure
    final String? profileImage = _getProfileImage(user);
    final String username = _getUsername(user);
    final String firstLetter = _getFirstLetter(user);

    Widget avatarContent = CircleAvatar(
      radius: radius.r,
      backgroundColor: effectiveBackgroundColor,
      backgroundImage: profileImage != null && profileImage.isNotEmpty
          ? _getImageProvider(profileImage)
          : null,
      child: profileImage == null || profileImage.isEmpty
          ? Text(
              firstLetter,
              style: TextStyle(
                fontSize: effectiveFontSize,
                fontWeight: FontWeight.w600,
                color: effectiveTextColor,
              ),
            )
          : null,
    );

    // Add border if needed
    if (showBorder) {
      avatarContent = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: effectiveBorderColor,
            width: borderWidth,
          ),
        ),
        child: avatarContent,
      );
    }

    // Add tap gesture if needed
    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatarContent,
      );
    }

    return avatarContent;
  }

  // Helper methods to extract data from user object
  String? _getProfileImage(dynamic user) {
    if (user is BaseUser) {
      return user.profileImage;
    } else if (user is Map) {
      return user['profileImage'] ?? user['profile_image'];
    } else if (user is Map<String, dynamic>) {
      return user['profileImage'] ?? user['profile_image'];
    }
    // Try to access via reflection or common patterns
    try {
      return user.profileImage as String?;
    } catch (e) {
      return null;
    }
  }

  String _getUsername(dynamic user) {
    if (user is BaseUser) {
      return user.username;
    } else if (user is Map) {
      return user['username'] ?? '';
    } else if (user is Map<String, dynamic>) {
      return user['username'] ?? '';
    }
    try {
      return user.username as String? ?? '';
    } catch (e) {
      return '';
    }
  }

  String _getFirstLetter(dynamic user) {
    final username = _getUsername(user);
    return username.isNotEmpty ? username[0].toUpperCase() : 'U';
  }

  ImageProvider? _getImageProvider(String profileImage) {
    // Handle both base64 and URL images
    if (profileImage.startsWith('data:image') || 
        profileImage.startsWith('/9j/') || 
        profileImage.length > 1000) {
      // Likely base64 image
      try {
        final imageData = getProfileImage(profileImage);
        return imageData != null ? MemoryImage(imageData) : null;
      } catch (e) {
        return null;
      }
    } else {
      // Likely URL - you may need to prepend base URL
      // return NetworkImage('${ApiConfig.baseUrlImage}$profileImage');
      return NetworkImage(profileImage);
    }
  }
}

// Stacked Avatars Widget (for showing multiple users)
class StackedUserAvatars extends StatelessWidget {
  final List<dynamic> users;
  final double avatarRadius;
  final double overlap;
  final int maxAvatars;
  final VoidCallback? onTap;
  final String? overflowText;

  const StackedUserAvatars({
    super.key,
    required this.users,
    this.avatarRadius = 12,
    this.overlap = 8.0,
    this.maxAvatars = 3,
    this.onTap,
    this.overflowText,
  });

  @override
  Widget build(BuildContext context) {
    final displayUsers = users.take(maxAvatars).toList();
    final overflowCount = users.length - displayUsers.length;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: (avatarRadius * 2).r,
        width: (displayUsers.length * (avatarRadius * 2 - overlap) + 
                (overflowCount > 0 ? avatarRadius : 0)).w,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Display avatars
            for (int i = 0; i < displayUsers.length; i++)
              Positioned(
                left: i * (avatarRadius * 2 - overlap).w,
                child: UserAvatar(
                  user: displayUsers[i],
                  radius: avatarRadius,
                  showBorder: true,
                  borderColor: Colors.white,
                ),
              ),
            
            // Overflow indicator if there are more users
            if (overflowCount > 0)
              Positioned(
                left: (displayUsers.length * (avatarRadius * 2 - overlap)).w,
                child: Container(
                  width: (avatarRadius * 2).r,
                  height: (avatarRadius * 2).r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      overflowText ?? '+$overflowCount',
                      style: TextStyle(
                        fontSize: (avatarRadius * 0.7).sp,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// User Avatar with Badge (for online status, verification, etc.)
class UserAvatarWithBadge extends StatelessWidget {
  final dynamic user;
  final double radius;
  final Widget? badge;
  final BadgePosition badgePosition;
  final double badgeSize;
  final bool showOnlineIndicator;
  final bool isOnline;

  const UserAvatarWithBadge({
    super.key,
    required this.user,
    this.radius = 15,
    this.badge,
    this.badgePosition = BadgePosition.bottomRight,
    this.badgeSize = 10,
    this.showOnlineIndicator = false,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        UserAvatar(
          user: user,
          radius: radius,
        ),
        
        // Online indicator
        if (showOnlineIndicator && isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: badgeSize.r,
              height: badgeSize.r,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
            ),
          ),
        
        // Custom badge
        if (badge != null)
          Positioned(
            right: badgePosition == BadgePosition.bottomRight ? 0 : null,
            left: badgePosition == BadgePosition.bottomLeft ? 0 : null,
            top: badgePosition == BadgePosition.topRight || 
                 badgePosition == BadgePosition.topLeft ? 0 : null,
            bottom: badgePosition == BadgePosition.bottomRight || 
                    badgePosition == BadgePosition.bottomLeft ? 0 : null,
            child: badge!,
          ),
      ],
    );
  }
}

enum BadgePosition {
  topRight,
  topLeft,
  bottomRight,
  bottomLeft,
}

// Compact User Info (Avatar + Username)
class UserInfoCompact extends StatelessWidget {
  final dynamic user;
  final double avatarRadius;
  final TextStyle? usernameStyle;
  final double spacing;
  final VoidCallback? onTap;
  final bool showUsername;
  final MainAxisAlignment alignment;

  const UserInfoCompact({
    super.key,
    required this.user,
    this.avatarRadius = 15,
    this.usernameStyle,
    this.spacing = 8,
    this.onTap,
    this.showUsername = true,
    this.alignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final defaultStyle = TextStyle(
      fontSize: 12.sp,
      fontWeight: FontWeight.w600,
    );

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: alignment,
        mainAxisSize: MainAxisSize.min,
        children: [
          UserAvatar(
            user: user,
            radius: avatarRadius,
          ),
          if (showUsername) SizedBox(width: spacing.w),
          if (showUsername)
            Text(
              _getUsername(user),
              style: usernameStyle ?? defaultStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  String _getUsername(dynamic user) {
    // Similar helper method as in UserAvatar
    if (user is BaseUser) return user.username;
    if (user is Map) return user['username'] ?? '';
    try {
      return user.username as String? ?? '';
    } catch (e) {
      return '';
    }
  }
}