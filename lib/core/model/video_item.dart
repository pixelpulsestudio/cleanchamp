// File: lib/core/models/video_item.dart
class VideoItem {
  final String id;
  final String path;
  final String name;
  final int size;
  final DateTime dateModified;
  final Duration duration;
  final VideoQuality quality;
  final int width;
  final int height;
  final int frameRate;

  VideoItem({
    required this.id,
    required this.path,
    required this.name,
    required this.size,
    required this.dateModified,
    required this.duration,
    required this.quality,
    required this.width,
    required this.height,
    required this.frameRate,
  });

  VideoItem copyWith({
    String? id,
    String? path,
    String? name,
    int? size,
    DateTime? dateModified,
    Duration? duration,
    VideoQuality? quality,
    int? width,
    int? height,
    int? frameRate,
  }) {
    return VideoItem(
      id: id ?? this.id,
      path: path ?? this.path,
      name: name ?? this.name,
      size: size ?? this.size,
      dateModified: dateModified ?? this.dateModified,
      duration: duration ?? this.duration,
      quality: quality ?? this.quality,
      width: width ?? this.width,
      height: height ?? this.height,
      frameRate: frameRate ?? this.frameRate,
    );
  }
}

enum VideoQuality { hd4k, hd1080p, hd720p, sd480p, sd360p, ultraHigh, high, medium }
