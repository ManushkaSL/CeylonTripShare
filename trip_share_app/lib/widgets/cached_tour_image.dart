import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Reusable cached network image widget with consistent loading and error handling
class CachedTourImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const CachedTourImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final widget = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => Container(
        color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1B5E20)),
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: const Color(0xFF1B5E20).withValues(alpha: 0.1),
        child: const Center(
          child: Icon(Icons.landscape, size: 36, color: Color(0xFF1B5E20)),
        ),
      ),
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: widget);
    }

    return widget;
  }
}
