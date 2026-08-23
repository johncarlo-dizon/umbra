import 'package:flutter/material.dart';
import '../services/social_service.dart';
import 'image_gallery_viewer.dart';

/// Renders a post's images in a Facebook-ish layout:
/// 1 image -> full width. 2 -> side by side. 3 -> one big + two stacked.
/// 4+ -> 2x2 grid, with a "+N" overlay on the last tile if there are
/// more than 4 (SocialService.maxImagesPerPost allows up to 10).
/// Tapping any tile — including the "+N" overflow tile — opens the
/// full-screen swipeable viewer starting at that image.
class PostImageGrid extends StatelessWidget {
  final List<String> imagePaths;
  final double height;

  const PostImageGrid({super.key, required this.imagePaths, this.height = 220});

  Widget _tile(
    BuildContext context,
    int index, {
    double? width,
    double? tileHeight,
    int? overflowCount,
  }) {
    final path = imagePaths[index];
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: width,
        height: tileHeight,
        child: InkWell(
          onTap: () => ImageGalleryViewer.open(
            context,
            imagePaths: imagePaths,
            initialIndex: index,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                SocialService.imageUrl(path),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey.withValues(alpha: 0.2),
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
              if (overflowCount != null && overflowCount > 0)
                Container(
                  color: Colors.black.withValues(alpha: 0.55),
                  alignment: Alignment.center,
                  child: Text(
                    '+$overflowCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (imagePaths.isEmpty) return const SizedBox.shrink();

    if (imagePaths.length == 1) {
      return SizedBox(
        width: double.infinity,
        height: height,
        child: _tile(context, 0, width: double.infinity, tileHeight: height),
      );
    }

    if (imagePaths.length == 2) {
      return SizedBox(
        height: height,
        child: Row(
          children: [
            Expanded(child: _tile(context, 0, tileHeight: height)),
            const SizedBox(width: 4),
            Expanded(child: _tile(context, 1, tileHeight: height)),
          ],
        ),
      );
    }

    if (imagePaths.length == 3) {
      return SizedBox(
        height: height,
        child: Row(
          children: [
            Expanded(child: _tile(context, 0, tileHeight: height)),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _tile(context, 1, width: double.infinity)),
                  const SizedBox(height: 4),
                  Expanded(child: _tile(context, 2, width: double.infinity)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 4+ images -> 2x2 grid, last tile gets a "+N" overlay if there are
    // more than 4 total.
    final overflow = imagePaths.length > 4 ? imagePaths.length - 4 : 0;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _tile(context, 0, width: double.infinity)),
                const SizedBox(width: 4),
                Expanded(child: _tile(context, 1, width: double.infinity)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _tile(context, 2, width: double.infinity)),
                const SizedBox(width: 4),
                Expanded(
                  child: _tile(
                    context,
                    3,
                    width: double.infinity,
                    overflowCount: overflow,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
