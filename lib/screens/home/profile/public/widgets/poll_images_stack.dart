// ignore_for_file: non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../api/api_config.dart';
import '../../../../../models/public/public_profile_model.dart';

Widget PollImagesStack(List<PollOptionImage> images) {
  List<Alignment> getAlignments(int totalImages) {
    switch (totalImages) {
      case 1:
        return [Alignment.center];
      case 2:
        return [Alignment.centerLeft, Alignment.centerRight];
      case 3:
        return [Alignment.centerLeft, Alignment.center, Alignment.centerRight];
      case 4:
      default:
        return [
          Alignment.centerLeft,
          Alignment.center,
          Alignment.centerRight,
          Alignment.centerRight,
        ];
    }
  }

  List<Alignment> alignments = getAlignments(images.length);

  return LayoutBuilder(
    builder: (context, constraints) {
      double availableWidth = constraints.maxWidth;
      double availableHeight = constraints.maxHeight;
      double imageHeight = 120.h;

      return SizedBox(
        height: availableHeight,
        width: availableWidth,
        child: Stack(
          children: images
              .asMap()
              .entries
              .map<Widget>((entry) {
                int index = entry.key;
                PollOptionImage imageData = entry.value;
                Alignment alignment = alignments[index];
                double imageWidth = (availableWidth * 0.7) - (index * 8.0);
                imageWidth = imageWidth < 60.w ? 60.w : imageWidth;

                return Align(
                  alignment: alignment,
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 3.w),
                    width: imageWidth,
                    height: imageHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 1),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(19.r),
                        child: Image.network(
                          '${ApiConfig.baseUrlImage}${imageData.url}',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Icon(
                                Icons.image_not_supported,
                                color: Colors.grey[600],
                                size: 30,
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  value:
                                      loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              })
              .toList()
              .reversed
              .toList(),
        ),
      );
    },
  );
}