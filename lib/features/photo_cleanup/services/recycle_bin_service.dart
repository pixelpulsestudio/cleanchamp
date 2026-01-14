// File: lib/features/photo_cleanup/services/recycle_bin_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/model/photo_item.dart';

class RecycleBinService {
  static const String _recycleBinDir = 'recycle_bin';
  static const String _metadataFile = 'recycle_bin_metadata.json';
  
  late Directory _recycleBinDirectory;
  late File _metadataFileInstance;
  List<RecycleBinItem> _items = [];

  RecycleBinService() {
    _initializeRecycleBin();
  }

  Future<void> _initializeRecycleBin() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _recycleBinDirectory = Directory('${appDir.path}/$_recycleBinDir');
      
      if (!await _recycleBinDirectory.exists()) {
        await _recycleBinDirectory.create(recursive: true);
      }
      
      _metadataFileInstance = File('${_recycleBinDirectory.path}/$_metadataFile');
      await _loadMetadata();
    } catch (e) {
      print('Error initializing recycle bin: $e');
    }
  }

  Future<void> _loadMetadata() async {
    try {
      if (await _metadataFileInstance.exists()) {
        final jsonString = await _metadataFileInstance.readAsString();
        final jsonList = json.decode(jsonString) as List;
        _items = jsonList.map((json) => RecycleBinItem.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error loading recycle bin metadata: $e');
      _items = [];
    }
  }

  Future<void> _saveMetadata() async {
    try {
      final jsonList = _items.map((item) => item.toJson()).toList();
      final jsonString = json.encode(jsonList);
      await _metadataFileInstance.writeAsString(jsonString);
    } catch (e) {
      print('Error saving recycle bin metadata: $e');
    }
  }

  // Move photo to recycle bin
  Future<bool> moveToRecycleBin(PhotoItem photo) async {
    try {
      final sourceFile = File(photo.path);
      if (!await sourceFile.exists()) {
        throw Exception('Source file does not exist');
      }

      // Create unique filename for recycle bin
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${photo.name}';
      final destinationPath = '${_recycleBinDirectory.path}/$fileName';
      final destinationFile = File(destinationPath);

      // Move file to recycle bin
      await sourceFile.copy(destinationPath);
      await sourceFile.delete();

      // Create recycle bin item
      final recycleItem = RecycleBinItem(
        id: photo.id,
        originalPath: photo.path,
        recycleBinPath: destinationPath,
        fileName: fileName,
        originalName: photo.name,
        size: photo.size,
        dateMoved: DateTime.now(),
        type: RecycleBinItemType.photo,
      );

      // Add to metadata
      _items.add(recycleItem);
      await _saveMetadata();

      return true;
    } catch (e) {
      print('Error moving to recycle bin: $e');
      return false;
    }
  }

  // Restore item from recycle bin
  Future<bool> restoreFromRecycleBin(String itemId) async {
    try {
      final item = _items.firstWhere((item) => item.id == itemId);
      final recycleFile = File(item.recycleBinPath);
      
      if (!await recycleFile.exists()) {
        throw Exception('Recycle bin file does not exist');
      }

      // Check if original location is available
      final originalPath = item.originalPath;
      final lastSlashIndex = originalPath.lastIndexOf('/');
      if (lastSlashIndex == -1) {
        throw Exception('Invalid original path');
      }
      
      final originalDir = Directory(originalPath.substring(0, lastSlashIndex));
      if (!await originalDir.exists()) {
        await originalDir.create(recursive: true);
      }

      // Restore file to original location
      await recycleFile.copy(item.originalPath);
      await recycleFile.delete();

      // Remove from metadata
      _items.removeWhere((item) => item.id == itemId);
      await _saveMetadata();

      return true;
    } catch (e) {
      print('Error restoring from recycle bin: $e');
      return false;
    }
  }

  // Permanently delete item from recycle bin
  Future<bool> permanentlyDelete(String itemId) async {
    try {
      final item = _items.firstWhere((item) => item.id == itemId);
      final recycleFile = File(item.recycleBinPath);
      
      if (await recycleFile.exists()) {
        await recycleFile.delete();
      }

      // Remove from metadata
      _items.removeWhere((item) => item.id == itemId);
      await _saveMetadata();

      return true;
    } catch (e) {
      print('Error permanently deleting: $e');
      return false;
    }
  }

  // Empty recycle bin
  Future<bool> emptyRecycleBin() async {
    try {
      // Delete all files in recycle bin
      final files = await _recycleBinDirectory.list().toList();
      for (final file in files) {
        if (file is File && file.path != _metadataFileInstance.path) {
          await file.delete();
        }
      }

      // Clear metadata
      _items.clear();
      await _saveMetadata();

      return true;
    } catch (e) {
      print('Error emptying recycle bin: $e');
      return false;
    }
  }

  // Get all items in recycle bin
  List<RecycleBinItem> getRecycleBinItems() {
    return List.from(_items);
  }

  // Get recycle bin statistics
  Map<String, dynamic> getRecycleBinStats() {
    final totalItems = _items.length;
    final totalSize = _items.fold<int>(0, (sum, item) => sum + item.size);
    final photosCount = _items.where((item) => item.type == RecycleBinItemType.photo).length;
    final videosCount = _items.where((item) => item.type == RecycleBinItemType.video).length;
    final documentsCount = _items.where((item) => item.type == RecycleBinItemType.document).length;

    return {
      'totalItems': totalItems,
      'totalSize': totalSize,
      'photosCount': photosCount,
      'videosCount': videosCount,
      'documentsCount': documentsCount,
      'totalSizeGB': totalSize / (1024 * 1024 * 1024),
    };
  }

  // Check if item exists in recycle bin
  bool isInRecycleBin(String itemId) {
    return _items.any((item) => item.id == itemId);
  }

  // Get item by ID
  RecycleBinItem? getItemById(String itemId) {
    try {
      return _items.firstWhere((item) => item.id == itemId);
    } catch (e) {
      return null;
    }
  }

  // Clean up old items (older than specified days)
  Future<int> cleanupOldItems(int daysOld) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      final oldItems = _items.where((item) => item.dateMoved.isBefore(cutoffDate)).toList();
      
      int deletedCount = 0;
      for (final item in oldItems) {
        final success = await permanentlyDelete(item.id);
        if (success) deletedCount++;
      }
      
      return deletedCount;
    } catch (e) {
      print('Error cleaning up old items: $e');
      return 0;
    }
  }
}

