// File: lib/core/services/ai_service.dart
import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

import '../model/cleanup_suggestion.dart';
import '../model/photo_item.dart';

class AIService {
  static const double _blurThreshold = 0.3;
  static const double _duplicateThreshold = 0.85;
  static const int _largeFileThreshold = 10 * 1024 * 1024; // 10MB
  static const int _hugeFileThreshold = 50 * 1024 * 1024; // 50MB

  // Advanced photo quality analysis
  Future<AIPhotoQuality> analyzePhotoQuality(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return AIPhotoQuality.poor;

      // Read image data
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        // Skip very large files for performance
        return AIPhotoQuality.good;
      }

      final image = img.decodeImage(bytes);
      if (image == null) return AIPhotoQuality.poor;

      // Analyze image characteristics
      final blurScore = await _analyzeBlur(image);
      final qualityScore = await _analyzeQuality(image);
      final resolutionScore = _analyzeResolution(image);

      // Combine scores for final quality assessment
      final overallScore = (blurScore * 0.4 + qualityScore * 0.4 + resolutionScore * 0.2);

      if (overallScore > 0.8) return AIPhotoQuality.excellent;
      if (overallScore > 0.6) return AIPhotoQuality.good;
      if (overallScore > 0.3) return AIPhotoQuality.poor;
    return AIPhotoQuality.blurry;

    } catch (e) {
      print('Error analyzing photo quality: $e');
      return AIPhotoQuality.poor;
    }
  }

  // Blur detection using Laplacian variance
  Future<double> _analyzeBlur(img.Image image) async {
    try {
      // Convert to grayscale for blur analysis
      final grayscale = img.grayscale(image);

      // Calculate Laplacian variance (blur indicator)
      double variance = 0;
      int pixelCount = 0;

      for (int y = 1; y < grayscale.height - 1; y++) {
        for (int x = 1; x < grayscale.width - 1; x++) {
          final center = grayscale.getPixel(x, y);
          final left = grayscale.getPixel(x - 1, y);
          final right = grayscale.getPixel(x + 1, y);
          final top = grayscale.getPixel(x, y - 1);
          final bottom = grayscale.getPixel(x, y + 1);

          // Laplacian operator - convert pixels to integers first
          final centerValue = center.r;
          final leftValue = left.r;
          final rightValue = right.r;
          final topValue = top.r;
          final bottomValue = bottom.r;
          
          final laplacian = (4 * centerValue - leftValue - rightValue - topValue - bottomValue).abs();
          variance += laplacian;
          pixelCount++;
        }
      }

      final avgVariance = variance / pixelCount;
      // Normalize blur score (higher variance = less blur)
      return (avgVariance / 255).clamp(0.0, 1.0);

    } catch (e) {
      return 0.5; // Default score
    }
  }

  // Quality analysis based on image characteristics
  Future<double> _analyzeQuality(img.Image image) async {
    try {
      // Analyze color distribution
      final histogram = _calculateHistogram(image);
      final colorVariety = histogram.where((count) => count > 0).length / 256;

      // Analyze contrast
      final contrast = _calculateContrast(image);

      // Analyze brightness
      final brightness = _calculateBrightness(image);

      // Combine factors
      return (colorVariety * 0.4 + contrast * 0.4 + brightness * 0.2);

    } catch (e) {
      return 0.5; // Default score
    }
  }

  // Resolution analysis
  double _analyzeResolution(img.Image image) {
    final totalPixels = image.width * image.height;

    if (totalPixels >= 4000000) return 1.0; // 4MP+
    if (totalPixels >= 2000000) return 0.8; // 2MP+
    if (totalPixels >= 1000000) return 0.6; // 1MP+
    if (totalPixels >= 500000) return 0.4;  // 0.5MP+
    return 0.2; // Low resolution
  }

  // Calculate image histogram
  List<int> _calculateHistogram(img.Image image) {
    final histogram = List<int>.filled(256, 0);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final gray = (pixel.r + pixel.g + pixel.b) ~/ 3;
        histogram[gray]++;
      }
    }

    return histogram;
  }

  // Calculate image contrast
  double _calculateContrast(img.Image image) {
    int minBrightness = 255;
    int maxBrightness = 0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final gray = (pixel.r + pixel.g + pixel.b) ~/ 3;
        minBrightness = min(minBrightness, gray);
        maxBrightness = max(maxBrightness, gray);
      }
    }

    return (maxBrightness - minBrightness) / 255.0;
  }

  // Calculate image brightness
  double _calculateBrightness(img.Image image) {
    int totalBrightness = 0;
    int pixelCount = 0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final gray = (pixel.r + pixel.g + pixel.b) ~/ 3;
        totalBrightness += gray;
        pixelCount++;
      }
    }

    return (totalBrightness / pixelCount) / 255.0;
  }

  // Advanced duplicate detection using perceptual hashing
  Future<bool> detectDuplicate(String imagePath1, String imagePath2) async {
    try {
      final hash1 = await _calculatePerceptualHash(imagePath1);
      final hash2 = await _calculatePerceptualHash(imagePath2);

      if (hash1 == null || hash2 == null) return false;

      final similarity = _calculateHashSimilarity(hash1, hash2);
      return similarity > _duplicateThreshold;

    } catch (e) {
      print('Error detecting duplicates: $e');
      return false;
    }
  }

  // Calculate perceptual hash for image
  Future<String?> _calculatePerceptualHash(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // Resize to 8x8 for hash calculation
      final resized = img.copyResize(image, width: 8, height: 8);
      final grayscale = img.grayscale(resized);

      // Calculate average pixel value
      int totalValue = 0;
      for (int y = 0; y < 8; y++) {
        for (int x = 0; x < 8; x++) {
          final pixel = grayscale.getPixel(x, y);
          totalValue += pixel.r.toInt();
        }
      }
      final average = totalValue ~/ 64;

      // Generate hash
      String hash = '';
      for (int y = 0; y < 8; y++) {
        for (int x = 0; x < 8; x++) {
          final pixel = grayscale.getPixel(x, y);
          hash += pixel.r > average ? '1' : '0';
        }
      }

      return hash;

    } catch (e) {
      return null;
    }
  }

  // Calculate similarity between two hashes
  double _calculateHashSimilarity(String hash1, String hash2) {
    if (hash1.length != hash2.length) return 0.0;

    int differences = 0;
    for (int i = 0; i < hash1.length; i++) {
      if (hash1[i] != hash2[i]) differences++;
    }

    return 1.0 - (differences / hash1.length);
  }

  // Calculate similarity score between two images
  Future<double> calculateSimilarity(String imagePath1, String imagePath2) async {
    try {
      final hash1 = await _calculatePerceptualHash(imagePath1);
      final hash2 = await _calculatePerceptualHash(imagePath2);

      if (hash1 == null || hash2 == null) return 0.0;

      return _calculateHashSimilarity(hash1, hash2);

    } catch (e) {
      return 0.0;
    }
  }

  // Analyze photo for cleanup recommendations
  Future<PhotoAnalysis> analyzePhoto(PhotoItem photo) async {
    try {
      final quality = await analyzePhotoQuality(photo.path);
      final isLarge = photo.size > _largeFileThreshold;
      final isHuge = photo.size > _hugeFileThreshold;
      final isBlurry = quality == AIPhotoQuality.blurry;

      // Generate AI suggestion
      String suggestion = '';
      double confidence = 0.0;

      if (isHuge) {
        suggestion = 'Delete - Extremely large file (${_formatFileSize(photo.size)})';
        confidence = 0.9;
      } else if (isBlurry) {
        suggestion = 'Delete - Blurry photo detected';
        confidence = 0.8;
      } else if (isLarge) {
        suggestion = 'Consider deleting - Large file (${_formatFileSize(photo.size)})';
        confidence = 0.6;
      } else if (quality == AIPhotoQuality.excellent) {
        suggestion = 'Keep - Excellent quality photo';
        confidence = 0.9;
      } else if (quality == AIPhotoQuality.good) {
        suggestion = 'Keep - Good quality photo';
        confidence = 0.7;
      } else {
        suggestion = 'Review - Average quality photo';
        confidence = 0.5;
      }

      return PhotoAnalysis(
        quality: quality,
        isBlurry: isBlurry,
        isLarge: isLarge,
        isHuge: isHuge,
        suggestion: suggestion,
        confidence: confidence,
        estimatedSpaceSaved: isHuge ? photo.size : (isLarge ? photo.size ~/ 2 : 0),
      );

    } catch (e) {
      return PhotoAnalysis(
        quality: AIPhotoQuality.poor,
        isBlurry: false,
        isLarge: false,
        isHuge: false,
        suggestion: 'Error analyzing photo',
        confidence: 0.0,
        estimatedSpaceSaved: 0,
      );
    }
  }

  // Format file size for display
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

  // Generate comprehensive cleanup suggestions
  Future<List<CleanupSuggestion>> generateCleanupSuggestions(List<PhotoItem> photos) async {
    final suggestions = <CleanupSuggestion>[];

    // Analyze each photo
    for (final photo in photos) {
      final analysis = await analyzePhoto(photo);

      if (analysis.isHuge || analysis.isBlurry || analysis.isLarge) {
        suggestions.add(CleanupSuggestion(
          id: photo.id,
          title: analysis.suggestion,
          description: 'Photo analysis completed',
          size: analysis.estimatedSpaceSaved / (1024 * 1024 * 1024), // Convert to GB
          type: CleanupType.photos,
          priority: _getPriority(analysis.confidence),
          itemCount: 1,
        ));
      }
    }

    // Group similar suggestions
    return _groupSimilarSuggestions(suggestions);
  }

  // Get priority based on confidence
  Priority _getPriority(double confidence) {
    if (confidence > 0.8) return Priority.high;
    if (confidence > 0.5) return Priority.medium;
    return Priority.low;
  }

  // Group similar cleanup suggestions
  List<CleanupSuggestion> _groupSimilarSuggestions(List<CleanupSuggestion> suggestions) {
    final grouped = <String, List<CleanupSuggestion>>{};

    for (final suggestion in suggestions) {
      final key = suggestion.title.split(' - ').first;
      grouped.putIfAbsent(key, () => []).add(suggestion);
    }

    return grouped.entries.map((entry) {
      final totalSize = entry.value.fold<double>(0, (sum, s) => sum + s.size);
      final avgPriority = _calculateAveragePriority(entry.value);

      return CleanupSuggestion(
        id: 'group_${entry.key}',
        title: '${entry.key} (${entry.value.length} items)',
        description: 'Grouped cleanup suggestions',
        size: totalSize,
        type: CleanupType.photos,
        priority: avgPriority,
        itemCount: entry.value.length,
      );
    }).toList();
  }

  // Calculate average priority
  Priority _calculateAveragePriority(List<CleanupSuggestion> suggestions) {
    int highCount = 0;
    int mediumCount = 0;
    int lowCount = 0;

    for (final suggestion in suggestions) {
      switch (suggestion.priority) {
        case Priority.high:
          highCount++;
          break;
        case Priority.medium:
          mediumCount++;
          break;
        case Priority.low:
          lowCount++;
          break;
      }
    }

    if (highCount > mediumCount && highCount > lowCount) return Priority.high;
    if (mediumCount > lowCount) return Priority.medium;
    return Priority.low;
  }

  // Legacy method for backward compatibility
  String generatePhotoSuggestion(PhotoItem photo) {
    if (photo.quality == AIPhotoQuality.blurry) {
      return 'Delete - Photo is blurry';
    }
    if (photo.isDuplicate) {
      return 'Delete - Duplicate photo detected';
    }
    if (photo.quality == AIPhotoQuality.excellent) {
      return 'Keep - Excellent quality photo';
    }
    if (photo.quality == AIPhotoQuality.good) {
      return 'Keep - Good quality photo';
    }
    return 'Review - Average quality photo';
  }
}

// Enhanced photo analysis result
class PhotoAnalysis {
  final AIPhotoQuality quality;
  final bool isBlurry;
  final bool isLarge;
  final bool isHuge;
  final String suggestion;
  final double confidence;
  final int estimatedSpaceSaved;

  PhotoAnalysis({
    required this.quality,
    required this.isBlurry,
    required this.isLarge,
    required this.isHuge,
    required this.suggestion,
    required this.confidence,
    required this.estimatedSpaceSaved,
  });
}