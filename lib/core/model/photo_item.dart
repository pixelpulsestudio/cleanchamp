// File: lib/core/models/photo_item.dart
class PhotoItem {
  final String id;
  final String path;
  final String name;
  final int size;
  final DateTime dateModified;
  final AIPhotoQuality quality;
  late final bool isDuplicate;
  final double similarity;
  final String aiSuggestion;
  final int width;
  final int height;

  PhotoItem({
    required this.id,
    required this.path,
    required this.name,
    required this.size,
    required this.dateModified,
    required this.quality,
    required this.isDuplicate,
    required this.similarity,
    required this.aiSuggestion,
    required this.width,
    required this.height,
  });

  PhotoItem copyWith({
    String? id,
    String? path,
    String? name,
    int? size,
    DateTime? dateModified,
    AIPhotoQuality? quality,
    bool? isDuplicate,
    double? similarity,
    String? aiSuggestion,
    int? width,
    int? height,
  }) {
    return PhotoItem(
      id: id ?? this.id,
      path: path ?? this.path,
      name: name ?? this.name,
      size: size ?? this.size,
      dateModified: dateModified ?? this.dateModified,
      quality: quality ?? this.quality,
      isDuplicate: isDuplicate ?? this.isDuplicate,
      similarity: similarity ?? this.similarity,
      aiSuggestion: aiSuggestion ?? this.aiSuggestion,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}

enum AIPhotoQuality { excellent, good, poor, blurry }
enum PhotoFilter {
  all,
  duplicates,
  large,
  blurry,
  screenshots,
}