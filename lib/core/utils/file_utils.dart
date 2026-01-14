// File: lib/core/utils/file_utils.dart
import 'dart:math';

import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

class FileUtils {
  static String formatBytes(int bytes, {int decimals = 1}) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  static String formatBytesToGB(double bytes, {int decimals = 1}) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(decimals)} GB';
  }

  static String formatBytesToMB(double bytes, {int decimals = 1}) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(decimals)} MB';
  }
  /// Format date with relative time
  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today ${DateFormat.Hm().format(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${DateFormat.Hm().format(date)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else {
      return DateFormat.yMMMd().format(date);
    }
  }
  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  static String getFileExtension(String fileName) {
    return fileName.contains('.')
        ? '.${fileName.split('.').last.toLowerCase()}'
        : '';
  }

  static bool isImageFile(String fileName) {
    final extension = getFileExtension(fileName);
    return AppConstants.imageExtensions.contains(extension);
  }

  static bool isVideoFile(String fileName) {
    final extension = getFileExtension(fileName);
    return AppConstants.videoExtensions.contains(extension);
  }

  static bool isAudioFile(String fileName) {
    final extension = getFileExtension(fileName);
    return AppConstants.audioExtensions.contains(extension);
  }

  static bool isDocumentFile(String fileName) {
    final extension = getFileExtension(fileName);
    return AppConstants.documentExtensions.contains(extension);
  }
}
