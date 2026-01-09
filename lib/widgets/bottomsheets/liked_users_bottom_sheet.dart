// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../models/home feed/home_feed_items_model.dart';
import '../../widgets/base64/image_convert.dart';

class LikedUsersBottomSheet extends StatefulWidget {
  final List<LikeUser> likedUsers;
  final int postId;

  const LikedUsersBottomSheet({
    Key? key,
    required this.likedUsers,
    required this.postId,
  }) : super(key: key);

  @override
  State<LikedUsersBottomSheet> createState() => _LikedUsersBottomSheetState();
}

class _LikedUsersBottomSheetState extends State<LikedUsersBottomSheet> {
  late List<LikeUser> _likedUsers;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _likedUsers = widget.likedUsers;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(vertical: 10.h),
            margin: EdgeInsets.symmetric(horizontal: 10.w),
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Center(
              child: Text(
                'Likes',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          // List of users who liked
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _likedUsers.isEmpty
                ? Center(
                    child: Text(
                      'No likes yet',
                      style: TextStyle(fontSize: 14.sp, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    itemCount: _likedUsers.length,
                    itemBuilder: (context, index) {
                      final user = _likedUsers[index];
                      return ListTile(
                        onTap: () {
                          Navigator.pop(context);
                          // Navigate to user profile
                          // context.pushNamed('user_profile', extra: user.id);
                        },
                        leading: CircleAvatar(
                          radius: 15.r,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.15),
                          backgroundImage:
                              user.profileImage != null &&
                                  user.profileImage!.isNotEmpty
                              ? MemoryImage(getProfileImage(user.profileImage)!)
                              : null,
                          child:
                              user.profileImage == null ||
                                  user.profileImage!.isEmpty
                              ? Text(
                                  user.firstLetter,
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                )
                              : null,
                        ),
                        title: Text(
                          user.username,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
