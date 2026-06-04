// widgets/error/connection_error_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:polzet_app/core/constants/app_radius.dart';
import 'package:polzet_app/gen/assets.gen.dart';

import '../../core/themes/app_text_colors.dart';
import '../../core/themes/app_text_styles.dart';

enum ConnectionErrorType { noInternet, serverError, unknown }

class ConnectionErrorScreen extends StatelessWidget {
  final ConnectionErrorType type;
  final VoidCallback onRetry;
  final String? errorMessage;

  const ConnectionErrorScreen({
    super.key,
    required this.type,
    required this.onRetry,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final txt = AppTextColors.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
              // Image or Icon
              type == ConnectionErrorType.unknown
                  ? (isDarkMode
                        ? const SizedBox()
                        : Image.asset(
                            Assets.images.somethingWentWrong.path,
                            width: 200,
                            height: 200,
                            fit: BoxFit.contain,
                          ))
                  : Container(
                      width: 80.w,
                      height: 80.w,
                      decoration: BoxDecoration(
                        color: _iconBgColor(context),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _icon,
                        size: 35.sp,
                        color: _iconColor(context),
                      ),
                    ),
      
              const SizedBox(height: 10),
              // Title
              Text(
                _title,
                textAlign: TextAlign.center,
                style: AppTextStyles.sectionHeading.copyWith(
                  fontSize: type == ConnectionErrorType.unknown ? 18.5 : 14.sp,
                  color: txt.title,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 10.h),
              // Subtitle
              Text(
                _subtitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: type == ConnectionErrorType.unknown ? 13 : 12.sp,
                  fontWeight: FontWeight.w400,
                  color: type == ConnectionErrorType.unknown
                      ? txt.muted
                      : Theme.of(
                          context,
                        ).colorScheme.onBackground.withOpacity(0.5),
                  height: 1.4,
                ),
              ),
      
              const SizedBox(height: 30),
      
              // Retry Button
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  height: type == ConnectionErrorType.unknown ? 40 : 30.h,
                  width: 220,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(
                      type == ConnectionErrorType.unknown ? AppRadius.button : 12,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Try Again',
                      style: AppTextStyles.cardTitle.copyWith(
                        color: Colors.white,
                        fontSize: type == ConnectionErrorType.unknown
                            ? 14
                            : 12.sp,
                        fontWeight: FontWeight.w600,
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

  IconData get _icon {
    switch (type) {
      case ConnectionErrorType.noInternet:
        return Icons.wifi_off_rounded;
      case ConnectionErrorType.serverError:
        return Icons.cloud_off_rounded;
      case ConnectionErrorType.unknown:
        return Icons.error_outline_rounded;
    }
  }

  String get _title {
    switch (type) {
      case ConnectionErrorType.noInternet:
        return 'No Internet Connection';
      case ConnectionErrorType.serverError:
        return 'Server Unavailable';
      case ConnectionErrorType.unknown:
        return 'Ooops!! Something\nwent wrong';
    }
  }

  String get _subtitle {
    if (errorMessage != null && errorMessage!.isNotEmpty) {
      final err = errorMessage!.toLowerCase();
      if (err.contains('timeout') || err.contains('time out')) {
        return 'The connection has timed out. Please try again.';
      } else if (err.contains('500') || err.contains('internal server error')) {
        return 'Internal Server Error (500)';
      } else if (err.contains('404') || err.contains('not found')) {
        return 'Requested resource not found (404).';
      } else if (err.contains('401') || err.contains('unauthorized')) {
        return 'Unauthorized access (401).';
      } else if (err.contains('403') || err.contains('forbidden')) {
        return 'Access forbidden (403).';
      } else if (err.contains('502') || err.contains('bad gateway')) {
        return 'Bad Gateway (502).';
      } else if (err.contains('503') || err.contains('service unavailable')) {
        return 'Service Unavailable (503).';
      } else if (err.contains('socketexception') ||
          err.contains('network') ||
          err.contains('connection error')) {
        return 'Network error. Please check your internet connection.';
      }
    }

    switch (type) {
      case ConnectionErrorType.noInternet:
        return 'Please check your Wi-Fi or mobile data\nand try again.';
      case ConnectionErrorType.serverError:
        return 'Our servers are temporarily down.\nWe\'re working on it. Please try later.';
      case ConnectionErrorType.unknown:
        return 'Please try again in a moment.';
    }
  }

  Color _iconBgColor(BuildContext context) {
    switch (type) {
      case ConnectionErrorType.noInternet:
        return Colors.orange.withOpacity(0.12);
      case ConnectionErrorType.serverError:
        return Colors.red.withOpacity(0.12);
      case ConnectionErrorType.unknown:
        return Colors.grey.withOpacity(0.12);
    }
  }

  Color _iconColor(BuildContext context) {
    switch (type) {
      case ConnectionErrorType.noInternet:
        return Colors.orange;
      case ConnectionErrorType.serverError:
        return Colors.red;
      case ConnectionErrorType.unknown:
        return Colors.grey;
    }
  }
}
