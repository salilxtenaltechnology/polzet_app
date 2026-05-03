// ignore_for_file: deprecated_member_use
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ImagePreviewScreen extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const ImagePreviewScreen({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    // Full immersive — hide status & nav bars
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _prev() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _next() {
    if (_currentIndex < widget.imageUrls.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── PageView ────────────────────────────────────────────────
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) =>
                _ImagePage(url: widget.imageUrls[index]),
          ),

          // ── Close button ─────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),

          // ── Bottom: arrows + dots ─────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Prev arrow
                _NavButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: _currentIndex > 0 ? _prev : null,
                ),

                // Dot indicators
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    widget.imageUrls.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _currentIndex ? 10 : 7,
                      height: i == _currentIndex ? 10 : 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _currentIndex
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ),
                ),

                // Next arrow
                _NavButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: _currentIndex < widget.imageUrls.length - 1
                      ? _next
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Single image page: auto-detects portrait vs landscape ─────────────────────

class _ImagePage extends StatefulWidget {
  final String url;
  const _ImagePage({required this.url});

  @override
  State<_ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends State<_ImagePage> {
  bool _isPortrait = true;

  @override
  void initState() {
    super.initState();
    _resolveOrientation();
  }

  void _resolveOrientation() {
    final image = NetworkImage(widget.url);
    final stream = image.resolve(ImageConfiguration.empty);
    stream.addListener(
      ImageStreamListener((info, _) {
        if (!mounted) return;
        setState(() {
          _isPortrait = info.image.height >= info.image.width;
        });
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return _buildWithBlurredBackground(screenSize);

    // return _isPortrait
    //     ? _buildPortrait(screenSize)
    //     : _buildLandscape(screenSize);
  }

  Widget _buildWithBlurredBackground(Size screen) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Blurred background (always shown) ──────────────────────
        Image.network(
          widget.url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black),
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(color: Colors.black.withOpacity(0.5)),
        ),

        // ── Sharp image on top ──────────────────────────────────────
        Center(
          child: Image.network(
            widget.url,
            width: screen.width,
            height: screen.height,
            fit: BoxFit.contain, // ← contain keeps full image visible
            errorBuilder: (_, __, ___) => _errorWidget(),
            loadingBuilder: _loadingBuilder,
          ),
        ),
      ],
    );
  }

  // Vertical image → fill full screen width, centered vertically
  Widget _buildPortrait(Size screen) {
    return Center(
      child: Image.network(
        widget.url,
        width: screen.width,
        fit: BoxFit.fitWidth,
        errorBuilder: (_, __, ___) => _errorWidget(),
        loadingBuilder: _loadingBuilder,
      ),
    );
  }

  // Horizontal image → blurred background + centered fitted image on top
  Widget _buildLandscape(Size screen) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Blurred background ──────────────────────────────────────
        Image.network(
          widget.url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),

        // ImageFilter blur — much stronger than before
        BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 25,
            sigmaY: 25,
          ), // ← was just opacity overlay
          child: Container(color: Colors.black.withOpacity(0.55)),
        ),

        // ── Sharp image on top ──────────────────────────────────────
        Center(
          child: Image.network(
            widget.url,
            width: screen.width,
            height: screen.height,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _errorWidget(),
            loadingBuilder: _loadingBuilder,
          ),
        ),
      ],
    );
  }

  Widget _loadingBuilder(
    BuildContext context,
    Widget child,
    ImageChunkEvent? loadingProgress,
  ) {
    if (loadingProgress == null) return child;
    return Center(
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: Colors.white,
        value: loadingProgress.expectedTotalBytes != null
            ? loadingProgress.cumulativeBytesLoaded /
                  loadingProgress.expectedTotalBytes!
            : null,
      ),
    );
  }

  Widget _errorWidget() => const Center(
    child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
  );
}

// ── Nav arrow button ──────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _NavButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap != null ? 1.0 : 0.3,
        duration: const Duration(milliseconds: 200),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
