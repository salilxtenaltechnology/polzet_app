// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/api/services/api_service.dart';

import '../../models/like/like_uers_model.dart';
import '../../widgets/base64/image_convert.dart';

class LikedUsersBottomSheet extends StatefulWidget {
  final int postId;

  const LikedUsersBottomSheet({super.key, required this.postId});

  @override
  State<LikedUsersBottomSheet> createState() => _LikedUsersBottomSheetState();
}

class _LikedUsersBottomSheetState extends State<LikedUsersBottomSheet> {
  late List<LikeUser> _likedUsers;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _likedUsers = [];
    _fetchLikedUsers();
  }

  // Fetch liked users from API
  Future<void> _fetchLikedUsers() async {
    try {
      final users = await ApiService().fetchLikedUsers(widget.postId);

      if (mounted) {
        setState(() {
          _likedUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _likedUsers = [];
          _isLoading = false;
        });
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load likes: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 10.h),
            margin: EdgeInsets.symmetric(horizontal: 10.w),
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                  width: 1,
                ),
              ),
            ),
            child: Center(
              child: Text(
                'Likes',
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          // List of users who liked
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _likedUsers.isEmpty
                ? Center(
                    child: Text(
                      'No likes yet',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
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
                            fontSize: 11.5.sp,
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
