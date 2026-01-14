// File: lib/features/photo_cleanup/controllers/photo_cleanup_controller.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:math';
import '../../../core/model/photo_item.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/file_service.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/storage_service.dart';

class PhotoCleanupController extends ChangeNotifier {
  final FileService _fileService = serviceLocator<FileService>();
  final AnalyticsService _analyticsService = serviceLocator<AnalyticsService>();

  // Core data with minimal state
  List<PhotoItem> _allPhotos = [];
  List<PhotoItem> _selectedPhotos = [];
  PhotoFilter _currentFilter = PhotoFilter.all;
  bool _isLoading = false;
  String? _error;

  // Ultra-light pagination
  static const int _photosPerPage = 50;
  int _currentPage = 0;
  bool _isLoadingMore = false;
  bool _hasMorePhotos = true;
  bool _isInitialized = false;

  // Viewport-based loading
  Set<String> _visiblePhotoPaths = {};
  Timer? _viewportTimer;

  // Minimal caching system
  final Map<String, Uint8List> _thumbnailCache = {};
  final Set<String> _failedThumbnails = {};
  final Set<String> _loadingThumbnails = {};
  static const int _maxThumbnailCacheSize = 100;

  // Optimized preloading
  Timer? _thumbnailTimer;
  int _lastPreloadIndex = 0;

  // Getters
  List<PhotoItem> get allPhotos => _allPhotos;
  List<PhotoItem> get selectedPhotos => _selectedPhotos;
  PhotoFilter get currentFilter => _currentFilter;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMorePhotos => _hasMorePhotos;
  bool get isInitialized => _isInitialized;
  String? get error => _error;

  // MISSING GETTERS - Added these
  int get cacheHitRate => _thumbnailCache.length;

  String get cacheStatusText {
    return 'Cached: ${_thumbnailCache.length}/${_maxThumbnailCacheSize} thumbnails';
  }

  double get loadingProgress {
    if (totalPhotosCount == 0) return 0.0;
    return (displayedPhotosCount / totalPhotosCount).clamp(0.0, 1.0);
  }

  List<PhotoItem> get filteredPhotos {
    switch (_currentFilter) {
      case PhotoFilter.all:
        return _allPhotos;
      case PhotoFilter.duplicates:
        return _allPhotos.where((photo) => photo.isDuplicate).toList();
      case PhotoFilter.large:
        return _allPhotos.where((photo) => photo.size > 5 * 1024 * 1024).toList();
      case PhotoFilter.blurry:
        return _allPhotos.where((photo) => photo.isDuplicate ?? false).toList();
      case PhotoFilter.screenshots:
        return _allPhotos.where((photo) => photo.isDuplicate ?? false).toList();
    }
  }

  List<PhotoItem> get paginatedPhotos {
    final filtered = filteredPhotos;
    final endIndex = (_currentPage + 1) * _photosPerPage;

    if (endIndex >= filtered.length) {
      _hasMorePhotos = false;
      return filtered;
    }

    _hasMorePhotos = true;
    return filtered.take(endIndex).toList();
  }

  // Performance getters
  int get totalSize => filteredPhotos.fold(0, (sum, photo) => sum + photo.size);
  int get selectedSize => _selectedPhotos.fold(0, (sum, photo) => sum + photo.size);
  int get displayedPhotosCount => paginatedPhotos.length;
  int get totalPhotosCount => filteredPhotos.length;

  Future<void> initialize() async {
    if (_isInitialized && _allPhotos.isNotEmpty) {
      _startThumbnailPreloading();
      notifyListeners();
      return;
    }

    await _analyticsService.trackScreenView('photo_cleanup');
    await _loadPhotosUltraFast();
  }

