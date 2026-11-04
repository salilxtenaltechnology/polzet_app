// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../api/api_config.dart';
import '../../../../api/api_service.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/themes/app_text_colors.dart';
import '../../../../core/themes/app_text_styles.dart';
import '../../../../gen/assets.gen.dart';
import '../../../../languages/l10n/generated/app_localizations.dart';
import '../../../../provider/user_provider.dart';
import '../../../../widgets/appbar/common_appbar.dart';
import '../../../../widgets/button/primary_button.dart';
import '../../../../widgets/show_toast.dart';

class PreviewPost extends StatefulWidget {
  final String? caption;
  final List<File>? selectedImages;

  const PreviewPost({
    super.key,
    this.caption,
    this.selectedImages,
  });

  @override
  State<PreviewPost> createState() => _PreviewPostState();
}

class _PreviewPostState extends State<PreviewPost> {
  int _currentImageIndex = 0;
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  Future<void> _publishPost() async {
    if (_isLoading) return;

    final caption = widget.caption?.trim() ?? '';
    final images = widget.selectedImages ?? [];

    if (caption.isEmpty) {
      showToast(message: 'Please enter a caption');
      return;
    }
    if (images.isEmpty) {
      showToast(message: 'Please select at least one image');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _apiService.createPost(
        description: caption,
        images: images,
      );

      if (!mounted) return;

      showToast(message: 'Post created successfully!');
      Provider.of<UserProvider>(context, listen: false).clearUserPostsCache();
      Provider.of<UserProvider>(
        context,
        listen: false,
      ).loadUserDataSilently(force: true);

      Navigator.of(context).pop(response);
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString().replaceAll('Exception: ', '').trim();
      showToast(
        message: errorMsg.isNotEmpty ? errorMsg : 'Failed to create post',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  ImageProvider? _getProfileImage(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null') {
      return AssetImage(Assets.images.icAvatar.path);
    }
    if (raw == Assets.images.icAvatar.path || raw.endsWith('ic_avatar.png')) {
      return AssetImage(Assets.images.icAvatar.path);
    }
    if (raw.startsWith('assets/')) {
      return AssetImage(raw);
    }
    if (raw.startsWith('http')) {
      return NetworkImage(raw);
    }
    final String clean = raw.startsWith('/') ? raw : '/$raw';
    return NetworkImage('${ApiConfig.baseUrlImage}$clean');
  }

  Widget _buildCaption(BuildContext context, String caption, AppTextColors txt) {
    if (!caption.contains('#')) {
      return Text(
        caption,
        style: AppTextStyles.bodyText.copyWith(
          color: txt.title,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.2,
        ),
      );
    }

    final RegExp exp = RegExp(r'(#[a-zA-Z0-9_]+)');
    final List<TextSpan> spans = [];

    caption.splitMapJoin(
      exp,
      onMatch: (Match match) {
        spans.add(
          TextSpan(
            text: match.group(0),
            style: AppTextStyles.bodyText.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 14.2.sp,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        );
        return '';
      },
      onNonMatch: (String text) {
        if (text.isNotEmpty) {
          spans.add(
            TextSpan(
              text: text,
              style: AppTextStyles.bodyText.copyWith(
                color: txt.title,
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                height: 1.2,
              ),
            ),
          );
        }
        return '';
      },
    );

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txt = AppTextColors.of(context);
    final userProvider = Provider.of<UserProvider>(context);

    final String fn = userProvider.firstName?.trim() ?? '';
    final String ln = userProvider.lastName?.trim() ?? '';
    final String fullName = '$fn $ln'.trim();
    final String displayName = fullName.isNotEmpty
        ? fullName
        : (userProvider.username?.isNotEmpty == true
            ? userProvider.username!
            : 'Polzet User');

    final images = widget.selectedImages ?? [];
    final hasImages = images.isNotEmpty;
    final hasCaption =
        widget.caption != null && widget.caption!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar:  CommonAppBar(title: AppLocalizations.of(context)!.previewpost, showBackButton: true),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.h, vertical: 5),
              child: Text(
               AppLocalizations.of(context)!.seehowyourpollwillappearinthefeedbeforepublishing,
                style: AppTextStyles.subText.copyWith(
                  fontSize: 14,
                  color: txt.body,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 15),
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                  width: 1,
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0x06000000), blurRadius: 2),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Header Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 19.r,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                        backgroundImage: _getProfileImage(
                          userProvider.profile_picture,
                        ),
                        onBackgroundImageError: (_, __) {},
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: AppTextStyles.sectionHeading.copyWith(
                                    color: txt.title,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '@${userProvider.username ?? ''}',
                                   style: AppTextStyles.bodyText.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: txt.body,
                                  ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  ' • Just now',
                                   style: AppTextStyles.subText.copyWith(
                                  color: txt.muted,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 11.5,
                                ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Caption
                  if (hasCaption) ...[
                    SizedBox(height: 12.h),
                    _buildCaption(context, widget.caption!, txt),
                  ],

                  // Images
                  if (hasImages) ...[
                    SizedBox(height: 12.h),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                      child: images.length == 1
                          ? Image.file(
                              images.first,
                              width: double.infinity,
                              height: 250.h,
                              fit: BoxFit.cover,
                            )
                          : Stack(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: 250.h,
                                  child: PageView.builder(
                                    itemCount: images.length,
                                    onPageChanged: (i) {
                                      setState(() {
                                        _currentImageIndex = i;
                                      });
                                    },
                                    itemBuilder: (context, index) {
                                      return Image.file(
                                        images[index],
                                        width: double.infinity,
                                        height: 250.h,
                                        fit: BoxFit.cover,
                                      );
                                    },
                                  ),
                                ),
                                Positioned(
                                  top: 10.h,
                                  right: 10.w,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.w,
                                      vertical: 4.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.65),
                                      borderRadius: BorderRadius.circular(AppRadius.button),
                                    ),
                                    child: Text(
                                      '${_currentImageIndex + 1}/${images.length}',
                                      style: AppTextStyles.bodyText.copyWith(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    if (images.length > 1) ...[
                      SizedBox(height: 8.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(images.length, (idx) {
                          final bool isActive = idx == _currentImageIndex;
                          return Container(
                            margin: EdgeInsets.symmetric(horizontal: 3.w),
                            width: isActive ? 7.w : 5.w,
                            height: 5.w,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              color: isActive
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onPrimary.withOpacity(0.2),
                            ),
                          );
                        }),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        padding: const EdgeInsets.only(bottom: 20, left: 12, right: 12),
        height: 70.h,
        color: Theme.of(context).colorScheme.background,
        child: PrimaryButton(
          title: AppLocalizations.of(context)!.publishpoll,
          onPressed: _isLoading ? null : _publishPost,
          isLoading: _isLoading,
        ),
      ),
    );
  }
}
