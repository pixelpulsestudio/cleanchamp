import 'dart:convert';

class StorageInfo {
  final double totalStorage;
  final double usedStorage;
  final double availableStorage;
  final double usagePercentage;
  final List<StorageCategory> categories;
  final DateTime lastUpdated;
  final bool isScanning;
  final int discoveredPaths;

  StorageInfo({
    required this.totalStorage,
    required this.usedStorage,
    required this.availableStorage,
    required this.usagePercentage,
    required this.categories,
    required this.lastUpdated,
    this.isScanning = false,
    this.discoveredPaths = 0,
  });

  String toJson() {
    return jsonEncode({
      'totalStorage': totalStorage,
      'usedStorage': usedStorage,
      'availableStorage': availableStorage,
      'usagePercentage': usagePercentage,
      'categories': categories.map((c) => c.toMap()).toList(),
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
      'isScanning': isScanning,
      'discoveredPaths': discoveredPaths,
    });
  }

  factory StorageInfo.fromJson(String jsonStr) {
    final map = jsonDecode(jsonStr);
    return StorageInfo(
      totalStorage: map['totalStorage']?.toDouble() ?? 0.0,
      usedStorage: map['usedStorage']?.toDouble() ?? 0.0,
      availableStorage: map['availableStorage']?.toDouble() ?? 0.0,
      usagePercentage: map['usagePercentage']?.toDouble() ?? 0.0,
      categories:
      (map['categories'] as List?)
          ?.map((c) => StorageCategory.fromMap(c))
          .toList() ??
          [],
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(map['lastUpdated'] ?? 0),
      isScanning: map['isScanning'] ?? false,
      discoveredPaths: map['discoveredPaths'] ?? 0,
    );
  }

  StorageInfo copyWith({
    double? totalStorage,
    double? usedStorage,
    double? availableStorage,
    double? usagePercentage,
    List<StorageCategory>? categories,
    DateTime? lastUpdated,
    bool? isScanning,
    int? discoveredPaths,
  }) {
    return StorageInfo(
      totalStorage: totalStorage ?? this.totalStorage,
      usedStorage: usedStorage ?? this.usedStorage,
      availableStorage: availableStorage ?? this.availableStorage,
      usagePercentage: usagePercentage ?? this.usagePercentage,
      categories: categories ?? this.categories,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isScanning: isScanning ?? this.isScanning,
      discoveredPaths: discoveredPaths ?? this.discoveredPaths,
    );
  }
}
class StorageCategory {
  final String name;
  final double size;
  final double percentage;
  final int itemCount;
  final String icon;

  StorageCategory({
    required this.name,
    required this.size,
    required this.percentage,
    required this.itemCount,
    required this.icon,
  });

  String get formattedSize {
    if (size >= 1) {
      return '${size.toStringAsFixed(1)} GB';
    } else if (size >= 0.001) {
      return '${(size * 1024).toStringAsFixed(0)} MB';
    } else {
      return '${(size * 1024 * 1024).toStringAsFixed(0)} KB';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'size': size,
      'percentage': percentage,
      'itemCount': itemCount,
      'icon': icon,
    };
  }

  factory StorageCategory.fromMap(Map<String, dynamic> map) {
    return StorageCategory(
      name: map['name'] ?? '',
      size: map['size']?.toDouble() ?? 0.0,
      percentage: map['percentage']?.toDouble() ?? 0.0,
      itemCount: map['itemCount'] ?? 0,
      icon: map['icon'] ?? '📁',
    );
  }
}