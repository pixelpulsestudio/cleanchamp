// File: lib/features/video_cleanup/controllers/video_cleanup_controller.dart
import 'package:flutter/material.dart';
import '../../../core/model/video_item.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/file_service.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/constants/app_constants.dart';

class VideoCleanupController extends ChangeNotifier {
  final FileService _fileService = serviceLocator<FileService>();
  final AnalyticsService _analyticsService = serviceLocator<AnalyticsService>();

  List<VideoItem> _videos = [];
  List<VideoItem> _selectedVideos = [];
  bool _isLoading = false;
  bool _isDeleting = false;
  String? _error;
  int _currentPage = 0;
  static const int _pageSize = 20;
  bool _hasMoreVideos = true;
  final Map<String, String?> _thumbnailCache = {};

  List<VideoItem> get videos => _videos;
  List<VideoItem> get selectedVideos => _selectedVideos;
  bool get isLoading => _isLoading;
  bool get isDeleting => _isDeleting;
  String? get error => _error;
  bool get hasMoreVideos => _hasMoreVideos;
  int get totalSize => _videos.fold(0, (sum, video) => sum + video.size);
  int get selectedSize => _selectedVideos.fold(0, (sum, video) => sum + video.size);

  String? getThumbnail(String videoPath) => _thumbnailCache[videoPath];

  Future<void> initialize() async {
    await _analyticsService.trackScreenView('video_cleanup');
    await loadVideos(refresh: true);
  }

  Future<void> loadVideos({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 0;
      _videos.clear();
      _hasMoreVideos = true;
      _thumbnailCache.clear();
    }

    if (!_hasMoreVideos || _isLoading) return;

    _setLoading(true);
    try {
      final newVideos = await _fileService.getVideos(
        limit: _pageSize,
      );

      if (newVideos.length < _pageSize) {
        _hasMoreVideos = false;
      }

      if (refresh) {
        _videos = newVideos;
      } else {
        _videos.addAll(newVideos);
      }

      // Sort by size (largest first) only on refresh
      if (refresh) {
        _videos.sort((a, b) => b.size.compareTo(a.size));
      }

      _currentPage++;
      _error = null;

      // Load thumbnails in background
      _loadThumbnailsInBackground(newVideos);
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadThumbnailsInBackground(List<VideoItem> videos) async {
    for (final video in videos) {
      if (!_thumbnailCache.containsKey(video.path)) {
        try {
          final thumbnail = await FileService.getVideoThumbnail(video.path);
          _thumbnailCache[video.path] = thumbnail;
          notifyListeners(); // Update UI when thumbnail is loaded
        } catch (e) {
          _thumbnailCache[video.path] = null; // Mark as failed
        }
      }
    }
  }

  Future<void> refreshThumbnail(String videoPath) async {
    try {
      final thumbnail = await FileService.getVideoThumbnail(videoPath);
      _thumbnailCache[videoPath] = thumbnail;
      notifyListeners();
    } catch (e) {
      _thumbnailCache[videoPath] = null;
    }
  }

  void selectVideo(VideoItem video) {
    if (!_selectedVideos.contains(video)) {
      _selectedVideos.add(video);
      notifyListeners();
    }
  }

  void deselectVideo(VideoItem video) {
    _selectedVideos.remove(video);
    notifyListeners();
  }

  void toggleVideoSelection(VideoItem video) {
    if (_selectedVideos.contains(video)) {
      deselectVideo(video);
    } else {
      selectVideo(video);
    }
  }

  void selectAll() {
    _selectedVideos = List.from(_videos);
    notifyListeners();
  }

  void clearSelection() {
    _selectedVideos.clear();
    notifyListeners();
  }

  void selectLargeVideos() {
    _selectedVideos = _videos
        .where((video) => video.size > AppConstants.largVideoSizeMB * AppConstants.megabyte)
        .toList();
    notifyListeners();
  }

  void selectOldVideos() {
    final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 180));
    _selectedVideos = _videos
        .where((video) => video.dateModified.isBefore(sixMonthsAgo))
        .toList();
    notifyListeners();
  }

  void selectByQuality(String quality) {
    _selectedVideos = _videos
        .where((video) => video.quality.name.toLowerCase() == quality.toLowerCase())
        .toList();
    notifyListeners();
  }

  Future<bool> deleteSelectedVideos({bool moveToRecycleBin = true}) async {
    if (_selectedVideos.isEmpty) return false;

    _setDeleting(true);
    try {
      final filePaths = _selectedVideos.map((video) => video.path).toList();
      final success = await _fileService.deleteFiles(
        filePaths,
      );

      if (success) {
        await _analyticsService.trackCleanupAction(
          'videos',
          _selectedVideos.length,
          selectedSize / (1024 * 1024 * 1024),
        );

        // Remove deleted videos from list and cache
        for (final video in _selectedVideos) {
          _videos.remove(video);
          _thumbnailCache.remove(video.path);
        }
        _selectedVideos.clear();
        _error = null;
        return true;
      } else {
        _error = 'Failed to delete some videos';
        return false;
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setDeleting(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setDeleting(bool deleting) {
    _isDeleting = deleting;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _thumbnailCache.clear();
    super.dispose();
  }
}