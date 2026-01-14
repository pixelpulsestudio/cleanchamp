// File: lib/features/video_cleanup/widgets/video_list_item.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/app_theme.dart';
import '../../../core/model/video_item.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/custom_card.dart';

class VideoListItem extends StatefulWidget {
  final VideoItem video;
  final bool isSelected;
  final Function(bool) onSelectionChanged;
  final VoidCallback? onTap;
  final String? thumbnail;
  final VoidCallback? onRefreshThumbnail;

  const VideoListItem({
    super.key,
    required this.video,
    required this.isSelected,
    required this.onSelectionChanged,
    this.onTap,
    this.thumbnail,
    this.onRefreshThumbnail,
  });

  @override
  State<VideoListItem> createState() => _VideoListItemState();
}

class _VideoListItemState extends State<VideoListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: GestureDetector(
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) {
            _controller.reverse();
            widget.onTap?.call();
          },
          onTapCancel: () => _controller.reverse(),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.isSelected
                    ? [
                  Colors.blue.shade100,
                  Colors.blue.shade50,
                  Colors.white,
                ]
                    : [
                  Colors.white,
                  Colors.grey.shade50,
                  Colors.white,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.isSelected
                      ? Colors.blue.shade200.withOpacity(0.3)
                      : Colors.black.withOpacity(0.06),
                  blurRadius: widget.isSelected ? 12 : 8,
                  offset: const Offset(0, 2),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.isSelected
                      ? Colors.blue.shade200
                      : Colors.grey.shade200,
                  width: widget.isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Checkbox, Thumbnail, Title, Tags
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Custom Checkbox
                      _buildCheckbox(),
                      const SizedBox(width: 10),

                      // Thumbnail
                      _buildThumbnail(),
                      const SizedBox(width: 10),

                      // Title and basic info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Video name
                            Text(
                              widget.video.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade900,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),

                            // Size and Duration in a clean row
                            Row(
                              children: [
                                _buildCompactInfo(
                                  FileUtils.formatBytes(widget.video.size),
                                  _getSizeColor(widget.video.size),
                                  Icons.storage_rounded,
                                ),
                                const SizedBox(width: 12),
                                _buildCompactInfo(
                                  FileUtils.formatDuration(widget.video.duration),
                                  Colors.grey.shade600,
                                  Icons.access_time_rounded,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Tags column
                      SizedBox(
                        width: 60,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (_isLargeVideo()) _buildLargeTag(),
                            if (_isOldVideo()) ...[
                              if (_isLargeVideo()) const SizedBox(height: 3),
                              _buildOldTag(),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Bottom Row: Resolution, Quality, Date, Action
                  Row(
                    children: [
                      // Resolution
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.grey.shade100,
                        ),
                        child: Text(
                          '${widget.video.width}×${widget.video.height}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),

                      const SizedBox(width: 6),

                      // Quality
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: _getQualityColor(widget.video.quality.name),
                        ),
                        child: Text(
                          widget.video.quality.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 9,
                          ),
                        ),
                      ),

                      const SizedBox(width: 6),

                      // Date
                      Expanded(
                        child: Text(
                          FileUtils.formatDate(widget.video.dateModified),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Action button
                      _buildActionButton(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onSelectionChanged(!widget.isSelected);
      },
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          gradient: widget.isSelected
              ? LinearGradient(
            colors: [Colors.blue.shade500, Colors.blue.shade600],
          )
              : null,
          color: widget.isSelected ? null : Colors.white,
          border: Border.all(
            color: widget.isSelected
                ? Colors.blue.shade500
                : Colors.grey.shade400,
            width: 1.5,
          ),
        ),
        child: widget.isSelected
            ? const Icon(
          Icons.check_rounded,
          color: Colors.white,
          size: 14,
        )
            : null,
      ),
    );
  }

  Widget _buildThumbnail() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            if (widget.thumbnail != null)
              Image.file(
                File(widget.thumbnail!),
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildDefaultThumbnail(),
              )
            else
              _buildDefaultThumbnail(),

            // Play icon overlay
            Center(
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),

            // Loading indicator for thumbnail
            if (widget.thumbnail == null)
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultThumbnail() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade200, Colors.grey.shade100],
        ),
      ),
      child: Icon(
        Icons.videocam_rounded,
        color: Colors.grey.shade400,
        size: 20,
      ),
    );
  }

  Widget _buildCompactInfo(String text, Color color, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: color,
          size: 10,
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLargeTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: Colors.red.shade500,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_rounded,
            color: Colors.white,
            size: 8,
          ),
          const SizedBox(width: 2),
          const Text(
            'LARGE',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 8,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOldTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: Colors.orange.shade500,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.schedule_rounded,
            color: Colors.white,
            size: 8,
          ),
          const SizedBox(width: 2),
          const Text(
            'OLD',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 8,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onRefreshThumbnail?.call();
      },
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(
          Icons.refresh_rounded,
          size: 14,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Color _getSizeColor(int size) {
    if (size > AppConstants.largVideoSizeMB * AppConstants.megabyte) {
      return Colors.red.shade600;
    }
    if (size > 50 * AppConstants.megabyte) {
      return Colors.orange.shade600;
    }
    return Colors.blue.shade600;
  }

  Color _getQualityColor(String quality) {
    switch (quality.toLowerCase()) {
      case '4k':
      case 'uhd':
        return Colors.purple.shade600;
      case 'hd':
      case '1080p':
      case '720p':
        return Colors.blue.shade600;
      case 'sd':
      case '480p':
      case '360p':
        return Colors.orange.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  bool _isLargeVideo() {
    return widget.video.size > AppConstants.largVideoSizeMB * AppConstants.megabyte;
  }

  bool _isOldVideo() {
    final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 180));
    return widget.video.dateModified.isBefore(sixMonthsAgo);
  }
}