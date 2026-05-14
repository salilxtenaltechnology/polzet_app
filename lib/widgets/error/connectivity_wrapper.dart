// widgets/error/connectivity_wrapper.dart
// ignore_for_file: unused_field, deprecated_member_use

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../connection/no_internet_screen.dart';

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onReconnect;

  const ConnectivityWrapper({super.key, required this.child, this.onReconnect});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper>
    with SingleTickerProviderStateMixin {
  bool _hasInternet = true;
  bool _isChecking = false;
  bool _isFirstCheck = true;
  bool _showBanner = false;
  bool _isConnected = false;

  Timer? _retryTimer;
  Timer? _bannerTimer;

  late AnimationController _animController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  static bool _bannerShownOnce = false;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnim = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _checkConnection();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _bannerTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    bool hasInternet = false;
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 10));

      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        hasInternet = true;
      }
    } on TimeoutException catch (_) {
      hasInternet = true; // Slow network, don't show offline screen
    } on SocketException catch (_) {
      hasInternet = false;
    } catch (_) {
      hasInternet = false;
    }

    if (hasInternet) {
      _retryTimer?.cancel();
      if (mounted) {
        final wasOffline = !_hasInternet;
        setState(() {
          _hasInternet = true;
          _isChecking = false;
          _isConnected = true;
        });

        if (wasOffline && !_isFirstCheck) {
          _bannerShownOnce = false;
          _showTopBanner(isConnected: true);
          widget.onReconnect?.call();
        }
        _isFirstCheck = false;
      }
    } else {
      if (mounted) {
        final wasOnline = _hasInternet;
        setState(() {
          _hasInternet = false;
          _isChecking = false;
          _isConnected = false;
          _isFirstCheck = false;
        });

        if (wasOnline) {
          _bannerShownOnce = true;
          _showTopBanner(isConnected: false);
        }
        _startAutoRetry();
      }
    }
  }

  void _startAutoRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkConnection();
    });
  }

  void _showTopBanner({required bool isConnected}) {
    _bannerTimer?.cancel();
    setState(() => _showBanner = true);
    _animController.forward(from: 0);

    // Auto-hide after delay
    _bannerTimer = Timer(
      Duration(seconds: isConnected ? 2 : 3),
      () => _hideBanner(),
    );
  }

  void _hideBanner() {
    if (!mounted) return;
    _animController.reverse().then((_) {
      if (mounted) setState(() => _showBanner = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Main content ──
        if (!_hasInternet)
          ConnectionErrorScreen(
            type: ConnectionErrorType.noInternet,
            onRetry: () {
              _retryTimer?.cancel();
              _checkConnection();
            },
          )
        else
          widget.child,

        // ── Top animated banner ──
        if (_showBanner)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: _ConnectivityBanner(
                    isConnected: _isConnected,
                    onDismiss: _hideBanner,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/*──── Banner Widget ────*/
class _ConnectivityBanner extends StatelessWidget {
  final bool isConnected;
  final VoidCallback onDismiss;

  const _ConnectivityBanner({
    required this.isConnected,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final color = isConnected
        ? const Color(0xFF2E7D32)
        : const Color(0xFFC62828);
    final icon = isConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded;
    final message = isConnected ? 'Back online' : 'No internet connection';
    final subMessage = isConnected
        ? 'Your connection has been restored'
        : 'Check your Wi-Fi or mobile data';

    return Container(
      margin: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 0),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon circle
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 18.sp),
          ),

          SizedBox(width: 10.w),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subMessage,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          // Dismiss button
          GestureDetector(
            onTap: onDismiss,
            child: Icon(
              Icons.close_rounded,
              color: Colors.white.withOpacity(0.8),
              size: 16.sp,
            ),
          ),
        ],
      ),
    );
  }
}
