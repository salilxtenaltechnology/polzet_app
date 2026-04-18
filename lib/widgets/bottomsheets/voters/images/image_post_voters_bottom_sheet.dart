// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/widgets/base64/image_convert.dart';

import '../../../../api/services/api_service.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../models/voters/top_voters_model.dart';
import '../../../loader.dart';

class ImagePostVotersBottomSheet extends StatefulWidget {
  final int pollId;
  final int optionId;

  const ImagePostVotersBottomSheet({
    super.key,
    required this.pollId,
    required this.optionId,
  });

  @override
  State<ImagePostVotersBottomSheet> createState() =>
      _PostVotersBottomSheetState();
}

class _PostVotersBottomSheetState extends State<ImagePostVotersBottomSheet> {
  bool _isLoading = true;
  String? _error;
  TopVotersModel? _data;

  @override
  void initState() {
    super.initState();
    _fetchTopVoters();
  }

  Future<void> _fetchTopVoters() async {
    try {
      final result = await ApiService.getTopVoters(
        pollId: widget.pollId,
        optionId: widget.optionId,
      );
      if (mounted) {
        setState(() {
          _data = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.modal),
          topRight: Radius.circular(AppRadius.modal),
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
                AppLocalizations.of(context)!.voters,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onBackground,
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return  Center(child: Loader(color: Theme.of(context).colorScheme.primary));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48.sp, color: Colors.grey[400]),
            SizedBox(height: 12.h),
            Text(
              'Failed to load voters',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[500]),
            ),
            SizedBox(height: 8.h),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _fetchTopVoters();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final users = _data?.users ?? [];

    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.how_to_vote_outlined,
              size: 45.sp,
              color: Colors.grey[400],
            ),
            SizedBox(height: 12.h),
            Text(
              AppLocalizations.of(context)!.novotersthisimageyet,
              style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      itemCount: users.length,
      separatorBuilder: (_, __) => SizedBox(height: 20.h),
      itemBuilder: (context, index) => _buildVoterRow(users[index]),
    );
  }

  Widget _buildVoterRow(TopVoterUser user) {
    final bytes =
        user.profilePictureUrl != null && user.profilePictureUrl!.isNotEmpty
        ? getProfileImage(user.profilePictureUrl!)
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 30.w,
          height: 30.h,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF9E3E8),
            image: bytes != null
                ? DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover)
                : null,
          ),
          child: bytes == null
              ? Center(
                  child: Text(
                    user.firstLetter,
                    style: TextStyle(
                      color: AppColors.primaryColor,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : null,
        ),

        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.username,
                style: TextStyle(
                  fontSize: 10.8.sp,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              SizedBox(height: 2.h),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: AppLocalizations.of(
                        context,
                      )!.voterspickedthisastopchoicesheet, // dynamic : _data?.label
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    TextSpan(
                      text: AppLocalizations.of(context)!.peoplelikeyouchosetop,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.green,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
