
// File: lib/features/storage_analysis/widgets/category_list_item.dart
import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/model/storage_info.dart';
import '../../../core/utils/ui_utils.dart';
import '../../../shared/widgets/custom_card.dart';

class CategoryListItem extends StatelessWidget {
  final StorageCategory category;
  final double totalStorage;

  const CategoryListItem({super.key, required this.category, required this.totalStorage});

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 12, height: 12,
            decoration: BoxDecoration(color: _getCategoryColor(category.name), shape: BoxShape.circle),
          ),
          const SizedBox(width: 16),
          Icon(UIUtils.getTypeIcon(category.name), color: AppTheme.textSecondary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category.name, style: AppTheme.bodyLarge),
                Text('${category.itemCount} items', style: AppTheme.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${category.size.toStringAsFixed(1)} GB',
                  style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
              Text('${category.percentage.toStringAsFixed(1)}%', style: AppTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'photos': return AppTheme.primaryColor;
      case 'videos': return AppTheme.secondaryColor;
      case 'apps': return AppTheme.successColor;
      case 'music': return AppTheme.warningColor;
      case 'documents': return AppTheme.errorColor;
      default: return Colors.grey;
    }
  }
}