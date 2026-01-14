
// File: lib/features/storage_analysis/controllers/storage_analysis_controller.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/model/storage_info.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/analytics_service.dart';

class StorageAnalysisController extends ChangeNotifier {
  final StorageService _storageService = serviceLocator<StorageService>();
  final AnalyticsService _analyticsService = serviceLocator<AnalyticsService>();

  StorageInfo? _storageInfo;
  double _cleanupPotential = 0.0;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<StorageInfo>? _storageSubscription;

  StorageInfo? get storageInfo => _storageInfo;
  double get cleanupPotential => _cleanupPotential;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isScanning => _storageInfo?.isScanning ?? false;

  Future<void> initialize() async {
    await _analyticsService.trackScreenView('storage_analysis');
    await loadStorageInfo();
    _setupRealTimeUpdates();
    await calculateCleanupPotential();
  }

// Add this method to the StorageAnalysisController class
  Future<void> loadStorageInfo({bool forceRefresh = false}) async {
    _setLoading(true);
    try {
      // Use the method that bypasses storage_space package for better reliability
      _storageInfo = await _storageService.getStorageInfoWithoutStorageSpace(forceRefresh: forceRefresh);
      _error = null;

      // Enhanced debug logging
      if (_storageInfo != null) {
        print('Storage Analysis Controller - Storage loaded:');
        print('- Total: ${_storageInfo!.totalStorage.toStringAsFixed(2)} GB');
        print('- Used: ${_storageInfo!.usedStorage.toStringAsFixed(2)} GB');
        print('- Available: ${_storageInfo!.availableStorage.toStringAsFixed(2)} GB');
        print('- Usage: ${_storageInfo!.usagePercentage.toStringAsFixed(1)}%');
        print('- Categories: ${_storageInfo!.categories.length}');
        print('- Discovered paths: ${_storageInfo!.discoveredPaths}');

        // Log category details
        for (var category in _storageInfo!.categories) {
          print('  - ${category.name}: ${category.size.toStringAsFixed(2)} GB (${category.percentage.toStringAsFixed(1)}%)');
        }
      }

      // If we got basic storage info but categories are empty, trigger a refresh
      if (_storageInfo != null && _hasEmptyCategories() && !forceRefresh) {
        print('Categories are empty, triggering background refresh...');
        // Trigger background scan for detailed data
        Future.delayed(Duration.zero, () async {
          try {
            await _storageService.getStorageInfoWithoutStorageSpace(forceRefresh: true);
          } catch (e) {
            print('Background refresh error: $e');
          }
        });
      }
    } catch (e) {
      _error = e.toString();
      print('Storage Analysis Error: $e');
    } finally {
      _setLoading(false);
    }
  }
  bool _hasEmptyCategories() {
    if (_storageInfo?.categories == null) return true;
    return _storageInfo!.categories.every((category) => category.size == 0);
  }

  void _setupRealTimeUpdates() {
    _storageSubscription = _storageService.storageStream.listen(
          (updatedInfo) {
        _storageInfo = updatedInfo;
        notifyListeners();

        // Recalculate cleanup potential when storage info updates
        if (!updatedInfo.isScanning) {
          calculateCleanupPotential();
        }
      },
      onError: (error) {
        print('Storage stream error: $error');
      },
    );
  }

  Future<void> calculateCleanupPotential() async {
    try {
      _cleanupPotential = await _storageService.calculateCleanupPotential();
      notifyListeners();
    } catch (e) {
      print('Cleanup calculation error: $e');
      // Silent fail for cleanup potential calculation
    }
  }

  Future<void> refreshAnalysis() async {
    await _analyticsService.trackUserBehavior('refresh_storage_analysis');
    await loadStorageInfo(forceRefresh: true);
    await calculateCleanupPotential();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Method to force refresh storage info
  Future<void> forceRefresh() async {
    _setLoading(true);
    try {
      _storageInfo = await _storageService.getStorageInfoWithoutStorageSpace(forceRefresh: true);
      _error = null;
      print('Storage info force refreshed successfully');
    } catch (e) {
      _error = e.toString();
      print('Force refresh error: $e');
    } finally {
      _setLoading(false);
    }
  }

  @override
  void dispose() {
    _storageSubscription?.cancel();
    super.dispose();
  }
}