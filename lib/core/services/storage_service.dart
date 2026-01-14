// File: lib/core/services/storage_service.dart
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:disk_space_plus/disk_space_plus.dart';
import 'package:external_path/external_path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storage_space/storage_space.dart';

import '../model/storage_info.dart';


class StorageService {
  static const String _cacheKey = 'storage_cache';
  static const String _lastScanKey = 'last_scan_timestamp';
  static const int _cacheValidityMinutes = 30;
  static const int _backgroundScanIntervalMinutes = 60;

  final Completer<void> _initCompleter = Completer<void>();
  Timer? _backgroundScanTimer;
  StreamController<StorageInfo>? _storageStreamController;
  StorageInfo? _cachedStorageInfo;
  bool _isScanning = false;

  // Dynamic storage paths discovered at runtime
  List<StoragePath> _discoveredPaths = [];
  int _androidSdkVersion = 0;
  String _pathSeparator = '/';

  // File extension mappings for fast categorization
  static const Map<String, String> _extensionCategories = {
    // Photos
    'jpg': 'photos',
    'jpeg': 'photos',
    'png': 'photos',
    'gif': 'photos',
    'bmp': 'photos',
    'webp': 'photos',
    'heic': 'photos',
    'heif': 'photos',
    'tiff': 'photos',
    'tif': 'photos',
    'svg': 'photos',
    'ico': 'photos',
    'raw': 'photos',
    'cr2': 'photos',
    'nef': 'photos',
    'arw': 'photos',
    'dng': 'photos',
    'orf': 'photos',
    'rw2': 'photos',

    // Videos
    'mp4': 'videos',
    'avi': 'videos',
    'mkv': 'videos',
    'mov': 'videos',
    'wmv': 'videos',
    'flv': 'videos',
    '3gp': 'videos',
    '3g2': 'videos',
    'webm': 'videos',
    'mpg': 'videos',
    'mpeg': 'videos',
    'm4v': 'videos',
    'ts': 'videos',
    'mts': 'videos',
    'vob': 'videos',
    'f4v': 'videos',
    'rm': 'videos',
    'rmvb': 'videos',
    'asf': 'videos',

    // Audio
    'mp3': 'audios',
    'wav': 'audios',
    'flac': 'audios',
    'aac': 'audios',
    'ogg': 'audios',
    'wma': 'audios',
    'm4a': 'audios',
    'opus': 'audios',
    'aiff': 'audios',
    'amr': 'audios',
    '3ga': 'audios',
    'ac3': 'audios',
    'ape': 'audios',
    'dts': 'audios',
    'mka': 'audios',
    'mpc': 'audios',
    'ra': 'audios',
    'tta': 'audios',
    'wv': 'audios',

    // Documents
    'pdf': 'documents',
    'doc': 'documents',
    'docx': 'documents',
    'txt': 'documents',
    'rtf': 'documents',
    'xls': 'documents',
    'xlsx': 'documents',
    'ppt': 'documents',
    'pptx': 'documents',
    'odt': 'documents',
    'ods': 'documents',
    'odp': 'documents',
    'csv': 'documents',
    'xml': 'documents',
    'json': 'documents',
    'html': 'documents',
    'htm': 'documents',
    'epub': 'documents',
    'mobi': 'documents',
    'azw': 'documents',
    'fb2': 'documents',
    'djvu': 'documents',
    'cbr': 'documents',
    'cbz': 'documents',
    'md': 'documents',
    'tex': 'documents',
    'log': 'documents',

    // Apps
    'apk': 'apps',
    'aab': 'apps',
    'xapk': 'apps',
    'apks': 'apps',
    'ipa': 'apps',
    'app': 'apps',
    'deb': 'apps',
    'rpm': 'apps',

    // Archives
    'zip': 'others',
    'rar': 'others',
    '7z': 'others',
    'tar': 'others',
    'gz': 'others',
    'bz2': 'others',
    'xz': 'others',
    'lzma': 'others',
    'cab': 'others',
    'iso': 'others',
    'dmg': 'others',
    'img': 'others',
  };

  StorageService() {
    _initialize();
  }

  Future<void> _initialize() async {
    if (_initCompleter.isCompleted) return;

    try {
      await _detectPlatformInfo();
      await _requestPermissions();
      await _discoverStoragePaths();
      await _loadCachedData();
      _startBackgroundScanning();
      _initCompleter.complete();
    } catch (e) {
      _initCompleter.completeError(e);
    }
  }

