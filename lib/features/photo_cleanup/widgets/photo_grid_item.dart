/*
// File: lib/features/photo_cleanup/widgets/photo_grid_item.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../../core/app_theme.dart';
import '../../../core/model/photo_item.dart';
import '../../../core/utils/file_utils.dart';
import '../controllers/photo_cleanup_controller.dart';
import 'package:provider/provider.dart';

class PhotoGridItem extends StatefulWidget {
  final PhotoItem photo;
  final bool isSelected;
  final Function(bool) onSelectionChanged;
  final VoidCallback? onVisibilityChanged;

  const PhotoGridItem({
    super.key,
    required this.photo,
    required this.isSelected,
    required this.onSelectionChanged,
    this.onVisibilityChanged,
  });

  @override
  State<PhotoGridItem> createState() => _PhotoGridItemState();
}

class _PhotoGridItemState extends State<PhotoGridItem>
    with AutomaticKeepAliveClientMixin {

  // Optimized state management
  bool _isVisible = false;
  bool _thumbnailLoaded = false;
  bool _thumbnailError = false;
  Uint8List? _thumbnailData;
  ImageProvider? _fallbackImageProvider;
  bool _fallbackLoaded = false;
  bool _fallbackError = false;

  @override
  bool get wantKeepAlive => _thumbnailLoaded || _fallbackLoaded;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(PhotoGridItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo.path != widget.photo.path) {
      _resetState();
      _loadThumbnail();
    }
  }

  void _resetState() {
    _thumbnailLoaded = false;
    _thumbnailError = false;
    _thumbnailData = null;
    _fallbackImageProvider = null;
    _fallbackLoaded = false;
    _fallbackError = false;
  }

  void _loadThumbnail() {
    if (_thumbnailLoaded || _thumbnailError) return;

    final controller = context.read<PhotoCleanupController>();

    // Check if thumbnail is already cached
    final cachedThumbnail = controller.getThumbnail(widget.photo.path);
    if (cachedThumbnail != null) {
      _thumbnailData = cachedThumbnail;
      _thumbnailLoaded = true;
      if (mounted) setState(() {});
      return;
    }

    // Check if thumbnail is loading
    if (controller.isThumbnailLoading(widget.photo.path)) {
      return;
    }

    // Check if thumbnail failed before
    if (controller.isThumbnailFailed(widget.photo.path)) {
      _loadFallbackImage();
      return;
    }

    // Load thumbnail asynchronously
    _loadThumbnailAsync(controller);
  }

  Future<void> _loadThumbnailAsync(PhotoCleanupController controller) async {
    try {
      final thumbnail = await controller.generateThumbnail(
          widget.photo.path,
          150,
          150
      );

      if (mounted) {
        if (thumbnail != null) {
          _thumbnailData = thumbnail;
          _thumbnailLoaded = true;
          // Use post frame callback to batch setState calls
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {});
          });
        } else {
          _thumbnailError = true;
          _loadFallbackImage();
        }
      }
    } catch (e) {
      if (mounted) {
        _thumbnailError = true;
        _loadFallbackImage();
      }
    }
  }

  void _loadFallbackImage() {
    if (_fallbackLoaded || _fallbackError) return;

    try {
      final file = File(widget.photo.path);
      if (file.existsSync()) {
        _fallbackImageProvider = FileImage(file);

        // Preload with error handling
        _fallbackImageProvider!.resolve(const ImageConfiguration()).addListener(
          ImageStreamListener(
                (ImageInfo image, bool synchronousCall) {
              if (mounted) {
                setState(() {
                  _fallbackLoaded = true;
                  _fallbackError = false;
                });
              }
            },
            onError: (dynamic error, StackTrace? stackTrace) {
              if (mounted) {
                setState(() {
                  _fallbackError = true;
                  _fallbackLoaded = false;
                });
              }
            },
          ),
        );
      } else {
        setState(() {
          _fallbackError = true;
        });
      }
    } catch (e) {
      setState(() {
        _fallbackError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return VisibilityDetector(
      key: Key(widget.photo.path),
      onVisibilityChanged: (info) {
        final wasVisible = _isVisible;
        _isVisible = info.visibleFraction > 0.1; // 10% visible threshold

        if (!wasVisible && _isVisible) {
          widget.onVisibilityChanged?.call();
        }
      },
      child: GestureDetector(
        onTap: () => widget.onSelectionChanged(!widget.isSelected),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected ? AppTheme.primaryColor : Colors.transparent,
              width: 3,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildImageContent(),
                _buildSelectionOverlay(),
                _buildInfoOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageContent() {
    // Show thumbnail if available
    if (_thumbnailLoaded && _thumbnailData != null) {
      return Image.memory(
        _thumbnailData!,
        fit: BoxFit.cover,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 150),
            child: child,
          );
        },
        errorBuilder: (context, error, stackTrace) {
          _thumbnailError = true;
          _loadFallbackImage();
          return _buildLoadingPlaceholder();
        },
      );
    }

    // Show fallback image if thumbnail failed
    if (_fallbackLoaded && _fallbackImageProvider != null) {
      return Image(
        image: _fallbackImageProvider!,
        fit: BoxFit.cover,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            child: child,
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorPlaceholder();
        },
      );
    }

    // Show error if both thumbnail and fallback failed
    if (_thumbnailError && _fallbackError) {
      return _buildErrorPlaceholder();
    }

    // Show loading placeholder
    return _buildLoadingPlaceholder();
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      color: AppTheme.textSecondary.withOpacity(0.1),
      child: const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: AppTheme.textSecondary.withOpacity(0.1),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image,
              color: AppTheme.textSecondary,
              size: 20,
            ),
            SizedBox(height: 2),
            Text(
              'Error',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionOverlay() {
    if (!widget.isSelected) return const SizedBox.shrink();

    return Container(
      color: AppTheme.primaryColor.withOpacity(0.3),
      child: const Center(
        child: Icon(
          Icons.check_circle,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildInfoOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.7),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              FileUtils.formatBytes(widget.photo.size),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_hasPhotoTags())
              Row(
                children: [
                  if (widget.photo.isDuplicate)
                    _buildTag('DUP', AppTheme.warningColor),
                  if (widget.photo.isDuplicate ?? false)
                    _buildTag('BLUR', AppTheme.errorColor),
                  if (widget.photo.isDuplicate ?? false)
                    _buildTag('SS', AppTheme.primaryColor),
                ],
              ),
          ],
        ),
      ),
    );
  }

  bool _hasPhotoTags() {
    return widget.photo.isDuplicate ||
        (widget.photo.isDuplicate ?? false) ||
        (widget.photo.isDuplicate ?? false);
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 2),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _thumbnailData = null;
    _fallbackImageProvider = null;
    super.dispose();
  }
}

// Simple visibility detector widget
class VisibilityDetector extends StatefulWidget {
  final Widget child;
  final Function(VisibilityInfo) onVisibilityChanged;

  const VisibilityDetector({
    super.key,
    required this.child,
    required this.onVisibilityChanged,
  });

  @override
  State<VisibilityDetector> createState() => _VisibilityDetectorState();
}

class _VisibilityDetectorState extends State<VisibilityDetector> {
  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Simple visibility detection based on scroll position
        // In a real app, you'd use a more sophisticated approach
        widget.onVisibilityChanged(VisibilityInfo(visibleFraction: 1.0));
        return false;
      },
      child: widget.child,
    );
  }
}

class VisibilityInfo {
  final double visibleFraction;

  VisibilityInfo({required this.visibleFraction});
}*/
