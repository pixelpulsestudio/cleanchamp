// File: lib/features/photo_cleanup/widgets/tinder_photo_card.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/model/photo_item.dart';

class TinderPhotoCard extends StatefulWidget {
  final PhotoItem photo;
  final Uint8List? thumbnail;
  final VoidCallback? onKeep;
  final VoidCallback? onDelete;
  final VoidCallback? onSkip;
  final bool isInteractive;

  const TinderPhotoCard({
    Key? key,
    required this.photo,
    this.thumbnail,
    this.onKeep,
    this.onDelete,
    this.onSkip,
    this.isInteractive = true,
  }) : super(key: key);

  @override
  State<TinderPhotoCard> createState() => _TinderPhotoCardState();
}

class _TinderPhotoCardState extends State<TinderPhotoCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _swipeController;
  late Animation<Offset> _swipeAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  double _swipeThreshold = 0.3;

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _swipeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.easeInOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _swipeController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    if (!widget.isInteractive) return;
    _isDragging = true;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!widget.isInteractive || !_isDragging) return;

    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!widget.isInteractive || !_isDragging) return;

    _isDragging = false;

    final screenWidth = MediaQuery.of(context).size.width;
    final threshold = screenWidth * _swipeThreshold;

    if (_dragOffset.dx > threshold) {
      // Swipe right - Keep
      _swipeRight();
    } else if (_dragOffset.dx < -threshold) {
      // Swipe left - Delete
      _swipeLeft();
    } else {
      // Return to center
      _resetPosition();
    }
  }

  void _swipeLeft() {
    _swipeAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: const Offset(-2.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.easeInOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: _dragOffset.dx * 0.0003,
      end: -0.5,
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.easeInOut,
    ));

    _swipeController.forward().then((_) {
      widget.onDelete?.call();
    });
  }

  void _swipeRight() {
    _swipeAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: const Offset(2.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.easeInOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: _dragOffset.dx * 0.0003,
      end: 0.5,
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.easeInOut,
    ));

    _swipeController.forward().then((_) {
      widget.onKeep?.call();
    });
  }

  void _resetPosition() {
    _swipeAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.elasticOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: _dragOffset.dx * 0.0003,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.elasticOut,
    ));

    _swipeController.forward().then((_) {
      _swipeController.reset();
      setState(() {
        _dragOffset = Offset.zero;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final cardHeight = screenSize.height * 0.6;
    final cardWidth = screenSize.width - 32;

    return AnimatedBuilder(
      animation: _swipeController,
      builder: (context, child) {
        final offset = _isDragging ? _dragOffset : _swipeAnimation.value;
        final rotation = _isDragging
            ? _dragOffset.dx * 0.0003
            : _rotationAnimation.value;
        final scale = _isDragging ? 1.0 : _scaleAnimation.value;

        return Transform.translate(
          offset: Offset(offset.dx, offset.dy),
          child: Transform.rotate(
            angle: rotation,
            child: Transform.scale(
              scale: scale,
              child: GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: Container(
                  width: cardWidth,
                  height: cardHeight,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        // Main image
                        _buildImageContent(cardWidth, cardHeight),

                        // Swipe indicators
                        _buildSwipeIndicators(offset.dx),

                        // Photo info overlay
                        _buildPhotoInfo(),

                        // Action buttons (bottom)
                        if (widget.isInteractive) _buildActionButtons(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageContent(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: AppTheme.backgroundColor,
      child: widget.thumbnail != null
          ? Image.memory(
        widget.thumbnail!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(),
      )
          : FutureBuilder<ImageProvider?>(
        future: _loadImageProvider(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingPlaceholder();
          } else if (snapshot.hasError || !snapshot.hasData) {
            return _buildErrorPlaceholder();
          } else {
            return Image(
              image: snapshot.data!,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildErrorPlaceholder(),
            );
          }
        },
      ),
    );
  }

  Future<ImageProvider?> _loadImageProvider() async {
    try {
      final file = File(widget.photo.path);
      if (await file.exists()) {
        return FileImage(file);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Widget _buildLoadingPlaceholder() {
    return Container(
      color: AppTheme.textSecondary.withValues(alpha: 0.1),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: AppTheme.textSecondary.withValues(alpha: 0.1),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            size: 64,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Unable to load image',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            widget.photo.name,
            style: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeIndicators(double dragX) {
    return Stack(
      children: [
        // Left swipe indicator (Delete)
        if (dragX < -50)
          Positioned(
            left: 20,
            top: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.errorColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'DELETE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Right swipe indicator (Keep)
        if (dragX > 50)
          Positioned(
            right: 20,
            top: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.successColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'KEEP',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPhotoInfo() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.6),
              Colors.transparent,
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quality indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getQualityColor().withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getQualityIcon(),
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _getQualityText(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            if (widget.photo.isDuplicate) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.content_copy, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'DUPLICATE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Photo details
            Text(
              widget.photo.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${(widget.photo.size / (1024 * 1024)).toStringAsFixed(1)} MB • ${_formatDate(widget.photo.dateModified)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
            if (widget.photo.aiSuggestion.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                widget.photo.aiSuggestion,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 16),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  color: AppTheme.errorColor,
                  onTap: widget.onDelete,
                ),
                _buildActionButton(
                  icon: Icons.skip_next_outlined,
                  label: 'Skip',
                  color: AppTheme.warningColor,
                  onTap: widget.onSkip,
                ),
                _buildActionButton(
                  icon: Icons.favorite_outline,
                  label: 'Keep',
                  color: AppTheme.successColor,
                  onTap: widget.onKeep,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getQualityColor() {
    switch (widget.photo.quality) {
      case AIPhotoQuality.blurry:
        return AppTheme.errorColor;
      case AIPhotoQuality.poor:
        return AppTheme.warningColor;
      case AIPhotoQuality.poor:
        return Colors.orange;
      case AIPhotoQuality.good:
      default:
        return AppTheme.successColor;
    }
  }

  IconData _getQualityIcon() {
    switch (widget.photo.quality) {
      case AIPhotoQuality.blurry:
        return Icons.blur_on;
      case AIPhotoQuality.poor:
        return Icons.low_priority;
      case AIPhotoQuality.poor:
        return Icons.brightness_low;
      case AIPhotoQuality.good:
      default:
        return Icons.check_circle;
    }
  }

  String _getQualityText() {
    switch (widget.photo.quality) {
      case AIPhotoQuality.blurry:
        return 'BLURRY';
      case AIPhotoQuality.poor:
        return 'LOW QUALITY';
      case AIPhotoQuality.good:
        return 'GOOD';
      case AIPhotoQuality.excellent:
        return 'EXCELLENT';
      default:
        return 'Unknown';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else if (difference < 30) {
      final weeks = (difference / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else if (difference < 365) {
      final months = (difference / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else {
      final years = (difference / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    }
  }
}