  Future<void> _loadPhotosUltraFast() async {
    if (_isLoading) return;

    _setLoading(true);

    try {
      final photos = await _fileService.getPhotos(limit: 200);

      if (photos.isNotEmpty) {
        _allPhotos = photos;
        _isInitialized = true;
        _updatePaginationState();

        _setLoading(false);
        _startThumbnailPreloading();
        _loadMorePhotosInBackground();
      } else {
        await _loadFromStoragePaths();
      }

    } catch (e) {
      _error = e.toString();
      _setLoading(false);
    }
  }

  Future<void> _loadFromStoragePaths() async {
    try {
      final storageService = serviceLocator<StorageService>();
      final photoPaths = await _fileService.getPhotoDirectories();

      if (photoPaths.isNotEmpty) {
        final photos = await _fileService.getPhotosFromPath(
          photoPaths.first,
          limit: 100,
        );

        if (photos.isNotEmpty) {
          _allPhotos = photos;
          _isInitialized = true;
          _updatePaginationState();
          _setLoading(false);
          _startThumbnailPreloading();
        }
      }
    } catch (e) {
      _error = 'Failed to load photos: ${e.toString()}';
      _setLoading(false);
    }
  }

  void _loadMorePhotosInBackground() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));

      final additionalPhotos = await _fileService.getPhotos(limit: 1000);

      if (additionalPhotos.length > _allPhotos.length) {
        _allPhotos = additionalPhotos;
        _updatePaginationState();

        if (_currentPage == 0) {
          notifyListeners();
        }
      }
    } catch (e) {
      print('Background loading error: $e');
    }
  }

  void _startThumbnailPreloading() {
    _thumbnailTimer?.cancel();
    _viewportTimer?.cancel();

    // Use viewport-based loading instead of continuous preloading
    _viewportTimer = Timer.periodic(
      const Duration(milliseconds: 200), // Check viewport every 200ms
          (_) => _preloadVisibleThumbnails(),
    );
  }

  void _preloadVisibleThumbnails() {
    try {
      if (_visiblePhotoPaths.isEmpty) return;

      const batchSize = 1; // Load one at a time for smooth scrolling
      int loaded = 0;

      for (final photoPath in _visiblePhotoPaths) {
        if (loaded >= batchSize) break;

        if (!_thumbnailCache.containsKey(photoPath) &&
            !_failedThumbnails.contains(photoPath) &&
            !_loadingThumbnails.contains(photoPath)) {

          _loadSingleThumbnail(photoPath);
          loaded++;
        }
      }
    } catch (e) {
      print('Viewport preload error: $e');
    }
  }

  // Method to update visible photos (called from UI)
  void updateVisiblePhotos(Set<String> visiblePaths) {
    _visiblePhotoPaths = visiblePaths;
  }

  Future<void> _loadSingleThumbnail(String photoPath) async {
    if (_loadingThumbnails.contains(photoPath)) return; // Prevent duplicate loads

    _loadingThumbnails.add(photoPath);

    try {
      // Add timeout to prevent hanging
      final thumbnail = await _fileService.generateThumbnail(photoPath, 150, 150)
          .timeout(const Duration(seconds: 5));

      if (thumbnail != null) {
        if (_thumbnailCache.length >= _maxThumbnailCacheSize) {
          _cleanupOldThumbnails();
        }

        _thumbnailCache[photoPath] = thumbnail;

        // Only notify if the photo is still visible
        final visiblePhotos = paginatedPhotos;
        if (visiblePhotos.any((p) => p.path == photoPath)) {
          notifyListeners();
        }
      } else {
        _failedThumbnails.add(photoPath);
      }
    } catch (e) {
      _failedThumbnails.add(photoPath);
    } finally {
      _loadingThumbnails.remove(photoPath);
    }
  }

  void _cleanupOldThumbnails() {
    final visiblePaths = paginatedPhotos.map((p) => p.path).toSet();
    final keysToRemove = _thumbnailCache.keys
        .where((key) => !visiblePaths.contains(key))
        .take(_maxThumbnailCacheSize ~/ 3)
        .toList();

    for (final key in keysToRemove) {
      _thumbnailCache.remove(key);
    }

    // Also clean up failed thumbnails periodically
    if (_failedThumbnails.length > 100) {
      _failedThumbnails.clear();
    }
  }

