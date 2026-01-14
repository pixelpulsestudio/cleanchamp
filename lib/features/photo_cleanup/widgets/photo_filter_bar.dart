import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/model/photo_item.dart';

class PhotoFilterBar extends StatelessWidget {
  final PhotoFilter currentFilter;
  final Function(PhotoFilter) onFilterChanged;

  const PhotoFilterBar({
    super.key,
    required this.currentFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: PhotoFilter.values.map((filter) {
          final isSelected = currentFilter == filter;
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(_getFilterLabel(filter)),
              selected: isSelected,
              onSelected: (_) => onFilterChanged(filter),
              selectedColor: AppTheme.primaryColor.withOpacity(0.2),
              checkmarkColor: AppTheme.primaryColor,
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getFilterLabel(PhotoFilter filter) {
    switch (filter) {
      case PhotoFilter.all:
        return 'All';
      case PhotoFilter.duplicates:
        return 'Duplicates';
      case PhotoFilter.large:
        return 'Large';
      case PhotoFilter.blurry:
        return 'Blurry';
      case PhotoFilter.screenshots:
        return 'Screenshots';
    }
  }
}
