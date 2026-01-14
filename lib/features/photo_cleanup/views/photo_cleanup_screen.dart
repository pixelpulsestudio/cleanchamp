/*
// File: lib/features/photo_cleanup/views/photo_cleanup_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../../../core/app_theme.dart';
import '../../../core/model/photo_item.dart';
import '../../../core/utils/ui_utils.dart';
import '../../../core/utils/file_utils.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../controllers/photo_cleanup_controller.dart';
import '../widgets/photo_filter_bar.dart';
import '../widgets/photo_grid_item.dart';

class PhotoCleanupScreen extends StatefulWidget {
  const PhotoCleanupScreen({super.key});

  @override
  State<PhotoCleanupScreen> createState() => _PhotoCleanupScreenState();
}

class _PhotoCleanupScreenState extends State<PhotoCleanupScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {

  final ScrollController _scrollController = ScrollController();
  bool _isAppInBackground = false;

  @override
  bool get wantKeepAlive => true; // Keep screen alive to maintain state

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize controller with smart state management
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<PhotoCleanupController>();

      // Smart initialization - only load if not already initialized
      if (!controller.isInitialized) {
        controller.initialize();
      } else {
        // Controller already has data, just update UI
        setState(() {});
      }
    });

    // Setup scroll listener for infinite scroll
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _isAppInBackground = true;
        break;
      case AppLifecycleState.resumed:
        if (_isAppInBackground) {
          _isAppInBackground = false;
          // Refresh data when app comes back to foreground (optional)
          _refreshIfNeeded();
        }
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _refreshIfNeeded() {
    // Only refresh if user has been away for a significant time
    // This prevents unnecessary reloads on quick app switches
    final controller = context.read<PhotoCleanupController>();

    // Add logic here to check if refresh is needed
    // For now, we'll keep the existing state
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      // Load more when user is 300px from bottom
      context.read<PhotoCleanupController>().loadMorePhotos();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: 'Photo Cleanup',
        actions: [
          Consumer<PhotoCleanupController>(
            builder: (context, controller, child) {
              if (controller.isInitialized && !controller.isLoading) {
                return Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _navigateToRecycleBin,
                      tooltip: 'Recycle Bin',
                    ),
                    IconButton(
                      icon: const Icon(Icons.swipe),
                      onPressed: () => _navigateToTinderMode(controller),
                      tooltip: 'Tinder Mode',
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () => _showRefreshOptions(controller),
                      tooltip: 'Refresh',
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<PhotoCleanupController>(
        builder: (context, controller, child) {
          // Show initial loading only if not initialized
          if (controller.isLoading && !controller.isInitialized) {
            return _buildInitialLoadingView(controller);
          }

          if (controller.error != null && !controller.isInitialized) {
            return _buildErrorView(controller.error!, controller);
          }

          if (controller.filteredPhotos.isEmpty && controller.isInitialized) {
            return _buildEmptyView(controller);
          }

          return Column(
            children: [
              _buildSummaryCard(controller),
              PhotoFilterBar(
                currentFilter: controller.currentFilter,
                onFilterChanged: controller.setFilter,
              ),
              Expanded(
                child: _buildPhotoGrid(controller),
              ),
              _buildActionBar(controller),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPhotoGrid(PhotoCleanupController controller) {
    final photos = controller.paginatedPhotos;

    return RefreshIndicator(
      onRefresh: () => controller.refreshPhotos(),
      color: AppTheme.primaryColor,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1,
              ),
                              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  if (index >= photos.length) return null;

                  final photo = photos[index];
                  return RepaintBoundary(
                    child: PhotoGridItem(
                      key: ValueKey(photo.path),
                      photo: photo,
                      isSelected: controller.selectedPhotos.contains(photo),
                      onSelectionChanged: (selected) {
                        if (selected) {
                          controller.selectPhoto(photo);
                        } else {
                          controller.deselectPhoto(photo);
                        }
                      },
                      onVisibilityChanged: () {
                        // Update visible photos for viewport-based loading
                        final visiblePaths = photos
                            .skip(max(0, index - 5))
                            .take(10)
                            .map((p) => p.path)
                            .toSet();
                        controller.updateVisiblePhotos(visiblePaths);
                      },
                    ),
                  );
                },
                childCount: photos.length,
                addAutomaticKeepAlives: false, // Disable to reduce memory usage
                addRepaintBoundaries: false, // We're using RepaintBoundary manually
              ),
            ),
          ),

          // Loading indicator at bottom
          _buildBottomLoader(controller),
        ],
      ),
    );
  }

  Widget _buildBottomLoader(PhotoCleanupController controller) {
    if (!controller.canLoadMore() && !controller.isLoadingMore) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (controller.isLoadingMore)
              Column(
                children: [
                  const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Loading more photos...',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              )
            else if (controller.canLoadMore())
              ElevatedButton.icon(
                onPressed: controller.loadMorePhotos,
                icon: const Icon(Icons.expand_more),
                label: const Text('Load More'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),

            const SizedBox(height: 8),
            Text(
              controller.loadingStatusText,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),

            if (controller.cacheHitRate > 0) ...[
              const SizedBox(height: 4),
              Text(
                controller.cacheStatusText,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInitialLoadingView(PhotoCleanupController controller) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading your photos...',
            style: AppTheme.headingSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'This may take a moment for large photo libraries',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            controller.loadingStatusText,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(PhotoCleanupController controller) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration.copyWith(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  title: 'Photos',
                  value: '${controller.displayedPhotosCount}/${controller.totalPhotosCount}',
                  subtitle: FileUtils.formatBytes(controller.totalSize),
                  icon: Icons.photo_library,
                  color: AppTheme.primaryColor,
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: AppTheme.textSecondary.withOpacity(0.2),
              ),
              Expanded(
                child: _buildSummaryItem(
                  title: 'Selected',
                  value: '${controller.selectedPhotos.length}',
                  subtitle: FileUtils.formatBytes(controller.selectedSize),
                  icon: Icons.check_circle,
                  color: AppTheme.successColor,
                ),
              ),
            ],
          ),

          // Progress indicator
          if (controller.totalPhotosCount > 0) ...[
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Loading Progress',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      '${(controller.loadingProgress * 100).toInt()}%',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: controller.loadingProgress,
                  backgroundColor: AppTheme.textSecondary.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    controller.hasMorePhotos
                        ? AppTheme.primaryColor
                        : AppTheme.successColor,
                  ),
                ),
              ],
            ),
          ],

          if (controller.selectedPhotos.isNotEmpty) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showDeleteConfirmation(controller),
                icon: const Icon(Icons.delete),
                label: Text('Delete ${controller.selectedPhotos.length} Photos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(title, style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: AppTheme.headingSmall.copyWith(color: color)),
        Text(subtitle, style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildActionBar(PhotoCleanupController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Select Visible',
                Icons.select_all,
                controller.selectAll,
                AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                'Clear',
                Icons.clear,
                controller.clearSelection,
                AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                'Duplicates',
                Icons.copy,
                controller.selectDuplicates,
                AppTheme.warningColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
      String text,
      IconData icon,
      VoidCallback onPressed,
      Color color,
      ) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(text),
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _buildErrorView(String error, PhotoCleanupController controller) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to load photos',
              style: AppTheme.headingMedium,
            ),
            const SizedBox(height: 12),
            Text(
              error,
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => controller.refreshPhotos(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(PhotoCleanupController controller) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                size: 48,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              controller.currentFilter == PhotoFilter.all
                  ? 'No photos found'
                  : 'No ${_getFilterDisplayName(controller.currentFilter)} found',
              style: AppTheme.headingMedium,
            ),
            const SizedBox(height: 12),
            Text(
              controller.currentFilter == PhotoFilter.all
                  ? 'Your photo library appears to be empty or inaccessible'
                  : 'Try changing the filter to see more photos',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (controller.currentFilter != PhotoFilter.all)
                  ElevatedButton.icon(
                    onPressed: () => controller.setFilter(PhotoFilter.all),
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Show All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (controller.currentFilter != PhotoFilter.all)
                  const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => controller.refreshPhotos(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surfaceColor,
                    foregroundColor: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getFilterDisplayName(PhotoFilter filter) {
    switch (filter) {
      case PhotoFilter.all:
        return 'photos';
      case PhotoFilter.duplicates:
        return 'duplicates';
      case PhotoFilter.large:
        return 'large photos';
      case PhotoFilter.blurry:
        return 'blurry photos';
      case PhotoFilter.screenshots:
        return 'screenshots';
    }
  }

  void _showRefreshOptions(PhotoCleanupController controller) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Refresh Options',
              style: AppTheme.headingSmall,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.refresh, color: AppTheme.primaryColor),
              title: const Text('Refresh Current View'),
              subtitle: const Text('Reload visible photos'),
              onTap: () {
                Navigator.pop(context);
                // Just reload current page without clearing cache
                controller.notifyListeners();
              },
            ),
            ListTile(
              leading: const Icon(Icons.sync, color: AppTheme.warningColor),
              title: const Text('Full Refresh'),
              subtitle: const Text('Rescan all photos and clear cache'),
              onTap: () {
                Navigator.pop(context);
                controller.refreshPhotos();
              },
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(PhotoCleanupController controller) {
    final count = controller.selectedPhotos.length;
    final size = FileUtils.formatBytes(controller.selectedSize);

    UIUtils.showConfirmDialog(
      context,
      title: 'Delete Photos',
      content: 'Are you sure you want to permanently delete $count photos ($size)?\n\nThis action cannot be undone.',
      confirmText: 'Delete',
      confirmColor: AppTheme.errorColor,
    ).then((confirmed) {
      if (confirmed == true) {
        controller.deleteSelectedPhotos().then((_) {
          if (mounted && controller.error == null) {
            UIUtils.showSuccessSnackBar(
              context,
              'Successfully deleted $count photos',
            );
          } else if (mounted && controller.error != null) {
            UIUtils.showErrorSnackBar(
              context,
              controller.error!,
            );
          }
        });
      }
    });
  }

  void _navigateToTinderMode(PhotoCleanupController controller) {
    Navigator.pushNamed(context, '/tinder_mode');
  }

  void _navigateToRecycleBin() {
    Navigator.pushNamed(context, '/recycle_bin');
  }
}*/
