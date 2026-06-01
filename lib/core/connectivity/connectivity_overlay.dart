// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import '../../gen/assets.gen.dart';
import '../../provider/connection_provider.dart';

class ConnectivityOverlay extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey; // ← ADDED

  const ConnectivityOverlay({
    super.key,
    required this.child,
    required this.navigatorKey, // ← ADDED
  });

  static void showTestSheet(BuildContext context, String type) {
    final sheetType = type == 'online'
        ? _SheetType.backOnline
        : type == 'server'
        ? _SheetType.serverDown
        : _SheetType.offline;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (_) => _ConnectivitySheet(
        type: sheetType,
        onRetry: () async {},
        onDismiss: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  State<ConnectivityOverlay> createState() => _ConnectivityOverlayState();
}

class _ConnectivityOverlayState extends State<ConnectivityOverlay> {
  ConnectionStatus _lastStatus = ConnectionStatus.unknown;

  @override
  void dispose() {
    super.dispose();
  }

  // ── Status change handler ──────────────────────────────────────────────────
  void _onStatusChanged(ConnectionStatus status) {
    if (status == _lastStatus) return;
    _lastStatus = status;
    // Logic removed when disconnect internet or server down pop
  }



  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityProvider>(
      builder: (context, connectivity, _) {
        if (connectivity.isInitialized) {
          Future.microtask(() => _onStatusChanged(connectivity.status));
        }
        return widget.child;
      },
    );
  }
}

enum _SheetType { offline, serverDown, backOnline }

class _ConnectivitySheet extends StatefulWidget {
  final _SheetType type;
  final Future<void> Function() onRetry;
  final VoidCallback onDismiss;

  const _ConnectivitySheet({
    required this.type,
    required this.onRetry,
    required this.onDismiss,
  });

  @override
  State<_ConnectivitySheet> createState() => _ConnectivitySheetState();
}

class _ConnectivitySheetState extends State<_ConnectivitySheet>
    with SingleTickerProviderStateMixin {
  bool _isRetrying = false;
  late AnimationController _iconCtrl;

  @override
  void initState() {
    super.initState();
    _iconCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _iconCtrl.forward();
  }

  @override
  void dispose() {
    _iconCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRetry() async {
    setState(() => _isRetrying = true);
    _iconCtrl.repeat();
    await widget.onRetry();
    if (mounted) {
      _iconCtrl
        ..stop()
        ..forward(from: 0);
      setState(() => _isRetrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = widget.type == _SheetType.backOnline;
    final isServerDown = widget.type == _SheetType.serverDown;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color accent = Theme.of(context).colorScheme.primary;

    final String title = isOnline
        ? 'You\'re Back Online!'
        : isServerDown
        ? 'Server Unavailable'
        : 'Oops! No Internet!';

    final String subtitle = isOnline
        ? 'Your internet connection has been\nrestored. Everything is working again.'
        : isServerDown
        ? 'We\'re having trouble reaching our servers.\nWe\'re working to fix this. Please try\nagain in a moment.'
        : 'Looks like you are facing a temporary\nnetwork interruption.\nOr check your network connection.';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 20,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.15)
                    : Colors.black.withOpacity(0.10),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 8),
            child: Column(
              children: [
                if (widget.type == _SheetType.offline)
                  Lottie.asset(
                    Assets.images.lostConnection,
                    width: 80.w,
                    height: 80.w,
                    repeat: true,
                  )
                else if (widget.type == _SheetType.backOnline)
                  Lottie.asset(
                    Assets.images.connected,
                    width: 80.w,
                    height: 80.w,
                    repeat: true,
                  )
                else
                  Image.asset(Assets.images.server.path, width: 84, height: 84),
                const SizedBox(height: 22),

                // ── Title ──
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onBackground,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    // letterSpacing: -0.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),

                // ── Subtitle ──
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.52),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // ── Primary action (Try Again) ──
                if (!isOnline)
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: _isRetrying ? null : _handleRetry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: accent.withOpacity(0.38),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25.r),
                        ),
                      ),
                      child: _isRetrying
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Center(
                              child: Text(
                                'Try Again',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.sp,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                    ),
                  ),

                if (!isOnline) const SizedBox(height: 10),

                // ── Secondary / dismiss ──
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: isOnline
                      ? ElevatedButton(
                          onPressed: widget.onDismiss,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25.r),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Continue',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.sp,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        )
                      : TextButton(
                          onPressed: widget.onDismiss,
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25.r),
                            ),
                          ),
                          child: Text(
                            'Dismiss',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onBackground.withOpacity(0.32),
                              fontWeight: FontWeight.w600,
                              fontSize: 11.5.sp,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}
