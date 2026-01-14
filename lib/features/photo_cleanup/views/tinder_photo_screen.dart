// File: lib/features/photo_cleanup/views/tinder_photo_screen.dart
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:isolate';
import 'dart:async';
import '../../../core/app_theme.dart';
import '../../../core/model/photo_item.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/ui_utils.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../controllers/photo_cleanup_controller.dart';
import '../widgets/tinder_photo_card.dart';
import '../services/recycle_bin_service.dart';

class TinderPhotoScreen extends StatefulWidget {
  const TinderPhotoScreen({super.key});

  @override
  State<TinderPhotoScreen> createState() => _TinderPhotoScreenState();
}

class _TinderPhotoScreenState extends State<TinderPhotoScreen>
    with TickerProviderStateMixin {
  late AnimationController _cardController;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  List<PhotoItem> _photos = [];
  int _currentIndex = 0;
  int _keptCount = 0;
  int _deletedCount = 0;
  int _skippedCount = 0;
  double _totalSpaceSaved = 0.0;
  bool _isLoading = true;
  String _loadingStatus = 'Loading photos...';
  bool _isInitialized = false;

  // Recycle bin service
  late RecycleBinService _recycleBinService;
  late PhotoCleanupController _photoController;

  // Thumbnail cache for fast loading
  final Map<String, Uint8List?> _thumbnailCache = {};
  final Set<String> _preloadingThumbnails = {};

  // Performance optimization
  Timer? _preloadTimer;
  final RootIsolateToken rootIsolateToken = RootIsolateToken.instance!;

  @override
  void initState() {
    super.initState();
    _cardController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _recycleBinService = RecycleBinService();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPhotosInBackground();
    });
  }

  @override
  void dispose() {
    _cardController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _loadPhotosInBackground() async {
    setState(() {
      _isLoading = true;
      _loadingStatus = 'Loading photos...';
    });

    try {
      // Load photos in background isolate
      final photos = await _loadPhotosIsolate();

      if (mounted) {
        setState(() {
          _photos = photos;
          _isLoading = false;
          _updateProgress();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        UIUtils.showErrorSnackBar(context, 'Failed to load photos: $e');
      }
    }
  }

  Future<List<PhotoItem>> _loadPhotosIsolate() async {

    return await compute(_loadPhotosBackground, rootIsolateToken);
  }

  static Future<List<PhotoItem>> _loadPhotosBackground(RootIsolateToken token) async {
    BackgroundIsolateBinaryMessenger.ensureInitialized(token);

    try {
      final storageService = StorageService();
      final storageInfo = await storageService.getStorageInfo(forceRefresh: false);
      final photoPaths = storageService.getPathsByCategory('photos');
      print("Discovered photo paths: ${photoPaths.map((e) => e.path).toList()}");

      final photos = <PhotoItem>[];
      final random = Random();

      // Define valid image extensions
      final validExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'heic'];

      for (final photoPath in photoPaths) {
        final dir = Directory(photoPath.path);

        if (await dir.exists()) {
          final files = await dir
              .list(recursive: true, followLinks: false)
              .where((entity) =>
          entity is File &&
              validExtensions.contains(entity.path.split('.').last.toLowerCase()))
              .cast<File>()
              .toList();

          // Sort by modification date (most recent first)
          files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

          for (final file in files) {
            try {
              final stat = await file.stat();
              final fileName = file.path.split(Platform.pathSeparator).last;

              // Basic quality analysis for filtering
              final quality = _analyzePhotoQuality(file, stat);
              final isDuplicate = _checkForDuplicate(file, photos);

              // Only add photos that are low quality, blurred, duplicates, or large
              if (quality != AIPhotoQuality.good || isDuplicate || stat.size > 5 * 1024 * 1024) {
                photos.add(PhotoItem(
                  id: file.path.hashCode.toString(),
                  path: file.path,
                  name: fileName,
                  size: stat.size,
                  dateModified: stat.modified,
                  quality: quality,
                  isDuplicate: isDuplicate,
                  similarity: isDuplicate ? 0.9 : random.nextDouble() * 0.3,
                  aiSuggestion: _generateAISuggestion(quality, isDuplicate),
                  width: 0,
                  height: 0,
                ));
              }

              if (photos.length >= 100) break; // Limit to 100 for performance
            } catch (e) {
              // Skip problematic files
              continue;
            }
          }
        } else {
          print('Directory does not exist: ${photoPath.path}');
        }

        if (photos.length >= 100) break; // Exit outer loop too
      }

      print('Loaded ${photos.length} photos needing cleanup');
      return photos;
    } catch (e) {
      print('Error loading photos: $e');
      return [];
    }
  }

  // Basic quality analysis
  static AIPhotoQuality _analyzePhotoQuality(File file, FileStat stat) {
    final fileName = file.path.split(Platform.pathSeparator).last.toLowerCase();
    final fileSizeKB = stat.size / 1024;

    // Very small images are likely low quality
    if (fileSizeKB < 10) {
      return AIPhotoQuality.poor;
    }

    // Screenshots and thumbnails
    if (fileName.contains('screenshot') ||
        fileName.contains('thumb') ||
        fileName.contains('cache') ||
        fileName.contains('temp')) {
      return AIPhotoQuality.blurry;
    }

    // Memes and social media images
    if (fileName.contains('meme') ||
        fileName.contains('status') ||
        fileName.contains('story')) {
      return AIPhotoQuality.poor;
    }

    // Random quality assignment for demo (in real app, use image processing)
    final random = Random(file.path.hashCode);
    final qualityRand = random.nextDouble();

    if (qualityRand < 0.4) return AIPhotoQuality.blurry;
    if (qualityRand < 0.7) return AIPhotoQuality.poor;
    return AIPhotoQuality.good;
  }

  // Simple duplicate detection
  static bool _checkForDuplicate(File file, List<PhotoItem> existingPhotos) {
    try {
      final fileName = file.path.split(Platform.pathSeparator).last;
      final stat = file.statSync();

      for (final existing in existingPhotos) {
        if ((stat.size - existing.size).abs() < 1024 && // Within 1KB
            _calculateNameSimilarity(fileName, existing.name) > 0.8) {
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static double _calculateNameSimilarity(String name1, String name2) {
    final set1 = Set.from(name1.toLowerCase().split(''));
    final set2 = Set.from(name2.toLowerCase().split(''));
    final intersection = set1.intersection(set2);
    final union = set1.union(set2);
    return union.isEmpty ? 0 : intersection.length / union.length;
  }

  static String _generateAISuggestion(AIPhotoQuality quality, bool isDuplicate) {
    if (isDuplicate) return 'Duplicate photo detected';

    switch (quality) {
      case AIPhotoQuality.blurry:
        return 'Image appears blurry or out of focus';
      case AIPhotoQuality.poor:
        return 'Low quality or small image';
      default:
        return 'Consider for cleanup';
    }
  }

  void _updateProgress() {
    if (_photos.isNotEmpty) {
      final progress = (_currentIndex + 1) / _photos.length;
      _progressController.animateTo(progress);
    }
  }

  void _onKeep() {
    if (_currentIndex >= _photos.length) return;

    // First animate the card away
    _cardController.forward().then((_) {
      // Then update state after animation completes
      if (mounted) {
        setState(() {
          _keptCount++;
          _currentIndex++;
          _updateProgress();
        });
        // Reset controller for next card
        _cardController.reset();
      }
    });
  }

  void _onDelete() async {
    if (_currentIndex >= _photos.length) return;

    final photo = _photos[_currentIndex];

    // First animate the card away
    _cardController.forward().then((_) async {
      try {
        // For demo paths, just simulate success
        bool success = true;
        if (!photo.path.startsWith('/path/to/')) {
          // Only try to move real files
          success = await _recycleBinService.moveToRecycleBin(photo);
        }

        if (mounted && success) {
          setState(() {
            _deletedCount++;
            _totalSpaceSaved += photo.size / (1024 * 1024 * 1024); // Convert to GB
            _currentIndex++;
            _updateProgress();
          });

          // Show success message
          UIUtils.showSuccessSnackBar(
            context,
            'Photo moved to recycle bin',
          );
        } else if (mounted) {
          UIUtils.showErrorSnackBar(
            context,
            'Failed to move photo to recycle bin',
          );
        }
      } catch (e) {
        if (mounted) {
          UIUtils.showErrorSnackBar(
            context,
            'Failed to move photo: $e',
          );
        }
      } finally {
        // Always reset controller for next card
        if (mounted) {
          _cardController.reset();
        }
      }
    });
  }

  void _onSkip() {
    if (_currentIndex >= _photos.length) return;

    // First animate the card away
    _cardController.forward().then((_) {
      // Then update state after animation completes
      if (mounted) {
        setState(() {
          _skippedCount++;
          _currentIndex++;
          _updateProgress();
        });
        // Reset controller for next card
        _cardController.reset();
      }
    });
  }

  void _onFinish() {
    _showCompletionDialog();
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Session Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Photos reviewed: ${_photos.length}'),
            const SizedBox(height: 8),
            Text('Kept: $_keptCount'),
            Text('Moved to bin: $_deletedCount'),
            Text('Skipped: $_skippedCount'),
            const SizedBox(height: 8),
            Text('Space saved: ${_totalSpaceSaved.toStringAsFixed(2)} GB'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: 'Photo Cleanup',
        actions: [
          if (!_isLoading && _currentIndex < _photos.length)
            TextButton(
              onPressed: _onFinish,
              child: const Text('Finish'),
            ),
        ],
      ),
      body: _isLoading ? _buildLoadingView() : _buildMainContent(),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            _loadingStatus,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        _buildProgressBar(),
        _buildStats(),
        Expanded(
          child: _buildPhotoStack(),
        ),
        _buildInstructions(),
      ],
    );
  }

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                '${_currentIndex + 1}/${_photos.length}',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return LinearProgressIndicator(
                value: _progressAnimation.value,
                backgroundColor: AppTheme.textSecondary.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Kept', _keptCount, AppTheme.successColor),
          _buildStatItem('Moved', _deletedCount, AppTheme.errorColor),
          _buildStatItem('Skipped', _skippedCount, AppTheme.warningColor),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoStack() {
    if (_photos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: AppTheme.textSecondary,
            ),
            SizedBox(height: 16),
            Text(
              'No photos to review',
              style: TextStyle(
                fontSize: 18,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_currentIndex >= _photos.length) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: 64,
              color: AppTheme.successColor,
            ),
            SizedBox(height: 16),
            Text(
              'All photos reviewed!',
              style: TextStyle(
                fontSize: 18,
                color: AppTheme.successColor,
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Background cards - show up to 3 cards behind the current one
        for (int i = _currentIndex + 1; i < _currentIndex + 4 && i < _photos.length; i++)
          Positioned(
            top: (i - _currentIndex) * 10.0,
            left: (i - _currentIndex) * 5.0,
            right: (i - _currentIndex) * 5.0,
            child: Opacity(
              opacity: 1.0 - ((i - _currentIndex) * 0.2),
              child: TinderPhotoCard(
                key: ValueKey('background_${_photos[i].id}'),
                photo: _photos[i],
                onKeep: () {},
                onDelete: () {},
                onSkip: () {},
              ),
            ),
          ),
        // Current card
        TinderPhotoCard(
          key: ValueKey('current_${_photos[_currentIndex].id}'),
          photo: _photos[_currentIndex],
          onKeep: _onKeep,
          onDelete: _onDelete,
          onSkip: _onSkip,
        ),
      ],
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildInstruction('Swipe Left', 'Move to Bin', AppTheme.errorColor),
              _buildInstruction('Tap Skip', 'Skip', AppTheme.warningColor),
              _buildInstruction('Swipe Right', 'Keep', AppTheme.successColor),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Review your photos and decide what to keep or move to recycle bin',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInstruction(String gesture, String action, Color color) {
    return Column(
      children: [
        Icon(
          gesture.contains('Left') ? Icons.swipe_left :
          gesture.contains('Right') ? Icons.swipe_right :
          Icons.touch_app,
          color: color,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          action,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}