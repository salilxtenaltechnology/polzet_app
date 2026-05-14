// widgets/error/connection_error_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

enum ConnectionErrorType { noInternet, serverError, unknown }

class ConnectionErrorScreen extends StatelessWidget {
  final ConnectionErrorType type;
  final VoidCallback onRetry;

  const ConnectionErrorScreen({
    super.key,
    required this.type,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {

    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 80.w,
                height: 80.w,
                decoration: BoxDecoration(
                  color: _iconBgColor(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, size: 35.sp, color: _iconColor(context)),
              ),

              SizedBox(height: 24.h),

              // Title
              Text(
                _title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              SizedBox(height: 10.h),
              // Subtitle
              Text(
                _subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w400,
                  color: Theme.of(
                    context,
                  ).colorScheme.onBackground.withOpacity(0.5),
                  height: 1.5,
                ),
              ),

              SizedBox(height: 32.h),

              // Retry Button
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  height: 30.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(25.r),
                  ),
                  child: Center(
                    child: Text(
                      'Try Again',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
        return 'Something Went Wrong';
    }
  }

  String get _subtitle {
    switch (type) {
      case ConnectionErrorType.noInternet:
        return 'Please check your Wi-Fi or mobile data\nand try again.';
      case ConnectionErrorType.serverError:
        return 'Our servers are temporarily down.\nWe\'re working on it. Please try later.';
      case ConnectionErrorType.unknown:
        return 'An unexpected error occurred.\nPlease try again.';
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
