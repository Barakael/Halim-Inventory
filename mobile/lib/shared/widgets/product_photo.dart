import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/brand_palette.dart';
import '../../core/utils/media_url.dart';

class ProductPhoto extends StatelessWidget {
  const ProductPhoto({
    super.key,
    required this.url,
    this.size = 48,
    this.radius = 12,
    this.iconSize = 22,
  });

  final String? url;
  final double size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final p = BrandTokens.current;
    final resolved = resolveMediaUrl(url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        color: p.primary.withValues(alpha: 0.08),
        child: resolved == null
            ? Icon(Icons.inventory_2_outlined, color: p.primary, size: iconSize)
            : CachedNetworkImage(
                imageUrl: resolved,
                cacheKey: resolved,
                fit: BoxFit.cover,
                width: size,
                height: size,
                placeholder: (_, __) => Center(
                  child: SizedBox(
                    width: iconSize,
                    height: iconSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: p.primary.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Icon(
                  Icons.inventory_2_outlined,
                  color: p.primary,
                  size: iconSize,
                ),
              ),
      ),
    );
  }
}
