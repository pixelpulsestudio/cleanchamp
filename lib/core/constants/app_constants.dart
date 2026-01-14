class AppConstants {
  // App Info
  static const String appName = 'Phone Cleaner Pro';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'AI-Powered Storage Optimization';

  // Storage
  static const int megabyte = 1024 * 1024;
  static const int gigabyte = 1024 * 1024 * 1024;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
  static const Duration scanAnimation = Duration(seconds: 2);
  static const Duration cleanupAnimation = Duration(seconds: 5);

  // Limits
  static const int maxPhotosPerSession = 50;
  static const int maxVideosToShow = 100;
  static const double similarityThreshold = 0.8;
  static const int largVideoSizeMB = 100;

  // File Extensions
  static const List<String> imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'];
  static const List<String> videoExtensions = ['.mp4', '.avi', '.mov', '.mkv', '.wmv', '.flv'];
  static const List<String> audioExtensions = ['.mp3', '.wav', '.aac', '.flac', '.ogg'];
  static const List<String> documentExtensions = ['.pdf', '.doc', '.docx', '.txt', '.xls', '.xlsx'];
}