  Future<void> _detectPlatformInfo() async {
    _pathSeparator = Platform.pathSeparator;

    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      _androidSdkVersion = androidInfo.version.sdkInt;
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Handle different Android versions and their permission requirements
      if (_androidSdkVersion >= 30) {
        // Android 11+ (API 30+) - Request MANAGE_EXTERNAL_STORAGE for full access
        await [Permission.storage, Permission.manageExternalStorage].request();
      } else if (_androidSdkVersion >= 23) {
        // Android 6+ (API 23+) - Standard storage permissions
        await [Permission.storage].request();
      }

      // Request additional permissions for specific directories
      await [Permission.photos, Permission.videos, Permission.audio.request()];
    } else if (Platform.isIOS) {
      await [Permission.photos, Permission.mediaLibrary].request();
    }
  }

  Future<void> _discoverStoragePaths() async {
    _discoveredPaths.clear();

    if (Platform.isAndroid) {
      await _discoverAndroidPaths();
    } else if (Platform.isIOS) {
      await _discoverIOSPaths();
    } else{
      await _discoverAndroidPaths();
    }
  }

  Future<void> _discoverAndroidPaths() async {
    try {
      // Primary external storage (usually /storage/emulated/0)
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        final primaryPath = externalDir.path.split('Android')[0];
        _discoveredPaths.add(
          StoragePath(
            path: primaryPath,
            type: StorageType.primary,
            accessible: true,
            description: 'Internal Storage',
          ),
        );

        print('primary path: $primaryPath');
        // Discover standard directories using ExternalPath
        await _addStandardAndroidPaths(primaryPath);
      }

      // Move these calls outside to avoid concurrent modification
      final initialPathCount = _discoveredPaths.length;
      print('Discovered paths after standard: $initialPathCount');

      // Secondary storage (SD Cards, USB drives) - Create separate list first
      await _discoverSecondaryStorage();

      // App-specific directories
      await _discoverAppSpecificPaths();

      // System directories (with restricted access) - Fix this method too
      await _discoverSystemPaths();

      print('Final discovered paths: ${_discoveredPaths.length}');
      for (int i = 0; i < _discoveredPaths.length; i++) {
        final storage = _discoveredPaths[i];
        print('$i. Path: ${storage.path}, Type: ${storage.type}, Description: ${storage.description}');
      }

    } catch (e) {
      print('Error discovering Android paths: $e');
      // Add fallback paths
      _addFallbackAndroidPaths();
    }
  }

// Fix the system paths discovery to avoid concurrent modification
  Future<void> _discoverSystemPaths() async {
    // Android/data and Android/obb - These require special handling
    final restrictedPaths = [
      'Android${_pathSeparator}data',
      'Android${_pathSeparator}obb',
      'Android${_pathSeparator}media',
      '.android_secure',
    ];

    // Create a separate list to avoid concurrent modification
    final List<StoragePath> systemPaths = [];

    for (final storagePath in _discoveredPaths) {
      if (storagePath.type == StorageType.primary) {
        for (final restrictedPath in restrictedPaths) {
          final fullPath = '${storagePath.path}$restrictedPath';
          final accessible = await _checkRestrictedAccess(fullPath);

          systemPaths.add(
            StoragePath(
              path: fullPath,
              type: StorageType.restricted,
              accessible: accessible,
              description: 'System Directory - ${restrictedPath.split(_pathSeparator).last}',
              requiresSpecialAccess: true,
            ),
          );
        }
      }
    }

    // Add all system paths at once
    _discoveredPaths.addAll(systemPaths);
  }

  Future<void> _addStandardAndroidPaths(String basePath) async {
    try {
      // Use external_path plugin for dynamic path discovery
      final standardPaths = {
        'DCIM': await ExternalPath.getExternalStoragePublicDirectory(
          ExternalPath.DIRECTORY_DCIM,
        ),
        'Pictures': await ExternalPath.getExternalStoragePublicDirectory(
          ExternalPath.DIRECTORY_PICTURES,
        ),
        'Movies': await ExternalPath.getExternalStoragePublicDirectory(
          ExternalPath.DIRECTORY_MOVIES,
        ),
        'Music': await ExternalPath.getExternalStoragePublicDirectory(
          ExternalPath.DIRECTORY_MUSIC,
        ),
        'Documents': await ExternalPath.getExternalStoragePublicDirectory(
          ExternalPath.DIRECTORY_DOCUMENTS,
        ),
        'Download': await ExternalPath.getExternalStoragePublicDirectory(
          ExternalPath.DIRECTORY_DOWNLOAD,
        ),
        'Podcasts': await ExternalPath.getExternalStoragePublicDirectory(
          ExternalPath.DIRECTORY_PODCASTS,
        ),
        'Ringtones': await ExternalPath.getExternalStoragePublicDirectory(
          ExternalPath.DIRECTORY_RINGTONES,
        ),
        'Alarms': await ExternalPath.getExternalStoragePublicDirectory(
          ExternalPath.DIRECTORY_ALARMS,
        ),
        'Notifications': await ExternalPath.getExternalStoragePublicDirectory(
          ExternalPath.DIRECTORY_NOTIFICATIONS,
        ),
      };

      for (final entry in standardPaths.entries) {
        if (entry.value.isNotEmpty) {
          _discoveredPaths.add(
            StoragePath(
              path: entry.value,
              type: StorageType.publicDirectory,
              accessible: true,
              description: entry.key,
              category: _getDirectoryCategory(entry.key),
            ),
          );
        }
      }
    } catch (e) {
      print('Error adding standard Android paths: $e');
    }
  }