class RecycleBinItem {
  final String id;
  final String originalPath;
  final String recycleBinPath;
  final String fileName;
  final String originalName;
  final int size;
  final DateTime dateMoved;
  final RecycleBinItemType type;

  RecycleBinItem({
    required this.id,
    required this.originalPath,
    required this.recycleBinPath,
    required this.fileName,
    required this.originalName,
    required this.size,
    required this.dateMoved,
    required this.type,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'originalPath': originalPath,
      'recycleBinPath': recycleBinPath,
      'fileName': fileName,
      'originalName': originalName,
      'size': size,
      'dateMoved': dateMoved.toIso8601String(),
      'type': type.name, // Use .name instead of .toString()
    };
  }

  factory RecycleBinItem.fromJson(Map<String, dynamic> json) {
    return RecycleBinItem(
      id: json['id'],
      originalPath: json['originalPath'],
      recycleBinPath: json['recycleBinPath'],
      fileName: json['fileName'],
      originalName: json['originalName'],
      size: json['size'],
      dateMoved: DateTime.parse(json['dateMoved']),
      type: RecycleBinItemType.values.firstWhere(
        (e) => e.name == json['type'], // Use .name instead of .toString()
      ),
    );
  }
}

enum RecycleBinItemType { photo, video, document, other } 