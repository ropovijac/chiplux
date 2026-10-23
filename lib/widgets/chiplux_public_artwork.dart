import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Public artwork only: TMDB posters/backdrops, cast photos, and album art.
/// Never use this persistent cache for account-private media or auth resources.
// The ImageCacheManager mixin is required for maxWidthDiskCache resizing;
// a bare CacheManager does not support the resized-image storage API.
class _ChipluxArtworkCacheManager extends CacheManager with ImageCacheManager {
  _ChipluxArtworkCacheManager()
      : super(
          Config(
            'chiplux_public_artwork_v1',
            stalePeriod: const Duration(days: 14),
            maxNrOfCacheObjects: 400,
          ),
        );
}

class ChipluxPublicArtworkCache {
  ChipluxPublicArtworkCache._();

  static final CacheManager instance = _ChipluxArtworkCacheManager();
}

/// Decode images for their actual display width at the current device DPR.
/// A small set of widths improves cache reuse between list/grid widgets.
int _artworkDecodeWidth(double logicalWidth, double dpr) {
  final physical = (logicalWidth * dpr).ceil();
  for (final bucket in const <int>[
    128, 192, 256, 384, 512, 768, 1024, 1536, 2048,
  ]) {
    if (physical <= bucket) return bucket;
  }
  return 2048;
}

/// Use for publicly accessible artwork only. Call signatures deliberately
/// mirror the Image.network subset used throughout Chiplux so previous
/// sizing, fallbacks, and BoxFit are preserved.
class ChipluxPublicArtwork extends StatelessWidget {
  const ChipluxPublicArtwork(
    this.imageUrl, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholderBuilder,
    this.errorBuilder,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final WidgetBuilder? placeholderBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The explicit image width is preferred. Otherwise use the parent
        // (grid card or detail page) rather than an oversized source bitmap.
        final logicalWidth = width ??
            (constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width);
        final targetWidth = _artworkDecodeWidth(
          logicalWidth,
          MediaQuery.devicePixelRatioOf(context),
        );

        return CachedNetworkImage(
          imageUrl: imageUrl,
          cacheManager: ChipluxPublicArtworkCache.instance,
          width: width,
          height: height,
          fit: fit,
          filterQuality: FilterQuality.medium,
          memCacheWidth: targetWidth,
          maxWidthDiskCache: targetWidth,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          placeholderFadeInDuration: Duration.zero,
          placeholder: (context, url) =>
              placeholderBuilder?.call(context) ??
              SizedBox(width: width, height: height),
          errorWidget: (context, url, error) =>
              errorBuilder?.call(context, error, StackTrace.empty) ??
              const Center(child: Icon(Icons.broken_image_outlined)),
        );
      },
    );
  }
}

/// Avatar images are resized for their rendered diameter, but unlike public
/// catalogue artwork they are not written to the public-artwork disk cache.
ImageProvider chipluxSizedAvatar(
  BuildContext context,
  String url,
  double diameter,
) {
  final decoded = _artworkDecodeWidth(
    diameter,
    MediaQuery.devicePixelRatioOf(context),
  );
  return ResizeImage.resizeIfNeeded(decoded, null, NetworkImage(url));
}
