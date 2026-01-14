// File: lib/features/storage_analysis/views/storage_analysis_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_theme.dart';
import '../../../core/model/storage_info.dart';
import '../../../core/utils/file_utils.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../controllers/storage_analysis_controller.dart';
import '../widgets/category_list_item.dart';
import '../widgets/storage_chart.dart';

class StorageAnalysisScreen extends StatefulWidget {
  const StorageAnalysisScreen({super.key});

  @override
  State<StorageAnalysisScreen> createState() => _StorageAnalysisScreenState();
}

class _StorageAnalysisScreenState extends State<StorageAnalysisScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StorageAnalysisController>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: 'Storage Analysis',
        actions: [
          Consumer<StorageAnalysisController>(
            builder: (context, controller, child) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: controller.isLoading ? null : () => controller.forceRefresh(),
                tooltip: 'Refresh Storage Info',
              );
            },
          ),
        ],
      ),
      body: Consumer<StorageAnalysisController>(
        builder: (context, controller, child) {
          if (controller.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          if (controller.error != null) {
            return _buildErrorView(controller.error!);
          }

          final storageInfo = controller.storageInfo;
          if (storageInfo == null) {
            return const Center(child: Text('No storage data available'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStorageOverview(storageInfo),
                const SizedBox(height: 24),
                StorageChart(categories: storageInfo.categories),
                const SizedBox(height: 24),
                Text('Storage Breakdown', style: AppTheme.headingSmall),
                const SizedBox(height: 16),
                ...storageInfo.categories.map(
                      (category) => CategoryListItem(
                    category: category,
                    totalStorage: storageInfo.totalStorage,
                  ),
                ),
                const SizedBox(height: 24),
                _buildCleanupSuggestions(controller),
              ],
            ),
          );
        },
      ),
    );
  }

// In the _buildStorageOverview method, add validation:
  Widget _buildStorageOverview(StorageInfo storageInfo) {
    // Add validation to prevent division by zero or negative values
    final totalStorage = storageInfo.totalStorage > 0 ? storageInfo.totalStorage : 1.0;
    final usedStorage = storageInfo.usedStorage >= 0 ? storageInfo.usedStorage : 0.0;
    final availableStorage = storageInfo.availableStorage >= 0 ? storageInfo.availableStorage : 0.0;
    final usagePercentage = (usedStorage / totalStorage) * 100;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.gradientCardDecoration,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStorageItem(
                'Total',
                '${totalStorage.toStringAsFixed(1)} GB',
                Colors.white,
              ),
              _buildStorageItem(
                'Used',
                '${usedStorage.toStringAsFixed(1)} GB',
                Colors.white70,
              ),
              _buildStorageItem(
                'Free',
                '${availableStorage.toStringAsFixed(1)} GB',
                Colors.white70,
              ),
            ],
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: usagePercentage / 100,
            backgroundColor: Colors.white.withOpacity(0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            '${usagePercentage.toStringAsFixed(1)}% used',
            style: AppTheme.bodyMedium.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
  Widget _buildStorageItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: AppTheme.headingSmall.copyWith(color: color)),
        Text(label, style: AppTheme.bodySmall.copyWith(color: color)),
      ],
    );
  }

  Widget _buildCleanupSuggestions(StorageAnalysisController controller) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cleanup Potential', style: AppTheme.headingSmall),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(
                Icons.cleaning_services,
                color: AppTheme.primaryColor,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimated cleanup potential',
                      style: AppTheme.bodyMedium,
                    ),
                    Text(
                      '${controller.cleanupPotential.toStringAsFixed(1)} GB',
                      style: AppTheme.headingSmall.copyWith(
                        color: AppTheme.successColor,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/quick-clean'),
                child: const Text('Start Cleanup'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
          const SizedBox(height: 16),
          Text('Error loading storage data', style: AppTheme.headingMedium),
          const SizedBox(height: 8),
          Text(error, style: AppTheme.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () =>
                context.read<StorageAnalysisController>().loadStorageInfo(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
