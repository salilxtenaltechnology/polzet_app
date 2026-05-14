// common/voters/voter_tile.dart
// ignore_for_file: deprecated_member_use

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../mixin/utility_mixins.dart';
import '../../screens/home/profile/public/public_profile_screen.dart';
import '../../widgets/base64/image_convert.dart';
import 'things_voters_models.dart';

class ThingsVoterTile extends StatelessWidget with UtilityMixin {
  final ThingsVoter voter;
  const ThingsVoterTile({super.key, required this.voter});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      child: GestureDetector(
        onTap: () =>
            navigationPush(context, PublicProfileScreen(userId: voter.id)),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16.r,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withOpacity(0.15),
              backgroundImage:
                  voter.profileImage != null && voter.profileImage!.isNotEmpty
                  ? (voter.profileImage!.startsWith('data:image')
                        ? MemoryImage(
                                base64Decode(
                                  voter.profileImage!.split(',').last,
                                ),
                              )
                              as ImageProvider
                        : voter.profileImage!.startsWith('http')
                        ? NetworkImage(voter.profileImage!)
                        : MemoryImage(getProfileImage(voter.profileImage)!))
                  : null,
              child: voter.profileImage == null || voter.profileImage!.isEmpty
                  ? Text(
                      voter.username.isNotEmpty
                          ? voter.username[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 8.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  voter.username,
                  style: TextStyle(
                    fontSize: 10.8.sp,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),
                Text(
                  'picked this as top choice',
                  style: TextStyle(fontSize: 9.8.sp, color: Colors.green),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
