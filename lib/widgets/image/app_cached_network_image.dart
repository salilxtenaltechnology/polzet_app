import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AppCachedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
  final double? width;
  final double? height;
  final bool showSpinnerPlaceholder;

  // Global static tracker for loaded image URLs to prevent asynchronous re-check flickering
  static final Set<String> _loadedUrls = {};

  const AppCachedNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.width,
    this.height,
    this.showSpinnerPlaceholder = false,
  });

  /// Clear the loaded URLs cache (e.g. on logout or pull-to-refresh)
  static void clearCache() {
    _loadedUrls.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _buildErrorWidget(context, 'Empty URL');
    }

    // Check if the image is already loaded/fetched in this session
    final bool isAlreadyLoaded = _loadedUrls.contains(imageUrl);

    if (isAlreadyLoaded) {
      // Avoid placeholder or fade-in completely; load immediately from cache
      return Image(
        key: ValueKey('cached_$imageUrl'),
        image: CachedNetworkImageProvider(imageUrl),
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWidget(context, error);
        },
      );
    }

    // Otherwise, load with CachedNetworkImage and show placeholder, then remember it
    return CachedNetworkImage(
      key: ValueKey('net_$imageUrl'),
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      useOldImageOnUrlChange: true,
      imageBuilder: (context, imageProvider) {
        // Record that the image has loaded successfully after this build frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadedUrls.add(imageUrl);
        });
        return Image(
          image: imageProvider,
          fit: fit,
          width: width,
          height: height,
        );
      },
      placeholder: placeholder ?? (context, url) {
        if (showSpinnerPlaceholder) {
          return const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          );
        }
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return Container(
          color: isDarkMode ? const Color(0xFF2D2D2D) : const Color(0xFFF6F3F2),
        );
      },
      errorWidget: errorWidget ?? (context, url, error) {
        return _buildErrorWidget(context, error);
      },
    );
  }

  Widget _buildErrorWidget(BuildContext context, dynamic error) {
    return Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        size: 30,
      ),
    );
  }
}
