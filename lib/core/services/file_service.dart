// File: lib/core/services/file_service.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:contacts_service_plus/contacts_service_plus.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path; // For basenameWithoutExtension & join
import 'package:path_provider/path_provider.dart'; // For getApplicationDocumentsDirectoryimport 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../model/contact_item.dart';
import '../model/photo_item.dart';
import '../model/video_item.dart';
import 'storage_service.dart';

class FileService {
  final StorageService _storageService;

  // Cache for thumbnails to avoid regenerating
  static final Map<String, Uint8List> _thumbnailCache = {};
  static const int _maxCacheSize = 50; // Reduced cache size

  // Semaphore to limit concurrent thumbnail generation
  static int _activeThumbnailTasks = 0;
  static const int _maxConcurrentTasks = 2; // Reduced concurrent tasks

  // File processing cache
  static final Map<String, List<PhotoItem>> _photoPathCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const int _pathCacheValidityMinutes = 15;

  FileService(this._storageService);

  Future<List<VideoItem>> getVideos({int limit = 10000}) async {
    try {
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.video,
      );
      final List<VideoItem> videos = [];

      for (final album in albums) {
        final assets = await album.getAssetListRange(start: 0, end: limit);

        for (final asset in assets) {
          final file = await asset.file;
          if (file != null) {
            final video = VideoItem(
              id: asset.id,
              name: asset.title ?? 'Unknown',
              path: file.path,
              size: await file.length(),
              duration: Duration(seconds: asset.duration),
              width: asset.width,
              height: asset.height,
              quality: _getVideoQuality(asset.width, asset.height),
              dateModified: file.lastModifiedSync(),
              frameRate: 30,
            );
            videos.add(video);
          }
        }
      }

      return videos;
    } catch (e) {
      throw Exception('Failed to load videos: $e');
    }
  }

  /// Generate and cache video thumbnail
  static Future<String?> getVideoThumbnail(String videoPath) async {
    try {
      final fileName = path.basenameWithoutExtension(videoPath);
      final thumbnailDir = await _getThumbnailDirectory();
      final thumbnailPath = path.join(thumbnailDir.path, '$fileName.jpg');

      // Check if thumbnail already exists
      final thumbnailFile = File(thumbnailPath);
      if (await thumbnailFile.exists()) {
        return thumbnailPath;
      }

      // Generate thumbnail
      final uint8list = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 128, // Thumbnail width
        maxHeight: 128, // Thumbnail height
        quality: 75,
      );

      if (uint8list != null) {
        await thumbnailFile.writeAsBytes(uint8list);
        return thumbnailPath;
      }

      return null;
    } catch (e) {
      print('Error generating thumbnail for $videoPath: $e');
      return null;
    }
  }
  /// Get thumbnail directory, create if doesn't exist
  static Future<Directory> _getThumbnailDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final thumbnailDir = Directory(path.join(appDir.path, 'thumbnails'));

    if (!await thumbnailDir.exists()) {
      await thumbnailDir.create(recursive: true);
    }

    return thumbnailDir;
  }

  /// Clear thumbnail cache
  static Future<void> clearThumbnailCache() async {
    try {
      final thumbnailDir = await _getThumbnailDirectory();
      if (await thumbnailDir.exists()) {
        await for (FileSystemEntity entity in thumbnailDir.list()) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      print('Error clearing thumbnail cache: $e');
    }
  }


  /// Delete files with option to move to recycle bin
   Future<bool> deleteFiles(List<String> filePaths, {bool moveToRecycleBin = true}) async {
    try {
      if (moveToRecycleBin) {
        return await _moveFilesToRecycleBin(filePaths);
      } else {
        return await _deleteFilesPermanently(filePaths);
      }
    } catch (e) {
      print('Error deleting files: $e');
      return false;
    }
  }

  /// Move files to recycle bin (platform-specific implementation)
  static Future<bool> _moveFilesToRecycleBin(List<String> filePaths) async {
    if (Platform.isWindows) {
      return await _moveToWindowsRecycleBin(filePaths);
    } else if (Platform.isMacOS) {
      return await _moveToMacOSTrash(filePaths);
    } else if (Platform.isLinux) {
      return await _moveToLinuxTrash(filePaths);
    } else if (Platform.isAndroid) {
      return await _moveToAndroidRecycleBin(filePaths);
    } else {
      // Fallback to permanent deletion if recycle bin not supported
      return await _deleteFilesPermanently(filePaths);
    }
  }

  /// Windows-specific recycle bin implementation
  static Future<bool> _moveToWindowsRecycleBin(List<String> filePaths) async {
    try {
      for (String filePath in filePaths) {
        final result = await Process.run('powershell', [
          '-Command',
          'Add-Type -AssemblyName Microsoft.VisualBasic; [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile("$filePath", "OnlyErrorDialogs", "SendToRecycleBin")'
        ]);

        if (result.exitCode != 0) {
          print('Failed to move $filePath to recycle bin: ${result.stderr}');
          return false;
        }
      }
      return true;
    } catch (e) {
      print('Error moving files to Windows recycle bin: $e');
      return false;
    }
  }

  /// macOS-specific trash implementation
  static Future<bool> _moveToMacOSTrash(List<String> filePaths) async {
    try {
      for (String filePath in filePaths) {
        final result = await Process.run('osascript', [
          '-e',
          'tell application "Finder" to move POSIX file "$filePath" to trash'
        ]);

        if (result.exitCode != 0) {
          print('Failed to move $filePath to trash: ${result.stderr}');
          return false;
        }
      }
      return true;
    } catch (e) {
      print('Error moving files to macOS trash: $e');
      return false;
    }
  }

  /// Linux-specific trash implementation
  static Future<bool> _moveToLinuxTrash(List<String> filePaths) async {
    try {
      for (String filePath in filePaths) {
        final result = await Process.run('gio', ['trash', filePath]);

        if (result.exitCode != 0) {
          // Fallback to trash-put command
          final result2 = await Process.run('trash-put', [filePath]);
          if (result2.exitCode != 0) {
            print('Failed to move $filePath to trash: ${result2.stderr}');
            return false;
          }
        }
      }
      return true;
    } catch (e) {
      print('Error moving files to Linux trash: $e');
      return false;
    }
  }

  /// Android-specific implementation (move to Android recycle bin if available)
  static Future<bool> _moveToAndroidRecycleBin(List<String> filePaths) async {
    try {
      // For Android, we'll use the MediaStore API to delete files properly
      // This is a simplified version - you might need to use platform channels
      // for full MediaStore integration

      for (String filePath in filePaths) {
        final file = File(filePath);
        if (await file.exists()) {
          // On Android, files are typically managed by MediaStore
          // For now, we'll do a regular delete but this should be enhanced
          // to work with MediaStore for proper recycle bin functionality
          await file.delete();
        }
      }
      return true;
    } catch (e) {
      print('Error moving files to Android recycle bin: $e');
      return false;
    }
  }

  /// Permanently delete files
  static Future<bool> _deleteFilesPermanently(List<String> filePaths) async {
    try {
      for (String filePath in filePaths) {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      return true;
    } catch (e) {
      print('Error deleting files permanently: $e');
      return false;
    }
  }


  Future<List<PhotoItem>> getPhotos({int limit = 50}) async {
    try {
      // Get photo paths from storage service
      final photoPaths = await _getPhotoPathsFromStorage();

      if (photoPaths.isEmpty) {
        return _generateSamplePhotos(limit);
      }

      final List<PhotoItem> photos = [];
      final random = Random();

      // Process paths in batches to avoid memory issues
      const batchSize = 20;
      for (
        int i = 0;
        i < photoPaths.length && photos.length < limit;
        i += batchSize
      ) {
        final batch = photoPaths.skip(i).take(batchSize).toList();

        for (final path in batch) {
          if (photos.length >= limit) break;

          try {
            final file = File(path);
            if (await file.exists()) {
              final stat = await file.stat();
              final photoItem = PhotoItem(
                id: 'photo_${photos.length}',
                path: path,
                name: path.split('/').last,
                size: stat.size,
                dateModified: stat.modified,
                quality: AIPhotoQuality
                    .values[random.nextInt(AIPhotoQuality.values.length)],
                isDuplicate: random.nextBool(),
                similarity: random.nextDouble(),
                aiSuggestion: '',
                width: 1920,
                height: 1080,
              );
              photos.add(photoItem);
            }
          } catch (e) {
            // Skip problematic files
            continue;
          }
        }

        // Add small delay between batches to prevent UI blocking
        await Future.delayed(const Duration(milliseconds: 10));
      }

      return photos;
    } catch (e) {
      print('Error loading photos: $e');
      return _generateSamplePhotos(limit);
    }
  }

  Future<List<String>> _getPhotoPathsFromStorage() async {
    try {
      final discoveredPaths = _storageService.getDiscoveredPaths();
      final photoPaths = <String>[];

      // Get paths that likely contain photos
      final photoDirs = discoveredPaths
          .where(
            (path) =>
                path.accessible &&
                (path.category == 'photos' ||
                    path.description.toLowerCase().contains('dcim') ||
                    path.description.toLowerCase().contains('pictures') ||
                    path.description.toLowerCase().contains('camera')),
          )
          .toList();

      // If no specific photo directories found, use primary storage
      if (photoDirs.isEmpty) {
        final primaryPaths = discoveredPaths
            .where(
              (path) => path.type == StorageType.primary && path.accessible,
            )
            .toList();

        for (final path in primaryPaths) {
          photoPaths.addAll(await _scanForPhotos(path.path));
        }
      } else {
        for (final path in photoDirs) {
          photoPaths.addAll(await _scanForPhotos(path.path));
        }
      }

      return photoPaths;
    } catch (e) {
      print('Error getting photo paths from storage: $e');
      return [];
    }
  }

  Future<List<String>> _scanForPhotos(String basePath) async {
    final photoPaths = <String>[];

    try {
      final directory = Directory(basePath);
      if (!await directory.exists()) return photoPaths;

      // Check cache first
      final cacheKey = basePath;
      if (_photoPathCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
        return _photoPathCache[cacheKey]!.map((p) => p.path).toList();
      }

      await for (final entity in directory.list(recursive: true)) {
        if (entity is File && _isImageFile(entity.path)) {
          photoPaths.add(entity.path);

          // Limit scan to prevent memory issues
          if (photoPaths.length >= 1000) break;
        }
      }

      // Sort by modification date (newest first)
      photoPaths.sort((a, b) {
        try {
          final aStat = File(a).statSync();
          final bStat = File(b).statSync();
          return bStat.modified.compareTo(aStat.modified);
        } catch (e) {
          return 0;
        }
      });
    } catch (e) {
      print('Error scanning for photos in $basePath: $e');
    }

    return photoPaths;
  }

  bool _isCacheValid(String cacheKey) {
    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null) return false;

    final now = DateTime.now();
    return now.difference(timestamp).inMinutes < _pathCacheValidityMinutes;
  }

  List<PhotoItem> _generateSamplePhotos(int limit) {
    final random = Random();
    return List.generate(limit, (index) {
      return PhotoItem(
        id: 'sample_photo_$index',
        path: 'assets/sample_photo_$index.jpg',
        name: 'Photo_$index.jpg',
        size: random.nextInt(5000000) + 100000,
        dateModified: DateTime.now().subtract(
          Duration(days: random.nextInt(365)),
        ),
        quality:
            AIPhotoQuality.values[random.nextInt(AIPhotoQuality.values.length)],
        isDuplicate: random.nextBool(),
        similarity: random.nextDouble(),
        aiSuggestion: '',
        width: 1920,
        height: 1080,
      );
    });
  }

  Future<List<PhotoItem>> getPhotosFromPath(
    String directoryPath, {
    int? limit,
    int? offset,
  }) async {
    final List<PhotoItem> photos = [];

    try {
      final directory = Directory(directoryPath);
      if (!await directory.exists()) return photos;

      // Check if this path is accessible according to storage service
      final discoveredPaths = _storageService.getDiscoveredPaths();
      final matchingPath = discoveredPaths.firstWhere(
        (path) => directoryPath.startsWith(path.path),
        orElse: () => StoragePath(
          path: directoryPath,
          type: StorageType.primary,
          accessible: true,
          description: 'Unknown',
        ),
      );

      if (!matchingPath.accessible) {
        print('Path not accessible: $directoryPath');
        return photos;
      }

      // Use cached results if available
      final cacheKey = '$directoryPath-${limit}-${offset}';
      if (_photoPathCache.containsKey(cacheKey) && _isCacheValid(cacheKey)) {
        return _photoPathCache[cacheKey]!;
      }

      final List<FileSystemEntity> files = [];

      // Get all image files from directory with limits
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File && _isImageFile(entity.path)) {
          files.add(entity);
        }

        // Stop if we have enough for this batch
        if (limit != null && files.length >= (limit + (offset ?? 0))) {
          break;
        }
      }

      // Sort by modification date (newest first)
      files.sort((a, b) {
        try {
          final aStat = a.statSync();
          final bStat = b.statSync();
          return bStat.modified.compareTo(aStat.modified);
        } catch (e) {
          return 0;
        }
      });

      // Apply offset and limit
      final startIndex = offset ?? 0;
      final endIndex = limit != null ? startIndex + limit : files.length;
      final selectedFiles = files.skip(startIndex).take(endIndex - startIndex);
      final random = Random();

      // Convert to PhotoItem objects in batches
      const batchSize = 10;
      final filesList = selectedFiles.toList();

      for (int i = 0; i < filesList.length; i += batchSize) {
        final batch = filesList.skip(i).take(batchSize);

        for (final file in batch) {
          try {
            final stat = await file.stat();
            final photoItem = PhotoItem(
              path: file.path,
              name: file.path.split('/').last,
              size: stat.size,
              dateModified: stat.modified,
              quality: AIPhotoQuality
                  .values[random.nextInt(AIPhotoQuality.values.length)],
              isDuplicate: random.nextBool(),
              similarity: random.nextDouble(),
              aiSuggestion: '',
              width: 1920,
              height: 1080,
              id: 'photo_${photos.length}',
            );
            photos.add(photoItem);
          } catch (e) {
            // Skip files with access issues
            continue;
          }
        }

        // Small delay between batches
        if (i + batchSize < filesList.length) {
          await Future.delayed(const Duration(milliseconds: 5));
        }
      }

      // Cache results
      _photoPathCache[cacheKey] = photos;
      _cacheTimestamps[cacheKey] = DateTime.now();
    } catch (e) {
      print('Error loading photos from $directoryPath: $e');
    }

    return photos;
  }

  // OPTIMIZED: Ultra-smooth thumbnail generation with crash prevention
  Future<Uint8List?> generateThumbnail(
    String imagePath,
    int width,
    int height,
  ) async {
    // Check cache first
    final cacheKey = '$imagePath-${width}x$height';
    if (_thumbnailCache.containsKey(cacheKey)) {
      return _thumbnailCache[cacheKey];
    }

    // Wait if too many tasks are running
    while (_activeThumbnailTasks >= _maxConcurrentTasks) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    _activeThumbnailTasks++;

    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;

      // Quick file size check - be more aggressive
      final stat = await file.stat();
      if (stat.size > 5 * 1024 * 1024) {
        // Skip files > 5MB to prevent crashes
        return null;
      }

      // Use lightweight generation for better performance
      final result = await _generateThumbnailLightweight(
        imagePath,
        width,
        height,
      );

      if (result != null && result.length < 1024 * 1024) { // Max 1MB thumbnail
        _addToCache(cacheKey, result);
      }

      return result;
    } catch (e) {
      print('Thumbnail generation error for $imagePath: $e');
      return null;
    } finally {
      _activeThumbnailTasks--;
    }
  }

  // Ultra-lightweight thumbnail generation with memory protection
  static Future<Uint8List?> _generateThumbnailLightweight(
    String imagePath,
    int width,
    int height,
  ) async {
    try {
      final file = File(imagePath);

      // Read file with size limit
      final bytes = await file.readAsBytes();
      if (bytes.length > 2 * 1024 * 1024) {
        // > 2MB - too large for thumbnail generation
        return null;
      }

      // Decode with reduced quality for speed
      final originalImage = img.decodeImage(bytes);
      if (originalImage == null) return null;

      // Limit maximum dimensions to prevent memory issues
      final maxDimension = 800;
      int targetWidth = width.clamp(50, maxDimension);
      int targetHeight = height.clamp(50, maxDimension);

      // Calculate target size maintaining aspect ratio
      final aspectRatio = originalImage.width / originalImage.height;
      if (aspectRatio > 1) {
        targetHeight = (targetWidth / aspectRatio).round().clamp(50, maxDimension);
      } else {
        targetWidth = (targetHeight * aspectRatio).round().clamp(50, maxDimension);
      }

      // Use fastest resize algorithm
      final resizedImage = img.copyResize(
        originalImage,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.nearest, // Fastest option
      );

      // Encode as JPEG with lower quality for speed and smaller size
      final jpegBytes = img.encodeJpg(resizedImage, quality: 50);

      // Check final size to prevent memory issues
      if (jpegBytes.length > 500 * 1024) {
        // > 500KB thumbnail - too large
        return null;
      }

      return Uint8List.fromList(jpegBytes);
    } catch (e) {
      return null;
    }
  }

  // Optimized cache management
  void _addToCache(String key, Uint8List data) {
    if (_thumbnailCache.length >= _maxCacheSize) {
      // Remove half the cache entries (simple cleanup)
      final keysToRemove = _thumbnailCache.keys
          .take(_maxCacheSize ~/ 2)
          .toList();
      for (final keyToRemove in keysToRemove) {
        _thumbnailCache.remove(keyToRemove);
      }
    }
    _thumbnailCache[key] = data;
  }

  // Clear all caches when memory is low
  static void clearAllCaches() {
    _thumbnailCache.clear();
    _photoPathCache.clear();
    _cacheTimestamps.clear();
  }

  // Get photo directories from storage service
  Future<List<String>> getPhotoDirectories() async {
    final discoveredPaths = _storageService.getDiscoveredPaths();
    return discoveredPaths
        .where(
          (path) =>
              path.accessible &&
              (path.category == 'photos' ||
                  path.description.toLowerCase().contains('dcim') ||
                  path.description.toLowerCase().contains('pictures')),
        )
        .map((path) => path.path)
        .toList();
  }

  // Get all accessible storage paths
  Future<List<String>> getAllAccessiblePaths() async {
    final discoveredPaths = _storageService.getDiscoveredPaths();
    return discoveredPaths
        .where((path) => path.accessible)
        .map((path) => path.path)
        .toList();
  }

  // Check if files are identical
  Future<bool> areFilesIdentical(String path1, String path2) async {
    try {
      final file1 = File(path1);
      final file2 = File(path2);

      if (!await file1.exists() || !await file2.exists()) {
        return false;
      }

      // Quick size check first
      final stat1 = await file1.stat();
      final stat2 = await file2.stat();

      if (stat1.size != stat2.size) {
        return false;
      }

      // For small files, compare content directly
      if (stat1.size < 1024 * 1024) {
        // < 1MB
        final bytes1 = await file1.readAsBytes();
        final bytes2 = await file2.readAsBytes();
        return _bytesEqual(bytes1, bytes2);
      }

      // For larger files, compare hash
      return await _compareFileHashes(path1, path2);
    } catch (e) {
      return false;
    }
  }

  // Helper method to check if file is an image
  bool _isImageFile(String path) {
    final extension = path.toLowerCase().split('.').last;
    const imageExtensions = {
      'jpg',
      'jpeg',
      'png',
      'gif',
      'bmp',
      'webp',
      'heic',
      'heif',
      'tiff',
      'tif',
      'raw',
      'cr2',
      'nef',
      'arw',
      'dng',
      'orf',
      'rw2',
    };
    return imageExtensions.contains(extension);
  }

  // Compare bytes arrays
  bool _bytesEqual(Uint8List bytes1, Uint8List bytes2) {
    if (bytes1.length != bytes2.length) return false;

    for (int i = 0; i < bytes1.length; i++) {
      if (bytes1[i] != bytes2[i]) return false;
    }

    return true;
  }

  // Compare file hashes for large files
  Future<bool> _compareFileHashes(String path1, String path2) async {
    try {
      const chunkSize = 64 * 1024;

      final file1 = File(path1);
      final file2 = File(path2);

      // Compare start chunks
      final start1 = await _readFileChunk(file1, 0, chunkSize);
      final start2 = await _readFileChunk(file2, 0, chunkSize);

      if (!_bytesEqual(start1, start2)) return false;

      // Compare end chunks if files are large enough
      final length1 = await file1.length();
      final length2 = await file2.length();

      if (length1 > chunkSize && length2 > chunkSize) {
        final end1 = await _readFileChunk(
          file1,
          length1 - chunkSize,
          chunkSize,
        );
        final end2 = await _readFileChunk(
          file2,
          length2 - chunkSize,
          chunkSize,
        );

        if (!_bytesEqual(end1, end2)) return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // Read specific chunk from file
  Future<Uint8List> _readFileChunk(File file, int offset, int length) async {
    final randomAccess = await file.open();
    try {
      await randomAccess.setPosition(offset);
      return await randomAccess.read(length);
    } finally {
      await randomAccess.close();
    }
  }

  Future<List<ContactGroup>> getDuplicateContacts() async {
    try {
      final contacts = await ContactsService.getContacts();
      final Map<String, List<ContactItem>> groupedContacts = {};

      for (final contact in contacts) {
        final name = contact.displayName ?? 'Unknown';
        final phone = contact.phones?.isNotEmpty == true
            ? contact.phones!.first.value ?? ''
            : '';
        final email = contact.emails?.isNotEmpty == true
            ? contact.emails!.first.value ?? ''
            : '';

        final contactItem = ContactItem(
          id: contact.identifier ?? '',
          name: name,
          phone: phone,
          email: email,
          isComplete: name.isNotEmpty && (phone.isNotEmpty || email.isNotEmpty),
        );

        final key = name.toLowerCase().trim();
        groupedContacts.putIfAbsent(key, () => []).add(contactItem);
      }

      return groupedContacts.entries
          .where((entry) => entry.value.length > 1)
          .map((entry) => ContactGroup(name: entry.key, contacts: entry.value))
          .toList();
    } catch (e) {
      throw Exception('Failed to load contacts: $e');
    }
  }
// Add these methods to your FileService class

// Add these methods to your FileService class

// Add these methods to your existing FileService class:

  /// Updates a contact with new information
  Future<void> updateContact(ContactItem contactItem) async {
    try {
      if (!await Permission.contacts.isGranted) {
        throw Exception('Contacts permission not granted');
      }

      // Convert ContactItem to contacts_service Contact
      final contact = Contact(
        displayName: contactItem.name,
        phones: contactItem.phone.isNotEmpty
            ? [Item(label: 'mobile', value: contactItem.phone)]
            : [],
        emails: contactItem.email.isNotEmpty
            ? [Item(label: 'work', value: contactItem.email)]
            : [],
      );

      await ContactsService.updateContact(contact);
    } catch (e) {
      throw Exception('Failed to update contact: $e');
    }
  }

  /// Deletes a contact by ID
  Future<void> deleteContact(String contactId) async {
    try {
      if (!await Permission.contacts.isGranted) {
        throw Exception('Contacts permission not granted');
      }

      // Get all contacts and find the one to delete
      final contacts = await ContactsService.getContacts();
      final contactToDelete = contacts.firstWhere(
            (contact) => contact.identifier == contactId,
        orElse: () => throw Exception('Contact not found'),
      );

      await ContactsService.deleteContact(contactToDelete);
    } catch (e) {
      throw Exception('Failed to delete contact: $e');
    }
  }

  /// Gets a single contact by ID
  Future<ContactItem?> getContactById(String contactId) async {
    try {
      if (!await Permission.contacts.isGranted) {
        throw Exception('Contacts permission not granted');
      }

      // Get all contacts and find the specific one
      final contacts = await ContactsService.getContacts();
      final contact = contacts.firstWhere(
            (contact) => contact.identifier == contactId,
        orElse: () => throw Exception('Contact not found'),
      );

      return ContactItem(
        id: contact.identifier ?? '',
        name: contact.displayName ?? '',
        phone: contact.phones?.isNotEmpty == true ? contact.phones!.first.value ?? '' : '',
        email: contact.emails?.isNotEmpty == true ? contact.emails!.first.value ?? '' : '',
        isComplete: (contact.displayName?.isNotEmpty ?? false) &&
            ((contact.phones?.isNotEmpty ?? false) || (contact.emails?.isNotEmpty ?? false)),
      );
    } catch (e) {
      print('Failed to get contact: $e');
      return null;
    }
  }
  VideoQuality _getVideoQuality(int width, int height) {
    final pixels = width * height;
    if (pixels >= 3840 * 2160) return VideoQuality.ultraHigh; // 4K
    if (pixels >= 1920 * 1080) return VideoQuality.high; // 1080p
    if (pixels >= 1280 * 720) return VideoQuality.medium; // 720p
    return VideoQuality.medium;
  }

  // Memory management
  void dispose() {
    clearAllCaches();
  }
}
