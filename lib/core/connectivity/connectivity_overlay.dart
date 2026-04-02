// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import 'package:polzet_app/widgets/button/primary_button.dart';
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
  Timer? _serverModalDebounce;
  bool _serverModalShown = false;
  bool _bottomSheetShown = false;

  // ── Helper: always use navigatorKey context for sheets/overlays ────────────
  BuildContext? get _navContext => widget.navigatorKey.currentContext;

  @override
  void dispose() {
    _serverModalDebounce?.cancel();
    super.dispose();
  }

  // ── Status change handler ──────────────────────────────────────────────────
  void _onStatusChanged(ConnectionStatus status) {
    if (status == _lastStatus) return;

    final prev = _lastStatus;
    _lastStatus = status;

    switch (status) {
      case ConnectionStatus.offline:
        _showConnectivitySheet(type: _SheetType.offline);
        break;

      case ConnectionStatus.serverDown:
        _showConnectivitySheet(type: _SheetType.serverDown);
        _debounceServerModal();
        break;

      case ConnectionStatus.online:
        final wasProblematic =
            prev == ConnectionStatus.offline ||
            prev == ConnectionStatus.serverDown;

        _dismissServerModal();
        _closeBottomSheet();

        if (wasProblematic) {
          Future.delayed(const Duration(milliseconds: 250), () {
            if (mounted) _showConnectivitySheet(type: _SheetType.backOnline);
          });
        }
        break;

      case ConnectionStatus.unknown:
        break;
    }
  }

  void _showConnectivitySheet({required _SheetType type}) {
    if (_bottomSheetShown) {
      _closeBottomSheet(then: () => _openSheet(type: type));
      return;
    }
    _openSheet(type: type);
  }

  void _openSheet({required _SheetType type}) {
    final ctx = _navContext; // ← uses navigatorKey context
    if (ctx == null) return;
    _bottomSheetShown = true;

    final connectivity = Provider.of<ConnectivityProvider>(ctx, listen: false);

    showModalBottomSheet(
      context: ctx, // ← uses navigatorKey context
      isDismissible: type == _SheetType.backOnline,
      enableDrag: type == _SheetType.backOnline,
      backgroundColor: Colors.transparent,
      barrierColor: type == _SheetType.backOnline
          ? Colors.transparent
          : Colors.black.withOpacity(0.4),
      builder: (_) => _ConnectivitySheet(
        type: type,
        onRetry: () async => connectivity.retryNow(),
        onDismiss: () => Navigator.of(ctx).pop(),
      ),
    ).whenComplete(() => _bottomSheetShown = false);

    // Auto-dismiss "back online" after 3 seconds
    if (type == _SheetType.backOnline) {
      Timer(const Duration(seconds: 3), () {
        if (mounted && _bottomSheetShown) {
          Navigator.of(ctx, rootNavigator: true).maybePop();
        }
      });
    }
  }

  void _closeBottomSheet({VoidCallback? then}) {
    final ctx = _navContext; // ← uses navigatorKey context
    if (_bottomSheetShown && ctx != null) {
      Navigator.of(ctx, rootNavigator: true).maybePop();
      Future.delayed(const Duration(milliseconds: 300), () => then?.call());
    } else {
      then?.call();
    }
  }

  // ── Server-down modal (debounced) ──────────────────────────────────────────
  void _debounceServerModal() {
    _serverModalDebounce?.cancel();
    _serverModalDebounce = Timer(const Duration(seconds: 2), () {
      if (mounted &&
          _lastStatus == ConnectionStatus.serverDown &&
          !_serverModalShown) {
        _showServerDownModal();
      }
    });
  }

  void _showServerDownModal() {
    final ctx = _navContext; // ← uses navigatorKey context
    if (ctx == null) return;
    _serverModalShown = true;

    final overlay = Overlay.of(ctx); // ← uses navigatorKey context
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _ServerDownModal(
        onRetry: () async {
          final provider = Provider.of<ConnectivityProvider>(
            ctx,
            listen: false,
          );
          await provider.retryNow();
          if (_lastStatus == ConnectionStatus.online) {
            entry.remove();
            _serverModalShown = false;
          }
        },
        onDismiss: () {
          entry.remove();
          _serverModalShown = false;
        },
      ),
    );
    overlay.insert(entry);
  }

  void _dismissServerModal() {
    _serverModalShown = false;
    _serverModalDebounce?.cancel();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
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

// ── Sheet type ─────────────────────────────────────────────────────────────
enum _SheetType { offline, serverDown, backOnline }

// ── Connectivity Bottom Sheet ──────────────────────────────────────────────
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

// ── Server-down full-screen modal (after debounce) ─────────────────────────
class _ServerDownModal extends StatefulWidget {
  final Future<void> Function() onRetry;
  final VoidCallback onDismiss;

  const _ServerDownModal({required this.onRetry, required this.onDismiss});

  @override
  State<_ServerDownModal> createState() => _ServerDownModalState();
}

class _ServerDownModalState extends State<_ServerDownModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _scaleAnim = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(_ctrl);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleRetry() async {
    setState(() => _isRetrying = true);
    await widget.onRetry();
    if (mounted) setState(() => _isRetrying = false);
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFF6D00);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        color: Colors.black.withOpacity(0.55),
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: accent.withOpacity(0.15), blurRadius: 40),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 3,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.10),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accent.withOpacity(0.20),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.cloud_off_rounded,
                      color: accent,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Server Unavailable',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'We\'re having trouble reaching our\nservers. Please check back in a moment.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.52),
                      height: 1.65,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
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
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.refresh_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Try Again',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: widget.onDismiss,
                    child: Text(
                      'Dismiss',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.42),
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
