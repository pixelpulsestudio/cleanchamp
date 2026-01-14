// File: lib/shared/widgets/progress_indicator_with_label.dart
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class ProgressIndicatorWithLabel extends StatelessWidget {
  final double progress;
  final String label;
  final Color? color;
  final Color? backgroundColor;

  const ProgressIndicatorWithLabel({
    super.key,
    required this.progress,
    required this.label,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTheme.bodyMedium),
            Text(
              '${(progress * 100).toInt()}%',
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: backgroundColor ?? Colors.white24,
          valueColor: AlwaysStoppedAnimation<Color>(
            color ?? AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }
}