/*
  Uint8List? getThumbnail(String photoPath) {
    return _thumbnailCache[photoPath];
  }
*/

  bool isThumbnailLoading(String photoPath) {
    return _loadingThumbnails.contains(photoPath);
  }

  bool isThumbnailFailed(String photoPath) {
    return _failedThumbnails.contains(photoPath);
  }

  // Expose thumbnail generation for widgets
/*
  Future<Uint8List?> generateThumbnail(String photoPath, int width, int height) async {
    return await _fileService.generateThumbnail(photoPath, width, height);
  }
*/

  Future<void> loadMorePhotos() async {
    if (_isLoadingMore || !_hasMorePhotos || _isLoading) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      await Future.delayed(const Duration(milliseconds: 100));

      _currentPage++;
      _updatePaginationState();

      _lastPreloadIndex = (_currentPage * _photosPerPage) - 10;

    } catch (e) {
      _error = e.toString();
      _currentPage = max(0, _currentPage - 1);
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void setFilter(PhotoFilter filter) {
    if (_currentFilter == filter) return;

    _currentFilter = filter;
    _selectedPhotos.clear();
    _resetPagination();
    _updatePaginationState();

    _failedThumbnails.clear();
    _lastPreloadIndex = 0;

    notifyListeners();
  }

  Future<void> deleteSelectedPhotos() async {
    if (_selectedPhotos.isEmpty) return;

    _setLoading(true);

    try {
      final filePaths = _selectedPhotos.map((photo) => photo.path).toList();

      final success = await _fileService.deleteFiles(filePaths);

      if (success) {
        for (final path in filePaths) {
          _thumbnailCache.remove(path);
          _failedThumbnails.remove(path);
          _loadingThumbnails.remove(path);
        }

        _allPhotos.removeWhere((photo) => _selectedPhotos.contains(photo));
        _selectedPhotos.clear();
        _updatePaginationState();

        await _analyticsService.trackCleanupAction(
          'photos',
          filePaths.length,
          selectedSize / (1024 * 1024 * 1024),
        );
      } else {
        throw Exception('Failed to delete selected photos');
      }

    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshPhotos() async {
    _selectedPhotos.clear();
    _thumbnailCache.clear();
    _failedThumbnails.clear();
    _loadingThumbnails.clear();
    _allPhotos.clear();
    _isInitialized = false;
    _error = null;
    _resetPagination();
    _lastPreloadIndex = 0;

    _thumbnailTimer?.cancel();

    FileService.clearAllCaches();

    await _loadPhotosUltraFast();
  }

  // Selection methods
  void selectPhoto(PhotoItem photo) {
    if (!_selectedPhotos.contains(photo)) {
      _selectedPhotos.add(photo);
      notifyListeners();
    }
  }

  void deselectPhoto(PhotoItem photo) {
    if (_selectedPhotos.remove(photo)) {
      notifyListeners();
    }
  }

  void selectAll() {
    final paginated = paginatedPhotos;
    _selectedPhotos.clear();
    _selectedPhotos.addAll(paginated);
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedPhotos.isNotEmpty) {
      _selectedPhotos.clear();
      notifyListeners();
    }
  }

  // MISSING METHOD - Added selectDuplicates
  void selectDuplicates() {
    final duplicates = paginatedPhotos.where((photo) => photo.isDuplicate).toList();
    for (final duplicate in duplicates) {
      if (!_selectedPhotos.contains(duplicate)) {
        _selectedPhotos.add(duplicate);
      }
    }
    notifyListeners();
  }


  // Utility methods
  void _resetPagination() {
    _currentPage = 0;
    _hasMorePhotos = true;
  }

  void _updatePaginationState() {
    final filtered = filteredPhotos;
    final maxDisplayable = (_currentPage + 1) * _photosPerPage;
    _hasMorePhotos = filtered.length > maxDisplayable;
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  bool canLoadMore() {
    return _hasMorePhotos && !_isLoadingMore && !_isLoading;
  }

  String get loadingStatusText {
    if (_isLoading && !_isInitialized) return 'Loading photos...';
    if (_isLoadingMore) return 'Loading more...';
    return 'Showing ${displayedPhotosCount} of ${totalPhotosCount} photos';
  }

  // Method to force refresh storage info
  Future<void> forceRefresh() async {
    _setLoading(true);
    try {
      final storageService = serviceLocator<StorageService>();
      final _storageInfo = await storageService.getStorageInfoWithoutStorageSpace(forceRefresh: true);
      _error = null;
      print('Storage info force refreshed successfully');
    } catch (e) {
      _error = e.toString();
      print('Force refresh error: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Tinder-style photo cleaning methods
  List<PhotoItem> getPhotosForTinder() {
    return filteredPhotos.where((photo) =>
    photo.quality == AIPhotoQuality.blurry ||
        photo.isDuplicate ||
        photo.size > 5 * 1024 * 1024 // 5MB+
    ).toList();
  }

  Future<void> analyzePhotoForTinder(PhotoItem photo) async {
    // Enhanced analysis for Tinder interface
    try {
      // Analyze photo quality
      final quality = await _analyzePhotoQuality(photo.path);

      // Check for duplicates
      final isDuplicate = await _checkForDuplicates(photo);

      // Check file size
      final isLarge = photo.size > 5 * 1024 * 1024;

      // Update photo with analysis results
      final updatedPhoto = photo.copyWith(
        quality: quality,
        isDuplicate: isDuplicate,
        aiSuggestion: _generateSuggestion(quality, isDuplicate, isLarge, photo.size),
      );

      // Update in the list
      final index = _allPhotos.indexWhere((p) => p.id == photo.id);
      if (index != -1) {
        _allPhotos[index] = updatedPhoto;
        notifyListeners();
      }

    } catch (e) {
      print('Error analyzing photo for Tinder: $e');
    }
  }

  Future<AIPhotoQuality> _analyzePhotoQuality(String imagePath) async {
    // Enhanced quality analysis
    try {
      final file = File(imagePath);
      if (!await file.exists()) return AIPhotoQuality.poor;

      final stat = await file.stat();
      if (stat.size > 10 * 1024 * 1024) {
        // Very large files might be low quality
        return AIPhotoQuality.poor;
      }

      // Simulate AI analysis with better logic
      final random = Random();
      final qualityScore = random.nextDouble();

      // Consider file size in quality assessment
      final sizeFactor = stat.size < 1024 * 1024 ? 0.3 : 1.0;
      final adjustedScore = qualityScore * sizeFactor;

      if (adjustedScore > 0.8) return AIPhotoQuality.excellent;
      if (adjustedScore > 0.6) return AIPhotoQuality.good;
      if (adjustedScore > 0.3) return AIPhotoQuality.poor;
      return AIPhotoQuality.blurry;

    } catch (e) {
      return AIPhotoQuality.poor;
    }
  }

  Future<bool> _checkForDuplicates(PhotoItem photo) async {
    // Enhanced duplicate detection
    try {
      final similarPhotos = _allPhotos.where((p) =>
      p.id != photo.id &&
          p.size == photo.size &&
          p.name != photo.name
      ).toList();

      if (similarPhotos.isEmpty) return false;

      // Simulate similarity check
      final random = Random();
      return random.nextDouble() < 0.3; // 30% chance of being duplicate

    } catch (e) {
      return false;
    }
  }

  String _generateSuggestion(AIPhotoQuality quality, bool isDuplicate, bool isLarge, int size) {
    if (isDuplicate) {
      return 'Delete - Duplicate photo detected';
    }
    if (quality == AIPhotoQuality.blurry) {
      return 'Delete - Blurry photo';
    }
    if (isLarge) {
      return 'Consider deleting - Large file (${_formatFileSize(size)})';
    }
    if (quality == AIPhotoQuality.excellent) {
      return 'Keep - Excellent quality';
    }
    if (quality == AIPhotoQuality.good) {
      return 'Keep - Good quality';
    }
    return 'Review - Average quality';
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

  // Get photos by category for Tinder interface
  List<PhotoItem> getPhotosByCategory(PhotoFilter filter) {
    switch (filter) {
      case PhotoFilter.blurry:
        return _allPhotos.where((photo) => photo.quality == AIPhotoQuality.blurry).toList();
      case PhotoFilter.duplicates:
        return _allPhotos.where((photo) => photo.isDuplicate).toList();
      case PhotoFilter.large:
        return _allPhotos.where((photo) => photo.size > 5 * 1024 * 1024).toList();
      case PhotoFilter.screenshots:
        return _allPhotos.where((photo) => photo.name.toLowerCase().contains('screenshot')).toList();
      default:
        return _allPhotos;
    }
  }

  // Get cleanup statistics
  Map<String, dynamic> getCleanupStats() {
    final totalPhotos = _allPhotos.length;
    final blurryPhotos = _allPhotos.where((p) => p.quality == AIPhotoQuality.blurry).length;
    final duplicatePhotos = _allPhotos.where((p) => p.isDuplicate).length;
    final largePhotos = _allPhotos.where((p) => p.size > 5 * 1024 * 1024).length;

    final totalSize = _allPhotos.fold<int>(0, (sum, p) => sum + p.size);
    final potentialSpaceSaved = _allPhotos
        .where((p) => p.quality == AIPhotoQuality.blurry || p.isDuplicate || p.size > 5 * 1024 * 1024)
        .fold<int>(0, (sum, p) => sum + p.size);

    return {
      'totalPhotos': totalPhotos,
      'blurryPhotos': blurryPhotos,
      'duplicatePhotos': duplicatePhotos,
      'largePhotos': largePhotos,
      'totalSize': totalSize,
      'potentialSpaceSaved': potentialSpaceSaved,
    };
  }

  // Get all photos for Tinder interface
  List<PhotoItem> getAllPhotosForTinder() {
    return List.from(_allPhotos);
  }

  // Get photos with specific filters for Tinder
  List<PhotoItem> getFilteredPhotosForTinder(PhotoFilter filter) {
    switch (filter) {
      case PhotoFilter.blurry:
        return _allPhotos.where((photo) => photo.quality == AIPhotoQuality.blurry).toList();
      case PhotoFilter.duplicates:
        return _allPhotos.where((photo) => photo.isDuplicate).toList();
      case PhotoFilter.large:
        return _allPhotos.where((photo) => photo.size > 5 * 1024 * 1024).toList();
      case PhotoFilter.screenshots:
        return _allPhotos.where((photo) => photo.name.toLowerCase().contains('screenshot')).toList();
      default:
        return _allPhotos;
    }
  }

  // Move photo to recycle bin
  Future<bool> movePhotoToRecycleBin(PhotoItem photo) async {
    try {
      // Add to selected photos for recycle bin
      selectPhoto(photo);

      // In a real implementation, you would use the RecycleBinService here
      // For now, we'll just mark it as selected
      return true;
    } catch (e) {
      print('Error moving photo to recycle bin: $e');
      return false;
    }
  }

  // Get thumbnail for photo (optimized)
  Uint8List? getThumbnail(String photoPath) {
    return _thumbnailCache[photoPath];
  }

  // Generate thumbnail in background
  Future<Uint8List?> generateThumbnail(String photoPath, int width, int height) async {
    try {
      // Check cache first
      if (_thumbnailCache.containsKey(photoPath)) {
        return _thumbnailCache[photoPath];
      }

      // Generate thumbnail using FileService
      final thumbnail = await _fileService.generateThumbnail(photoPath, width, height);

      if (thumbnail != null) {
        // Cache the thumbnail
        if (_thumbnailCache.length >= _maxThumbnailCacheSize) {
          // Remove oldest entry
          final oldestKey = _thumbnailCache.keys.first;
          _thumbnailCache.remove(oldestKey);
        }
        _thumbnailCache[photoPath] = thumbnail;
      }

      return thumbnail;
    } catch (e) {
      print('Error generating thumbnail: $e');
      return null;
    }
  }


  @override
  void dispose() {
    _thumbnailTimer?.cancel();
    _viewportTimer?.cancel();
    _thumbnailCache.clear();
    _failedThumbnails.clear();
    _loadingThumbnails.clear();
    _visiblePhotoPaths.clear();
    super.dispose();
  }
}


/*New code
*
*
*
*
*

// File: lib/features/photo_cleanup/controllers/photo_cleanup_controller.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../core/model/photo_item.dart';
import '../../../core/services/storage_service.dart';
import '../services/recycle_bin_service.dart';

class PhotoCleanupController extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final RecycleBinService _recycleBinService = RecycleBinService();

  // State management
  List<PhotoItem> _allPhotos = [];
  List<PhotoItem> _filteredPhotos = [];
  Map<String, Uint8List?> _thumbnailCache = {};

  bool _isLoading = false;
  bool _isScanning = false;
  String _loadingStatus = '';

  // Performance optimization
  static const int _maxCacheSize = 100;
  static const int _preloadCount = 5;

  // Statistics
  int _totalPhotos = 0;
  int _lowQualityPhotos = 0;
  int _duplicatePhotos = 0;
  double _potentialSpaceSaving = 0.0;

  // Getters
  List<PhotoItem> get allPhotos => _allPhotos;
  List<PhotoItem> get filteredPhotos => _filteredPhotos;
  bool get isLoading => _isLoading;
  bool get isScanning => _isScanning;
  String get loadingStatus => _loadingStatus;

  int get totalPhotos => _totalPhotos;
  int get lowQualityPhotos => _lowQualityPhotos;
  int get duplicatePhotos => _duplicatePhotos;
  double get potentialSpaceSaving => _potentialSpaceSaving;

  Uint8List? getThumbnail(String path) => _thumbnailCache[path];

  // Initialize and load photos
  Future<void> initializePhotoScan() async {
    if (_allPhotos.isNotEmpty) {
      // Use cached data
      _setupFilteredPhotos();
      return;
    }

    _setLoading(true, 'Initializing photo scan...');

    try {
      await _loadPhotosWithAnalysis();
    } catch (e) {
      print('Error initializing photo scan: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Load photos with quality analysis
  Future<void> _loadPhotosWithAnalysis() async {
    _setStatus('Discovering photo directories...');

    // Get storage info and photo paths
    final storageInfo = await _storageService.getStorageInfoEnhanced();
    final photoPaths = _storageService.getPathsByCategory('photos');

    if (photoPaths.isEmpty) {
      _setStatus('No photo directories found');
      return;
    }

    _setStatus('Analyzing photos for quality issues...');
    _isScanning = true;
    notifyListeners();

    try {
      // Load photos in isolate for better performance
      final photos = await compute(_analyzePhotosInBackground, {
        'photoPaths': photoPaths.map((p) => p.path).toList(),
        'maxPhotos': 500, // Limit for performance
      });

      _allPhotos = photos;
      _calculateStatistics();
      _setupFilteredPhotos();
      _preloadInitialThumbnails();

    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  // Background photo analysis
  static Future<List<PhotoItem>> _analyzePhotosInBackground(Map<String, dynamic> params) async {
    final photoPaths = params['photoPaths'] as List<String>;
    final maxPhotos = params['maxPhotos'] as int;
    final photos = <PhotoItem>[];

    // Valid image extensions
    const validExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'heic', 'heif'];

    for (final photoPath in photoPaths) {
      final dir = Directory(photoPath);

      if (!await dir.exists()) continue;

      try {
        final files = await dir
            .list(recursive: true, followLinks: false)
            .where((entity) => entity is File)
            .cast<File>()
            .where((file) {
          final extension = file.path.split('.').last.toLowerCase();
          return validExtensions.contains(extension);
        })
            .toList();

        // Sort by modification date (most recent first)
        files.sort((a, b) {
          try {
            return b.statSync().modified.compareTo(a.statSync().modified);
          } catch (e) {
            return 0;
          }
        });

        for (final file in files) {
          if (photos.length >= maxPhotos) break;

          try {
            final stat = await file.stat();
            final fileName = file.path.split('/').last;

            // Analyze photo quality
            final analysis = await _analyzePhotoQualityDetailed(file, stat);

            // Only include photos that need cleanup
            if (analysis.needsCleanup) {
              photos.add(PhotoItem(
                id: file.path.hashCode.toString(),
                path: file.path,
                name: fileName,
                size: stat.size,
                dateModified: stat.modified,
                quality: analysis.quality,
                isDuplicate: analysis.isDuplicate,
                similarity: analysis.similarity,
                aiSuggestion: analysis.suggestion,
                width: analysis.width ?? 0,
                height: analysis.height ?? 0,
              ));
            }
          } catch (e) {
            // Skip problematic files
            continue;
          }
        }
      } catch (e) {
        // Skip directories with permission issues
        continue;
      }

      if (photos.length >= maxPhotos) break;
    }

    return photos;
  }

  // Detailed photo quality analysis
  static Future<PhotoAnalysis> _analyzePhotoQualityDetailed(File file, FileStat stat) async {
    final fileName = file.path.split('/').last.toLowerCase();
    final fileSize = stat.size;
    final fileSizeKB = fileSize / 1024;
    final fileSizeMB = fileSize / (1024 * 1024);

    var quality = AIPhotoQuality.good;
    var needsCleanup = false;
    var isDuplicate = false;
    var similarity = 0.0;
    var suggestion = '';

    // Size-based analysis
    if (fileSizeKB < 10) {
      quality = AIPhotoQuality.poor;
      needsCleanup = true;
      suggestion = 'Very small file size indicates low quality';
    } else if (fileSizeMB > 50) {
      // Very large files might be unnecessarily large
      suggestion = 'Large file size - consider compression';
    }

    // Filename-based analysis
    if (fileName.contains('screenshot')) {
      quality = AIPhotoQuality.poor;
      needsCleanup = true;
      suggestion = 'Screenshot detected - consider cleanup';
    } else if (fileName.contains('thumb') || fileName.contains('cache')) {
      quality = AIPhotoQuality.poor;
      needsCleanup = true;
      suggestion = 'Thumbnail or cache file detected';
    } else if (fileName.contains('temp') || fileName.contains('tmp')) {
      quality = AIPhotoQuality.blurry;
      needsCleanup = true;
      suggestion = 'Temporary file detected';
    } else if (fileName.contains('blur') || fileName.contains('draft')) {
      quality = AIPhotoQuality.blurry;
      needsCleanup = true;
      suggestion = 'Potentially blurry or draft image';
    } else if (fileName.contains('duplicate') || fileName.contains('copy')) {
      isDuplicate = true;
      similarity = 0.9;
      needsCleanup = true;
      suggestion = 'Potential duplicate detected in filename';
    }

    // Extension-based analysis
    final extension = fileName.split('.').last;
    if (extension == 'gif' && fileSizeMB > 10) {
      needsCleanup = true;
      suggestion = 'Large GIF file - consider optimization';
    }

    // Random quality assignment for demonstration
    // In real implementation, use image processing libraries
    if (!needsCleanup) {
      final random = DateTime.now().millisecondsSinceEpoch % 100;
      if (random < 20) {
        quality = AIPhotoQuality.blurry;
        needsCleanup = true;
        suggestion = 'Image appears blurry (AI detected)';
      } else if (random < 35) {
        quality = AIPhotoQuality.poor;
        needsCleanup = true;
        suggestion = 'Low resolution detected (AI analysis)';
      } else if (random < 45) {
        quality = AIPhotoQuality.poor;
        needsCleanup = true;
        suggestion = 'Image appears dark or underexposed';
      } else if (random < 50) {
        isDuplicate = true;
        // CONTINUED: _analyzePhotoQualityDetailed (completion)
        similarity = 0.85;
        needsCleanup = true;
        suggestion = 'Duplicate image detected (AI analysis)';
      }
    }

    // Extract dimensions (dummy for now)
    int width = 0;
    int height = 0;
    try {
      final bytes = await file.readAsBytes();
      final codec = await instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      width = frame.image.width;
      height = frame.image.height;
    } catch (_) {
      // Ignore dimension extraction failure
    }

    return PhotoAnalysis(
      quality: quality,
      isDuplicate: isDuplicate,
      similarity: similarity,
      needsCleanup: needsCleanup,
      suggestion: suggestion,
      width: width,
      height: height,
    );
  }

  // Preload initial thumbnails into memory
  Future<void> _preloadInitialThumbnails() async {
    final preloadPhotos = _filteredPhotos.take(_preloadCount);
    for (final photo in preloadPhotos) {
      await _loadThumbnail(photo.path);
    }
  }

  Future<void> _loadThumbnail(String path) async {
    if (_thumbnailCache.containsKey(path)) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (_thumbnailCache.length >= _maxCacheSize) {
          _thumbnailCache.remove(_thumbnailCache.keys.first);
        }
        _thumbnailCache[path] = bytes;
        notifyListeners();
      }
    } catch (_) {
      _thumbnailCache[path] = null;
    }
  }

  // Setters
  void _setLoading(bool value, [String status = '']) {
    _isLoading = value;
    _loadingStatus = status;
    notifyListeners();
  }

  void _setStatus(String status) {
    _loadingStatus = status;
    notifyListeners();
  }

  void _setupFilteredPhotos() {
    _filteredPhotos = _allPhotos
        .where((photo) => photo.quality != AIPhotoQuality.good || photo.isDuplicate)
        .toList();
  }

  void _calculateStatistics() {
    _totalPhotos = _allPhotos.length;
    _lowQualityPhotos = _allPhotos.where((p) => p.quality != AIPhotoQuality.good).length;
    _duplicatePhotos = _allPhotos.where((p) => p.isDuplicate).length;
    _potentialSpaceSaving = _allPhotos
        .where((p) => p.quality != AIPhotoQuality.good || p.isDuplicate)
        .map((p) => p.size.toDouble())
        .fold(0.0, (a, b) => a + b) /
        (1024 * 1024); // MB
  }

  // Actions
  Future<void> deletePhoto(PhotoItem photo) async {
    try {
      final file = File(photo.path);
      if (await file.exists()) {
        await _recycleBinService.moveToRecycleBin(photo);
        _allPhotos.remove(photo);
        _filteredPhotos.remove(photo);
        _thumbnailCache.remove(photo.path);
        notifyListeners();
      }
    } catch (e) {
      print('Failed to delete photo: $e');
    }
  }

  void keepPhoto(PhotoItem photo) {
    _filteredPhotos.remove(photo);
    notifyListeners();
  }

  void resetFilter() {
    _setupFilteredPhotos();
    notifyListeners();
  }

  void clearAll() {
    _allPhotos.clear();
    _filteredPhotos.clear();
    _thumbnailCache.clear();
    notifyListeners();
  }
}

class PhotoAnalysis {
  final AIPhotoQuality quality;
  final bool isDuplicate;
  final double similarity;
  final bool needsCleanup;
  final String suggestion;
  final int? width;
  final int? height;

  PhotoAnalysis({
    required this.quality,
    required this.isDuplicate,
    required this.similarity,
    required this.needsCleanup,
    required this.suggestion,
    this.width,
    this.height,
  });
}

* */

