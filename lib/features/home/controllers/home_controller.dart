// File: lib/features/home/controllers/home_controller.dart
import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/model/storage_info.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/analytics_service.dart';

class HomeController extends ChangeNotifier {
  final StorageService _storageService = serviceLocator<StorageService>();
  final AnalyticsService _analyticsService = serviceLocator<AnalyticsService>();

  StorageInfo? _storageInfo;
  bool _isLoading = false;
  String? _error;
  StreamSubscription<StorageInfo>? _storageSubscription;

  StorageInfo? get storageInfo => _storageInfo;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isScanning => _storageInfo?.isScanning ?? false;

  Future<void> initialize() async {
    await _analyticsService.trackScreenView('home');
    await loadStorageInfo();
    _setupRealTimeUpdates();

    final storageService = StorageService();
    final info = await storageService.getStorageInfo(forceRefresh: true);
    print('Storage Info: ${info.toJson()}');



  }

  Future<void> loadStorageInfo({bool forceRefresh = false}) async {
    _setLoading(true);
    try {
      // Use the method that bypasses storage_space package for better reliability
      _storageInfo = await _storageService.getStorageInfoWithoutStorageSpace(forceRefresh: forceRefresh);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshStorageInfo() async {
    await _analyticsService.trackUserBehavior('refresh_storage');
    await loadStorageInfo(forceRefresh: true);
  }

  void _setupRealTimeUpdates() {
    _storageSubscription = _storageService.storageStream.listen(
          (updatedInfo) {
        _storageInfo = updatedInfo;
        notifyListeners();
      },
    );
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  @override
  void dispose() {
    _storageSubscription?.cancel();
    super.dispose();
  }
}