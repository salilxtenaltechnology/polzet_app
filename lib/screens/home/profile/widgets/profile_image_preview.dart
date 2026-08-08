// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../api/api_config.dart';

class ProfileImagePreview extends StatefulWidget {
  final dynamic imageSource;
  final String? username;

  const ProfileImagePreview({
    super.key,
    required this.imageSource,
    required this.username,
  });

  @override
  State<ProfileImagePreview> createState() => _ProfileImagePreviewState();
}

class _ProfileImagePreviewState extends State<ProfileImagePreview>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  Animation<Offset>? _dragResetAnimation;
  ImageProvider? _imageProvider;

  final ValueNotifier<Offset> _dragOffsetNotifier = ValueNotifier<Offset>(Offset.zero);
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _imageProvider = _resolveImageProvider(widget.imageSource);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _dragOffsetNotifier.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_animationController.isAnimating) return;

    _isDragging = true;
    final newOffset = _dragOffsetNotifier.value + details.delta;
    _dragOffsetNotifier.value = newOffset;
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;

    final currentOffset = _dragOffsetNotifier.value;
    final velocity = details.velocity.pixelsPerSecond.distance;
    final dragDistance = currentOffset.distance;

    if (dragDistance > 120 || velocity > 800) {
      Navigator.of(context).pop();
    } else {
      _dragResetAnimation = Tween<Offset>(
        begin: currentOffset,
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOutCubic,
        ),
      )..addListener(() {
          _dragOffsetNotifier.value = _dragResetAnimation!.value;
        });
      _animationController.forward(from: 0.0);
    }
  }

  ImageProvider? _resolveImageProvider(dynamic source) {
    if (source == null) return null;
    if (source is Uint8List) {
      return MemoryImage(source);
    }
    if (source is String) {
      if (source.isEmpty) return null;
      if (source.startsWith('assets/')) {
        return AssetImage(source);
      }
      // Check if it's base64 string
      if (source.startsWith('data:image') || (!source.contains('/') && !source.contains('.'))) {
        try {
          final base64Str = source.contains(',') ? source.split(',').last : source;
          return MemoryImage(base64Decode(base64Str));
        } catch (_) {
          // Fallback to treat as URL/path if base64 decoding fails
        }
      }
      // Treat as URL/path
      String url = source;
      if (!url.startsWith('http')) {
        final separator = url.startsWith('/') ? '' : '/';
        url = '${ApiConfig.baseUrlImage}$separator$url';
      }
      return NetworkImage(url);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.75),
      body: GestureDetector(
        // Tap outside the image to close the preview
        onTap: () => Navigator.of(context).pop(),
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Blurred background image
            if (_imageProvider != null)
              Positioned.fill(
                child: Image(
                  key: const ValueKey('preview_bg_image'),
                  image: _imageProvider!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            // Blur filter overlay with static darkening
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  color: Colors.black.withOpacity(0.75),
                ),
              ),
            ),
            // Centered circular image
            ValueListenableBuilder<Offset>(
              valueListenable: _dragOffsetNotifier,
              builder: (context, offset, child) {
                return Transform.translate(
                  offset: offset,
                  child: child,
                );
              },
              child: Center(
                child: GestureDetector(
                  // Prevent tapping the circular image itself from dismissing
                  onTap: () {},
                  child: Container(
                    width: 0.70.sw,
                    height: 0.70.sw,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 20,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _imageProvider != null
                          ? Image(
                              key: const ValueKey('preview_fg_image'),
                              image: _imageProvider!,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              errorBuilder: (_, __, ___) => _PlaceholderImage(username: widget.username),
                            )
                          : _PlaceholderImage(username: widget.username),
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
}

class _PlaceholderImage extends StatelessWidget {
  final String? username;

  const _PlaceholderImage({this.username});

  @override
  Widget build(BuildContext context) {
    String firstLetter = 'P';
    if (username != null && username!.isNotEmpty) {
      firstLetter = username![0].toUpperCase();
    }

    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Text(
          firstLetter,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 70.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
