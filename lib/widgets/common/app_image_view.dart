import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/core/constants/app_images.dart';

/// Universal image viewer supporting both local assets and network URLs with caching & shimmer.
class AppImageView extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final String? fallbackAsset;

  const AppImageView({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackAsset,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;

    final url = imageUrl?.trim();

    if (url == null || url.isEmpty) {
      imageWidget = _buildFallback();
    } else if (url.startsWith('assets/')) {
      imageWidget = Image.asset(
        url,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildFallback(),
      );
    } else if (url.startsWith('http://') || url.startsWith('https://')) {
      imageWidget = CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Shimmer.fromColors(
          baseColor: AppColors.surfaceLight,
          highlightColor: AppColors.surface,
          child: Container(
            width: width,
            height: height,
            color: Colors.white,
          ),
        ),
        errorWidget: (context, errorUrl, error) {
          final fallbackUrl = AppImages.getPublicFallbackUrl(errorUrl);
          if (fallbackUrl != errorUrl) {
            return CachedNetworkImage(
              imageUrl: fallbackUrl,
              width: width,
              height: height,
              fit: fit,
              errorWidget: (_, _, _) => _buildFallback(),
            );
          }
          return _buildFallback();
        },
      );
    } else {
      // Resolve through Supabase storage bucket
      final bucketUrl = AppImages.getBucketUrl(url);
      imageWidget = CachedNetworkImage(
        imageUrl: bucketUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Shimmer.fromColors(
          baseColor: AppColors.surfaceLight,
          highlightColor: AppColors.surface,
          child: Container(
            width: width,
            height: height,
            color: Colors.white,
          ),
        ),
        errorWidget: (context, errorUrl, error) {
          final fallbackUrl = AppImages.getPublicFallbackUrl(errorUrl);
          if (fallbackUrl != errorUrl) {
            return CachedNetworkImage(
              imageUrl: fallbackUrl,
              width: width,
              height: height,
              fit: fit,
              errorWidget: (_, _, _) => _buildFallback(),
            );
          }
          return _buildFallback();
        },
      );
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildFallback() {
    if (fallbackAsset != null) {
      return Image.asset(
        fallbackAsset!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => _buildIconPlaceholder(),
      );
    }
    return _buildIconPlaceholder();
  }

  Widget _buildIconPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: AppColors.surfaceLight,
      child: Center(
        child: Icon(
          Icons.memory,
          size: (height != null && height! < 50) ? 20 : 36,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}
