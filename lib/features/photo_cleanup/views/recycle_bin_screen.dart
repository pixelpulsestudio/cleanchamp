// File: lib/features/photo_cleanup/views/recycle_bin_screen.dart
import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../services/recycle_bin_service.dart';
import '../../../core/utils/ui_utils.dart';

class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  late RecycleBinService _recycleBinService;
  List<RecycleBinItem> _items = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _recycleBinService = RecycleBinService();
    _loadRecycleBinData();
  }

  Future<void> _loadRecycleBinData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 500)); // Simulate loading
      final items = _recycleBinService.getRecycleBinItems();
      final stats = _recycleBinService.getRecycleBinStats();

      setState(() {
        _items = items;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      UIUtils.showErrorSnackBar(context, 'Failed to load recycle bin: $e');
    }
  }

  Future<void> _restoreItem(RecycleBinItem item) async {
    try {
      final success = await _recycleBinService.restoreFromRecycleBin(item.id);
      if (success) {
        UIUtils.showSuccessSnackBar(context, 'Item restored successfully');
        _loadRecycleBinData(); // Reload data
      } else {
        UIUtils.showErrorSnackBar(context, 'Failed to restore item');
      }
    } catch (e) {
      UIUtils.showErrorSnackBar(context, 'Error restoring item: $e');
    }
  }

  Future<void> _permanentlyDeleteItem(RecycleBinItem item) async {
    final confirmed = await UIUtils.showConfirmDialog(
      context,
      title: 'Permanently Delete',
      content: 'Are you sure you want to permanently delete "${item.originalName}"?\n\nThis action cannot be undone.',
      confirmText: 'Delete Permanently',
      confirmColor: AppTheme.errorColor,
    );

    if (confirmed == true) {
      try {
        final success = await _recycleBinService.permanentlyDelete(item.id);
        if (success) {
          UIUtils.showSuccessSnackBar(context, 'Item deleted permanently');
          _loadRecycleBinData(); // Reload data
        } else {
          UIUtils.showErrorSnackBar(context, 'Failed to delete item');
        }
      } catch (e) {
        UIUtils.showErrorSnackBar(context, 'Error deleting item: $e');
      }
    }
  }

  Future<void> _emptyRecycleBin() async {
    final confirmed = await UIUtils.showConfirmDialog(
      context,
      title: 'Empty Recycle Bin',
      content: 'Are you sure you want to permanently delete all ${_items.length} items?\n\nThis action cannot be undone.',
      confirmText: 'Empty All',
      confirmColor: AppTheme.errorColor,
    );

    if (confirmed == true) {
      try {
        final success = await _recycleBinService.emptyRecycleBin();
        if (success) {
          UIUtils.showSuccessSnackBar(context, 'Recycle bin emptied');
          _loadRecycleBinData(); // Reload data
        } else {
          UIUtils.showErrorSnackBar(context, 'Failed to empty recycle bin');
        }
      } catch (e) {
        UIUtils.showErrorSnackBar(context, 'Error emptying recycle bin: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: 'Recycle Bin',
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              onPressed: _emptyRecycleBin,
              tooltip: 'Empty Recycle Bin',
            ),
        ],
      ),
      body: _isLoading ? _buildLoadingView() : _buildMainContent(),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: CircularProgressIndicator(
        color: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildMainContent() {
    if (_items.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        _buildStatsCard(),
        Expanded(
          child: _buildItemsList(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.delete_outline,
            size: 64,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'Recycle Bin is Empty',
            style: AppTheme.headingSmall.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Deleted items will appear here',
            ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recycle Bin Statistics',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem('Total Items', '${_stats['totalItems'] ?? 0}'),
              const SizedBox(width: 24),
              _buildStatItem('Total Size', '${(_stats['totalSizeGB'] ?? 0).toStringAsFixed(2)} GB'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatItem('Photos', '${_stats['photosCount'] ?? 0}'),
              const SizedBox(width: 24),
              _buildStatItem('Videos', '${_stats['videosCount'] ?? 0}'),
              const SizedBox(width: 24),
              _buildStatItem('Documents', '${_stats['documentsCount'] ?? 0}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTheme.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildItemsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return _buildItemCard(item);
      },
    );
  }

  Widget _buildItemCard(RecycleBinItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: _buildItemIcon(item.type),
        title: Text(
          item.originalName,
          style: AppTheme.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatFileSize(item.size),
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            Text(
              'Moved: ${_formatDate(item.dateMoved)}',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.restore, color: AppTheme.primaryColor),
              onPressed: () => _restoreItem(item),
              tooltip: 'Restore',
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever, color: AppTheme.errorColor),
              onPressed: () => _permanentlyDeleteItem(item),
              tooltip: 'Delete Permanently',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemIcon(RecycleBinItemType type) {
    IconData iconData;
    Color iconColor;

    switch (type) {
      case RecycleBinItemType.photo:
        iconData = Icons.photo;
        iconColor = AppTheme.primaryColor;
        break;
      case RecycleBinItemType.video:
        iconData = Icons.video_file;
        iconColor = AppTheme.warningColor;
        break;
      case RecycleBinItemType.document:
        iconData = Icons.description;
        iconColor = AppTheme.successColor;
        break;
      case RecycleBinItemType.other:
        iconData = Icons.insert_drive_file;
        iconColor = AppTheme.textSecondary;
        break;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 20,
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } else if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '$bytes B';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
} 