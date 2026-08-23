import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/social_service.dart';

/// Full-screen swipeable viewer for a post's images. Opens on the tapped
/// image and lets you swipe through the rest — this is what tapping any
/// tile in PostImageGrid (including the "+N" overflow tile) leads to.
class ImageGalleryViewer extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;

  const ImageGalleryViewer({
    super.key,
    required this.imagePaths,
    this.initialIndex = 0,
  });

  static void open(
    BuildContext context, {
    required List<String> imagePaths,
    int initialIndex = 0,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: const Color(0xFF0A0A0A),
        pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
          opacity: animation,
          child: ImageGalleryViewer(
            imagePaths: imagePaths,
            initialIndex: initialIndex,
          ),
        ),
      ),
    );
  }

  @override
  State<ImageGalleryViewer> createState() => _ImageGalleryViewerState();
}

class _ImageGalleryViewerState extends State<ImageGalleryViewer> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  final FocusNode _focusNode = FocusNode();
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _hasPrev => _index > 0;
  bool get _hasNext => _index < widget.imagePaths.length - 1;

  void _goTo(int delta) {
    _controller.animateToPage(
      _index + delta,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        if (_hasPrev) _goTo(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        if (_hasNext) _goTo(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        Navigator.of(context).pop();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        // Slightly softer than pure black, matching Facebook's actual
        // photo-viewer background rather than a flat #000000.
        backgroundColor: const Color(0xFF0A0A0A),
        body: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.imagePaths.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: SizedBox.expand(
                  child: Image.network(
                    SocialService.imageUrl(widget.imagePaths[i]),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            if (widget.imagePaths.length > 1) ...[
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton.filled(
                    onPressed: _hasPrev ? () => _goTo(-1) : null,
                    icon: const Icon(Icons.chevron_left),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.4),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.black.withValues(
                        alpha: 0.15,
                      ),
                      disabledForegroundColor: Colors.white.withValues(
                        alpha: 0.25,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton.filled(
                    onPressed: _hasNext ? () => _goTo(1) : null,
                    icon: const Icon(Icons.chevron_right),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.4),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.black.withValues(
                        alpha: 0.15,
                      ),
                      disabledForegroundColor: Colors.white.withValues(
                        alpha: 0.25,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    if (widget.imagePaths.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          '${_index + 1}/${widget.imagePaths.length}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