// Fix secondary storage discovery to handle permission errors gracefully
  Future<void> _discoverSecondaryStorage() async {
    try {
      // Scan for external SD cards and USB drives
      final mountPoints = [
        '/storage',
        '/mnt',
        '/sdcard',
        '/external_sd',
        '/extSdCard',
      ];

      final List<StoragePath> secondaryPaths = [];

      for (final mountPoint in mountPoints) {
        try {
          final dir = Directory(mountPoint);
          if (await dir.exists()) {
            await for (final entity in dir.list(followLinks: false)) {
              if (entity is Directory) {
                if (await _isExternalStorage(entity.path)) {
                  secondaryPaths.add(
                    StoragePath(
                      path: entity.path,
                      type: StorageType.external,
                      accessible: await _checkDirectoryAccess(entity.path),
                      description: 'External Storage',
                    ),
                  );
                }
              }
            }
          }
        } catch (e) {
          // Skip individual mount points that cause permission errors
          print('Permission denied for mount point $mountPoint: $e');
          continue;
        }
      }

      _discoveredPaths.addAll(secondaryPaths);
    } catch (e) {
      print('Error discovering secondary storage: $e');
    }
  }
  Future<void> _discoverAppSpecificPaths() async {
    try {
      // App-specific external directories
      final appExternalDir = await getExternalStorageDirectory();
      if (appExternalDir != null) {
        _discoveredPaths.add(
          StoragePath(
            path: appExternalDir.path,
            type: StorageType.appSpecific,
            accessible: true,
            description: 'App External Storage',
          ),
        );
      }

      // App cache directories
      final appCacheDir = await getApplicationCacheDirectory();
      _discoveredPaths.add(
        StoragePath(
          path: appCacheDir.path,
          type: StorageType.cache,
          accessible: true,
          description: 'App Cache',
        ),
      );

      // Internal app directories
      final internalDir = await getApplicationDocumentsDirectory();
      _discoveredPaths.add(
        StoragePath(
          path: internalDir.path,
          type: StorageType.internal,
          accessible: true,
          description: 'Internal App Storage',
        ),
      );
    } catch (e) {
      print('Error discovering app-specific paths: $e');
    }
  }


  Future<void> _discoverIOSPaths() async {
    try {
      // iOS sandbox directories
      final documentsDir = await getApplicationDocumentsDirectory();
      final libraryDir = await getLibraryDirectory();
      final tempDir = await getTemporaryDirectory();
      final supportDir = await getApplicationSupportDirectory();

      _discoveredPaths.addAll([
        StoragePath(
          path: documentsDir.path,
          type: StorageType.documents,
          accessible: true,
          description: 'Documents',
        ),
        StoragePath(
          path: libraryDir.path,
          type: StorageType.library,
          accessible: true,
          description: 'Library',
        ),
        StoragePath(
          path: tempDir.path,
          type: StorageType.temp,
          accessible: true,
          description: 'Temporary Files',
        ),
        StoragePath(
          path: supportDir.path,
          type: StorageType.support,
          accessible: true,
          description: 'Application Support',
        ),
      ]);

      // Try to access Photos library (requires permission)
      if (await Permission.photos.isGranted) {
        // Note: iOS Photos library access is handled through PhotoKit API
        // File system access to photos is limited
      }
    } catch (e) {
      print('Error discovering iOS paths: $e');
    }
  }

  void _addFallbackAndroidPaths() {
    // Fallback paths when discovery fails
    _discoveredPaths.addAll([
      StoragePath(
        path: '/storage/emulated/0',
        type: StorageType.primary,
        accessible: true,
        description: 'Internal Storage (Fallback)',
      ),
      StoragePath(
        path: '/sdcard',
        type: StorageType.primary,
        accessible: true,
        description: 'SD Card (Fallback)',
      ),
    ]);
  }

  Future<bool> _isExternalStorage(String path) async {
    try {
      // Check if it's a real external storage (not symlink or internal)
      final directory = Directory(path);
      final stat = await directory.stat();

      // Basic heuristics to identify external storage
      return !path.contains('emulated') &&
          !path.contains('self') &&
          path != '/storage/emulated/0' &&
          await directory.exists();
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkDirectoryAccess(String path) async {
    try {
      final directory = Directory(path);
      if (!await directory.exists()) return false;

      // Try to list directory contents
      await directory.list(followLinks: false).take(1).toList();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkRestrictedAccess(String path) async {
    if (_androidSdkVersion >= 30) {
      // Android 11+ - Check if we have MANAGE_EXTERNAL_STORAGE permission
      final hasPermission = await Permission.manageExternalStorage.isGranted;
      if (!hasPermission) return false;
    }

    return await _checkDirectoryAccess(path);
  }

  String _getDirectoryCategory(String dirName) {
    switch (dirName.toLowerCase()) {
      case 'dcim':
      case 'pictures':
        return 'photos';
      case 'movies':
        return 'videos';
      case 'music':
      case 'podcasts':
      case 'ringtones':
      case 'alarms':
      case 'notifications':
        return 'audios';
      case 'documents':
        return 'documents';
      case 'download':
        return 'others';
      default:
        return 'others';
    }
  }

  Stream<StorageInfo> get storageStream {
    _storageStreamController ??= StreamController<StorageInfo>.broadcast();
    return _storageStreamController!.stream;
  }

  Future<StorageInfo> getStorageInfo({bool forceRefresh = false}) async {
    await _initCompleter.future;

    // Return cached data immediately if available and valid
    if (!forceRefresh && _cachedStorageInfo != null && await _isCacheValid()) {
      return _cachedStorageInfo!;
    }

    // If scanning is in progress, wait for it or return cached data
    if (_isScanning) {
      return _cachedStorageInfo ?? await _getBasicStorageInfo();
    }

    // Start scanning in background and return basic info immediately
    _scanStorageInBackground();

    return _cachedStorageInfo ?? await _getBasicStorageInfo();
  }

  // Enhanced method to get storage info with better error handling
  Future<StorageInfo> getStorageInfoEnhanced({bool forceRefresh = false}) async {
    try {
      await _initCompleter.future;

      // Return cached data immediately if available and valid
      if (!forceRefresh && _cachedStorageInfo != null && await _isCacheValid()) {
        print('Returning cached storage info');
        return _cachedStorageInfo!;
      }

      print('Calculating fresh storage info...');
      final storageInfo = await _getBasicStorageInfo();

      // Cache the result
      _cachedStorageInfo = storageInfo;
      await _cacheData(storageInfo);

      return storageInfo;
    } catch (e) {
      print('Error in getStorageInfoEnhanced: $e');
      // Clear cache and try again with fallback
      await clearCache();
      return await _getFallbackStorageInfo();
    }
  }

  // Method to force refresh storage info
  Future<StorageInfo> forceRefreshStorageInfo() async {
    try {
      await clearCache();
      return await getStorageInfoEnhanced(forceRefresh: true);
    } catch (e) {
      print('Error in forceRefreshStorageInfo: $e');
      return await _getFallbackStorageInfo();
    }
  }

  // Method to get storage info without using storage_space package
  Future<StorageInfo> getStorageInfoWithoutStorageSpace({bool forceRefresh = false}) async {
    try {
      await _initCompleter.future;

      // Return cached data immediately if available and valid
      if (!forceRefresh && _cachedStorageInfo != null && await _isCacheValid()) {
        print('Returning cached storage info');
        return _cachedStorageInfo!;
      }

      print('Calculating storage info without storage_space package...');

      // Use only disk_space_plus and fallback methods
      final totalStorage = await _getTotalStorageWithoutStorageSpace();
      final availableStorage = await _getAvailableStorageWithoutStorageSpace();
      final usedStorage = max(0.0, totalStorage - availableStorage);
      final usagePercentage = totalStorage > 0 ? (usedStorage / totalStorage) * 100 : 0;

      final storageInfo = StorageInfo(
        totalStorage: totalStorage,
        usedStorage: usedStorage,
        availableStorage: availableStorage,
        usagePercentage: usagePercentage.toDouble(),
        categories: await _getDefaultCategories(),
        lastUpdated: DateTime.now(),
        isScanning: _isScanning,
        discoveredPaths: _discoveredPaths.length,
      );

      // Cache the result
      _cachedStorageInfo = storageInfo;
      await _cacheData(storageInfo);

      return storageInfo;
    } catch (e) {
      print('Error in getStorageInfoWithoutStorageSpace: $e');
      return await _getFallbackStorageInfo();
    }
  }
  // Method to force refresh storage info


  // Method to get storage info without using storage_space package

  Future<double> _getTotalStorageWithoutStorageSpace() async {
    try {
      // Method 1: Using disk_space_plus package
      try {
        DiskSpacePlus diskSpacePlus = DiskSpacePlus();
        final totalSpace = await diskSpacePlus.getTotalDiskSpace;
        if (totalSpace != null && totalSpace > 0) {
          final totalStorage = totalSpace / (1024 * 1024 * 1024); // Convert to GB
          print('Total storage (disk_space_plus): ${totalStorage.toStringAsFixed(2)} GB');
          return totalStorage;
        }
      } catch (e) {
        print('disk_space_plus failed: $e');
      }

      // Method 2: Using fallback
      final fallbackInfo = await _getBasicStorageInfoFallback();
      final totalStorage = fallbackInfo['total']!;
      print('Total storage (fallback): ${totalStorage.toStringAsFixed(2)} GB');
      return totalStorage;

    } catch (e) {
      print('Error getting total storage: $e');
      return 64.0; // Reasonable fallback
    }
  }

  Future<double> _getAvailableStorageWithoutStorageSpace() async {
    try {
      // Method 1: Using disk_space_plus package
      try {
        DiskSpacePlus diskSpacePlus = DiskSpacePlus();
        final freeSpace = await diskSpacePlus.getFreeDiskSpace;
        if (freeSpace != null && freeSpace > 0) {
          final availableStorage = freeSpace / (1024 * 1024 * 1024); // Convert to GB
          print('Available storage (disk_space_plus): ${availableStorage.toStringAsFixed(2)} GB');
          return availableStorage;
        }
      } catch (e) {
        print('disk_space_plus failed: $e');
      }

      // Method 2: Using fallback
      final fallbackInfo = await _getBasicStorageInfoFallback();
      final availableStorage = fallbackInfo['available']!;
      print('Available storage (fallback): ${availableStorage.toStringAsFixed(2)} GB');
      return availableStorage;

    } catch (e) {
      print('Error getting available storage: $e');
      return 32.0; // Reasonable fallback
    }
  }
  Future<StorageInfo> _getBasicStorageInfo() async {
    try {
      final totalStorage = await _getTotalStorage();
      final availableStorage = await _getAvailableStorage();
      final usedStorage = totalStorage - availableStorage;
      final usagePercentage = totalStorage > 0 ? (usedStorage / totalStorage) * 100 : 0;

      print('Storage calculation (final):');
      print('- Total: ${totalStorage.toStringAsFixed(2)} GB');
      print('- Used: ${usedStorage.toStringAsFixed(2)} GB');
      print('- Available: ${availableStorage.toStringAsFixed(2)} GB');
      print('- Usage: ${usagePercentage.toStringAsFixed(1)}%');

      // Validate the calculations
      if (totalStorage <= 0) {
        throw Exception('Invalid total storage: $totalStorage');
      }
      if (usedStorage < 0) {
        throw Exception('Invalid used storage: $usedStorage');
      }
      if (availableStorage < 0) {
        throw Exception('Invalid available storage: $availableStorage');
      }

      return StorageInfo(
        totalStorage: totalStorage,
        usedStorage: usedStorage,
        availableStorage: availableStorage,
        usagePercentage: usagePercentage.toDouble(),
        categories: await _getDefaultCategories(),
        lastUpdated: DateTime.now(),
        isScanning: _isScanning,
        discoveredPaths: _discoveredPaths.length,
      );
    } catch (e) {
      throw Exception('Failed to get basic storage info: $e');
    }
  }
  Future<StorageInfo> _getFallbackStorageInfo() async {
    print('Using fallback storage info');
    return StorageInfo(
      totalStorage: 64.0,
      usedStorage: 32.0,
      availableStorage: 32.0,
      usagePercentage: 50.0,
      categories: await _getDefaultCategories(),
      lastUpdated: DateTime.now(),
      isScanning: _isScanning,
      discoveredPaths: _discoveredPaths.length,
    );
  }

  // Helper method to safely parse storage strings
  double _parseStorageString(String storageString, String type) {
    try {
      // Remove any whitespace
      final cleanString = storageString.trim();

      // Try to parse as integer
      final result = double.tryParse(cleanString);

      if (result == null) {
        print('Warning: Failed to parse $type storage string: "$storageString"');
        return 0;
      }

      if (result < 0) {
        print('Warning: Negative $type storage value: $result');
        return 0;
      }

      return result;
    } catch (e) {
      print('Error parsing $type storage string "$storageString": $e');
      return 0;
    }
  }
  // Fixed storage calculation methods using multiple approaches
  Future<double> _getTotalStorage() async {
    try {
      //if (Platform.isAndroid || Platform.isIOS) {
        final storageSpace = await getStorageSpace(lowOnSpaceThreshold: 2 * 1024 * 1024, fractionDigits: 1);
        final totalBytesString = storageSpace.totalSize;
        final totalBytes = _parseStorageString(totalBytesString, 'total');
        final totalGB = totalBytes / (1024 * 1024 * 1024);

        print('Total storage parsing:');
        print('- Raw string: "$totalBytesString"');
        print('- Parsed bytes: $totalBytes');
        print('- Converted GB: ${totalGB.toStringAsFixed(2)}');

        return totalBytes > 0 ? totalGB : 64.0; // Fallback if parsing fails
     // }
      return 64.0;
    } catch (e) {
      print('Error getting total storage: $e');
      return 64.0;
    }
  }


  Future<double> _getAvailableStorage() async {
    try {
      //if (Platform.isAndroid || Platform.isIOS) {
        final storageSpace = await getStorageSpace(lowOnSpaceThreshold: 2 * 1024 * 1024, fractionDigits: 1);
        final freeBytesString = storageSpace.freeSize;
        final freeBytes = _parseStorageString(freeBytesString, 'free');
        final freeGB = freeBytes / (1024 * 1024 * 1024);

        print('Available storage parsing:');
        print('- Raw string: "$freeBytesString"');
        print('- Parsed bytes: $freeBytes');
        print('- Converted GB: ${freeGB.toStringAsFixed(2)}');

        return freeBytes > 0 ? freeGB : 32.0; // Fallback if parsing fails
      //}
      return 32.0;
    } catch (e) {
      print('Error getting available storage: $e');
      return 32.0;
    }
  }

  // Android-specific storage calculation using system commands
  Future<Map<String, int>?> _getAndroidStorageInfo() async {
    try {
      // This would require platform-specific implementation
      // For now, return null to use other methods
      return null;
    } catch (e) {
      return null;
    }
  }

  // Fallback method using basic file system operations
  Future<Map<String, double>> _getBasicStorageInfoFallback() async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        // Get basic directory info
        final stat = await directory.stat();

        // Estimate storage based on available space patterns
        // This is a rough estimate but better than nothing
        final estimatedTotal = 64.0; // GB
        final estimatedAvailable = 32.0; // GB

        return {
          'total': estimatedTotal,
          'available': estimatedAvailable,
        };
      }
    } catch (e) {
      print('Basic storage fallback failed: $e');
    }

    // Return default values
    return {
      'total': 64.0,
      'available': 32.0,
    };
  }

  void _scanStorageInBackground() {
    if (_isScanning) return;

    _isScanning = true;
    _performFullScan()
        .then((storageInfo) {
      _cachedStorageInfo = storageInfo;
      _storageStreamController?.add(storageInfo);
      _cacheData(storageInfo);
      _isScanning = false;
    })
        .catchError((error) {
      _isScanning = false;
      print('Background scan error: $error');
    });
  }

  Future<StorageInfo> _performFullScan() async {
    final receivePort = ReceivePort();

    try {
      // Prepare scan data for isolate
      final scanData = ScanData(
        paths: _discoveredPaths,
        extensionCategories: _extensionCategories,
        pathSeparator: _pathSeparator,
        androidSdkVersion: _androidSdkVersion,
      );

      // Use isolate for heavy file system operations
      await Isolate.spawn(_scanIsolate, {
        'sendPort': receivePort.sendPort,
        'scanData': scanData.toMap(),
      });

      final isolateResult = await receivePort.first as Map<String, dynamic>;
      receivePort.close();

      final totalStorage = await _getTotalStorage();
      final availableStorage = await _getAvailableStorage();
      final usedStorage = totalStorage - availableStorage;

      final categories = _processIsolateResult(isolateResult, usedStorage);

      return StorageInfo(
        totalStorage: totalStorage,
        usedStorage: usedStorage,
        availableStorage: availableStorage,
        usagePercentage: (usedStorage / totalStorage) * 100,
        categories: categories,
        lastUpdated: DateTime.now(),
        isScanning: false,
        discoveredPaths: _discoveredPaths.length,
      );
    } catch (e) {
      receivePort.close();
      return await _getBasicStorageInfo();
    }
  }

  static void _scanIsolate(Map<String, dynamic> data) async {
    final sendPort = data['sendPort'] as SendPort;

    try {
      final scanData = ScanData.fromMap(
        data['scanData'] as Map<String, dynamic>,
      );
      final result = await _scanFileSystemDynamic(scanData);
      sendPort.send(result);
    } catch (e) {
      sendPort.send({'error': e.toString()});
    }
  }

  static Future<Map<String, dynamic>> _scanFileSystemDynamic(
      ScanData scanData,
      ) async {
    final Map<String, CategoryData> categories = {
      'photos': CategoryData(),
      'videos': CategoryData(),
      'audios': CategoryData(),
      'apps': CategoryData(),
      'documents': CategoryData(),
      'others': CategoryData(),
    };

    // Scan each discovered path
    for (final storagePath in scanData.paths) {
      if (!storagePath.accessible) continue;

      try {
        await _scanStoragePath(storagePath, categories, scanData);
      } catch (e) {
        print('Error scanning ${storagePath.path}: $e');
        continue;
      }
    }

    return {
      'photos': categories['photos']!.toMap(),
      'videos': categories['videos']!.toMap(),
      'audios': categories['audios']!.toMap(),
      'apps': categories['apps']!.toMap(),
      'documents': categories['documents']!.toMap(),
      'others': categories['others']!.toMap(),
    };
  }

  static Future<void> _scanStoragePath(
      StoragePath storagePath,
      Map<String, CategoryData> categories,
      ScanData scanData,
      ) async {
    final directory = Directory(storagePath.path);
    if (!await directory.exists()) return;

    try {
      // Handle restricted directories differently
      if (storagePath.requiresSpecialAccess) {
        await _scanRestrictedDirectory(directory, categories, scanData);
        return;
      }

      // Regular directory scanning
      await _scanDirectoryRecursive(directory, categories, scanData, 0, 3);
    } catch (e) {
      // Skip directories with permission issues
      print('Permission denied for ${storagePath.path}');
    }
  }

  static Future<void> _scanRestrictedDirectory(
      Directory directory,
      Map<String, CategoryData> categories,
      ScanData scanData,
      ) async {
    try {
      // For Android/data and Android/obb, we need special handling
      if (scanData.androidSdkVersion >= 30) {
        // Android 11+ - Limited access even with MANAGE_EXTERNAL_STORAGE
        await _scanDirectoryShallow(directory, categories, scanData);
      } else {
        // Older Android versions
        await _scanDirectoryRecursive(directory, categories, scanData, 0, 2);
      }
    } catch (e) {
      // Silently handle restricted access
    }
  }

  static Future<void> _scanDirectoryShallow(
      Directory directory,
      Map<String, CategoryData> categories,
      ScanData scanData,
      ) async {
    await for (final entity in directory.list(recursive: false)) {
      if (entity is File) {
        await _categorizeFile(entity, categories, scanData);
      } else if (entity is Directory) {
        // Get directory size without recursing
        final size = await _estimateDirectorySize(entity);
        categories['others']!.addFile(size, 1);
      }
    }
  }

  static Future<void> _scanDirectoryRecursive(
      Directory directory,
      Map<String, CategoryData> categories,
      ScanData scanData,
      int currentDepth,
      int maxDepth,
      ) async {
    if (currentDepth > maxDepth) return;

    await for (final entity in directory.list(recursive: false)) {
      if (entity is File) {
        await _categorizeFile(entity, categories, scanData);
      } else if (entity is Directory) {
        // Skip system directories and hidden directories
        final dirName = entity.path.split(scanData.pathSeparator).last;
        if (dirName.startsWith('.') || _isSystemDirectory(dirName)) {
          continue;
        }

        await _scanDirectoryRecursive(
          entity,
          categories,
          scanData,
          currentDepth + 1,
          maxDepth,
        );
      }
    }
  }

  static Future<void> _categorizeFile(
      File file,
      Map<String, CategoryData> categories,
      ScanData scanData,
      ) async {
    try {
      final stat = await file.stat();
      final sizeInBytes = stat.size;
      final sizeInGB = sizeInBytes / (1024 * 1024 * 1024);

      final fileName = file.path.split(scanData.pathSeparator).last;
      final extension = fileName.contains('.')
          ? fileName.split('.').last.toLowerCase()
          : '';

      final category = scanData.extensionCategories[extension] ?? 'others';
      categories[category]!.addFile(sizeInGB, 1);
    } catch (e) {
      // Skip files with access issues
    }
  }

  static Future<double> _estimateDirectorySize(Directory directory) async {
    try {
      // Quick size estimation without deep recursion
      double size = 0;
      int fileCount = 0;

      await for (final entity in directory.list(recursive: false)) {
        if (entity is File) {
          final stat = await entity.stat();
          size += stat.size;
          fileCount++;

          // Limit the number of files we check for performance
          if (fileCount > 100) break;
        }
      }

      // Estimate total size based on sample
      return (size / (1024 * 1024 * 1024)) * (fileCount > 100 ? 10 : 1);
    } catch (e) {
      return 0.0;
    }
  }

  static bool _isSystemDirectory(String dirName) {
    final systemDirs = {
      'Android',
      '.android_secure',
      'LOST.DIR',
      '.thumbnails',
      '.trashed',
      'System Volume Information',
      'RECYCLE.BIN',
      '.Spotlight-V100',
      '.Trashes',
      '.fseventsd',
    };
    return systemDirs.contains(dirName);
  }

  List<StorageCategory> _processIsolateResult(
      Map<String, dynamic> result,
      double totalUsedStorage,
      ) {
    final categories = <StorageCategory>[];
    double accountedStorage = 0;

    for (final entry in result.entries) {
      if (entry.key == 'error') continue;

      final categoryData = entry.value as Map<String, dynamic>;
      final size = categoryData['size'] as double;
      final count = categoryData['count'] as int;

      accountedStorage += size;

      categories.add(
        StorageCategory(
          name: _getCategoryDisplayName(entry.key),
          size: size,
          percentage: totalUsedStorage > 0
              ? (size / totalUsedStorage) * 100
              : 0,
          itemCount: count,
          icon: _getCategoryIcon(entry.key),
        ),
      );
    }

    // Add system/unaccounted storage as "System"
    final systemStorage = max(0.0, totalUsedStorage - accountedStorage);
    if (systemStorage > 0) {
      categories.add(
        StorageCategory(
          name: 'System',
          size: systemStorage,
          percentage: (systemStorage / totalUsedStorage) * 100,
          itemCount: 0,
          icon: '⚙️',
        ),
      );
    }

    // Sort by size descending
    categories.sort((a, b) => b.size.compareTo(a.size));

    return categories;
  }

  String _getCategoryDisplayName(String key) {
    switch (key) {
      case 'photos':
        return 'Photos';
      case 'videos':
        return 'Videos';
      case 'audios':
        return 'Music';
      case 'apps':
        return 'Apps';
      case 'documents':
        return 'Documents';
      case 'others':
        return 'Others';
      default:
        return key;
    }
  }

  String _getCategoryIcon(String key) {
    switch (key) {
      case 'photos':
        return '📷';
      case 'videos':
        return '🎬';
      case 'audios':
        return '🎵';
      case 'apps':
        return '📱';
      case 'documents':
        return '📄';
      case 'others':
        return '📦';
      default:
        return '📁';
    }
  }

  Future<List<StorageCategory>> _getDefaultCategories() async {
    return [
      StorageCategory(
        name: 'Photos',
        size: 0,
        percentage: 0,
        itemCount: 0,
        icon: '📷',
      ),
      StorageCategory(
        name: 'Videos',
        size: 0,
        percentage: 0,
        itemCount: 0,
        icon: '🎬',
      ),
      StorageCategory(
        name: 'Music',
        size: 0,
        percentage: 0,
        itemCount: 0,
        icon: '🎵',
      ),
      StorageCategory(
        name: 'Apps',
        size: 0,
        percentage: 0,
        itemCount: 0,
        icon: '📱',
      ),
      StorageCategory(
        name: 'Documents',
        size: 0,
        percentage: 0,
        itemCount: 0,
        icon: '📄',
      ),
      StorageCategory(
        name: 'Others',
        size: 0,
        percentage: 0,
        itemCount: 0,
        icon: '📦',
      ),
    ];
  }

  void _startBackgroundScanning() {
    _backgroundScanTimer?.cancel();
    _backgroundScanTimer = Timer.periodic(
      Duration(minutes: _backgroundScanIntervalMinutes),
          (_) => _scanStorageInBackground(),
    );
  }

  Future<bool> _isCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastScan = prefs.getInt(_lastScanKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final isValid = (now - lastScan) < (_cacheValidityMinutes * 60 * 1000);

      print('Cache validation: ${isValid ? 'valid' : 'expired'} (${(now - lastScan) / 1000 / 60} minutes old)');
      return isValid;
    } catch (e) {
      print('Error checking cache validity: $e');
      return false;
    }
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_cacheKey);
      if (cachedData != null && await _isCacheValid()) {
        _cachedStorageInfo = StorageInfo.fromJson(cachedData);
      }
    } catch (e) {
      print('Failed to load cached data: $e');
    }
  }

  Future<void> _cacheData(StorageInfo storageInfo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, storageInfo.toJson());
      await prefs.setInt(_lastScanKey, DateTime.now().millisecondsSinceEpoch);
      print('Storage data cached successfully');
    } catch (e) {
      print('Failed to cache data: $e');
    }
  }

  // Method to clear cache when there are issues
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_lastScanKey);
      _cachedStorageInfo = null;
      print('Storage cache cleared');
    } catch (e) {
      print('Failed to clear cache: $e');
    }
  }

  Future<double> calculateCleanupPotential() async {
    await _initCompleter.future;

    double cleanupPotential = 0.0;

    try {
      // Cache files
      for (final storagePath in _discoveredPaths) {
        if (storagePath.type == StorageType.cache ||
            storagePath.type == StorageType.temp) {
          final size = await _getDirectorySize(Directory(storagePath.path));
          cleanupPotential += size;
        }
      }

      // Large files analysis (files > 100MB)
      cleanupPotential += await _analyzeLargeFiles();

      // App cache estimation
      cleanupPotential += await _analyzeAppCache();

      return cleanupPotential;
    } catch (e) {
      return 0.0;
    }
  }

  Future<double> _analyzeLargeFiles() async {
    double largeFilesSize = 0.0;

    for (final storagePath in _discoveredPaths) {
      if (!storagePath.accessible) continue;

      try {
        final directory = Directory(storagePath.path);
        await for (final entity in directory.list(recursive: true)) {
          if (entity is File) {
            final stat = await entity.stat();
            if (stat.size > 100 * 1024 * 1024) {
              // Files > 100MB
              largeFilesSize += stat.size / (1024 * 1024 * 1024);
            }
          }
        }
      } catch (e) {
        continue;
      }
    }

    return largeFilesSize * 0.3; // Estimate 30% of large files can be cleaned
  }

  Future<double> _analyzeAppCache() async {
    double appCacheSize = 0.0;

    try {
      // App-specific cache directories
      for (final storagePath in _discoveredPaths) {
        if (storagePath.type == StorageType.cache) {
          appCacheSize += await _getDirectorySize(Directory(storagePath.path));
        }
      }

      // System cache estimation
      appCacheSize += await _estimateSystemCache();
    } catch (e) {
      print('Error analyzing app cache: $e');
    }

    return appCacheSize;
  }

  Future<double> _estimateSystemCache() async {
    // Estimate system cache based on device usage patterns
    final totalStorage = await _getTotalStorage();
    return totalStorage * 0.05; // Estimate 5% of storage as system cache
  }

  Future<double> _getDirectorySize(Directory directory) async {
    double size = 0;
    try {
      if (!await directory.exists()) return 0;

      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          final stat = await entity.stat();
          size += stat.size / (1024 * 1024 * 1024); // Convert to GB
        }
      }
    } catch (e) {
      // Handle permission errors
    }
    return size;
  }

  Future<void> optimizeStorage() async {
    // Implement storage optimization features
    // - Clear cache files
    // - Remove duplicates
    // - Compress large files
    // - Clean temp files

    for (final storagePath in _discoveredPaths) {
      if (storagePath.type == StorageType.cache ||
          storagePath.type == StorageType.temp) {
        await _cleanCacheDirectory(storagePath.path);
      }
    }
  }

  Future<void> _cleanCacheDirectory(String path) async {
    try {
      final directory = Directory(path);
      if (!await directory.exists()) return;

      await for (final entity in directory.list()) {
        if (entity is File) {
          // Check if file is safe to delete (older than 7 days)
          final stat = await entity.stat();
          final lastModified = stat.modified;
          final now = DateTime.now();

          if (now.difference(lastModified).inDays > 7) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      print('Error cleaning cache directory $path: $e');
    }
  }

  // Get list of discovered storage paths for debugging/info
  List<StoragePath> getDiscoveredPaths() => _discoveredPaths;

  // Check if specific path type is available
  bool hasStorageType(StorageType type) {
    return _discoveredPaths.any((path) => path.type == type);
  }

  // Get paths by category
  List<StoragePath> getPathsByCategory(String category) {
    return _discoveredPaths.where((path) => path.category == category).toList();
  }

  void dispose() {
    _backgroundScanTimer?.cancel();
    _storageStreamController?.close();
  }
}

// Supporting classes for dynamic path discovery

class StoragePath {
  final String path;
  final StorageType type;
  final bool accessible;
  final String description;
  final String? category;
  final bool requiresSpecialAccess;

  StoragePath({
    required this.path,
    required this.type,
    required this.accessible,
    required this.description,
    this.category,
    this.requiresSpecialAccess = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'type': type.toString(),
      'accessible': accessible,
      'description': description,
      'category': category,
      'requiresSpecialAccess': requiresSpecialAccess,
    };
  }

  factory StoragePath.fromMap(Map<String, dynamic> map) {
    return StoragePath(
      path: map['path'],
      type: StorageType.values.firstWhere((e) => e.toString() == map['type']),
      accessible: map['accessible'],
      description: map['description'],
      category: map['category'],
      requiresSpecialAccess: map['requiresSpecialAccess'] ?? false,
    );
  }
}

enum StorageType {
  primary, // Main internal storage
  external, // SD cards, USB drives
  publicDirectory, // DCIM, Pictures, etc.
  appSpecific, // App's external directory
  internal, // App's internal directory
  cache, // Cache directories
  temp, // Temporary directories
  restricted, // Android/data, Android/obb
  documents, // Documents directory (iOS)
  library, // Library directory (iOS)
  support, // Application Support (iOS)
}

class ScanData {
  final List<StoragePath> paths;
  final Map<String, String> extensionCategories;
  final String pathSeparator;
  final int androidSdkVersion;

  ScanData({
    required this.paths,
    required this.extensionCategories,
    required this.pathSeparator,
    required this.androidSdkVersion,
  });

  Map<String, dynamic> toMap() {
    return {
      'paths': paths.map((p) => p.toMap()).toList(),
      'extensionCategories': extensionCategories,
      'pathSeparator': pathSeparator,
      'androidSdkVersion': androidSdkVersion,
    };
  }

  factory ScanData.fromMap(Map<String, dynamic> map) {
    return ScanData(
      paths: (map['paths'] as List).map((p) => StoragePath.fromMap(p)).toList(),
      extensionCategories: Map<String, String>.from(map['extensionCategories']),
      pathSeparator: map['pathSeparator'],
      androidSdkVersion: map['androidSdkVersion'],
    );
  }
}

class CategoryData {
  double size = 0.0;
  int count = 0;

  void addFile(double fileSize, int fileCount) {
    size += fileSize;
    count += fileCount;
  }

  Map<String, dynamic> toMap() {
    return {'size': size, 'count': count};
  }
}

// File: lib/core/model/storage_info.dart




// File: pubspec.yaml additions
/*
dependencies:
  device_info_plus: ^10.1.0
  path_provider: ^2.1.1
  shared_preferences: ^2.2.2
  disk_space: ^0.2.1
  permission_handler: ^11.0.1
  external_path: ^1.0.3
*/
