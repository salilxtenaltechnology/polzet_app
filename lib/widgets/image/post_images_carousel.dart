// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../api/api_config.dart';
import '../../core/constants/app_radius.dart';
import '../../core/themes/app_text_styles.dart';
import '../../models/posts/user_post_model.dart';
import '../../screens/home/home feed/rank/result/image/image_preview_screen.dart';
import 'app_cached_network_image.dart';

class PostImagesCarousel extends StatefulWidget {
  final List<dynamic> images;

  const PostImagesCarousel({
    super.key,
    required this.images,
  });

  @override
  State<PostImagesCarousel> createState() => _PostImagesCarouselState();
}

class _PostImagesCarouselState extends State<PostImagesCarousel> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return const SizedBox.shrink();

    final List<String> imageUrls = widget.images
        .map<String>((img) {
          if (img is PostImage) {
            return img.resolvedUrl(ApiConfig.baseUrlImage);
          } else if (img is String) {
            return img;
          }
          try {
            return (img as dynamic).resolvedUrl(ApiConfig.baseUrlImage).toString();
          } catch (_) {
            return '';
          }
        })
        .where((url) => url.isNotEmpty)
        .toList();

    if (imageUrls.isEmpty) return const SizedBox.shrink();

    if (imageUrls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ImagePreviewScreen(
                  imageUrls: imageUrls,
                  initialIndex: 0,
                ),
              ),
            );
          },
          child: AppCachedNetworkImage(
            imageUrl: imageUrls.first,
            width: double.infinity,
            height: 230.h,
            fit: BoxFit.cover,
            showSpinnerPlaceholder: true,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.button),
          child: Stack(
            children: [
              SizedBox(
                width: double.infinity,
                height: 230.h,
                child: PageView.builder(
                  itemCount: imageUrls.length,
                  onPageChanged: (i) {
                    setState(() {
                      _currentIndex = i;
                    });
                  },
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ImagePreviewScreen(
                              imageUrls: imageUrls,
                              initialIndex: index,
                            ),
                          ),
                        );
                      },
                      child: AppCachedNetworkImage(
                        imageUrl: imageUrls[index],
                        width: double.infinity,
                        height: 250.h,
                        fit: BoxFit.cover,
                        showSpinnerPlaceholder: true,
                      ),
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
                    '${_currentIndex + 1}/${imageUrls.length}',
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
        if (imageUrls.length > 1) ...[
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(imageUrls.length, (idx) {
              final bool isActive = idx == _currentIndex;
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 3.w),
                width: isActive ? 7.w : 5.w,
                height: 5.w,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: isActive
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}
