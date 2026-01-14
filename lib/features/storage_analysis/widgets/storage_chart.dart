
// File: lib/features/storage_analysis/widgets/storage_chart.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/app_theme.dart';
import '../../../core/model/storage_info.dart';

class StorageChart extends StatelessWidget {
  final List<StorageCategory> categories;

  const StorageChart({super.key, required this.categories});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: AppTheme.cardDecoration,
      child: CustomPaint(
        painter: PieChartPainter(categories),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Storage Usage', style: AppTheme.bodySmall),
              Text('${categories.fold(0.0, (sum, cat) => sum + cat.size).toStringAsFixed(1)} GB',
                  style: AppTheme.headingSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class PieChartPainter extends CustomPainter {
  final List<StorageCategory> categories;

  PieChartPainter(this.categories);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;

    double startAngle = -math.pi / 2;
    final colors = [
      AppTheme.primaryColor, AppTheme.secondaryColor, AppTheme.successColor,
      AppTheme.warningColor, AppTheme.errorColor, Colors.grey,
    ];

    for (int i = 0; i < categories.length; i++) {
      final category = categories[i];
      final sweepAngle = (category.percentage / 100) * 2 * math.pi;

      final paint = Paint()..color = colors[i % colors.length]..style = PaintingStyle.fill;

      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, true, paint);
      startAngle += sweepAngle;
    }

    // Draw inner circle for donut effect
    final innerPaint = Paint()..color = AppTheme.backgroundColor..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.6, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}