// File: lib/features/quick_clean/widgets/suggestion_card.dart
import 'package:flutter/material.dart';

import '../../../core/model/cleanup_suggestion.dart';

class SuggestionCard extends StatefulWidget {
  final CleanupSuggestion suggestion;
  final bool isSelected;
  final Function(bool) onSelectionChanged;

  const SuggestionCard({
    super.key,
    required this.suggestion,
    required this.isSelected,
    required this.onSelectionChanged,
  });

  @override
  State<SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<SuggestionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _elevationAnimation = Tween<double>(begin: 1.0, end: 0.5).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        // FIX 1: Ensure elevation value is always positive and reasonable
        final elevationValue = _elevationAnimation.value.clamp(0.1, 1.0);

        return Transform.scale(
          scale: _scaleAnimation.value,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            margin: const EdgeInsets.only(bottom: 16),
            constraints: const BoxConstraints(minHeight: 120, maxHeight: 180),
            decoration: BoxDecoration(
              gradient: widget.isSelected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF667eea).withValues(alpha: 0.1),
                        const Color(0xFF764ba2).withValues(alpha: 0.05),
                      ],
                    )
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFFFFF), Color(0xFFFAFAFA)],
                    ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: widget.isSelected
                    ? const Color(0xFF667eea).withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.1),
                width: widget.isSelected ? 2.5 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.isSelected
                      ? const Color(0xFF667eea).withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.06),
                  // FIX 1: Ensure blur radius is always positive
                  blurRadius: widget.isSelected
                      ? (20 * elevationValue).clamp(1.0, double.infinity)
                      : (12 * elevationValue).clamp(1.0, double.infinity),
                  spreadRadius: widget.isSelected ? 2 : 0,
                  offset: Offset(
                    0,
                    widget.isSelected
                        ? (8 * elevationValue).clamp(1.0, double.infinity)
                        : (4 * elevationValue).clamp(1.0, double.infinity),
                  ),
                ),
                if (widget.isSelected)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    // FIX 1: Ensure blur radius is always positive
                    blurRadius: (8 * elevationValue).clamp(
                      1.0,
                      double.infinity,
                    ),
                    offset: Offset(
                      0,
                      (2 * elevationValue).clamp(1.0, double.infinity),
                    ),
                  ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => widget.onSelectionChanged(!widget.isSelected),
                onTapDown: (_) => _animationController.forward(),
                onTapUp: (_) => _animationController.reverse(),
                onTapCancel: () => _animationController.reverse(),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  // FIX 2: Use IntrinsicHeight and simplify layout
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Elegant custom checkbox
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.elasticOut,
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            gradient: widget.isSelected
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF667eea),
                                      Color(0xFF764ba2),
                                    ],
                                  )
                                : null,
                            color: widget.isSelected
                                ? null
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: widget.isSelected
                                  ? Colors.transparent
                                  : Colors.grey.withValues(alpha: 0.4),
                              width: 2,
                            ),
                            boxShadow: widget.isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF667eea,
                                      ).withValues(alpha: 0.3),
                                      // FIX 1: Fixed blur radius value
                                      blurRadius: (8 * elevationValue).clamp(
                                        1.0,
                                        double.infinity,
                                      ),
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: widget.isSelected
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 16,
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),

                        // Beautiful icon with gradient background
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: _getPriorityGradient(
                              widget.suggestion.priority,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: _getPriorityColor(
                                  widget.suggestion.priority,
                                ).withValues(alpha: 0.3),
                                // FIX 1: Fixed blur radius value
                                blurRadius: (8 * elevationValue).clamp(
                                  1.0,
                                  double.infinity,
                                ),
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            _getTypeIcon(widget.suggestion.type),
                            color: Colors.white,
                            size: 24,
                          ),
                        ),

                        const SizedBox(width: 16),

                        // FIX 2: Simplified content section without nested Row issues
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // FIX 2: Title and priority badge with proper constraints
                              Row(
                                children: [
                                  // Title takes most of the space
                                  Expanded(
                                    child: Text(
                                      widget.suggestion.title,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.3,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // FIX 2: Priority badge with flexible sizing
                                  Flexible(
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        maxWidth: 80,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: _getPriorityGradient(
                                          widget.suggestion.priority,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _getPriorityColor(
                                              widget.suggestion.priority,
                                            ).withValues(alpha: 0.2),
                                            // FIX 1: Fixed blur radius value
                                            blurRadius: 4.0,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        widget.suggestion.priority.name
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // Description with strict overflow handling
                              Text(
                                widget.suggestion.description,
                                style: TextStyle(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  height: 1.3,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                              const SizedBox(height: 12),
                              // FIX 2: Bottom badges with proper wrapping and width constraints
                              SizedBox(
                                width: double.infinity,
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF56ab2f),
                                            Color(0xFFa8e6cf),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF56ab2f,
                                            ).withValues(alpha: 0.2),
                                            // FIX 1: Fixed blur radius value
                                            blurRadius: 4.0,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        _formatBytes(
                                          widget.suggestion.size.toInt(),
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.grey.withValues(alpha: 0.1),
                                            Colors.grey.withValues(alpha: 0.05),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.grey.withValues(
                                            alpha: 0.2,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        '${widget.suggestion.itemCount} items',
                                        style: TextStyle(
                                          color: Colors.black.withValues(
                                            alpha: 0.7,
                                          ),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
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

  LinearGradient _getPriorityGradient(Priority priority) {
    switch (priority) {
      case Priority.high:
        return const LinearGradient(
          colors: [Color(0xFFff9a9e), Color(0xFFfad0c4)],
        );
      case Priority.medium:
        return const LinearGradient(
          colors: [Color(0xFFffecd2), Color(0xFFfcb69f)],
        );
      case Priority.low:
        return const LinearGradient(
          colors: [Color(0xFF56ab2f), Color(0xFFa8e6cf)],
        );
    }
  }

  Color _getPriorityColor(Priority priority) {
    switch (priority) {
      case Priority.high:
        return const Color(0xFFff9a9e);
      case Priority.medium:
        return const Color(0xFFffecd2);
      case Priority.low:
        return const Color(0xFF56ab2f);
    }
  }

  IconData _getTypeIcon(CleanupType type) {
    switch (type) {
      case CleanupType.photos:
        return Icons.photo_library_rounded;
      case CleanupType.videos:
        return Icons.video_library_rounded;
      case CleanupType.cache:
        return Icons.cached_rounded;
      case CleanupType.other:
        return Icons.delete_sweep_rounded;
      default:
        return Icons.folder_rounded;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
